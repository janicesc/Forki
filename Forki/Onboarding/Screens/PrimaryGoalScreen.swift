//
//  PrimaryGoalScreen.swift
//  Forki
//
//  Created by Cursor AI on 11/11/25.
//

import SwiftUI

struct PrimaryGoalScreen: View {
    @ObservedObject var data: OnboardingData
    @ObservedObject var navigator: OnboardingNavigator
    let onNext: () -> Void
    
    private let goals: [(id: String, title: String, emoji: String)] = [
        ("improve_habits", "Build healthier eating habits", "🌱"),
        ("lose_weight", "Lose weight", "⚖️"),
        ("maintain_weight", "Maintain my weight", "🧘‍♀️"),
        ("gain_weight", "Gain weight / build muscle", "💪"),
        ("boost_energy", "Boost energy & reduce stress", "⚡")
    ]
    
    var body: some View {
        ZStack {
            ForkiTheme.backgroundGradient
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Progress Bar with Back Button
                    OnboardingProgressBar(
                        currentStep: navigator.currentStep,
                        totalSteps: navigator.totalSteps,
                        sectionIndex: navigator.getSectionIndex(for: navigator.currentStep),
                        totalSections: 6,
                        canGoBack: navigator.canGoBack(),
                        onBack: { navigator.goBack() }
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    
                    // Content
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 8) {
                            Text("What's your primary goal?")
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .foregroundColor(ForkiTheme.textPrimary)
                                .multilineTextAlignment(.center)
                            
                            Text("Choose all that apply")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(ForkiTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 16)
                        
                        // Goal Cards
                        VStack(spacing: 12) {
                            ForEach(goals, id: \.id) { goal in
                                MultiSelectCard(
                                    title: goal.title,
                                    emoji: goal.emoji,
                                    isSelected: data.primaryGoals.contains(goal.id)
                                ) {
                                    if data.primaryGoals.contains(goal.id) {
                                        data.primaryGoals.remove(goal.id)
                                    } else {
                                        data.primaryGoals.insert(goal.id)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 6)
                    }
                    .forkiPanel()
                    .padding(.horizontal, 24)
                    
                    // Next Button
                    OnboardingPrimaryButton(
                        isEnabled: !data.primaryGoals.isEmpty
                    ) {
                        // If user didn't select lose/gain weight, skip goal weight screen
                        let needsGoalWeight = data.primaryGoals.contains("lose_weight") || data.primaryGoals.contains("gain_weight")
                        if !needsGoalWeight {
                            // Skip step 4 (GoalWeightScreen) and go directly to step 5
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                navigator.currentStep = 5
                            }
                        } else {
                            onNext()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
                .frame(maxWidth: 460)
            }
        }
    }
}

#Preview {
    PrimaryGoalScreen(
        data: OnboardingData(),
        navigator: OnboardingNavigator(),
        onNext: {}
    )
}

