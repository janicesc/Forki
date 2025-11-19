import Foundation
import CoreGraphics
import simd

// MARK: - Core Domain Types

/// Represents captured frame data with depth information
public struct CapturedFrame: Sendable {
    public let id: UUID
    public let timestamp: Date
    public let rgbImage: Data // JPEG or PNG data
    public let depthData: DepthData?
    public let cameraIntrinsics: CameraIntrinsics?
    public let metadata: FrameMetadata

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        rgbImage: Data,
        depthData: DepthData? = nil,
        cameraIntrinsics: CameraIntrinsics? = nil,
        metadata: FrameMetadata = FrameMetadata()
    ) {
        self.id = id
        self.timestamp = timestamp
        self.rgbImage = rgbImage
        self.depthData = depthData
        self.cameraIntrinsics = cameraIntrinsics
        self.metadata = metadata
    }
}

/// Depth information from LiDAR or SfM
public struct DepthData: Sendable {
    public let width: Int
    public let height: Int
    public let depthMap: [Float] // in meters
    public let confidenceMap: [Float]? // 0-1
    public let source: DepthSource

    public init(width: Int, height: Int, depthMap: [Float], confidenceMap: [Float]? = nil, source: DepthSource) {
        self.width = width
        self.height = height
        self.depthMap = depthMap
        self.confidenceMap = confidenceMap
        self.source = source
    }
}

public enum DepthSource: String, Sendable, Codable {
    case lidar
    case structureFromMotion
    case stereo
    case monocular
}

/// Camera intrinsic parameters
public struct CameraIntrinsics: Sendable {
    public let focalLength: SIMD2<Float> // fx, fy
    public let principalPoint: SIMD2<Float> // cx, cy
    public let imageSize: SIMD2<Int> // width, height

    public init(focalLength: SIMD2<Float>, principalPoint: SIMD2<Float>, imageSize: SIMD2<Int>) {
        self.focalLength = focalLength
        self.principalPoint = principalPoint
        self.imageSize = imageSize
    }
}

/// Frame capture metadata
public struct FrameMetadata: Sendable {
    public let exposureDuration: TimeInterval?
    public let iso: Float?
    public let brightness: Float?
    public let deviceOrientation: DeviceOrientation

    public init(
        exposureDuration: TimeInterval? = nil,
        iso: Float? = nil,
        brightness: Float? = nil,
        deviceOrientation: DeviceOrientation = .portrait
    ) {
        self.exposureDuration = exposureDuration
        self.iso = iso
        self.brightness = brightness
        self.deviceOrientation = deviceOrientation
    }
}

public enum DeviceOrientation: String, Sendable, Codable {
    case portrait
    case portraitUpsideDown
    case landscapeLeft
    case landscapeRight
    case unknown
}

// MARK: - Tracking & Quality

/// Simplified tracking state extracted from ARKit/Vision
public enum TrackingState: String, Sendable, Codable {
    case notAvailable
    case limited
    case normal

    /// Numeric quality contribution (0-1) for weighting
    public var qualityScore: Double {
        switch self {
        case .normal:
            return 1.0
        case .limited:
            return 0.6
        case .notAvailable:
            return 0.0
        }
    }

    /// True when tracking is stable enough to accumulate frames
    public var isStable: Bool {
        self == .normal
    }
}

/// Per-frame metrics used by the capture quality estimator
public struct CaptureQualitySample: Sendable {
    public let timestamp: Date
    /// Total parallax travelled since capture start (metres)
    public let parallax: Double
    /// Current AR tracking state
    public let trackingState: TrackingState
    /// Fraction (0-1) of pixels with reliable depth
    public let depthCoverage: Double

    public init(
        timestamp: Date = Date(),
        parallax: Double,
        trackingState: TrackingState,
        depthCoverage: Double
    ) {
        self.timestamp = timestamp
        self.parallax = parallax
        self.trackingState = trackingState
        self.depthCoverage = depthCoverage
    }
}

/// Result of evaluating the capture quality gates
public struct CaptureQualityStatus: Sendable {
    /// Weighted quality score, 0-1
    public let score: Double
    /// Score relative to stop threshold (0-1)
    public let progress: Double
    /// Whether the estimator recommends stopping capture
    public let shouldStop: Bool
    /// True when parallax requirement is satisfied
    public let meetsParallax: Bool
    /// True when depth coverage requirement is satisfied
    public let meetsDepth: Bool
    /// True when tracking has been stable long enough
    public let meetsTracking: Bool

    public init(
        score: Double,
        progress: Double,
        shouldStop: Bool,
        meetsParallax: Bool,
        meetsDepth: Bool,
        meetsTracking: Bool
    ) {
        self.score = score
        self.progress = progress
        self.shouldStop = shouldStop
        self.meetsParallax = meetsParallax
        self.meetsDepth = meetsDepth
        self.meetsTracking = meetsTracking
    }
}

// MARK: - Detection Results

/// Detected food item with bounding box
public struct FoodDetection: Sendable, Identifiable {
    public let id: UUID
    public let label: String
    public let confidence: Float // 0-1
    public let boundingBox: BoundingBox
    public let segmentationMask: [UInt8]? // Optional segmentation

    public init(
        id: UUID = UUID(),
        label: String,
        confidence: Float,
        boundingBox: BoundingBox,
        segmentationMask: [UInt8]? = nil
    ) {
        self.id = id
        self.label = label
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.segmentationMask = segmentationMask
    }
}

