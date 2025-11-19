//
//  WellnessSnapshotScreen.swift
//  Forki
//

import SwiftUI

struct WellnessSnapshotScreen: View {
    @ObservedObject var data: OnboardingData
    @ObservedObject var navigator: OnboardingNavigator
    @ObservedObject var userData: UserData
    let onNext: () -> Void
    
    @State private var snapshot: WellnessSnapshot?
    @State private var showFeedingEffect = false
    
    var body: some View {
        ZStack {
            ForkiTheme.backgroundGradient.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    
                    // PROGRESS BAR with Back Button
                    OnboardingProgressBar(
                        currentStep: navigator.currentStep,
                        totalSteps: navigator.totalSteps,
                        sectionIndex: navigator.getSectionIndex(for: navigator.currentStep),
                        totalSections: 6,
                        canGoBack: navigator.canGoBack(),
                        onBack: { navigator.goBack() }
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 4) // Further reduced to 4
                    
                    if let snapshot = snapshot {
                        snapshotContent(snapshot)
                    } else {
                        loadingContent
                    }
                    
                    // CONTINUE BUTTON
                    OnboardingPrimaryButton(title: "Continue") {
                        // Apply snapshot to UserData before proceeding
                        if let snapshot = snapshot {
                            userData.applySnapshot(snapshot)
                        }
                        onNext()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
                .frame(maxWidth: 460)
            }
        }
        .onAppear {
            snapshot = WellnessSnapshotCalculator.calculateSnapshot(from: data)
        }
    }
}

////////////////////////////////////////////////////////////
// MARK: - Snapshot Content (5-Card Clean Layout)
////////////////////////////////////////////////////////////

extension WellnessSnapshotScreen {
    
    private func snapshotContent(_ snapshot: WellnessSnapshot) -> some View {
        VStack(spacing: 20) {
            
            // TITLE + SHORT INTRO
            VStack(spacing: 10) {
                Text("Meet Your Eating Pet,\nForki!")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(ForkiTheme.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Your pet will help you build consistent habits.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(ForkiTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, -12) // Increased negative padding to move title up more
            
            ////////////////////////////////////////////////////////////
            // CARD 1 — BMI + BODY INFO + AVATAR
            ////////////////////////////////////////////////////////////
            
            VStack(alignment: .leading, spacing: 16) {
                // BMI SCALE - Full Width
                BMIScaleView(bmi: snapshot.BMI, bodyType: snapshot.bodyType)
                
                // BMI MESSAGE - Full Width
                BMIMessageView(bmi: snapshot.BMI, bodyType: snapshot.bodyType)
                
                // CONTENT ROW: Body Info + Avatar
                HStack(alignment: .bottom, spacing: 16) {
                    // LEFT COLUMN: Body Type + Metabolism
                    VStack(alignment: .leading, spacing: 16) {
                        EmojiProfileRow(icon: "person.fill", label: "Body Type", value: snapshot.bodyType)
                        EmojiProfileRow(icon: "flame.fill", label: "Metabolism", value: snapshot.metabolism)
                    }
                    
                    Spacer()
                    
                    // AVATAR - Bottom Right
                    AvatarView(
                        state: avatarStateForPersona(snapshot.persona.personaType),
                        showFeedingEffect: .constant(false),
                        size: 140
                    )
                }
            }
            .padding(20)
            .background(panel)
            .padding(.horizontal, 24)
            
            ////////////////////////////////////////////////////////////
            // CARD 2 — SUGGESTED EATING PATTERN
            ////////////////////////////////////////////////////////////
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(ForkiTheme.highlightText)
                    Text("Recommended Eating Habit")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(ForkiTheme.textPrimary)
                }
                
                Text(snapshot.persona.suggestedPattern)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(ForkiTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(ForkiTheme.surface.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(ForkiTheme.borderPrimary.opacity(0.4), lineWidth: 2)
                    )
            )
            .padding(.horizontal, 24)
            
            
            ////////////////////////////////////////////////////////////
            // CARD 3 — DAILY TARGETS
            ////////////////////////////////////////////////////////////
            VStack(alignment: .leading, spacing: 16) {
                Text("Daily Targets")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(ForkiTheme.textPrimary)
                
                // Calories
                HStack {
                    Text("Calories")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(ForkiTheme.textSecondary)
                    Spacer()
                    Text("\(snapshot.recommendedCalories)")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(ForkiTheme.highlightText)
                }
                
                Divider().background(ForkiTheme.borderPrimary.opacity(0.3))
                
                // Macros
                MacroRow(label: "Protein", value: snapshot.recommendedMacros.protein, unit: "g", color: ForkiTheme.legendProtein, icon: "dumbbell.fill")
                MacroRow(label: "Carbs", value: snapshot.recommendedMacros.carbs, unit: "g", color: ForkiTheme.legendCarbs, icon: "leaf.fill")
                MacroRow(label: "Fats", value: snapshot.recommendedMacros.fats, unit: "g", color: ForkiTheme.legendFats, icon: "drop.fill")
                MacroRow(label: "Fiber", value: snapshot.recommendedMacros.fiber, unit: "g", color: ForkiTheme.legendFiber, icon: "circle.grid.hex.fill")
            }
            .padding(20)
            .background(panel)
            .padding(.horizontal, 24)
            
            
            ////////////////////////////////////////////////////////////
            // CARD 4 — PET CHALLENGE
            ////////////////////////////////////////////////////////////
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Text("🎯")
                    Text("Week 1 Pet Challenge")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(ForkiTheme.textPrimary)
                }
                
                Text(snapshot.persona.petChallenge)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(ForkiTheme.textSecondary)
                    .multilineTextAlignment(.center)
                
                Text("Your pet evolves when you stay consistent!")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(ForkiTheme.highlightText.opacity(0.8))
            }
            .padding(20)
            .background(panelBordered)
            .padding(.horizontal, 24)
            .padding(.bottom, 10) // Add 10px padding below to match 20px spacing between cards (10px from main VStack + 10px padding = 20px total)
        }
        .padding(.top, 12)
    }
}

