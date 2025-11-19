//
//  ActivityLevelScreen.swift
//  Forki
//
//  Created by Cursor AI on 11/11/25.
//

import SwiftUI

struct ActivityLevelScreen: View {
    @ObservedObject var data: OnboardingData
    @ObservedObject var navigator: OnboardingNavigator
    let onNext: () -> Void
    
    private let activityLevels: [(id: String, title: String)] = [
        ("mostly_sitting", "Mostly sitting"),
        ("some_movement", "Some movement"),
        ("active", "Active"),
        ("very_active", "Very active")
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
                            Text("What's your activity level?")
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .foregroundColor(ForkiTheme.textPrimary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 16)
                        
                        // Activity Level Cards
                        VStack(spacing: 12) {
                            ForEach(activityLevels, id: \.id) { level in
                                MultiSelectCard(
                                    title: level.title,
                                    isSelected: data.activityLevel == level.id
                                ) {
                                    // Single-select behavior - only one can be selected
                                    data.activityLevel = level.id
                                }
                            }
                        }
                        .padding(.horizontal, 6)
                    }
                    .forkiPanel()
                    .padding(.horizontal, 24)
                    
                    // Next Button
                    OnboardingPrimaryButton(
                        isEnabled: !data.activityLevel.isEmpty
                    ) {
                        onNext()
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
    ActivityLevelScreen(
        data: OnboardingData(),
        navigator: OnboardingNavigator(),
        onNext: {}
    )
}

