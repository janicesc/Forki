import Foundation

/// Dual analyzer client that implements fallback chain: Next.js API → Supabase Edge Function
public struct DualAnalyzerClient: AnalyzerClient {
    public struct Configuration: Sendable {
        public let nextjsAPIURL: URL?  // Primary: Next.js API route
        public let supabaseURL: URL     // Fallback: Supabase Edge Function
        public let supabaseAPIKey: String
        public let timeout: TimeInterval
        
        public init(
            nextjsAPIURL: URL?,
            supabaseURL: URL,
            supabaseAPIKey: String,
            timeout: TimeInterval = 20.0
        ) {
            self.nextjsAPIURL = nextjsAPIURL
            self.supabaseURL = supabaseURL
            self.supabaseAPIKey = supabaseAPIKey
            self.timeout = timeout
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
        let startMsg = "🔄 [DualAnalyzer] Starting analyze() - imageData size: \(imageData.count) bytes, mimeType: \(mimeType)"
        NSLog(startMsg)
        print(startMsg)
        
        // Try Next.js API first (if configured)
        if let nextjsURL = configuration.nextjsAPIURL {
            do {
                let nextjsMsg = "🔄 [DualAnalyzer] Trying Next.js API first: \(nextjsURL.absoluteString)"
                NSLog(nextjsMsg)
                print(nextjsMsg)
                return try await analyzeViaNextJS(imageData: imageData, mimeType: mimeType, url: nextjsURL)
            } catch {
                let errorMsg = "⚠️ [DualAnalyzer] Next.js API failed: \(error), falling back to Supabase"
                NSLog(errorMsg)
                print(errorMsg)
                // Continue to fallback
            }
        }
        
        // Fallback to Supabase Edge Function
        let supabaseMsg = "🔄 [DualAnalyzer] Using Supabase Edge Function: \(configuration.supabaseURL.absoluteString)"
        NSLog(supabaseMsg)
        print(supabaseMsg)
        return try await analyzeViaSupabase(imageData: imageData, mimeType: mimeType)
    }
    
    // MARK: - Next.js API Implementation
    
    private func analyzeViaNextJS(imageData: Data, mimeType: String, url: URL) async throws -> AnalyzerObservation {
        var request = URLRequest(url: url.appendingPathComponent("/api/analyze-food"))
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Next.js API expects JSON with imageBase64
        let payload = NextJSRequestPayload(imageBase64: imageData.base64EncodedString())
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "n/a"
            throw AnalyzerClientError.server(status: status, body: body)
        }
        
        // Try Next.js format first, then fallback to Supabase format
        do {
            let nextjsResponse = try JSONDecoder().decode(NextJSResponsePayload.self, from: data)
            let analyzerResponse = nextjsResponse.toAnalyzerResponse()
            NSLog("✅ [DualAnalyzer] Next.js API success! Used analyzers: \(analyzerResponse.meta?.used?.joined(separator: ", ") ?? "unknown")")
            return try parseResponse(analyzerResponse)
        } catch {
            // Fallback: try Supabase format (in case Next.js returns same format)
            NSLog("⚠️ [DualAnalyzer] Next.js format parse failed, trying Supabase format: \(error)")
            let decoded = try JSONDecoder().decode(AnalyzerResponsePayload.self, from: data)
            return try parseResponse(decoded)
        }
    }
    
    // MARK: - Supabase Edge Function Implementation
    
    private func analyzeViaSupabase(imageData: Data, mimeType: String) async throws -> AnalyzerObservation {
        let url = configuration.supabaseURL.appendingPathComponent("/analyze_food")
        let urlMsg = "🔄 [DualAnalyzer] Supabase URL: \(url.absoluteString)"
        NSLog(urlMsg)
        print(urlMsg)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Increase timeout to 30 seconds to handle slow API responses (Edge Function can take 5-10 seconds)
        request.timeoutInterval = max(configuration.timeout, 30.0)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.supabaseAPIKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(configuration.supabaseAPIKey)", forHTTPHeaderField: "Authorization")
        
        NSLog("⏱️ [DualAnalyzer] Request timeout set to: \(request.timeoutInterval) seconds")
        print("⏱️ [DualAnalyzer] Request timeout set to: \(request.timeoutInterval) seconds")
        
        let base64String = imageData.base64EncodedString()
        let payload = SupabaseRequestPayload(
            imageBase64: base64String,
            mimeType: mimeType
        )
        request.httpBody = try JSONEncoder().encode(payload)
        
        let payloadSizeMsg = "🔄 [DualAnalyzer] Sending request - payload size: \(request.httpBody?.count ?? 0) bytes, base64 length: \(base64String.count)"
        NSLog(payloadSizeMsg)
        print(payloadSizeMsg)
        
        let (data, response) = try await urlSession.data(for: request)
        
        let responseMsg = "🔄 [DualAnalyzer] Received response - status: \((response as? HTTPURLResponse)?.statusCode ?? -1), data size: \(data.count) bytes"
        NSLog(responseMsg)
        print(responseMsg)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "n/a"
            throw AnalyzerClientError.server(status: status, body: body)
        }
        
