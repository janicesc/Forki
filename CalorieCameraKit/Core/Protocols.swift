import Foundation

// MARK: - Pipeline Protocols (Dependency Inversion)

/// Captures frames with optional depth data
public protocol FrameCaptureService: Sendable {
    /// Check if camera is available on this device
    func isCameraAvailable() -> Bool

    /// Request camera permissions
    func requestPermissions() async throws

    /// Start capture session
    func startSession() async throws

    /// Stop capture session
    func stopSession()

    /// Capture a single frame
    func captureFrame() async throws -> CapturedFrame
}

/// Detects food items in images
public protocol FoodDetectionService: Sendable {
    /// Detect food items in a frame
    func detectFood(in frame: CapturedFrame) async throws -> [FoodDetection]
}

/// Estimates portion size and volume
public protocol PortionEstimationService: Sendable {
    /// Estimate portion from frame and detection
    func estimatePortion(
        frame: CapturedFrame,
        detection: FoodDetection
    ) async throws -> PortionEstimate
}

/// Provides nutrition data
public protocol NutritionDataService: Sendable {
    /// Get nutrition data for a food item
    func getNutrition(
        for foodName: String,
        portionGrams: Float
    ) async throws -> NutritionData

    /// Search for food items
    func searchFood(query: String) async throws -> [NutritionData]
}

/// Decides where to run computation (local vs cloud)
public protocol ComputeRouter: Sendable {
    /// Determine if detection should run locally or in cloud
    func shouldRunLocally(frameSize: Int, config: FeatureConfig) -> Bool

    /// Get cloud endpoint if available
    func getCloudEndpoint() -> URL?
}

/// Telemetry for analytics and improvement
public protocol TelemetryService: Sendable {
    /// Log an event (anonymized by default)
    func logEvent(_ event: TelemetryEvent) async

    /// Log error for debugging
    func logError(_ error: Error, context: [String: String]) async
}

/// Configuration service for feature flags and remote config
public protocol ConfigurationService: Sendable {
    /// Get current feature configuration
    func getConfig() async -> FeatureConfig

    /// Refresh configuration from remote
    func refreshConfig() async throws
}

// MARK: - Configuration Types

/// Feature configuration with flags
public struct FeatureConfig: Sendable, Codable {
    // Core features
    public let enableDepthSensing: Bool
    public let enableLocalML: Bool
    public let enableCloudML: Bool
    public let enableTelemetry: Bool

    // Privacy
    public let uploadImages: Bool // Default: false
    public let uploadDepthMaps: Bool // Default: false
    public let anonymizeTelemetry: Bool // Default: true

    // ML thresholds
    public let minConfidenceThreshold: Float
    public let useSegmentation: Bool

    // Network
    public let apiEndpoint: String?
    public let apiTimeout: TimeInterval

    // Calibration
    public let enableCalibration: Bool
    public let calibrationSamples: Int

    public init(
        enableDepthSensing: Bool = true,
        enableLocalML: Bool = true,
        enableCloudML: Bool = false,
        enableTelemetry: Bool = false,
        uploadImages: Bool = false,
        uploadDepthMaps: Bool = false,
        anonymizeTelemetry: Bool = true,
        minConfidenceThreshold: Float = 0.7,
        useSegmentation: Bool = false,
        apiEndpoint: String? = nil,
        apiTimeout: TimeInterval = 30.0,
        enableCalibration: Bool = false,
        calibrationSamples: Int = 10
    ) {
        self.enableDepthSensing = enableDepthSensing
        self.enableLocalML = enableLocalML
        self.enableCloudML = enableCloudML
        self.enableTelemetry = enableTelemetry
        self.uploadImages = uploadImages
        self.uploadDepthMaps = uploadDepthMaps
        self.anonymizeTelemetry = anonymizeTelemetry
        self.minConfidenceThreshold = minConfidenceThreshold
        self.useSegmentation = useSegmentation
        self.apiEndpoint = apiEndpoint
        self.apiTimeout = apiTimeout
        self.enableCalibration = enableCalibration
        self.calibrationSamples = calibrationSamples
    }

