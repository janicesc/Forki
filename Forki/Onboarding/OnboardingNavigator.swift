//
//  OnboardingNavigator.swift
//  Forki
//
//  Created by Cursor AI on 11/11/25.
//

import SwiftUI

class OnboardingNavigator: ObservableObject {
    @Published var currentStep: Int = 0
    
    // Total steps: 9 screens (Notifications screen removed)
    let totalSteps = 9
    
    // Section mapping
    // Section 1 (Basic Info): steps 0-2 (Age/Gender, Height, Weight)
    // Section 2 (Goals): steps 3-4 (Primary Goals, Goal Weight)
    // Section 3 (Dietary): step 5 (Dietary Preferences)
    // Section 4 (Eating Habits): step 6 (Eating Habits)
    // Section 5 (Lifestyle): step 7 (Activity Level)
    // Section 6 (Personalized Results): step 8 (Wellness Snapshot - Final Step)
    
    func getSectionIndex(for step: Int) -> Int {
        switch step {
        case 0...2: return 0 // Basic Info
        case 3...4: return 1 // Goals
        case 5: return 2 // Dietary
        case 6: return 3 // Eating Habits
        case 7: return 4 // Lifestyle
        case 8: return 5 // Personalized Results (Final Step)
        default: return 0
        }
    }
    
    func canGoNext() -> Bool {
        return currentStep < totalSteps - 1
    }
    
    func canGoBack() -> Bool {
        return currentStep > 0
    }
    
    func goNext() {
        guard canGoNext() else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            currentStep += 1
        }
    }
    
    func goBack() {
        guard canGoBack() else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            currentStep -= 1
        }
    }
}