        // CRITICAL: Log raw response before decoding
        if let jsonString = String(data: data, encoding: .utf8) {
            let jsonPreview = String(jsonString.prefix(2000))
            NSLog("📦 [DualAnalyzer] Raw JSON response (first 2000 chars): \(jsonPreview)")
            print("📦 [DualAnalyzer] Raw JSON response (first 2000 chars): \(jsonPreview)")
            
            // Try to extract label directly from JSON string for debugging
            if let labelMatch = jsonString.range(of: "\"label\"\\s*:\\s*\"([^\"]+)\"", options: .regularExpression) {
                let extractedLabel = String(jsonString[labelMatch])
                NSLog("📦 [DualAnalyzer] Extracted label from raw JSON: \(extractedLabel)")
                print("📦 [DualAnalyzer] Extracted label from raw JSON: \(extractedLabel)")
            }
        }
        
        let decoded: AnalyzerResponsePayload
        do {
            decoded = try JSONDecoder().decode(AnalyzerResponsePayload.self, from: data)
        } catch {
            let decodeError = "❌ [DualAnalyzer] JSON DECODING FAILED: \(error)"
            NSLog(decodeError)
            print(decodeError)
            NSLog("❌ [DualAnalyzer] Response data: \(String(data: data, encoding: .utf8)?.prefix(500) ?? "n/a")")
            print("❌ [DualAnalyzer] Response data: \(String(data: data, encoding: .utf8)?.prefix(500) ?? "n/a")")
            throw AnalyzerClientError.decoding(error)
        }
        
        let successMsg = "✅ [DualAnalyzer] Supabase API success! Used analyzers: \(decoded.meta?.used?.joined(separator: ", ") ?? "unknown")"
        NSLog(successMsg)
        print(successMsg)
        
        let countMsg = "✅ [DualAnalyzer] Raw response items count: \(decoded.items.count)"
        NSLog(countMsg)
        print(countMsg)
        
        if let firstItem = decoded.items.first {
            let labelMsg = "✅ [DualAnalyzer] First item label from API: '\(firstItem.label)'"
            NSLog(labelMsg)
            print(labelMsg)
        } else {
            let errorMsg = "❌ [DualAnalyzer] NO ITEMS IN RESPONSE!"
            NSLog(errorMsg)
            print(errorMsg)
            throw AnalyzerClientError.decoding(
                NSError(domain: "DualAnalyzerClient", code: -2,
                       userInfo: [NSLocalizedDescriptionKey: "No items in API response"])
            )
        }
        return try parseResponse(decoded)
    }
    
    // MARK: - Response Parsing
    
    private func parseResponse(_ decoded: AnalyzerResponsePayload) throws -> AnalyzerObservation {
        guard let firstItem = decoded.items.first else {
            throw AnalyzerClientError.decoding(
                NSError(domain: "DualAnalyzerClient", code: -1,
                       userInfo: [NSLocalizedDescriptionKey: "No items in response"])
            )
        }
        
        let priors: FoodPriors? = firstItem.priors.map { priorsData in
            FoodPriors(
                density: PriorStats(mu: priorsData.density.mu, sigma: priorsData.density.sigma),
                kcalPerG: PriorStats(mu: priorsData.kcalPerG.mu, sigma: priorsData.kcalPerG.sigma)
            )
        }
        
        let path: DetectionPath? = firstItem.path.flatMap { DetectionPath(rawValue: $0) }
        
        let nutritionLabel: NutritionLabel? = firstItem.nutritionLabel.map { labelData in
            NutritionLabel(
                servingSize: labelData.servingSize,
                caloriesPerServing: labelData.caloriesPerServing,
                totalServings: labelData.totalServings
            )
        }
        
        let menuItem: RestaurantMenuItem? = firstItem.menuItem.map { menuData in
            RestaurantMenuItem(
                restaurant: menuData.restaurant,
                itemName: menuData.itemName,
                calories: menuData.calories
            )
        }
        
        let parsedMsg = "✅ [DualAnalyzer] Parsed: Path=\(path?.rawValue ?? "nil"), Label='\(firstItem.label)', Calories=\(firstItem.calories?.description ?? "nil")"
        NSLog(parsedMsg)
        print(parsedMsg) // Also use print for visibility
        
        let fullMsg = "✅ [DualAnalyzer] Full item: label='\(firstItem.label)', confidence=\(firstItem.confidence), calories=\(firstItem.calories ?? -1)"
        NSLog(fullMsg)
        print(fullMsg)
        
        // CRITICAL: Log the exact label being returned
        let observationLabel = firstItem.label
        NSLog("🔑 [DualAnalyzer] CRITICAL: Creating AnalyzerObservation with label: '\(observationLabel)'")
        print("🔑 [DualAnalyzer] CRITICAL: Creating AnalyzerObservation with label: '\(observationLabel)'")
        
        // Extract macros from API response
        let macros: (proteinG: Double?, carbsG: Double?, fatG: Double?)? = firstItem.macros.map { macrosData in
            (proteinG: macrosData.proteinG, carbsG: macrosData.carbsG, fatG: macrosData.fatG)
        }
        
        NSLog("📊 [DualAnalyzer] Macros from API: protein=\(macros?.proteinG ?? -1), carbs=\(macros?.carbsG ?? -1), fat=\(macros?.fatG ?? -1)")
        print("📊 [DualAnalyzer] Macros from API: protein=\(macros?.proteinG ?? -1), carbs=\(macros?.carbsG ?? -1), fat=\(macros?.fatG ?? -1)")
        
        let observation = AnalyzerObservation(
            label: observationLabel,
            confidence: firstItem.confidence,
            priors: priors,
            evidence: firstItem.evidence ?? [],
            metaUsed: decoded.meta?.used ?? [],
            path: path,
            calories: firstItem.calories,
            sigmaCalories: firstItem.sigmaCalories,
            macros: macros,
            nutritionLabel: nutritionLabel,
            menuItem: menuItem
        )
        
        NSLog("🔑 [DualAnalyzer] CRITICAL: AnalyzerObservation created, label='\(observation.label)'")
        print("🔑 [DualAnalyzer] CRITICAL: AnalyzerObservation created, label='\(observation.label)'")
        
        return observation
    }
}

