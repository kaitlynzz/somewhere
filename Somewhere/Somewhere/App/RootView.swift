//
//  RootView.swift
//  Somewhere — decides what the app opens to.
//
//  First launch: Muskaan's onboarding (splash → sign up → walkthrough).
//  After that: the wishlist + shelf tabs.
//

import SwiftUI
import AuthenticationServices

struct RootView: View {
    @AppStorage("somewhere.isLoggedIn") private var isLoggedIn = false
    @AppStorage("somewhere.userEmail") private var userEmail = ""

    var body: some View {
        content
            .task {
                // Muskaan: hash any old plain-text passwords into the Keychain,
                // and sign out if someone stopped using Sign in with Apple for us.
                AccountStore.migrateLegacyPasswords()
                if await !AccountStore.appleCredentialIsValid() { isLoggedIn = false }
            }
            .onReceive(NotificationCenter.default.publisher(
                for: ASAuthorizationAppleIDProvider.credentialRevokedNotification)) { _ in
                AccountStore.signOut()
                isLoggedIn = false
            }
    }

    @ViewBuilder
    private var content: some View {
        if isLoggedIn {
            MainTabView()
        } else {
            OnboardingFlow { result in
                result.save()
                userEmail = result.userEmail
                // The waiting period picked in onboarding becomes the shelf's setting
                // (stored in the App Group, so the Share Extension uses it too).
                ShelfSettings.coolingDays = result.coolingDays
                withAnimation { isLoggedIn = true }
            }
        }
    }
}
