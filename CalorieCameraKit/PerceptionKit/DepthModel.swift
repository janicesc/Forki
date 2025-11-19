import Foundation

/// Depth source type for different sensors
public enum DepthSourceType: String, Codable, Sendable {
    case lidar
    case dualCamera
    case monocularEstimate
    case analyzerDepth
}

/// Depth model abstraction for configurable depth conversion
/// Replaces hard-coded `depth = 1/disparity` with device/sensor-specific calibration
public struct DepthModel: Sendable {
    /// Source type
    public let sourceType: DepthSourceType
    
    /// Calibration parameters
    public struct Calibration: Codable, Sendable {
        /// Depth-to-disparity conversion factor (if available from camera calibration)
        public let depthToDisparityFactor: Double?
        /// Normalization factor for disparity (default: 1.0)
        public let disparityNormalization: Double
        /// Minimum valid depth (meters)
        public let minDepth: Double
        /// Maximum valid depth (meters)
        public let maxDepth: Double
        
        public init(
            depthToDisparityFactor: Double? = nil,
            disparityNormalization: Double = 1.0,
            minDepth: Double = 0.01,
            maxDepth: Double = 5.0
        ) {
            self.depthToDisparityFactor = depthToDisparityFactor
            self.disparityNormalization = disparityNormalization
            self.minDepth = minDepth
            self.maxDepth = maxDepth
        }
    }
    
    public let calibration: Calibration
    
    public init(sourceType: DepthSourceType, calibration: Calibration = Calibration()) {
        self.sourceType = sourceType
        self.calibration = calibration
    }
    
    /// Convert disparity to depth in meters
    /// - Parameter disparity: Raw disparity value from sensor
    /// - Returns: Depth in meters, or nil if invalid
    public func convertDisparityToDepth(_ disparity: Float) -> Double? {
        guard disparity > 0 && disparity < 100 else { return nil }
        
        let depth: Double
        if let factor = calibration.depthToDisparityFactor {
            // Use calibration factor if available
            depth = factor / Double(disparity)
        } else {
            // Fallback: normalized disparity (depth = normalization / disparity)
            depth = calibration.disparityNormalization / Double(disparity)
        }
        
        // Validate depth range
        guard depth >= calibration.minDepth && depth <= calibration.maxDepth else {
            return nil
        }
        
        return depth
    }
    
    /// Convert array of disparity values to depth map
    public func convertDisparityMap(_ disparityMap: [Float]) -> [Double] {
        return disparityMap.compactMap { convertDisparityToDepth($0) }
    }
    
    /// Apply confidence filtering to depth map
    public func applyConfidenceFilter(
        depthMap: [Double],
        confidenceMap: [Float]?,
        minConfidence: Float = 0.3
    ) -> [Double] {
        guard let confidence = confidenceMap, confidence.count == depthMap.count else {
            return depthMap
        }
        
        return zip(depthMap, confidence).compactMap { depth, conf in
            guard conf >= minConfidence else { return nil }
            return depth
        }
    }
}

/// Factory for creating depth models based on device/sensor type
public struct DepthModelFactory: Sendable {
    /// Create depth model for LiDAR sensor
    public static func lidarModel(calibration: DepthModel.Calibration? = nil) -> DepthModel {
        return DepthModel(
            sourceType: .lidar,
            calibration: calibration ?? DepthModel.Calibration(
                depthToDisparityFactor: nil, // LiDAR typically uses normalized disparity
                disparityNormalization: 1.0,
                minDepth: 0.01,
                maxDepth: 5.0
            )
        )
    }
    
    /// Create depth model for dual camera (stereo)
    public static func dualCameraModel(
        depthToDisparityFactor: Double,
        calibration: DepthModel.Calibration? = nil
    ) -> DepthModel {
        var cal = calibration ?? DepthModel.Calibration()
        cal = DepthModel.Calibration(
            depthToDisparityFactor: depthToDisparityFactor,
            disparityNormalization: cal.disparityNormalization,
            minDepth: cal.minDepth,
            maxDepth: cal.maxDepth
        )
        return DepthModel(sourceType: .dualCamera, calibration: cal)
    }
    
    /// Create depth model for monocular estimate
    public static func monocularModel(calibration: DepthModel.Calibration? = nil) -> DepthModel {
        return DepthModel(
            sourceType: .monocularEstimate,
            calibration: calibration ?? DepthModel.Calibration(
                depthToDisparityFactor: nil,
                disparityNormalization: 1.0,
                minDepth: 0.01,
                maxDepth: 3.0 // Monocular estimates are less reliable
            )
        )
    }
    
    /// Create depth model from camera calibration data
    public static func fromCameraCalibration(
        depthToDisparityFactor: Double?,
        sourceType: DepthSourceType = .lidar
    ) -> DepthModel {
        return DepthModel(
            sourceType: sourceType,
            calibration: DepthModel.Calibration(
                depthToDisparityFactor: depthToDisparityFactor,
                disparityNormalization: 1.0
            )
        )
    }
}

