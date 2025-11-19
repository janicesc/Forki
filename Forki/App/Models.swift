//
//  Models.swift
//  Forki
//
//  Created by Janice C on 9/16/25.
//

import Foundation
import CoreGraphics
import SwiftUI

class UserData: ObservableObject {
    @Published var name: String = ""
    @Published var email: String = ""
    @Published var age: String = ""
    @Published var gender: String = ""          // added
    @Published var height: String = ""
    @Published var weight: String = ""
    @Published var goal: String = ""
    @Published var goalDuration: Int = 0
    @Published var foodPreferences: [String] = []
    @Published var notifications: Bool = false
    @Published var selectedCharacter: CharacterType = .avatar
    
    // Main nutrition + avatar logic used across the entire app
    @Published var nutrition: NutritionState = NutritionState()

    // live-updating scales
    @Published var heightScale: CGFloat = 1.0
    @Published var weightScale: CGFloat = 1.0
    
    // Wellness snapshot data
    @Published var personaID: Int = 13
    @Published var recommendedCalories: Int = 2000
    @Published var recommendedMacros: Macros?
    @Published var eatingPattern: String = ""
    @Published var BMI: Double = 0
    @Published var bodyType: String = ""
    @Published var metabolism: String = ""
    
    init() {
        // Load persisted name
        self.name = UserDefaults.standard.string(forKey: "hp_userName") ?? ""
        
        // Load persisted wellness snapshot data
        self.personaID = UserDefaults.standard.integer(forKey: "hp_personaID")
        if personaID == 0 {
            personaID = 13 // Default
        }
        
        self.recommendedCalories = UserDefaults.standard.integer(forKey: "hp_recommendedCalories")
        if recommendedCalories == 0 {
            recommendedCalories = 2000 // Default
        }
        
        if let eatingPattern = UserDefaults.standard.string(forKey: "hp_eatingPattern") {
            self.eatingPattern = eatingPattern
        }
        
        self.BMI = UserDefaults.standard.double(forKey: "hp_BMI")
        if let bodyType = UserDefaults.standard.string(forKey: "hp_bodyType") {
            self.bodyType = bodyType
        }
        if let metabolism = UserDefaults.standard.string(forKey: "hp_metabolism") {
            self.metabolism = metabolism
        }
        
        // Load macros if available
        if let protein = UserDefaults.standard.object(forKey: "hp_macro_protein") as? Int,
           let carbs = UserDefaults.standard.object(forKey: "hp_macro_carbs") as? Int,
           let fats = UserDefaults.standard.object(forKey: "hp_macro_fats") as? Int,
           let fiber = UserDefaults.standard.object(forKey: "hp_macro_fiber") as? Int {
            self.recommendedMacros = Macros(protein: protein, carbs: carbs, fats: fats, fiber: fiber)
        }
    }
    
    func updateName(_ newName: String) {
        name = newName
        UserDefaults.standard.set(newName, forKey: "hp_userName")
    }
    
    func applySnapshot(_ snapshot: WellnessSnapshot) {
        // Store persona data
        personaID = snapshot.persona.personaType
        UserDefaults.standard.set(personaID, forKey: "hp_personaID")
        
        // Store eating pattern
        eatingPattern = snapshot.persona.suggestedPattern
        UserDefaults.standard.set(eatingPattern, forKey: "hp_eatingPattern")
        
        // Store calories and macros
        recommendedCalories = snapshot.recommendedCalories
        UserDefaults.standard.set(recommendedCalories, forKey: "hp_recommendedCalories")
        
        recommendedMacros = snapshot.recommendedMacros
        UserDefaults.standard.set(snapshot.recommendedMacros.protein, forKey: "hp_macro_protein")
        UserDefaults.standard.set(snapshot.recommendedMacros.carbs, forKey: "hp_macro_carbs")
        UserDefaults.standard.set(snapshot.recommendedMacros.fats, forKey: "hp_macro_fats")
        UserDefaults.standard.set(snapshot.recommendedMacros.fiber, forKey: "hp_macro_fiber")
        
        // Store BMI, bodyType, metabolism
        BMI = snapshot.BMI
        UserDefaults.standard.set(BMI, forKey: "hp_BMI")
        
        bodyType = snapshot.bodyType
        UserDefaults.standard.set(bodyType, forKey: "hp_bodyType")
        
        metabolism = snapshot.metabolism
        UserDefaults.standard.set(metabolism, forKey: "hp_metabolism")
    }
    