// MARK: - Request Payloads

private struct NextJSRequestPayload: Encodable {
    let imageBase64: String
}

private struct SupabaseRequestPayload: Encodable {
    let imageBase64: String
    let mimeType: String
}

// MARK: - Next.js API Response Format

private struct NextJSResponsePayload: Decodable {
    let foodType: String
    let confidence: Double
    let calories: Double
    let weight: Double
    let emoji: String?
    let items: [NextJSItem]?
    let meta: NextJSMeta?
    
    struct NextJSItem: Decodable {
        let label: String
        let calories: Double
        let weight: Double
        let confidence: Double?
        let emoji: String?
    }
    
    struct NextJSMeta: Decodable {
        let used: [String]?
        let latencyMs: Double?
        let isFallback: Bool?
        let warnings: [String]?
        let calculationMethod: String?
        let itemCount: Int?
    }
    
    // Convert Next.js format to Supabase format for iOS compatibility
    func toAnalyzerResponse() -> AnalyzerResponsePayload {
        let items: [AnalyzerResponsePayload.Item]
        
        if let nextjsItems = self.items, !nextjsItems.isEmpty {
            // Multi-item meal response
            items = nextjsItems.map { item in
                AnalyzerResponsePayload.Item(
                    label: item.label,
                    confidence: item.confidence ?? self.confidence,
                    priors: nil, // Next.js API doesn't return priors in this format
                    evidence: [],
                    path: nil,
                    calories: item.calories,
                    sigmaCalories: item.calories * 0.1, // Estimate uncertainty
                    macros: nil, // Next.js API doesn't return macros in this format
                    nutritionLabel: nil,
                    menuItem: nil
                )
            }
        } else {
            // Single item response
            items = [            AnalyzerResponsePayload.Item(
                label: self.foodType,
                confidence: self.confidence,
                priors: nil, // Next.js API doesn't return priors in this format
                evidence: [],
                path: nil,
                calories: self.calories,
                sigmaCalories: self.calories * 0.1, // Estimate uncertainty
                macros: nil, // Next.js API doesn't return macros in this format
                nutritionLabel: nil,
                menuItem: nil
            )]
        }
        
        return AnalyzerResponsePayload(
            items: items,
            meta: AnalyzerResponsePayload.Meta(
                used: self.meta?.used,
                latencyMs: self.meta?.latencyMs
            )
        )
    }
}

// MARK: - Reuse Types from HTTPAnalyzerClient

// AnalyzerResponsePayload is defined in HTTPAnalyzerClient.swift and is accessible here
// We need to reference it, but since it's private in HTTPAnalyzerClient, we'll define it here too
// for DualAnalyzerClient's use

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

    struct MacrosData: Decodable {
        let proteinG: Double?
        let carbsG: Double?
        let fatG: Double?
    }
    
    struct Item: Decodable {
        let label: String
        let confidence: Double
        let priors: PriorsData?
        let evidence: [String]?
        let path: String?
        let calories: Double?
        let sigmaCalories: Double?
        let macros: MacrosData?
        let nutritionLabel: NutritionLabelData?
        let menuItem: MenuItemData?
    }

    let items: [Item]
    let meta: Meta?
}

