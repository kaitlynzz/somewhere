//
//  AuthView.swift
//  somewhereapp
//
//  Created by Muskaan Bajaj on 11/10/26.
//


import SwiftUI
import AuthenticationServices

// sign up / sign in auth view
struct AuthView: View {
    let model: OnboardingModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // header
            VStack(spacing: 8) {
                Text(model.isSigningUp ? "create account." : "welcome back.")
                    .swText(.display)
                    .multilineTextAlignment(.center)

                Text(model.isSigningUp ? "start saving everything in one place." : "sign in to view your saved items.")
                    .swText(.body, color: .swMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 28)

            // inputs
            VStack(spacing: 14) {
                TextField("email address", text: Binding(get: { model.email }, set: { 
                    model.email = $0 
                    model.errorMessage = nil
                }))
                .swText(.body)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(model.errorMessage != nil && !model.isEmailValid ? Color.swError : Color.swLine, lineWidth: 1)
                )
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()

                SecureField("password (min 8 chars)", text: Binding(get: { model.password }, set: { 
                    model.password = $0 
                    model.errorMessage = nil
                }))
                .swText(.body)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(model.errorMessage != nil && !model.isPasswordValid ? Color.swError : Color.swLine, lineWidth: 1)
                )
            }
            .padding(.bottom, 12)

            // error message banner
            if let error = model.errorMessage {
                Text(error)
                    .swText(.caption, color: .swError)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 16)
                    .transition(.opacity)
            } else {
                Spacer().frame(height: 16)
            }

            // primary submit button
            Button {
                model.completeAuth()
            } label: {
                Text(model.isSigningUp ? "continue" : "sign in")
            }
            .buttonStyle(SWPrimaryButtonStyle())
            .disabled(!model.isFormValid)
            .opacity(model.isFormValid ? 1.0 : 0.45)
            .padding(.bottom, 14)

            // or: Sign in with Apple (one button handles sign up and sign in)
            HStack(spacing: 12) {
                Rectangle().fill(Color.swLine).frame(height: 1)
                Text("or").swText(.caption, color: .swMuted)
                Rectangle().fill(Color.swLine).frame(height: 1)
            }
            .padding(.bottom, 14)

            SignInWithAppleButton(model.isSigningUp ? .signUp : .signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                model.completeAppleSignIn(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .id(model.isSigningUp)   // relabel when switching sign up / sign in
            .padding(.bottom, 16)

            // mode toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { 
                    model.isSigningUp.toggle() 
                    model.errorMessage = nil
                }
            } label: {
                Text(model.isSigningUp ? "already have an account? sign in" : "don't have an account? sign up")
                    .swText(.bodyStrong, color: .swMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}