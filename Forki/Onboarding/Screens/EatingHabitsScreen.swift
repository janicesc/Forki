//
//  EatingHabitsScreen.swift
//  Forki
//
//  Created by Cursor AI on 11/11/25.
//

import SwiftUI

struct EatingHabitsScreen: View {
    @ObservedObject var data: OnboardingData
    @ObservedObject var navigator: OnboardingNavigator
    let onNext: () -> Void
    
    private let habits: [(id: String, title: String)] = [
        ("skip_meals", "I skip meals or eat inconsistently"),
        ("late_night", "I snack late at night"),
        ("stress_eat", "I overeat when stressed"),
        ("crave_snacks", "I crave sweet or salty snacks often"),
        ("not_enough", "I don't eat enough during the day"),
        ("none", "None of the above")
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
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 6) {
                            Text("Do you have any of these habits?")
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .foregroundColor(ForkiTheme.textPrimary)
                                .multilineTextAlignment(.center)
                            
                            Text("Choose all that apply")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(ForkiTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4) // Reduce spacing below header
                        
                        // Habit Cards
                        VStack(spacing: 10) {
                            ForEach(habits, id: \.id) { habit in
                                MultiSelectCard(
                                    title: habit.title,
                                    isSelected: data.eatingHabits.contains(habit.id)
                                ) {
                                    if habit.id == "none" {
                                        // If "None" is selected, clear all others
                                        if data.eatingHabits.contains("none") {
                                            data.eatingHabits.remove("none")
                                        } else {
                                            data.eatingHabits.removeAll()
                                            data.eatingHabits.insert("none")
                                        }
                                    } else {
                                        // If any other is selected, remove "none"
                                        data.eatingHabits.remove("none")
                                        if data.eatingHabits.contains(habit.id) {
                                            data.eatingHabits.remove(habit.id)
                                        } else {
                                            data.eatingHabits.insert(habit.id)
                                        }
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
                        isEnabled: !data.eatingHabits.isEmpty
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
    EatingHabitsScreen(
        data: OnboardingData(),
        navigator: OnboardingNavigator(),
        onNext: {}
    )
}

