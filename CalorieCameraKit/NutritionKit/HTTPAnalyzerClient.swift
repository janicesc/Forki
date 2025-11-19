import Foundation

public enum DetectionPath: String, Sendable {
    case label
    case menu
    case geometry
}

public struct NutritionLabel: Sendable {
    public let servingSize: String
    public let caloriesPerServing: Double
    public let totalServings: Double?

    public init(servingSize: String, caloriesPerServing: Double, totalServings: Double?) {
        self.servingSize = servingSize
        self.caloriesPerServing = caloriesPerServing
        self.totalServings = totalServings
    }
}

public struct RestaurantMenuItem: Sendable {
    public let restaurant: String
    public let itemName: String
    public let calories: Double

    public init(restaurant: String, itemName: String, calories: Double) {
        self.restaurant = restaurant
        self.itemName = itemName
        self.calories = calories
    }
}

public struct AnalyzerObservation: Sendable {
    public let label: String
    public let confidence: Double
    public let priors: FoodPriors?
    public let evidence: [String]
    public let metaUsed: [String]
    public let path: DetectionPath?
    public let calories: Double?
    public let sigmaCalories: Double?
    public let macros: (proteinG: Double?, carbsG: Double?, fatG: Double?)?
    public let nutritionLabel: NutritionLabel?
    public let menuItem: RestaurantMenuItem?

    public init(
        label: String,
        confidence: Double,
        priors: FoodPriors?,
        evidence: [String],
        metaUsed: [String],
        path: DetectionPath? = nil,
        calories: Double? = nil,
        sigmaCalories: Double? = nil,
        macros: (proteinG: Double?, carbsG: Double?, fatG: Double?)? = nil,
        nutritionLabel: NutritionLabel? = nil,
        menuItem: RestaurantMenuItem? = nil
    ) {
        self.label = label
        self.confidence = confidence
        self.priors = priors
        self.evidence = evidence
        self.metaUsed = metaUsed
        self.path = path
        self.calories = calories
        self.sigmaCalories = sigmaCalories
        self.macros = macros
        self.nutritionLabel = nutritionLabel
        self.menuItem = menuItem
    }
}

public protocol AnalyzerClient: Sendable {
    func analyze(imageData: Data, mimeType: String) async throws -> AnalyzerObservation
}

public struct HTTPAnalyzerClient: AnalyzerClient {
    public struct Configuration: Sendable {
        public let baseURL: URL
        public let endpointPath: String
        public let timeout: TimeInterval
        public let apiKey: String?

        public init(
            baseURL: URL,
            endpointPath: String = "/analyze_food",
            timeout: TimeInterval = 20.0,
            apiKey: String? = nil
        ) {
            self.baseURL = baseURL
            self.endpointPath = endpointPath
            self.timeout = timeout
            self.apiKey = apiKey
        }
    }

    private let configuration: Configuration
    private let urlSession: URLSession

    public init(
        configuration: Configuration,
        urlSession: URLSession = .shared
    ) {
        self.configuration = configuration
        self.urlSession = urlSession
    }

    public func analyze(imageData: Data, mimeType: String) async throws -> AnalyzerObservation {
        var request = URLRequest(
            url: configuration.baseURL.appendingPathComponent(configuration.endpointPath)
        )
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add Supabase API key header if provided
        if let apiKey = configuration.apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let payload = AnalyzerRequestPayload(
            imageBase64: imageData.base64EncodedString(),
            mimeType: mimeType
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await urlSession.data(for: request)

        guard
            let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode)
        else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "n/a"
            throw AnalyzerClientError.server(status: status, body: body)
        }

        // Log raw JSON response
        if let jsonString = String(data: data, encoding: .utf8) {
            NSLog("📦 RAW API RESPONSE: \(jsonString.prefix(500))")
        }

        let decoded: AnalyzerResponsePayload
        do {
            decoded = try JSONDecoder().decode(AnalyzerResponsePayload.self, from: data)
        } catch {
            NSLog("❌ JSON DECODE ERROR: \(error)")
            throw AnalyzerClientError.decoding(error)
        }
        // Extract first item from response
        guard let firstItem = decoded.items.first else {
            throw AnalyzerClientError.decoding(NSError(domain: "AnalyzerClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No items in response"]))
        }

        NSLog("📦 PARSED firstItem.calories: \(firstItem.calories?.description ?? "nil")")
        NSLog("📦 PARSED firstItem.sigmaCalories: \(firstItem.sigmaCalories?.description ?? "nil")")
        NSLog("📦 PARSED firstItem.path: \(firstItem.path ?? "nil")")

        // Parse priors from response
        let priors: FoodPriors? = firstItem.priors.map { priorsData in
            FoodPriors(
                density: PriorStats(mu: priorsData.density.mu, sigma: priorsData.density.sigma),
                kcalPerG: PriorStats(mu: priorsData.kcalPerG.mu, sigma: priorsData.kcalPerG.sigma)
            )
        }

        // Parse path from response
        let path: DetectionPath? = firstItem.path.flatMap { DetectionPath(rawValue: $0) }

        // Parse nutrition label if present
        let nutritionLabel: NutritionLabel? = firstItem.nutritionLabel.map { labelData in
            NutritionLabel(
                servingSize: labelData.servingSize,
                caloriesPerServing: labelData.caloriesPerServing,
                totalServings: labelData.totalServings
            )
        }

        // Parse menu item if present
        let menuItem: RestaurantMenuItem? = firstItem.menuItem.map { menuData in
            RestaurantMenuItem(
                restaurant: menuData.restaurant,
                itemName: menuData.itemName,
                calories: menuData.calories
            )
        }

        return AnalyzerObservation(
            label: firstItem.label,
            confidence: firstItem.confidence,
            priors: priors,
            evidence: firstItem.evidence ?? [],
            metaUsed: decoded.meta?.used ?? [],
            path: path,
            calories: firstItem.calories,
            sigmaCalories: firstItem.sigmaCalories,
            nutritionLabel: nutritionLabel,
            menuItem: menuItem
        )
    }
}

public enum AnalyzerClientError: Error, LocalizedError {
    case server(status: Int, body: String)
    case decoding(Error)

    public var errorDescription: String? {
        switch self {
        case .server(let status, let body):
            return "Analyzer server error \(status): \(body)"
        case .decoding(let error):
            return "Analyzer decoding error: \(error.localizedDescription)"
        }
    }
}

private struct AnalyzerRequestPayload: Encodable {
    let imageBase64: String
    let mimeType: String
}

private struct AnalyzerResponsePayload: Decodable {
    struct Meta: Decodable {
        let used: [String]?
        let latencyMs: Double?
    }

    struct PriorsData: Decodable {
        struct StatData: Decodable {
            let mu: Double
            let sigma: Double
        }
        let density: StatData
        let kcalPerG: StatData
    }

    struct NutritionLabelData: Decodable {
        let servingSize: String
        let caloriesPerServing: Double
        let totalServings: Double?
    }

    struct MenuItemData: Decodable {
        let restaurant: String
        let itemName: String
        let calories: Double
    }

    struct Item: Decodable {
        let label: String
        let confidence: Double
        let priors: PriorsData?
        let evidence: [String]?
        let path: String?
        let calories: Double?
        let sigmaCalories: Double?
        let nutritionLabel: NutritionLabelData?
        let menuItem: MenuItemData?
    }

    let items: [Item]
    let meta: Meta?
}