////////////////////////////////////////////////////////////
// MARK: - BMI Message View
////////////////////////////////////////////////////////////

private struct BMIMessageView: View {
    let bmi: Double
    let bodyType: String
    
    private var message: String {
        let value = Int(bmi.rounded())
        switch bodyType {
        case "Underweight": return "Your BMI is \(value) — below normal. Steady meals will help."
        case "Normal": return "Your BMI is \(value) — in the normal range."
        case "Overweight": return "Your BMI is \(value) — slightly high. Small steps make progress."
        case "Obese": return "Your BMI is \(value) — higher than ideal. We'll support your goals."
        default: return "Your BMI is \(value)."
        }
    }
    
    private var messageColor: Color {
        switch bodyType {
        case "Underweight": return Color(hex: "#4A90E2")
        case "Normal": return Color(hex: "#4CAF50")
        case "Overweight": return Color(hex: "#FF9800")
        case "Obese": return Color(hex: "#F44336")
        default: return ForkiTheme.textPrimary
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(messageColor)
            Text(message)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(ForkiTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(messageColor.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(messageColor.opacity(0.4), lineWidth: 2)
        )
    }
}

////////////////////////////////////////////////////////////
// MARK: - Avatar Mapping
////////////////////////////////////////////////////////////

private func avatarStateForPersona(_ persona: Int) -> AvatarState {
    switch persona {
    case 1: return .starving
    case 2,3,4,5: return .sad
    case 6: return .strong
    case 7,8,9: return .neutral
    case 10: return .bloated
    case 11,13: return .happy
    case 12: return .neutral
    default: return .neutral
    }
}

////////////////////////////////////////////////////////////
// MARK: - Panels
////////////////////////////////////////////////////////////

private var panel: some View {
    RoundedRectangle(cornerRadius: 20)
        .fill(ForkiTheme.surface.opacity(0.9))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(ForkiTheme.borderPrimary.opacity(0.4), lineWidth: 2)
        )
}

private var panelBordered: some View {
    RoundedRectangle(cornerRadius: 20)
        .fill(ForkiTheme.surface.opacity(0.15))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(ForkiTheme.borderPrimary, lineWidth: 2)
        )
}

////////////////////////////////////////////////////////////
// MARK: - BMI SCALE VIEW
////////////////////////////////////////////////////////////

private struct BMIScaleView: View {
    let bmi: Double
    let bodyType: String
    
    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background scale
                    HStack(spacing: 0) {
                        // Underweight (15-18.5)
                        Rectangle()
                            .fill(Color(hex: "#4A90E2").opacity(0.3))
                            .frame(width: geometry.size.width * 0.175)
                        // Normal (18.5-25)
                        Rectangle()
                            .fill(Color(hex: "#4CAF50").opacity(0.3))
                            .frame(width: geometry.size.width * 0.325)
                        // Overweight (25-30)
                        Rectangle()
                            .fill(Color(hex: "#FF9800").opacity(0.3))
                            .frame(width: geometry.size.width * 0.25)
                        // Obese (30-40)
                        Rectangle()
                            .fill(Color(hex: "#F44336").opacity(0.3))
                            .frame(width: geometry.size.width * 0.25)
                    }
                    
