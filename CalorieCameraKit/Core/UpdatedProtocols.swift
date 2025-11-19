import Foundation

// MARK: - Updated Service Protocols with Statistical Types

/// Provides nutrition priors with uncertainty
public protocol NutritionDB: Sendable {
    /// Get food priors for a given food key
    ///
    /// Example: "rice:white_cooked" → { kcalPerG: 1.30±0.05, density: 0.85±0.10 }
    ///
    /// - Parameter foodKey: Standardized food identifier
    /// - Returns: Food priors with uncertainty
    func getPriors(for foodKey: String) async throws -> FoodPriors

    /// Search for food items
    func search(query: String) async throws -> [String]  // Returns food keys
}

/// Label/barcode recognition service
public protocol LabelService: Sendable {
    /// Recognize barcode and get nutrition info
    ///
    /// - Parameter barcode: Barcode string
    /// - Returns: Nutrition data if found
    func getNutrition(barcode: String) async throws -> PackageNutrition?
}

/// Menu matching service
public protocol MenuService: Sendable {
    /// Search menu for matching items
    ///
    /// - Parameters:
    ///   - query: Food description
    ///   - venue: Optional restaurant/venue
    /// - Returns: Matching menu items with nutrition
    func search(query: String, venue: String?) async throws -> [MenuItem]
}

// MARK: - Supporting Types

/// Package nutrition from barcode
public struct PackageNutrition: Sendable {
    public let kcalPerServing: Double
    public let servingMassG: Double
    public let servingVolumeML: Double?

    public init(
        kcalPerServing: Double,
        servingMassG: Double,
        servingVolumeML: Double? = nil
    ) {
        self.kcalPerServing = kcalPerServing
        self.servingMassG = servingMassG
        self.servingVolumeML = servingVolumeML
    }
}

/// Menu item with nutrition
public struct MenuItem: Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let kcal: Double
    public let std: Double
    public let refMassG: Double
    public let cuisine: String?

    public init(
        id: UUID = UUID(),
        name: String,
        kcal: Double,
        std: Double,
        refMassG: Double,
        cuisine: String? = nil
    ) {
        self.id = id
        self.name = name
        self.kcal = kcal
        self.std = std
        self.refMassG = refMassG
        self.cuisine = cuisine
    }
}

// MARK: - Mock Implementations

/// Mock nutrition database for testing
public final class MockNutritionDB: NutritionDB {

    private var priors: [String: FoodPriors] = [
        "rice:white_cooked": FoodPriors(
            density: PriorStats(mu: 0.85, sigma: 0.10),
            kcalPerG: PriorStats(mu: 1.30, sigma: 0.05)
        ),
        "chicken:grilled_breast": FoodPriors(
            density: PriorStats(mu: 1.0, sigma: 0.05),
            kcalPerG: PriorStats(mu: 1.65, sigma: 0.10)
        ),
        "apple": FoodPriors(
            density: PriorStats(mu: 0.6, sigma: 0.05),
            kcalPerG: PriorStats(mu: 0.52, sigma: 0.03)
        ),
        "banana": FoodPriors(
            density: PriorStats(mu: 0.94, sigma: 0.05),
            kcalPerG: PriorStats(mu: 0.89, sigma: 0.04)
        )
    ]

    public init() {}

    public func getPriors(for foodKey: String) async throws -> FoodPriors {
        guard let prior = priors[foodKey] else {
            // Return generic fallback
            return FoodPriors(
                density: PriorStats(mu: 0.9, sigma: 0.15),
                kcalPerG: PriorStats(mu: 1.5, sigma: 0.3)
            )
        }
        return prior
    }

    public func search(query: String) async throws -> [String] {
        return priors.keys.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    /// Add custom prior
    public func add(foodKey: String, priors: FoodPriors) {
        self.priors[foodKey] = priors
    }
}

/// Mock label service
public final class MockLabelService: LabelService {

    public init() {}

    public func getNutrition(barcode: String) async throws -> PackageNutrition? {
        // Return nil for now (no barcode match)
        return nil
    }
}

/// Mock menu service
public final class MockMenuService: MenuService {

    public init() {}

    public func search(query: String, venue: String?) async throws -> [MenuItem] {
        // Return empty for now
        return []
    }
}
