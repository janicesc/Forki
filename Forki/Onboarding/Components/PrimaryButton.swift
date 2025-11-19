//
//  PrimaryButton.swift
//  Forki
//
//  Created by Cursor AI on 11/11/25.
//

import SwiftUI

struct OnboardingPrimaryButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void
    
    init(title: String = "Next", isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            isEnabled ?
                            LinearGradient(
                                colors: [
                                    Color(hex: "#8B5CF6"), // Vibrant purple
                                    Color(hex: "#A78BFA")  // Lighter vibrant purple
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [
                                    Color(hex: "#8B5CF6").opacity(0.5),
                                    Color(hex: "#A78BFA").opacity(0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color(hex: "#7B68C4"), lineWidth: 2) // Purple border matching theme
                        )
                )
                .shadow(color: isEnabled ? Color(hex: "#8B5CF6").opacity(0.4) : Color.clear, radius: 16, x: 0, y: 8) // Purple glow
        }
        .disabled(!isEnabled)
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    VStack(spacing: 20) {
        OnboardingPrimaryButton(title: "Next", isEnabled: true) {}
        OnboardingPrimaryButton(title: "Next", isEnabled: false) {}
    }
    .padding()
    .background(ForkiTheme.backgroundGradient)
}

