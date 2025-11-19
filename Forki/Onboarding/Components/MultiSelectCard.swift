//
//  MultiSelectCard.swift
//  Forki
//
//  Created by Cursor AI on 11/11/25.
//

import SwiftUI

struct MultiSelectCard: View {
    let title: String
    let subtitle: String?
    let emoji: String?
    let isSelected: Bool
    let action: () -> Void
    
    init(title: String, subtitle: String? = nil, emoji: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.emoji = emoji
        self.isSelected = isSelected
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                if let emoji = emoji {
                    Text(emoji)
                        .font(.system(size: 28))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(ForkiTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(ForkiTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(isSelected ? ForkiTheme.borderPrimary : ForkiTheme.textSecondary.opacity(0.5))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? ForkiTheme.surface.opacity(0.9) : ForkiTheme.surface.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? ForkiTheme.borderPrimary : ForkiTheme.borderPrimary.opacity(0.3), lineWidth: isSelected ? 3 : 2)
            )
            .shadow(color: ForkiTheme.borderPrimary.opacity(isSelected ? 0.2 : 0.05), radius: isSelected ? 8 : 4, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    VStack(spacing: 16) {
        MultiSelectCard(title: "Vegetarian", isSelected: true) {}
        MultiSelectCard(title: "Vegan", subtitle: "No animal products", isSelected: false) {}
    }
    .padding()
    .background(ForkiTheme.backgroundGradient)
}

