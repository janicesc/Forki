import Foundation

/// Configuration for geometry estimation v2 - all parameters are configurable
/// This replaces hard-coded magic numbers with data-driven calibration
public struct GeometryConfig: Codable, Sendable {
    /// Robust statistics configuration
    public struct RobustStatsConfig: Codable, Sendable {
        /// Lower percentile for food pixel detection (default: 0.05 = 5th percentile)
        public let foodPixelLowerPercentile: Double
        /// Upper percentile for food pixel detection (default: 0.20 = 20th percentile)
        public let foodPixelUpperPercentile: Double
        /// IQR multiplier for height band lower bound (default: 1.5)
        public let heightBandLowerMultiplier: Double
        /// IQR multiplier for height band upper bound (default: 1.5)
        public let heightBandUpperMultiplier: Double
        
        public init(
            foodPixelLowerPercentile: Double = 0.05,
            foodPixelUpperPercentile: Double = 0.20,
            heightBandLowerMultiplier: Double = 1.5,
            heightBandUpperMultiplier: Double = 1.5
        ) {
            self.foodPixelLowerPercentile = foodPixelLowerPercentile
            self.foodPixelUpperPercentile = foodPixelUpperPercentile
            self.heightBandLowerMultiplier = heightBandLowerMultiplier
            self.heightBandUpperMultiplier = heightBandUpperMultiplier
        }
    }
    
    /// Temporal fusion configuration
    public struct TemporalFusionConfig: Codable, Sendable {
        /// EMA alpha (smoothing factor) for area fraction (default: 0.3)
        public let areaFractionAlpha: Double
        /// EMA alpha for median depth (default: 0.4)
        public let medianDepthAlpha: Double
        /// EMA alpha for height (default: 0.3)
        public let heightAlpha: Double
        /// Maximum number of frames to buffer (default: 5)
        public let maxFrames: Int
        /// Minimum frames required before using temporal fusion (default: 2)
        public let minFrames: Int
        
        public init(
            areaFractionAlpha: Double = 0.3,
            medianDepthAlpha: Double = 0.4,
            heightAlpha: Double = 0.3,
            maxFrames: Int = 5,
            minFrames: Int = 2
        ) {
            self.areaFractionAlpha = areaFractionAlpha
            self.medianDepthAlpha = medianDepthAlpha
            self.heightAlpha = heightAlpha
            self.maxFrames = maxFrames
            self.minFrames = minFrames
        }
    }
    
    /// Soft validation configuration (plausibility scores)
    public struct SoftValidationConfig: Codable, Sendable {
        /// Calibration distributions for height (cm)
        public struct HeightCalibration: Codable, Sendable {
            public let mean: Double
            public let std: Double
            
            public init(mean: Double = 5.0, std: Double = 3.0) {
                self.mean = mean
                self.std = std
            }
        }
        
        /// Calibration distributions for volume (mL)
        public struct VolumeCalibration: Codable, Sendable {
            public let mean: Double
            public let std: Double
            
            public init(mean: Double = 500.0, std: Double = 300.0) {
                self.mean = mean
                self.std = std
            }
        }
        
        /// Z-score threshold for extreme rejection (default: 5.0)
        public let extremeZScoreThreshold: Double
        /// Plausibility score threshold for upweighting uncertainty (default: 0.3)
        public let lowPlausibilityThreshold: Double
        /// Uncertainty multiplier when plausibility is low (default: 1.5)
        public let lowPlausibilityUncertaintyMultiplier: Double
        
        public let heightCalibration: HeightCalibration
        public let volumeCalibration: VolumeCalibration
        
        public init(
            extremeZScoreThreshold: Double = 5.0,
            lowPlausibilityThreshold: Double = 0.3,
            lowPlausibilityUncertaintyMultiplier: Double = 1.5,
            heightCalibration: HeightCalibration = HeightCalibration(),
            volumeCalibration: VolumeCalibration = VolumeCalibration()
        ) {
            self.extremeZScoreThreshold = extremeZScoreThreshold
            self.lowPlausibilityThreshold = lowPlausibilityThreshold
            self.lowPlausibilityUncertaintyMultiplier = lowPlausibilityUncertaintyMultiplier
            self.heightCalibration = heightCalibration
            self.volumeCalibration = volumeCalibration
        }
    }
    
