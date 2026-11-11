//
//  ContentView.swift
//  somewhereapp
//
//  Created by Muskaan Bajaj on 11/10/26.
//

import SwiftUI

// root view managing active login session state
struct ContentView: View {
    @AppStorage("somewhere.isLoggedIn") private var isLoggedIn = false
    @AppStorage("somewhere.userEmail") private var userEmail = ""

    var body: some View {
        if isLoggedIn {
            // logged in main view placeholder
            VStack(spacing: 20) {
                Spacer()
                Text("welcome back.")
                    .swText(.display)
                Text("signed in as \(userEmail)")
                    .swText(.body, color: .swMuted)
                
                Button("sign out") {
                    withAnimation {
                        isLoggedIn = false
                    }
                }
                .font(.custom("Inter-SemiBold", size: 15))
                .foregroundStyle(Color.red)
                .padding(.top, 16)
                
                Spacer()
            }
            .padding(24)
            .background(Color.swPaper.ignoresSafeArea())
        } else {
            // onboarding flow
            OnboardingFlow { result in
                result.save()
                userEmail = result.userEmail
                withAnimation {
                    isLoggedIn = true
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
