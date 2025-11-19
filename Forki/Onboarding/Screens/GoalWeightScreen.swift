//
//  GoalWeightScreen.swift
//  Forki
//
//  Created by Cursor AI on 11/11/25.
//

import SwiftUI

struct GoalWeightScreen: View {
    @ObservedObject var data: OnboardingData
    @ObservedObject var navigator: OnboardingNavigator
    let onNext: () -> Void
    
    @FocusState private var isGoalWeightFocused: Bool
    
    private var shouldShow: Bool {
        data.primaryGoals.contains("lose_weight") || data.primaryGoals.contains("gain_weight")
    }
    
    var body: some View {
        if shouldShow {
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
                                Text("What's your goal weight?")
                                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                                    .foregroundColor(ForkiTheme.textPrimary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 16)
                            
                            // Option 1: Enter weight
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Enter weight", text: $data.goalWeight)
                                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                                    .foregroundColor(ForkiTheme.textPrimary)
                                    .keyboardType(.decimalPad)
                                    .focused($isGoalWeightFocused)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .onAppear {
                                        // Auto-focus goal weight field when screen appears for quick entry
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            isGoalWeightFocused = true
                                        }
                                    }
                                
                                Text(data.weightUnit.rawValue)
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(ForkiTheme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                
                                Rectangle()
                                    .fill(ForkiTheme.borderPrimary)
                                    .frame(height: 2)
                            }
                            .padding(.horizontal, 6)
                            
                            // Option 2: Recommend for me
                            MultiSelectCard(
                                title: "Recommend for me",
                                isSelected: data.useRecommendedGoalWeight
                            ) {
                                data.useRecommendedGoalWeight.toggle()
                                if data.useRecommendedGoalWeight {
                                    data.goalWeight = ""
                                }
                            }
                            .padding(.horizontal, 6)
                        }
                        .forkiPanel()
                        .padding(.horizontal, 24)
                        
                        // Next Button
                        OnboardingPrimaryButton(
                            isEnabled: !data.goalWeight.isEmpty || data.useRecommendedGoalWeight
                        ) {
                            onNext()
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                    }
                    .frame(maxWidth: 460)
                }
            }
        } else {
            // Skip this screen if not needed
            EmptyView()
                .onAppear {
                    onNext()
                }
        }
    }
}

#Preview {
    GoalWeightScreen(
        data: OnboardingData(),
        navigator: OnboardingNavigator(),
        onNext: {}
    )
}