    /// Volume uncertainty configuration
    public struct VolumeUncertaintyConfig: Codable, Sendable {
        /// Relative uncertainty for small volumes (< 500 mL) (default: 0.10)
        public let smallVolumeRelativeSigma: Double
        /// Relative uncertainty for medium volumes (500-1500 mL) (default: 0.15)
        public let mediumVolumeRelativeSigma: Double
        /// Relative uncertainty for large volumes (> 1500 mL) (default: 0.20)
        public let largeVolumeRelativeSigma: Double
        /// Minimum absolute uncertainty (default: 50 mL)
        public let minimumSigma: Double
        
        public init(
            smallVolumeRelativeSigma: Double = 0.10,
            mediumVolumeRelativeSigma: Double = 0.15,
            largeVolumeRelativeSigma: Double = 0.20,
            minimumSigma: Double = 50.0
        ) {
            self.smallVolumeRelativeSigma = smallVolumeRelativeSigma
            self.mediumVolumeRelativeSigma = mediumVolumeRelativeSigma
            self.largeVolumeRelativeSigma = largeVolumeRelativeSigma
            self.minimumSigma = minimumSigma
        }
    }
    
    /// Physical validation bounds (soft, not hard rejections)
    public struct ValidationBounds: Codable, Sendable {
        /// Minimum food area (m²) - below this, plausibility decreases
        public let minFoodArea: Double
        /// Maximum food area (m²) - above this, plausibility decreases
        public let maxFoodArea: Double
        /// Minimum height (m) - below this, plausibility decreases
        public let minHeight: Double
        /// Maximum height (m) - above this, plausibility decreases
        public let maxHeight: Double
        /// Minimum volume (mL) - below this, plausibility decreases
        public let minVolume: Double
        /// Maximum volume (mL) - above this, plausibility decreases
        public let maxVolume: Double
        
        public init(
            minFoodArea: Double = 0.001,
            maxFoodArea: Double = 0.1,
            minHeight: Double = 0.005,
            maxHeight: Double = 0.20,
            minVolume: Double = 10.0,
            maxVolume: Double = 5000.0
        ) {
            self.minFoodArea = minFoodArea
            self.maxFoodArea = maxFoodArea
            self.minHeight = minHeight
            self.maxHeight = maxHeight
            self.minVolume = minVolume
            self.maxVolume = maxVolume
        }
    }
    
    public let robustStats: RobustStatsConfig
    public let temporalFusion: TemporalFusionConfig
    public let softValidation: SoftValidationConfig
    public let volumeUncertainty: VolumeUncertaintyConfig
    public let validationBounds: ValidationBounds
    
    public init(
        robustStats: RobustStatsConfig = RobustStatsConfig(),
        temporalFusion: TemporalFusionConfig = TemporalFusionConfig(),
        softValidation: SoftValidationConfig = SoftValidationConfig(),
        volumeUncertainty: VolumeUncertaintyConfig = VolumeUncertaintyConfig(),
        validationBounds: ValidationBounds = ValidationBounds()
    ) {
        self.robustStats = robustStats
        self.temporalFusion = temporalFusion
        self.softValidation = softValidation
        self.volumeUncertainty = volumeUncertainty
        self.validationBounds = validationBounds
    }
    
    /// Default configuration (production-ready)
    public static let `default` = GeometryConfig()
    
    /// Load configuration from JSON data
    public static func load(from data: Data) throws -> GeometryConfig {
        let decoder = JSONDecoder()
        return try decoder.decode(GeometryConfig.self, from: data)
    }
    
    /// Load configuration from JSON file
    public static func load(from url: URL) throws -> GeometryConfig {
        let data = try Data(contentsOf: url)
        return try load(from: data)
    }
    
    /// Export configuration to JSON
    public func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

/// Plausibility score calculator using z-scores
public struct PlausibilityCalculator: Sendable {
    private let config: GeometryConfig.SoftValidationConfig
    
    public init(config: GeometryConfig.SoftValidationConfig) {
        self.config = config
    }
    
