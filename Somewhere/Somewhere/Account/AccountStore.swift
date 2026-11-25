//
//  AccountStore.swift
//  Somewhere — on-device accounts (Muskaan).
//
//  • Email + password: the password is never stored. We keep a salted
//    PBKDF2 hash in the Keychain and compare hashes at sign-in.
//  • Sign in with Apple: Apple handles the password. We keep the Apple user ID
//    (and the name/email Apple sends only on the very first sign-up).
//  • Everything stays on this phone. There is no server or database.
//

import Foundation
import AuthenticationServices
import CommonCrypto
import SwiftData
import UserNotifications

struct Account: Codable, Equatable {
    enum Kind: String, Codable { case email, apple }

    var kind: Kind
    /// The email address for email accounts, Apple's stable user ID for Apple accounts.
    var id: String
    var email: String?
    var name: String?

    /// What the settings screen shows.
    var displayName: String {
        if let email, !email.isEmpty { return email }
        if let name, !name.isEmpty { return name }
        return "your Apple ID"
    }
}

enum AccountError: LocalizedError {
    case alreadyExists, notFound, wrongPassword, couldNotSave

    var errorDescription: String? {
        switch self {
        case .alreadyExists: "An account with this email already exists. Tap below to sign in."
        case .notFound:      "No account found for this email. Tap below to sign up."
        case .wrongPassword: "Incorrect password. Please try again."
        case .couldNotSave:  "Couldn't save your account on this phone. Please try again."
        }
    }
}

enum AccountStore {

    // Keychain keys
    private static let currentKey = "current"
    private static func passwordKey(_ email: String) -> String { "password.\(email)" }
    private static func appleKey(_ userID: String) -> String { "apple.\(userID)" }

    /// The legacy, plain-text passwords the first version kept in UserDefaults.
    private static let legacyPrefix = "account_pwd_"

    private struct PasswordRecord: Codable {
        var salt: Data
        var hash: Data
    }

    /// Who is signed in on this phone, if anyone.
    static var current: Account? {
        Keychain.value(Account.self, for: currentKey)
    }

    static func normalized(_ email: String) -> String {
        email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Email + password

    static func signUp(email rawEmail: String, password: String) throws -> Account {
        let email = normalized(rawEmail)
        guard Keychain.data(for: passwordKey(email)) == nil else { throw AccountError.alreadyExists }
        guard storePassword(password, for: email) else { throw AccountError.couldNotSave }
        let account = Account(kind: .email, id: email, email: email, name: nil)
        Keychain.set(account, for: currentKey)
        return account
    }

    static func signIn(email rawEmail: String, password: String) throws -> Account {
        let email = normalized(rawEmail)
        guard let record = Keychain.value(PasswordRecord.self, for: passwordKey(email)) else {
            throw AccountError.notFound
        }
        guard derive(password, salt: record.salt) == record.hash else { throw AccountError.wrongPassword }
        let account = Account(kind: .email, id: email, email: email, name: nil)
        Keychain.set(account, for: currentKey)
        return account
    }

    // MARK: Sign in with Apple

    /// Apple sends the name and email only the first time someone signs up,
    /// so keep them, and reuse them on later sign-ins.
    static func signInWithApple(_ credential: ASAuthorizationAppleIDCredential) -> Account {
        let saved = Keychain.value(Account.self, for: appleKey(credential.user))
        let name = credential.fullName.flatMap {
            PersonNameComponentsFormatter.localizedString(from: $0, style: .default)
        }.flatMap { $0.isEmpty ? nil : $0 }

        let account = Account(
            kind: .apple,
            id: credential.user,
            email: credential.email ?? saved?.email,
            name: name ?? saved?.name
        )
        Keychain.set(account, for: appleKey(credential.user))
        Keychain.set(account, for: currentKey)
        return account
    }

    /// Signs out if the person stopped using Sign in with Apple for this app
    /// (Settings → their name → Sign in with Apple). Returns false when signed out.
    static func appleCredentialIsValid() async -> Bool {
        guard let account = current, account.kind == .apple else { return true }
        let state = await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: account.id) { state, _ in
                continuation.resume(returning: state)
            }
        }
        switch state {
        case .revoked, .notFound:
            signOut()
            return false
        default:
            return true
        }
    }

    // MARK: Sign out / delete

    /// Keeps the account and saved items; just forgets who is signed in.
    static func signOut() {
        Keychain.delete(currentKey)
        UserDefaults.standard.set(false, forKey: "somewhere.isLoggedIn")
    }

    /// Deletes the signed-in account and everything saved on this phone.
    @MainActor
    static func deleteAccount(in context: ModelContext) {
        // 1. The account itself
        if let account = current {
            switch account.kind {
            case .email: Keychain.delete(passwordKey(account.id))
            case .apple: Keychain.delete(appleKey(account.id))
            }
        }
        Keychain.delete(currentKey)

        // 2. Saved items and voice notes
        let items = (try? context.fetch(FetchDescriptor<SavedItem>())) ?? []
        items.forEach { context.delete($0) }
        try? context.save()
        try? FileManager.default.removeItem(at: AppGroup.voiceNotesDirectory)

        // 3. Reminders and preferences
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        ShelfSettings.store.removeObject(forKey: "somewhere.coolingDays")
        UserDefaults.standard.removeObject(forKey: "somewhere.coolingDays")
        UserDefaults.standard.removeObject(forKey: "somewhere.onboardingResult")
        UserDefaults.standard.removeObject(forKey: "somewhere.userEmail")
        UserDefaults.standard.set(false, forKey: "somewhere.isLoggedIn")
    }

    // MARK: Moving old accounts out of UserDefaults

    /// The first version stored passwords as plain text in UserDefaults.
    /// Hash each one into the Keychain and delete the plain-text copy.
    static func migrateLegacyPasswords() {
        let defaults = UserDefaults.standard
        for (key, value) in defaults.dictionaryRepresentation() where key.hasPrefix(legacyPrefix) {
            let email = normalized(String(key.dropFirst(legacyPrefix.count)))
            if let password = value as? String,
               !email.isEmpty,
               Keychain.data(for: passwordKey(email)) == nil {
                storePassword(password, for: email)
            }
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: Hashing

    @discardableResult
    private static func storePassword(_ password: String, for email: String) -> Bool {
        var salt = Data(count: 16)
        let ok = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        guard ok == errSecSuccess else { return false }
        return Keychain.set(PasswordRecord(salt: salt, hash: derive(password, salt: salt)),
                            for: passwordKey(email))
    }

    /// PBKDF2-SHA256, 100k rounds.
    private static func derive(_ password: String, salt: Data) -> Data {
        var out = Data(count: 32)
        let passwordBytes = Array(password.utf8)
        out.withUnsafeMutableBytes { outBytes in
            salt.withUnsafeBytes { saltBytes in
                _ = CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBytes.map { Int8(bitPattern: $0) }, passwordBytes.count,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 100_000,
                    outBytes.bindMemory(to: UInt8.self).baseAddress, 32
                )
            }
        }
        return out
    }
}
