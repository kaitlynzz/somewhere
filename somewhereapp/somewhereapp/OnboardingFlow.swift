//
//  OnboardingFlow.swift
//  somewhereapp
//
//  Created by Muskaan Bajaj on 11/10/26.
//

import SwiftUI

// onboarding result payload saved locally
struct OnboardingResult: Codable, Equatable {
    var userEmail: String
    var places: [String]
    var coolingDays: Int

    private static let key = "somewhere.onboardingResult"

    // persist user choices to local app memory
    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
    }
}

// state manager handling navigation, validation, and local auth recall
@MainActor
@Observable
final class OnboardingModel {
    enum Phase {
        case splash
        case auth
        case walkthrough
    }

    var phase: Phase = .splash
    var activePage: Int = 1
    var email = ""
    var password = ""
    var isSigningUp = true
    var errorMessage: String? = nil
    
    var places: Set<String> = ["clothes", "room", "gifts", "beauty", "tech"]
    var coolingDays = 3

    // email regex format check
    var isEmailValid: Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // password length check (8+ chars)
    var isPasswordValid: Bool {
        password.count >= 8
    }

    // combined form validity check
    var isFormValid: Bool {
        isEmailValid && isPasswordValid
    }

    func completeSplash() {
        withAnimation(.easeInOut(duration: 0.4)) {
            phase = .auth
        }
    }

    func completeAuth() {
        errorMessage = nil

        guard isEmailValid else {
            errorMessage = "Please enter a valid email address."
            return
        }

        guard isPasswordValid else {
            errorMessage = "Password must be at least 8 characters."
            return
        }

        let formattedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let accountKey = "account_pwd_\(formattedEmail)"

        if isSigningUp {
            // save new user credentials locally
            UserDefaults.standard.set(password, forKey: accountKey)
            withAnimation(.snappy(duration: 0.35)) { phase = .walkthrough }
        } else {
            // verify password matches saved account
            if let savedPassword = UserDefaults.standard.string(forKey: accountKey) {
                if savedPassword == password {
                    withAnimation(.snappy(duration: 0.35)) { phase = .walkthrough }
                } else {
                    errorMessage = "Incorrect password. Please try again."
                }
            } else {
                errorMessage = "No account found for this email. Tap below to sign up."
            }
        }
    }

    var result: OnboardingResult {
        OnboardingResult(
            userEmail: email.trimmingCharacters(in: .whitespacesAndNewlines),
            places: Array(places),
            coolingDays: coolingDays
        )
    }
}

// main onboarding container
struct OnboardingFlow: View {
    var onFinish: (OnboardingResult) -> Void
    @State private var model = OnboardingModel()

    var body: some View {
        ZStack {
            Color.swPaper.ignoresSafeArea()

            switch model.phase {
            case .splash:
                SplashView { model.completeSplash() }
                    .transition(.opacity)

            case .auth:
                AuthView(model: model)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            case .walkthrough:
                WalkthroughContainer(model: model) {
                    onFinish(model.result)
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
            }
        }
    }
}

// walkthrough frame with top progress indicators
struct WalkthroughContainer: View {
    let model: OnboardingModel
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // step indicator dots
            HStack(spacing: 6) {
                ForEach(1...3, id: \.self) { index in
                    Capsule()
                        .fill(index == model.activePage ? Color.swInk : Color.swLine)
                        .frame(width: index == model.activePage ? 20 : 6, height: 6)
                        .animation(.spring(duration: 0.3), value: model.activePage)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 12)

            // swipeable page view
            TabView(selection: Binding(get: { model.activePage }, set: { model.activePage = $0 })) {
                SaveAnywhereStep(model: model).tag(1)
                PlacesStep(model: model).tag(2)
                CoolingShelfStep(model: model).tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // bottom cta button
            Button {
                if model.activePage < 3 {
                    withAnimation(.snappy) { model.activePage += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(model.activePage == 3 ? "get started" : "continue")
                    .font(.custom("Inter-SemiBold", size: 16))
                    .foregroundStyle(Color.swPaper)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.swInk, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}