    /// Calculate z-score for a value given mean and std
    private func zScore(value: Double, mean: Double, std: Double) -> Double {
        guard std > 0 else { return 0.0 }
        return abs(value - mean) / std
    }
    
    /// Calculate plausibility score (0-1) from z-score
    /// Higher z-score = lower plausibility
    private func plausibilityFromZScore(_ zScore: Double) -> Double {
        // Use exponential decay: plausibility = exp(-z²/2)
        // This gives: z=0 → 1.0, z=1 → 0.61, z=2 → 0.14, z=3 → 0.01
        return exp(-pow(zScore, 2) / 2.0)
    }
    
    /// Calculate height plausibility score
    public func heightPlausibility(heightCm: Double) -> Double {
        let z = zScore(
            value: heightCm,
            mean: config.heightCalibration.mean,
            std: config.heightCalibration.std
        )
        return plausibilityFromZScore(z)
    }
    
    /// Calculate volume plausibility score
    public func volumePlausibility(volumeML: Double) -> Double {
        let z = zScore(
            value: volumeML,
            mean: config.volumeCalibration.mean,
            std: config.volumeCalibration.std
        )
        return plausibilityFromZScore(z)
    }
    
    /// Calculate combined plausibility score from multiple factors
    public func combinedPlausibility(
        heightCm: Double,
        volumeML: Double,
        areaCm2: Double? = nil
    ) -> Double {
        let heightScore = heightPlausibility(heightCm: heightCm)
        let volumeScore = volumePlausibility(volumeML: volumeML)
        
        // Combine using geometric mean (more conservative than arithmetic)
        let combined = sqrt(heightScore * volumeScore)
        
        return combined
    }
    
    /// Check if estimate should be rejected (extreme outlier)
    public func shouldReject(heightCm: Double, volumeML: Double) -> Bool {
        let heightZ = zScore(
            value: heightCm,
            mean: config.heightCalibration.mean,
            std: config.heightCalibration.std
        )
        let volumeZ = zScore(
            value: volumeML,
            mean: config.volumeCalibration.mean,
            std: config.volumeCalibration.std
        )
        
        // Reject if either is extremely far from calibration
        return heightZ > config.extremeZScoreThreshold || volumeZ > config.extremeZScoreThreshold
    }
    
    /// Calculate uncertainty adjustment factor based on plausibility
    public func uncertaintyAdjustment(plausibility: Double) -> Double {
        if plausibility < config.lowPlausibilityThreshold {
            return config.lowPlausibilityUncertaintyMultiplier
        }
        return 1.0
    }
}

/// Temporal fusion state for EMA smoothing
public struct TemporalFusionState: Sendable {
    public var areaFraction: Double?
    public var medianDepth: Double?
    public var height: Double?
    public var frameCount: Int = 0
    
    public init() {}
    
    /// Update state with new frame data using EMA
    public mutating func update(
        areaFraction: Double?,
        medianDepth: Double?,
        height: Double?,
        config: GeometryConfig.TemporalFusionConfig
    ) {
        frameCount += 1
        
        if let newArea = areaFraction {
            if let current = self.areaFraction {
                // EMA: new = alpha * new + (1 - alpha) * old
                self.areaFraction = config.areaFractionAlpha * newArea + (1.0 - config.areaFractionAlpha) * current
            } else {
                self.areaFraction = newArea
            }
        }
        
        if let newDepth = medianDepth {
            if let current = self.medianDepth {
                self.medianDepth = config.medianDepthAlpha * newDepth + (1.0 - config.medianDepthAlpha) * current
            } else {
                self.medianDepth = newDepth
            }
        }
        
        if let newHeight = height {
            if let current = self.height {
                self.height = config.heightAlpha * newHeight + (1.0 - config.heightAlpha) * current
            } else {
                self.height = newHeight
            }
        }
    }
    
    /// Check if enough frames have been accumulated
    public func isReady(config: GeometryConfig.TemporalFusionConfig) -> Bool {
        return frameCount >= config.minFrames
    }
    
    /// Reset state
    public mutating func reset() {
        areaFraction = nil
        medianDepth = nil
        height = nil
        frameCount = 0
    }
}