    // MARK: - Goal Normalization (Backwards Compatibility)
    /// Normalizes goal string to one of the 5 canonical goals
    var normalizedGoal: String {
        let goalLower = goal.lowercased()
        
        // Map old goal strings to new canonical format
        if goalLower.contains("lose") || goal == "slim" {
            return "Lose weight"
        } else if goalLower.contains("gain") || goalLower.contains("build muscle") || goal == "strong" {
            return "Gain weight / build muscle"
        } else if goalLower.contains("maintain") || goal == "content" {
            return "Maintain my weight"
        } else if goalLower.contains("improve") || goalLower.contains("healthier") || goalLower.contains("habits") || goalLower.contains("eat consistently") || goalLower.contains("eat more consistently") {
            return "Build healthier eating habits"
        } else if goalLower.contains("energy") || goalLower.contains("stress") || goalLower.contains("boost") || goalLower.contains("reduce stress") {
            return "Boost energy & reduce stress"
        }
        
        // If goal is already one of the canonical 5, return as-is
        let canonicalGoals = [
            "Build healthier eating habits",
            "Lose weight",
            "Maintain my weight",
            "Gain weight / build muscle",
            "Boost energy & reduce stress"
        ]
        if canonicalGoals.contains(goal) {
            return goal
        }
        
        // Default fallback
        return goal.isEmpty ? "Build healthier eating habits" : goal
    }
}

struct FoodItem: Identifiable, Equatable {
    let id: Int
    let name: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fats: Double
    let category: String
    let usdaFood: USDAFood?
    
    init(
        id: Int,
        name: String,
        calories: Int,
        protein: Double,
        carbs: Double,
        fats: Double,
        category: String,
        usdaFood: USDAFood? = nil
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fats = fats
        self.category = category
        self.usdaFood = usdaFood
    }
    
    static func == (lhs: FoodItem, rhs: FoodItem) -> Bool {
        return lhs.id == rhs.id
    }
}

struct LoggedFood: Identifiable {
    let id: UUID
    let food: FoodItem
    let portion: Double
    let timestamp: Date
    
    init(id: UUID = UUID(), food: FoodItem, portion: Double, timestamp: Date) {
        self.id = id
        self.food = food
        self.portion = portion
        self.timestamp = timestamp
    }
}

enum AvatarState: String {
    case starving
    case sad
    case neutral
    case happy
    case strong
    case overfull
    case bloated
    case dead
}

// MARK: - Recipe Models
struct Recipe: Identifiable, Equatable {
    let id: String
    let title: String
    let imageName: String
    let prepTime: String
    let calories: Int
    let protein: Double
    let fat: Double
    let carbs: Double
    let category: RecipeCategory
    let tags: [String]
    let description: String
    let ingredients: [String]
    let instructions: [String]
}

enum RecipeCategory: String, CaseIterable, Codable {
    case highProtein     = "High-Protein"
    case quickMeals      = "Quick Meals"
    case lightMeals      = "Light Meals"
    case breakfast       = "Breakfast"
    case grabAndGo       = "Grab & Go"
    case higherCalorie   = "Higher-Calorie"
    
    var displayName: String { self.rawValue }
    
    // MARK: - Neon Forki Icons
    var iconName: String {
        switch self {
        case .highProtein:    return "dumbbell"            // strong, protein-focused
        case .quickMeals:     return "bolt.fill"           // fast, 5-min
        case .lightMeals:     return "leaf.fill"           // light & clean
        case .breakfast:      return "sunrise.fill"        // morning icon
        case .grabAndGo:      return "bag.fill"            // portable / to-go
        case .higherCalorie:  return "flame.fill"          // energy / calorie boost
        }
    }
}

// MARK: - Recipe Extension for Food Logging
extension Recipe {
    func toFoodItem() -> FoodItem {
        return FoodItem(
            id: Int(id) ?? 0,
            name: title,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fats: fat,
            category: "Recipe"
        )
    }
}

// MARK: - Character Types
enum CharacterType: String, CaseIterable, Identifiable {
    case avoFriend = "Avo Friend"
    case bobaBuddy = "Boba Buddy"
    case berrySweet = "Berry Sweet"
    case squirtle = "Squirtle"
    case avatar = "Forki"
    case mochiMouse = "Mochi Mouse"
    
    var id: String { self.rawValue }
    
    var modelName: String {
        return self.rawValue.lowercased().replacingOccurrences(of: " ", with: "-")
    }
    
    var displayName: String {
        return self.rawValue
    }
    
    var description: String {
        switch self {
        case .avoFriend:
            return "A nutritious companion who loves healthy fats and green goodness"
        case .bobaBuddy:
            return "A sweet and bubbly friend who brings joy to your wellness journey"
        case .berrySweet:
            return "A delightful companion packed with antioxidants and natural sweetness"
        case .squirtle:
            return "A water-type Pokémon known for its friendly nature"
        case .avatar:
            return "A balanced companion for your health journey"
        case .mochiMouse:
            return "A soft and sweet companion who makes healthy eating fun"
        }
    }
    
    var emoji: String {
        switch self {
        case .avoFriend: return "🥑"
        case .bobaBuddy: return "🧋"
        case .berrySweet: return "🍓"
        case .squirtle: return "🐢"
        case .avatar: return "👤"
        case .mochiMouse: return "🐭"
        }
    }
    
    var imageName: String {
        switch self {
        case .avoFriend: return "avocado"
        case .bobaBuddy: return "boba"
        case .berrySweet: return "strawberry"
        case .squirtle: return "squirtle"
        case .avatar: return "habitpet"
        case .mochiMouse: return "MochiMouse"
        }
    }
}