/// Normalized bounding box (0-1 coordinates)
public struct BoundingBox: Sendable, Codable {
    public let x: Float // center x
    public let y: Float // center y
    public let width: Float
    public let height: Float

    public init(x: Float, y: Float, width: Float, height: Float) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var rect: CGRect {
        CGRect(
            x: CGFloat(x - width/2),
            y: CGFloat(y - height/2),
            width: CGFloat(width),
            height: CGFloat(height)
        )
    }
}

// MARK: - Estimation Results

/// Volume and portion estimation
public struct PortionEstimate: Sendable {
    public let volumeML: Float
    public let volumeConfidence: Float
    public let weightGrams: Float
    public let weightConfidence: Float
    public let method: EstimationMethod

    public init(
        volumeML: Float,
        volumeConfidence: Float,
        weightGrams: Float,
        weightConfidence: Float,
        method: EstimationMethod
    ) {
        self.volumeML = volumeML
        self.volumeConfidence = volumeConfidence
        self.weightGrams = weightGrams
        self.weightConfidence = weightConfidence
        self.method = method
    }
}

public enum EstimationMethod: String, Sendable, Codable {
    case depthBased // LiDAR or SfM
    case referenceBased // Plate/utensil reference
    case databaseAverage // Fallback to average
    case userProvided // Manual input
}

// MARK: - Nutrition Data

/// Complete nutrition information
public struct NutritionData: Sendable, Identifiable, Codable {
    public let id: UUID
    public let foodName: String
    public let calories: Int
    public let macros: Macronutrients
    public let micronutrients: Micronutrients?
    public let servingSize: ServingSize
    public let source: NutritionSource

    public init(
        id: UUID = UUID(),
        foodName: String,
        calories: Int,
        macros: Macronutrients,
        micronutrients: Micronutrients? = nil,
        servingSize: ServingSize,
        source: NutritionSource
    ) {
        self.id = id
        self.foodName = foodName
        self.calories = calories
        self.macros = macros
        self.micronutrients = micronutrients
        self.servingSize = servingSize
        self.source = source
    }
}

public struct Macronutrients: Sendable, Codable {
    public let proteinG: Float
    public let carbsG: Float
    public let fatG: Float
    public let fiberG: Float

    public init(proteinG: Float, carbsG: Float, fatG: Float, fiberG: Float) {
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
    }
}

public struct Micronutrients: Sendable, Codable {
    public let sodiumMg: Float?
    public let sugarG: Float?
    public let cholesterolMg: Float?
    // Add more as needed

    public init(sodiumMg: Float? = nil, sugarG: Float? = nil, cholesterolMg: Float? = nil) {
        self.sodiumMg = sodiumMg
        self.sugarG = sugarG
        self.cholesterolMg = cholesterolMg
    }
}

public struct ServingSize: Sendable, Codable {
    public let amount: Float
    public let unit: ServingUnit

    public init(amount: Float, unit: ServingUnit) {
        self.amount = amount
        self.unit = unit
    }
}

public enum ServingUnit: String, Sendable, Codable {
    case grams = "g"
    case milliliters = "ml"
    case ounces = "oz"
    case cups = "cup"
    case pieces = "pieces"
}

public enum NutritionSource: String, Sendable, Codable {
    case localDatabase
    case remoteAPI
    case userProvided
    case mlEstimate
}

// MARK: - Final Output

/// Complete food analysis result
public struct FoodAnalysisResult: Sendable, Identifiable {
    public let id: UUID
    public let detection: FoodDetection
    public let portion: PortionEstimate
    public let nutrition: NutritionData
    public let visualData: VisualData
    public let confidence: ConfidenceMetrics
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        detection: FoodDetection,
        portion: PortionEstimate,
        nutrition: NutritionData,
        visualData: VisualData,
        confidence: ConfidenceMetrics,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.detection = detection
        self.portion = portion
        self.nutrition = nutrition
        self.visualData = visualData
        self.confidence = confidence
        self.timestamp = timestamp
    }
}

/// Visual data for display (never uploaded by default)
public struct VisualData: Sendable {
    public let thumbnailData: Data? // Small preview
    public let emoji: String
    public let color: String // Hex color

    public init(thumbnailData: Data? = nil, emoji: String, color: String) {
        self.thumbnailData = thumbnailData
        self.emoji = emoji
        self.color = color
    }
}

/// Confidence metrics for transparency
public struct ConfidenceMetrics: Sendable {
    public let detection: Float // 0-1
    public let portion: Float // 0-1
    public let nutrition: Float // 0-1
    public let overall: Float // 0-1

    public init(detection: Float, portion: Float, nutrition: Float) {
        self.detection = detection
        self.portion = portion
        self.nutrition = nutrition
        self.overall = (detection + portion + nutrition) / 3.0
    }
}

// MARK: - Errors

public enum CalorieCameraError: LocalizedError, Sendable {
    case cameraUnavailable
    case permissionDenied
    case depthUnavailable
    case captureFailure(String)
    case detectionFailure(String)
    case networkFailure(String)
    case configurationError(String)
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "Camera is not available on this device"
        case .permissionDenied:
            return "Camera permission denied"
        case .depthUnavailable:
            return "Depth sensing unavailable (requires LiDAR or multi-frame)"
        case .captureFailure(let msg):
            return "Capture failed: \(msg)"
        case .detectionFailure(let msg):
            return "Detection failed: \(msg)"
        case .networkFailure(let msg):
            return "Network error: \(msg)"
        case .configurationError(let msg):
            return "Configuration error: \(msg)"
        case .unknown(let msg):
            return "Unknown error: \(msg)"
        }
    }
}
