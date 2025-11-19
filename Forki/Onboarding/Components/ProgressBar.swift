//
//  ProgressBar.swift
//  Forki
//
//  Created by Cursor AI on 11/11/25.
//

import SwiftUI

struct OnboardingProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    let sectionIndex: Int
    let totalSections: Int
    let canGoBack: Bool
    let onBack: (() -> Void)?
    var onCustomBack: (() -> Void)? = nil  // Custom back handler (e.g., for Profile Screen)
    
    init(
        currentStep: Int,
        totalSteps: Int,
        sectionIndex: Int,
        totalSections: Int,
        canGoBack: Bool = false,
        onBack: (() -> Void)? = nil,
        onCustomBack: (() -> Void)? = nil
    ) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.sectionIndex = sectionIndex
        self.totalSections = totalSections
        self.canGoBack = canGoBack
        self.onBack = onBack
        self.onCustomBack = onCustomBack
    }
    
    private let numberOfSegments = 4
    
    // Calculate fill percentage for each segment based on current step
    private func fillPercentage(for segmentIndex: Int) -> Double {
        switch segmentIndex {
        case 0: // Bar 1: Basic Info (steps 0-2)
            switch currentStep {
            case 0: return 1.0/3.0  // Age/Gender - 1/3
            case 1: return 2.0/3.0  // Height - 2/3
            case 2: return 3.0/3.0  // Weight - 3/3
            default: return currentStep > 2 ? 1.0 : 0.0
            }
        case 1: // Bar 2: Goals (steps 3-4)
            switch currentStep {
            case 3: return 1.0/2.0  // Primary Goals - 1/2
            case 4: return 2.0/2.0  // Goal Weight - 2/2
            default: 
                if currentStep < 3 { return 0.0 }
                if currentStep > 4 { return 1.0 }
                return 0.0
            }
        case 2: // Bar 3: Dietary + Eating + Lifestyle (steps 5-7)
            switch currentStep {
            case 5: return 1.0/3.0  // Dietary Preferences - 1/3
            case 6: return 2.0/3.0  // Eating Habits - 2/3
            case 7: return 3.0/3.0  // Activity Level - 3/3
            default:
                if currentStep < 5 { return 0.0 }
                if currentStep > 7 { return 1.0 }
                return 0.0
            }
        case 3: // Bar 4: Results (step 8 - Final Step)
            switch currentStep {
            case 8: return 1.0/1.0  // Wellness Snapshot - Final Step
            default:
                if currentStep < 8 { return 0.0 }
                return 1.0
            }
        default:
            return 0.0
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Back Button
            if let onCustomBack = onCustomBack {
                // Show custom back button (e.g., from Profile Screen)
                Button(action: onCustomBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(ForkiTheme.textPrimary)
                        .padding(12)
                        .background(
                            Circle()
                                .fill(ForkiTheme.surface.opacity(0.6))
                        )
                }
            } else if canGoBack, let onBack = onBack {
                // Show normal back button (within onboarding flow)
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(ForkiTheme.textPrimary)
                        .padding(12)
                        .background(
                            Circle()
                                .fill(ForkiTheme.surface.opacity(0.6))
                        )
                }
            } else {
                // Spacer to maintain alignment when no back button
                Color.clear
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            // Progress segments - centered with partial fills
            HStack(spacing: 8) {
                ForEach(0..<numberOfSegments, id: \.self) { index in
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background (unfilled)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(ForkiTheme.borderPrimary.opacity(0.25))
                            
                            // Filled portion
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(ForkiTheme.highlightText)
                                .frame(width: geometry.size.width * fillPercentage(for: index))
                        }
                    }
                    .frame(width: 48, height: 6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
                }
            }
            
            Spacer()
            
            // Right side spacer for symmetry
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.vertical, 16)
    }
}

#Preview {
    VStack(spacing: 40) {
        OnboardingProgressBar(currentStep: 0, totalSteps: 10, sectionIndex: 0, totalSections: 7, canGoBack: false) // Bar 1: 1/3
        OnboardingProgressBar(currentStep: 1, totalSteps: 10, sectionIndex: 0, totalSections: 7, canGoBack: true, onBack: {}) // Bar 1: 2/3
        OnboardingProgressBar(currentStep: 2, totalSteps: 10, sectionIndex: 0, totalSections: 7, canGoBack: true, onBack: {}) // Bar 1: 3/3
        OnboardingProgressBar(currentStep: 3, totalSteps: 10, sectionIndex: 1, totalSections: 7, canGoBack: true, onBack: {}) // Bar 2: 1/2
        OnboardingProgressBar(currentStep: 4, totalSteps: 10, sectionIndex: 1, totalSections: 7, canGoBack: true, onBack: {}) // Bar 2: 2/2
        OnboardingProgressBar(currentStep: 5, totalSteps: 10, sectionIndex: 2, totalSections: 7, canGoBack: true, onBack: {}) // Bar 3: 1/3
        OnboardingProgressBar(currentStep: 6, totalSteps: 10, sectionIndex: 3, totalSections: 7, canGoBack: true, onBack: {}) // Bar 3: 2/3
        OnboardingProgressBar(currentStep: 7, totalSteps: 10, sectionIndex: 4, totalSections: 7, canGoBack: true, onBack: {}) // Bar 3: 3/3
        OnboardingProgressBar(currentStep: 8, totalSteps: 10, sectionIndex: 5, totalSections: 7, canGoBack: true, onBack: {}) // Bar 4: 1/2
        OnboardingProgressBar(currentStep: 9, totalSteps: 10, sectionIndex: 6, totalSections: 7, canGoBack: true, onBack: {}) // Bar 4: 2/2
    }
    .background(ForkiTheme.backgroundGradient)
    .ignoresSafeArea()
}

