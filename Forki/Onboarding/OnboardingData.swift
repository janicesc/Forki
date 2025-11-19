//
//  OnboardingData.swift
//  Forki
//
//  Created by Cursor AI on 11/11/25.
//

import Foundation

// MARK: - Onboarding Data Model
class OnboardingData: ObservableObject {
    // Section 1: Basic Info
    @Published var age: String = ""
    @Published var gender: GenderChoice?
    
    // Height
    @Published var heightFeet: String = ""
    @Published var heightInches: String = ""
    @Published var heightCm: String = ""
    @Published var heightUnit: HeightUnit = .feet
    
    // Weight
    @Published var weightLbs: String = ""
    @Published var weightKg: String = ""
    @Published var weightUnit: WeightUnit = .lbs
    
    // Section 2: Goals
    @Published var primaryGoals: Set<String> = []
    @Published var goalWeight: String = ""
    @Published var useRecommendedGoalWeight: Bool = false
    
    // Section 3: Dietary Preferences
    @Published var dietaryPreferences: Set<String> = []
    @Published var dietaryRestrictions: Set<String> = []
    @Published var otherRestriction: String = ""
    
    // Section 4: Eating Habits
    @Published var eatingHabits: Set<String> = []
    
    // Section 5: Lifestyle
    @Published var activityLevel: String = ""
    
    // Section 7: Notifications
    @Published var notificationsEnabled: Bool = false
    
    // Persona ID (set after Wellness Snapshot calculation)
    var personaIDValue: Int = 13 // Default persona
    var personaID: Int? {
        return personaIDValue > 0 ? personaIDValue : nil
    }
    
    // MARK: - Validation
    
    func isSection1Complete() -> Bool {
        return !age.isEmpty && gender != nil && isHeightValid() && isWeightValid()
    }
    
    func isSection2Complete() -> Bool {
        guard !primaryGoals.isEmpty else { return false }
        // If user selected lose or gain weight, check if goal weight is set
        let hasLoseOrGain = primaryGoals.contains("lose_weight") || primaryGoals.contains("gain_weight")
        if hasLoseOrGain {
            return !goalWeight.isEmpty || useRecommendedGoalWeight
        }
        return true
    }
    
    func isSection3Complete() -> Bool {
        // At least one preference or restriction should be selected, or "No restrictions"
        return !dietaryPreferences.isEmpty || !dietaryRestrictions.isEmpty || dietaryPreferences.contains("no_restrictions")
    }
    
    func isSection4Complete() -> Bool {
        return !eatingHabits.isEmpty
    }
    
    func isSection5Complete() -> Bool {
        return !activityLevel.isEmpty
    }
    
    func isComplete() -> Bool {
        return isSection1Complete() && isSection2Complete() && isSection3Complete() && isSection4Complete() && isSection5Complete()
    }
    
    // MARK: - Helpers
    
    private func isHeightValid() -> Bool {
        if heightUnit == .feet {
            guard let feet = Int(heightFeet), feet >= 3, feet <= 8 else { return false }
            guard let inches = Int(heightInches), inches >= 0, inches < 12 else { return false }
            return true
        } else {
            guard let cm = Int(heightCm), cm >= 90, cm <= 250 else { return false }
            return true
        }
    }
    
    private func isWeightValid() -> Bool {
        if weightUnit == .lbs {
            guard let lbs = Double(weightLbs), lbs >= 50, lbs <= 500 else { return false }
            return true
        } else {
            guard let kg = Double(weightKg), kg >= 20, kg <= 250 else { return false }
            return true
        }
    }
    
    // MARK: - BMI Calculation
    
    func calculateBMI() -> Double? {
        guard isHeightValid() && isWeightValid() else { return nil }
        
        let heightInMeters: Double
        let weightInKg: Double
        
        if heightUnit == .feet {
            guard let feet = Double(heightFeet), let inches = Double(heightInches) else { return nil }
            let totalInches = feet * 12 + inches
            heightInMeters = totalInches * 0.0254
        } else {
            guard let cm = Double(heightCm) else { return nil }
            heightInMeters = cm / 100.0
        }
        
        if weightUnit == .lbs {
            guard let lbs = Double(weightLbs) else { return nil }
            weightInKg = lbs * 0.453592
        } else {
            guard let kg = Double(weightKg) else { return nil }
            weightInKg = kg
        }
        
        guard heightInMeters > 0 else { return nil }
        return weightInKg / (heightInMeters * heightInMeters)
    }
    
    func getBMICategory() -> String? {
        guard let bmi = calculateBMI() else { return nil }
        
        switch bmi {
        case ..<18.5:
            return "underweight"
        case 18.5..<25:
            return "normal"
        case 25..<30:
            return "overweight"
        default:
            return "obese"
        }
    }
}

// MARK: - Enums

enum GenderChoice: String, CaseIterable, Identifiable {
    case man = "man"
    case woman = "woman"
    case nonBinary = "non-binary"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .man:       return "Man"
        case .woman:     return "Woman"
        case .nonBinary: return "Non-binary"
        }
    }

    var icon: String {
        switch self {
        case .man:       return "♂"
        case .woman:     return "♀"
        case .nonBinary: return "🜬"
        }
    }
}

enum HeightUnit: String, CaseIterable {
    case feet = "ft"
    case cm = "cm"
}

enum WeightUnit: String, CaseIterable {
    case lbs = "lbs"
    case kg = "kg"
}

// MARK: - Helper Extensions

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