                    // BMI Indicator
                    // Calculate indicator dimensions
                    let indicatorWidth: CGFloat = 90
                    let triangleWidth: CGFloat = 12
                    let halfIndicatorWidth = indicatorWidth / 2
                    
                    // Calculate min/max positions to keep entire indicator visible
                    let padding: CGFloat = halfIndicatorWidth
                    let minPosition = padding
                    let maxPosition = geometry.size.width - padding
                    
                    // Determine position and arrow alignment based on BMI value
                    let isUnder15 = bmi < 15.0
                    let isOver40 = bmi > 40.0
                    
                    let clampedBMI = max(15.0, min(40.0, bmi))
                    let bmiPosition = CGFloat((clampedBMI - 15) / (40 - 15)) * geometry.size.width
                    
                    // Position the indicator container
                    let indicatorPosition: CGFloat = {
                        if isUnder15 {
                            return minPosition
                        } else if isOver40 {
                            return maxPosition
                        } else {
                            return max(minPosition, min(maxPosition, bmiPosition))
                        }
                    }()
                    
                    VStack(spacing: 4) {
                        Text("You - \(String(format: "%.1f", bmi))")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(ForkiTheme.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(ForkiTheme.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(ForkiTheme.borderPrimary, lineWidth: 2)
                                    )
                            )
                            .frame(maxWidth: .infinity, alignment: .center)
                        
                        // Arrow positioned based on alignment
                        HStack {
                            if isOver40 {
                                Spacer()
                            }
                            Triangle()
                                .fill(ForkiTheme.borderPrimary)
                                .frame(width: triangleWidth, height: 8)
                            if isUnder15 {
                                Spacer()
                            }
                        }
                        .frame(width: indicatorWidth)
                    }
                    .frame(width: indicatorWidth)
                    .offset(x: indicatorPosition - halfIndicatorWidth, y: 0)
                }
            }
            .frame(height: 50)
            
            // Labels
            HStack {
                Text("15")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(ForkiTheme.textSecondary)
                Spacer()
                Text("18.5")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(ForkiTheme.textSecondary)
                Spacer()
                Text("25")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(ForkiTheme.textSecondary)
                Spacer()
                Text("30")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(ForkiTheme.textSecondary)
                Spacer()
                Text("40")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(ForkiTheme.textSecondary)
            }
            
            // Category labels
            HStack(spacing: 0) {
                Text("UNDERWEIGHT")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#4A90E2"))
                    .frame(maxWidth: .infinity)
                Text("NORMAL")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#4CAF50"))
                    .frame(maxWidth: .infinity)
                Text("OVERWEIGHT")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#FF9800"))
                    .frame(maxWidth: .infinity)
                Text("OBESE")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#F44336"))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Triangle Shape
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

////////////////////////////////////////////////////////////
// MARK: - Profile Row + Macro Row (unchanged)
////////////////////////////////////////////////////////////

private struct ProfileRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(ForkiTheme.highlightText)
            Text(label)
                .foregroundColor(ForkiTheme.textSecondary)
            Spacer()
            Text(value)
                .foregroundColor(ForkiTheme.textPrimary)
        }
        .font(.system(size: 14, weight: .medium))
    }
}

private struct EmojiProfileRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .regular))
                .foregroundColor(ForkiTheme.textSecondary)
                .frame(width: 28, height: 28, alignment: .center)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .foregroundColor(ForkiTheme.textSecondary)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                
                Text(value)
                    .foregroundColor(ForkiTheme.textPrimary)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            }
        }
    }
}

private struct MacroRow: View {
    let label: String
    let value: Int
    let unit: String
    let color: Color
    let icon: String

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundColor(color)
                Text(label).foregroundColor(ForkiTheme.textSecondary)
            }
            Spacer()
            Text("\(value) \(unit)")
                .foregroundColor(ForkiTheme.textPrimary)
                .monospacedDigit()
        }
        .font(.system(size: 15, weight: .medium))
    }
}

////////////////////////////////////////////////////////////
// MARK: - Loading State
////////////////////////////////////////////////////////////

private var loadingContent: some View {
    VStack(spacing: 20) {
        Text("Creating Your Snapshot…")
            .font(.system(size: 22, weight: .bold))
            .foregroundColor(ForkiTheme.textPrimary)
        
        ProgressView().tint(ForkiTheme.borderPrimary)
    }
    .padding(.top, 80)
}

////////////////////////////////////////////////////////////
// MARK: - Preview
////////////////////////////////////////////////////////////

#Preview {
    WellnessSnapshotScreen(
        data: OnboardingData(),
        navigator: OnboardingNavigator(),
        userData: UserData(),
        onNext: {}
    )
}

