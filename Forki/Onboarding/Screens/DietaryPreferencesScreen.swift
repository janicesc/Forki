//
//  DietaryPreferencesScreen.swift
//  Forki
//
//  Created by Cursor AI on 11/11/25.
//

import SwiftUI

// MARK: - FoodOption Model
struct FoodOption: Identifiable {
    let id: String
    let name: String
    let icon: String
}

struct DietaryPreferencesScreen: View {
    @ObservedObject var data: OnboardingData
    @ObservedObject var navigator: OnboardingNavigator
    let onNext: () -> Void
    
    @FocusState private var isOtherFocused: Bool
    
    private let dietaryPreferences: [FoodOption] = [
        .init(id: "no_restrictions", name: "No restrictions", icon: "✅"),
        .init(id: "vegetarian", name: "Vegetarian", icon: "🌱"),
        .init(id: "vegan", name: "Vegan", icon: "🌿"),
        .init(id: "pescatarian", name: "Pescatarian", icon: "🐟"),
        .init(id: "low_carb_keto", name: "Low-carb / Keto", icon: "🥑")
    ]
    
    private let restrictions: [FoodOption] = [
        .init(id: "dairy_free", name: "Dairy-free", icon: "🧀"),
        .init(id: "gluten_free", name: "Gluten-free", icon: "🌾"),
        .init(id: "nut_free", name: "Nut-free", icon: "🥜"),
        .init(id: "soy_free", name: "Soy-free", icon: "🫘"),
        .init(id: "egg_free", name: "Egg-free", icon: "🥚"),
        .init(id: "shellfish_free", name: "Shellfish-free", icon: "🦐"),
        .init(id: "other", name: "Other", icon: "⚠️")
    ]
    
    var body: some View {
        ZStack {
            ForkiTheme.backgroundGradient
                .ignoresSafeArea()
                .onTapGesture {
                    // Dismiss keyboard when tapping background
                    if isOtherFocused {
                        isOtherFocused = false
                    }
                }
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    progressBarSection
                    contentSection
                    nextButtonSection
                }
                .frame(maxWidth: 460)
            }
        }
    }
    
    // MARK: - Sections
    
    private var progressBarSection: some View {
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
    }
    
    private var contentSection: some View {
        VStack(spacing: 20) {
            headerSection
            preferencesSection
            restrictionsSection
        }
        .forkiPanel()
        .padding(.horizontal, 24)
    }
    
    private var headerSection: some View {
        VStack(spacing: 6) {
            Text("What type of diet do you prefer?")
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
    }
    
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dietary Preferences")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(ForkiTheme.textPrimary)
            
            VStack(spacing: 8) {
                noRestrictionsButton
                preferencesGrid
            }
        }
        .padding(.horizontal, 6)
    }
    
    private var noRestrictionsButton: some View {
        Group {
            if let noRestrictions = dietaryPreferences.first(where: { $0.id == "no_restrictions" }) {
                Button(action: {
                    if data.dietaryPreferences.contains(noRestrictions.id) {
                        data.dietaryPreferences.remove(noRestrictions.id)
                    } else {
                        data.dietaryPreferences.removeAll()
                        data.dietaryPreferences.insert(noRestrictions.id)
                    }
                }) {
                    preferenceButtonContent(icon: noRestrictions.icon, name: noRestrictions.name, isSelected: data.dietaryPreferences.contains(noRestrictions.id))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private var preferencesGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(dietaryPreferences.filter { $0.id != "no_restrictions" }) { pref in
                Button(action: {
                    if data.dietaryPreferences.contains(pref.id) {
                        data.dietaryPreferences.remove(pref.id)
                    } else {
                        data.dietaryPreferences.remove("no_restrictions")
                        data.dietaryPreferences.insert(pref.id)
                    }
                }) {
                    preferenceButtonContent(icon: pref.icon, name: pref.name, isSelected: data.dietaryPreferences.contains(pref.id))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private var restrictionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Allergies / Restrictions")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(ForkiTheme.textPrimary)
            
            Text("Select items you cannot have")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(ForkiTheme.textSecondary)
            
            restrictionsGrid
        }
        .padding(.horizontal, 6)
    }
    
    private var restrictionsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(restrictions) { restriction in
                restrictionButton(for: restriction)
                
                // Show text field to the right of "Other" button when selected
                if restriction.id == "other" && data.dietaryRestrictions.contains("other") {
                    otherTextField
                }
            }
        }
    }
    
    private func restrictionButton(for restriction: FoodOption) -> some View {
        Button(action: {
            // If keyboard is visible, dismiss it first before handling button action
            // This prevents accidental button taps while typing
            if isOtherFocused {
                isOtherFocused = false
                // Wait for keyboard to dismiss before processing button action
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    handleRestrictionToggle(restriction)
                }
            } else {
                handleRestrictionToggle(restriction)
            }
        }) {
            preferenceButtonContent(icon: restriction.icon, name: restriction.name, isSelected: data.dietaryRestrictions.contains(restriction.id))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func handleRestrictionToggle(_ restriction: FoodOption) {
        if data.dietaryRestrictions.contains(restriction.id) {
            data.dietaryRestrictions.remove(restriction.id)
            if restriction.id == "other" {
                data.otherRestriction = ""
            }
        } else {
            data.dietaryRestrictions.insert(restriction.id)
        }
    }
    
    private var otherTextField: some View {
        ZStack {
            // Placeholder text (more visible)
            if data.otherRestriction.isEmpty {
                Text("Please specify")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(ForkiTheme.textSecondary.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            
            // TextField - match button text styling exactly
            TextField("", text: $data.otherRestriction)
                .focused($isOtherFocused)
                .multilineTextAlignment(.center)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(ForkiTheme.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.none)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: 40) // Match button height exactly (reduced from 48)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(ForkiTheme.surface.opacity(0.4)) // Match unselected button opacity
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isOtherFocused ? ForkiTheme.borderPrimary : ForkiTheme.borderPrimary.opacity(0.3), lineWidth: isOtherFocused ? 2 : 1.5) // Match button border exactly
        )
    }
    
    private var nextButtonSection: some View {
        OnboardingPrimaryButton(
            isEnabled: !data.dietaryPreferences.isEmpty || !data.dietaryRestrictions.isEmpty
        ) {
            onNext()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
    
    // MARK: - Helper Views
    
    private func preferenceButtonContent(icon: String, name: String, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            Text(icon)
                .font(.system(size: 18))
            Text(name)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(ForkiTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: 40) // Reduced from 48 to 40 for more compact buttons
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? ForkiTheme.surface.opacity(0.8) : ForkiTheme.surface.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? ForkiTheme.borderPrimary : ForkiTheme.borderPrimary.opacity(0.3), lineWidth: isSelected ? 2 : 1.5)
        )
    }
}

#Preview {
    DietaryPreferencesScreen(
        data: OnboardingData(),
        navigator: OnboardingNavigator(),
        onNext: {}
    )
}

