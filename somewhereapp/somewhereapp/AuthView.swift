//
//  AuthView.swift
//  somewhereapp
//
//  Created by Muskaan Bajaj on 11/10/26.
//


import SwiftUI

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
                .font(.custom("Inter-Regular", size: 16))
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(model.errorMessage != nil && !model.isEmailValid ? Color.red.opacity(0.8) : Color.swLine, lineWidth: 1)
                )
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()

                SecureField("password (min 8 chars)", text: Binding(get: { model.password }, set: { 
                    model.password = $0 
                    model.errorMessage = nil
                }))
                .font(.custom("Inter-Regular", size: 16))
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(model.errorMessage != nil && !model.isPasswordValid ? Color.red.opacity(0.8) : Color.swLine, lineWidth: 1)
                )
            }
            .padding(.bottom, 12)

            // error message banner
            if let error = model.errorMessage {
                Text(error)
                    .font(.custom("Inter-Medium", size: 13))
                    .foregroundStyle(Color.red)
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
                    .font(.custom("Inter-SemiBold", size: 16))
                    .foregroundStyle(Color.swPaper)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.swInk, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(!model.isFormValid)
            .opacity(model.isFormValid ? 1.0 : 0.45)
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