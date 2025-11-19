//
//  HeightScreen.swift
//  Forki
//
//  Created by Cursor AI on 11/11/25.
//

import SwiftUI

struct HeightScreen: View {
    @ObservedObject var data: OnboardingData
    @ObservedObject var navigator: OnboardingNavigator
    let onNext: () -> Void
    
    @FocusState private var isFeetFocused: Bool
    @FocusState private var isInchesFocused: Bool
    @FocusState private var isCmFocused: Bool
    
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
                            Text("How tall are you?")
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .foregroundColor(ForkiTheme.textPrimary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 16)
                        
                        // Unit Selector - Connected Toggle (Centered) - LOG FOOD button style
                        HStack {
                            Spacer()
                            HStack(spacing: 0) {
                                ForEach(Array(HeightUnit.allCases.enumerated()), id: \.element) { index, unit in
                                    UnitToggleButton(
                                        text: unit.rawValue.uppercased(),
                                        isSelected: data.heightUnit == unit,
                                        action: {
                                            withAnimation {
                                                data.heightUnit = unit
                                            }
                                        }
                                    )
                                    
                                    // Divider between buttons (except after last)
                                    if index < HeightUnit.allCases.count - 1 {
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
                        
                        // Height Input
                        if data.heightUnit == .feet {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    TextField("5", text: $data.heightFeet)
                                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                                        .foregroundColor(ForkiTheme.textPrimary)
                                        .keyboardType(.numberPad)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .focused($isFeetFocused)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            isFeetFocused = true
                                        }
                                        .onAppear {
                                            // Auto-focus feet field when screen appears for quick entry
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                if data.heightUnit == .feet {
                                                    isFeetFocused = true
                                                }
                                            }
                                        }
                                        .onChange(of: data.heightFeet) { _, newValue in
                                            // Filter to allow only numeric input
                                            let filtered = newValue.filter { $0.isNumber }
                                            if filtered != newValue {
                                                data.heightFeet = filtered
                                            }
                                            
                                            // Auto-focus to inches when valid feet value is entered
                                            if let feet = Int(filtered), feet >= 3 && feet <= 8 {
                                                // Small delay to allow user to finish typing
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                    isFeetFocused = false
                                                    isInchesFocused = true
                                                }
                                            }
                                        }
                                        .onChange(of: data.heightUnit) { _, _ in
                                            // Auto-focus when unit changes to feet
                                            if data.heightUnit == .feet {
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                    isFeetFocused = true
                                                }
                                            }
                                        }
                                    
                                    Text("ft")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(ForkiTheme.textSecondary)
                                        .frame(maxWidth: .infinity)
                                    
                                    Rectangle()
                                        .fill(ForkiTheme.borderPrimary)
                                        .frame(height: 2)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    TextField("3", text: $data.heightInches)
                                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                                        .foregroundColor(ForkiTheme.textPrimary)
                                        .keyboardType(.numberPad)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .focused($isInchesFocused)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            isInchesFocused = true
                                        }
                                        .onChange(of: data.heightInches) { _, newValue in
                                            // Filter to allow only numeric input
                                            let filtered = newValue.filter { $0.isNumber }
                                            if filtered != newValue {
                                                data.heightInches = filtered
                                            }
                                        }
                                    
                                    Text("in")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(ForkiTheme.textSecondary)
                                        .frame(maxWidth: .infinity)
                                    
                                    Rectangle()
                                        .fill(ForkiTheme.borderPrimary)
                                        .frame(height: 2)
                                }
                            }
                            .padding(.horizontal, 6)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("170", text: $data.heightCm)
                                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                                    .foregroundColor(ForkiTheme.textPrimary)
                                    .keyboardType(.numberPad)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .focused($isCmFocused)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        isCmFocused = true
                                    }
                                    .onAppear {
                                        // Auto-focus cm field when screen appears for quick entry
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            if data.heightUnit == .cm {
                                                isCmFocused = true
                                            }
                                        }
                                    }
                                    .onChange(of: data.heightCm) { _, newValue in
                                        // Filter to allow only numeric input
                                        let filtered = newValue.filter { $0.isNumber }
                                        if filtered != newValue {
                                            data.heightCm = filtered
                                        }
                                    }
                                    .onChange(of: data.heightUnit) { _, _ in
                                        // Auto-focus when unit changes to cm
                                        if data.heightUnit == .cm {
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                isCmFocused = true
                                            }
                                        }
                                    }
                                
                                Text("cm")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(ForkiTheme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                
                                Rectangle()
                                    .fill(ForkiTheme.borderPrimary)
                                    .frame(height: 2)
                            }
                            .padding(.horizontal, 6)
                        }
                    }
                    .forkiPanel()
                    .padding(.horizontal, 24)
                    
                    // Next Button
                    OnboardingPrimaryButton(
                        isEnabled: isHeightValid
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
    
    private var isHeightValid: Bool {
        if data.heightUnit == .feet {
            guard let feet = Int(data.heightFeet), feet >= 3, feet <= 8 else { return false }
            guard let inches = Int(data.heightInches), inches >= 0, inches < 12 else { return false }
            return true
        } else {
            guard let cm = Int(data.heightCm), cm >= 90, cm <= 250 else { return false }
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

#Preview {
    HeightScreen(
        data: OnboardingData(),
        navigator: OnboardingNavigator(),
        onNext: {}
    )
}



