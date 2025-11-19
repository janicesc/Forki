//
//  WeightScreen.swift
//  Forki
//
//  Created by Cursor AI on 11/11/25.
//

import SwiftUI

struct WeightScreen: View {
    @ObservedObject var data: OnboardingData
    @ObservedObject var navigator: OnboardingNavigator
    let onNext: () -> Void
    
    @FocusState private var isWeightFocused: Bool
    
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
                            Text("What's your current weight?")
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .foregroundColor(ForkiTheme.textPrimary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 16)
                        
                        // Unit Selector - Connected Toggle (Centered) - LOG FOOD button style
                        HStack {
                            Spacer()
                            HStack(spacing: 0) {
                                ForEach(Array(WeightUnit.allCases.enumerated()), id: \.element) { index, unit in
                                    UnitToggleButton(
                                        text: unit.rawValue.uppercased(),
                                        isSelected: data.weightUnit == unit,
                                        action: {
                                            withAnimation {
                                                data.weightUnit = unit
                                            }
                                        }
                                    )
                                    
                                    // Divider between buttons (except after last)
                                    if index < WeightUnit.allCases.count - 1 {
                                        Rectangle()
                                            .fill(ForkiTheme.surface.opacity(0.5))
                                            .frame(width: 1)
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(ForkiTheme.surface.opacity(0.4))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                                            .stroke(ForkiTheme.surface.opacity(0.6), lineWidth: 1.5)
                                    )
                            )
                            .frame(width: 200)
                            Spacer()
                        }
                        .padding(.horizontal, 6)
                        
                        // Weight Input
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("120", text: data.weightUnit == .lbs ? $data.weightLbs : $data.weightKg)
                                .font(.system(size: 48, weight: .heavy, design: .rounded))
                                .foregroundColor(ForkiTheme.textPrimary)
                                .keyboardType(.decimalPad)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($isWeightFocused)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .textFieldStyle(PlainTextFieldStyle())
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    isWeightFocused = true
                                }
                                .onAppear {
                                    // Auto-focus weight field when screen appears for quick entry
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        isWeightFocused = true
                                    }
                                }
                                .onChange(of: data.weightUnit == .lbs ? data.weightLbs : data.weightKg) { _, newValue in
                                    // Filter to allow only numeric input and decimal point
                                    let filtered = newValue.filter { $0.isNumber || $0 == "." }
                                    // Ensure only one decimal point
                                    let components = filtered.components(separatedBy: ".")
                                    let finalValue = components.prefix(2).joined(separator: ".")
                                    if finalValue != newValue {
                                        if data.weightUnit == .lbs {
                                            data.weightLbs = finalValue
                                        } else {
                                            data.weightKg = finalValue
                                        }
                                    }
                                }
                                .onChange(of: data.weightUnit) { _, _ in
                                    // Auto-focus when unit changes
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isWeightFocused = true
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
                        
                        // BMI Indicator
                        if isWeightValid, let bmi = data.calculateBMI(), let category = data.getBMICategory() {
                            BMIIndicatorView(bmi: bmi, category: category)
                                .padding(.top, 8)
                        }
                    }
                    .forkiPanel()
                    .padding(.horizontal, 24)
                    
                    // Next Button
                    OnboardingPrimaryButton(
                        isEnabled: isWeightValid
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
    
    private var isWeightValid: Bool {
        if data.weightUnit == .lbs {
            guard let lbs = Double(data.weightLbs), lbs >= 50, lbs <= 500 else { return false }
            return true
        } else {
            guard let kg = Double(data.weightKg), kg >= 20, kg <= 250 else { return false }
            return true
        }
    }
}

// MARK: - Unit Toggle Button
private struct UnitToggleButton: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(isSelected ? .white : ForkiTheme.textSecondary)
                .frame(width: 100) // Increased proportionally with bar width
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(
                            isSelected ?
                            LinearGradient(
                                colors: [Color(hex: "#8DD4D1"), Color(hex: "#6FB8B5")], // Mint gradient
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) : LinearGradient(
                                colors: [Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    isSelected ? Color(hex: "#7AB8B5") : Color.clear,
                                    lineWidth: isSelected ? 2 : 0
                                )
                        )
                )
                .shadow(
                    color: isSelected ? ForkiTheme.actionShadow : Color.clear,
                    radius: isSelected ? 12 : 0,
                    x: 0,
                    y: isSelected ? 6 : 0
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - BMI Indicator
struct BMIIndicatorView: View {
    let bmi: Double
    let category: String
    
    private var categoryColor: Color {
        switch category {
        case "underweight":
            return Color(hex: "#4A90E2") // Blue
        case "normal":
            return Color(hex: "#4CAF50") // Green
        case "overweight":
            return Color(hex: "#FF9800") // Orange
        default:
            return Color(hex: "#F44336") // Red
        }
    }
    
    private var categoryMessage: String {
        switch category {
        case "underweight":
            return "Your BMI is \(Int(bmi.rounded())) which is considered **underweight**. We'll help you build healthy habits!"
            
        case "normal":
            return "Your BMI is \(Int(bmi.rounded())) which is considered **normal**. You're starting strong — let's keep building healthy habits!"
            
        case "overweight":
            return "Your BMI is \(Int(bmi.rounded())) which is considered **overweight**. We'll create a plan to help you reach your goals!"
            
        default:
            return "Your BMI is \(Int(bmi.rounded())) which is considered **obese**. We're here to support you on your journey!"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(categoryColor)
            
            Text(.init(categoryMessage))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(ForkiTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(categoryColor.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(categoryColor.opacity(0.4), lineWidth: 2)
        )
    }
}

#Preview {
    WeightScreen(
        data: OnboardingData(),
        navigator: OnboardingNavigator(),
        onNext: {}
    )
}