    /// Safe defaults for production
    public static let `default` = FeatureConfig()

    /// Development config with more features enabled
    public static let development = FeatureConfig(
        enableDepthSensing: true,
        enableLocalML: true,
        enableCloudML: true,
        enableTelemetry: true,
        uploadImages: false, // Still privacy-first
        uploadDepthMaps: false,
        anonymizeTelemetry: true,
        minConfidenceThreshold: 0.5,
        useSegmentation: true,
        enableCalibration: true
    )
}

// MARK: - Telemetry Types

public struct TelemetryEvent: Sendable {
    public let name: String
    public let timestamp: Date
    public let properties: [String: String]
    public let metrics: [String: Double]

    public init(
        name: String,
        timestamp: Date = Date(),
        properties: [String: String] = [:],
        metrics: [String: Double] = [:]
    ) {
        self.name = name
        self.timestamp = timestamp
        self.properties = properties
        self.metrics = metrics
    }

    // Common events
    public static func captureStarted() -> TelemetryEvent {
        TelemetryEvent(name: "capture_started")
    }

    public static func captureCompleted(durationMs: Double) -> TelemetryEvent {
        TelemetryEvent(
            name: "capture_completed",
            metrics: ["duration_ms": durationMs]
        )
    }

    public static func detectionCompleted(
        confidence: Float,
        durationMs: Double,
        method: String
    ) -> TelemetryEvent {
        TelemetryEvent(
            name: "detection_completed",
            properties: ["method": method],
            metrics: [
                "confidence": Double(confidence),
                "duration_ms": durationMs
            ]
        )
    }

    public static func error(
        stage: String,
        errorType: String
    ) -> TelemetryEvent {
        TelemetryEvent(
            name: "error_occurred",
            properties: [
                "stage": stage,
                "error_type": errorType
            ]
        )
    }
}

// MARK: - Mock Implementations for Testing

/// Mock frame capture for testing
public final class MockFrameCaptureService: FrameCaptureService, @unchecked Sendable {
    public var shouldFail = false
    public var mockFrame: CapturedFrame?

    public init() {}

    public func isCameraAvailable() -> Bool { true }

    public func requestPermissions() async throws {
        if shouldFail {
            throw CalorieCameraError.permissionDenied
        }
    }

    public func startSession() async throws {
        if shouldFail {
            throw CalorieCameraError.cameraUnavailable
        }
    }

    public func stopSession() {}

    public func captureFrame() async throws -> CapturedFrame {
        if shouldFail {
            throw CalorieCameraError.captureFailure("Mock failure")
        }
        return mockFrame ?? CapturedFrame(
            rgbImage: Data(),
            depthData: nil,
            cameraIntrinsics: nil
        )
    }
}

/// Mock food detection for testing
public final class MockFoodDetectionService: FoodDetectionService, @unchecked Sendable {
    public var shouldFail = false
    public var mockDetections: [FoodDetection] = []

    public init() {}

    public func detectFood(in frame: CapturedFrame) async throws -> [FoodDetection] {
        if shouldFail {
            throw CalorieCameraError.detectionFailure("Mock failure")
        }
        return mockDetections
    }
}

/// Mock nutrition service for testing
public final class MockNutritionDataService: NutritionDataService, @unchecked Sendable {
    public var shouldFail = false
    public var mockNutrition: NutritionData?

    public init() {}

    public func getNutrition(for foodName: String, portionGrams: Float) async throws -> NutritionData {
        if shouldFail {
            throw CalorieCameraError.networkFailure("Mock failure")
        }
        return mockNutrition ?? NutritionData(
            foodName: foodName,
            calories: 100,
            macros: Macronutrients(proteinG: 5, carbsG: 20, fatG: 3, fiberG: 2),
            servingSize: ServingSize(amount: portionGrams, unit: .grams),
            source: .localDatabase
        )
    }

    public func searchFood(query: String) async throws -> [NutritionData] {
        if shouldFail {
            throw CalorieCameraError.networkFailure("Mock failure")
        }
        return []
    }
}
