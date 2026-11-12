//
//  RootView.swift
//  Somewhere — decides what the app opens to.
//
//  First launch: Muskaan's onboarding (splash → sign up → walkthrough).
//  After that: the wishlist + shelf tabs.
//

import SwiftUI

struct RootView: View {
    @AppStorage("somewhere.isLoggedIn") private var isLoggedIn = false
    @AppStorage("somewhere.userEmail") private var userEmail = ""

    var body: some View {
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
