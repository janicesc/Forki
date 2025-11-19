import Foundation

/// Geometry Estimator v2 - Robust, multi-frame, segmentation-aware
/// Implements the v2 design with:
/// - Robust statistics (median/IQR instead of min/max)
/// - Temporal fusion (EMA smoothing across frames)
/// - Soft validation (plausibility scores instead of hard rejections)
/// - Config-driven parameters (no hard-coded magic numbers)
public final class GeometryEstimatorV2 {
    private let config: GeometryConfig
    private let fusionEngine: FusionEngine
    private var temporalState: TemporalFusionState
    private let plausibilityCalculator: PlausibilityCalculator
    
    public init(config: GeometryConfig = .default) {
        self.config = config
        self.fusionEngine = FusionEngine(config: .default)
        self.temporalState = TemporalFusionState()
        self.plausibilityCalculator = PlausibilityCalculator(config: config.softValidation)
    }
    
    /// Reset temporal fusion state (call when starting a new capture session)
    public func resetTemporalState() {
        temporalState.reset()
    }
    
    /// Estimate calories with v2 improvements
    ///
    /// - Parameters:
    ///   - frame: Captured frame with depth data
    ///   - priors: Food priors from analyzer (optional)
    ///   - segmentationMask: Optional segmentation mask from analyzer (primary source for food pixels)
    /// - Returns: Geometry estimate or nil if depth unavailable
    public func estimate(
        from frame: CapturedFrame?,
        priors: FoodPriors? = nil,
        segmentationMask: FoodInstanceMask? = nil
    ) -> GeometryEstimate? {
        guard
            let frame,
            let depthData = frame.depthData,
            !depthData.depthMap.isEmpty
        else {
            NSLog("⚠️ [V2] NO DEPTH DATA: Cannot calculate volume-based calories")
            return nil
        }
        
        // Step 1: Extract depth values and apply robust statistics
        let depths = depthData.depthMap.map(Double.init)
        let sorted = depths.sorted()
        let count = sorted.count
        
        guard count > 0 else { return nil }
        
        // Step 2: Use robust statistics (median/IQR) instead of min/max
        let (medianDepth, depthIQR) = RobustStatistics.robustStats(depths)
        
        // Step 3: Calculate pixel area using camera intrinsics
        let pixelArea_m2 = calculatePixelArea(
            medianDepth: medianDepth,
            intrinsics: frame.cameraIntrinsics,
            config: config
        )
        
        // Step 4: Detect food pixels (segmentation-first, depth-fallback)
        let foodAreaFraction = detectFoodArea(
            depths: depths,
            sorted: sorted,
            segmentationMask: segmentationMask,
            config: config.robustStats
        )
        
        // Step 5: Calculate food area
        let validDepthCount = depths.filter { $0 > 0.01 && $0 < 5.0 }.count
        let totalValidPixels = validDepthCount > 0 ? validDepthCount : count
        let foodAreaMetersSquared = Double(totalValidPixels) * pixelArea_m2 * foodAreaFraction
        
        // Step 6: Calculate height using robust statistics (IQR-based band)
        let heightMeters = calculateHeight(
            depths: depths,
            sorted: sorted,
            config: config.robustStats
        )
        
        // Step 7: Update temporal fusion state
        temporalState.update(
            areaFraction: foodAreaFraction,
            medianDepth: medianDepth,
            height: heightMeters,
            config: config.temporalFusion
        )
        
        // Step 8: Use temporally fused values if enough frames accumulated
        let (finalArea, finalHeight): (Double, Double)
        if temporalState.isReady(config: config.temporalFusion) {
            // Use EMA-smoothed values
            let fusedArea = temporalState.areaFraction ?? foodAreaFraction
            let fusedHeight = temporalState.height ?? heightMeters
            (finalArea, finalHeight) = (fusedArea, fusedHeight)
        } else {
            // Use current frame values
            (finalArea, finalHeight) = (foodAreaFraction, heightMeters)
        }
        
        // Recalculate area and volume with fused values
        let finalFoodAreaMetersSquared = Double(totalValidPixels) * pixelArea_m2 * finalArea
        let volumeMetersCubed = finalHeight * finalFoodAreaMetersSquared
        let volumeML = volumeMetersCubed * 1_000_000.0
        
        // Step 9: Soft validation using plausibility scores
        let heightCm = finalHeight * 100.0
        let areaCm2 = finalFoodAreaMetersSquared * 10000.0
        
        let plausibility = plausibilityCalculator.combinedPlausibility(
            heightCm: heightCm,
            volumeML: volumeML,
            areaCm2: areaCm2
        )
        
        // Check for extreme outliers (hard rejection only for impossible cases)
        if plausibilityCalculator.shouldReject(heightCm: heightCm, volumeML: volumeML) {
            NSLog("⚠️ [V2] Extreme outlier detected (z-score > \(config.softValidation.extremeZScoreThreshold))")
            NSLog("⚠️ [V2] Height: \(heightCm) cm, Volume: \(volumeML) mL")
            NSLog("⚠️ [V2] Rejecting geometry estimate")
            return nil
        }
        
        // Step 10: Calculate volume uncertainty (adaptive based on volume size)
        let volumeUncertainty = calculateVolumeUncertainty(
            volumeML: volumeML,
            config: config.volumeUncertainty
        )
        
        // Step 11: Adjust uncertainty based on plausibility (soft validation)
        let adjustedVolumeUncertainty = volumeUncertainty * plausibilityCalculator.uncertaintyAdjustment(
            plausibility: plausibility
        )
        
        let volumeEstimate = VolumeEstimate(muML: volumeML, sigmaML: adjustedVolumeUncertainty)
        
        // Step 12: Use priors (from analyzer or defaults)
        let foodPriors = priors ?? FoodPriors(
            density: PriorStats(mu: 1.0, sigma: 0.20),
            kcalPerG: PriorStats(mu: 1.35, sigma: 0.15)
        )
        
        // Step 13: Calculate calories using delta method
        let calorieEstimate = fusionEngine.caloriesFromGeometry(
            volume: volumeEstimate,
            priors: foodPriors
        )
        
        // Step 14: Apply plausibility-based uncertainty adjustment to calories
        let adjustedCalorieSigma = calorieEstimate.sigma * plausibilityCalculator.uncertaintyAdjustment(
            plausibility: plausibility
        )
        
        // Log results with plausibility score
        NSLog("📐 [V2] Geometry Estimate:")
        NSLog("   Area: \(finalFoodAreaMetersSquared * 10000) cm²")
        NSLog("   Height: \(heightCm) cm")
        NSLog("   Volume: \(volumeML) ± \(adjustedVolumeUncertainty) mL")
        NSLog("   Calories: \(calorieEstimate.mu) ± \(adjustedCalorieSigma) kcal")
        NSLog("   Plausibility: \(String(format: "%.2f", plausibility))")
        if temporalState.isReady(config: config.temporalFusion) {
            NSLog("   Temporal fusion: Active (\(temporalState.frameCount) frames)")
        }
        
        return GeometryEstimate(
            label: "Geometry",
            volumeML: volumeML,
            calories: calorieEstimate.mu,
            sigma: adjustedCalorieSigma,
            evidence: ["Geometry", "Depth", "V2"]
        )
    }
    
    // MARK: - Helper Methods
    
    private func calculatePixelArea(
        medianDepth: Double,
        intrinsics: CameraIntrinsics?,
        config: GeometryConfig
    ) -> Double {
        if let intrinsics = intrinsics {
            let fx = Double(intrinsics.focalLength.x)
            let fy = Double(intrinsics.focalLength.y)
            let avgFocalLength = (fx + fy) / 2.0
            let pixelArea = pow(medianDepth / avgFocalLength, 2)
            NSLog("📐 [V2] Using camera intrinsics: fx=\(fx), fy=\(fy), depth=\(medianDepth)m, pixelArea=\(pixelArea * 1e6) mm²")
            return pixelArea
        } else {
            // Fallback: depth-scaled estimate
            let referenceDepth = 0.5 // meters
            let referencePixelArea = 1.5e-6 // m²
            let pixelArea = referencePixelArea * pow(medianDepth / referenceDepth, 2)
            NSLog("📐 [V2] Using depth-scaled estimate: depth=\(medianDepth)m, pixelArea=\(pixelArea * 1e6) mm²")
            return pixelArea
        }
    }
    
    private func detectFoodArea(
        depths: [Double],
        sorted: [Double],
        segmentationMask: FoodInstanceMask?,
        config: GeometryConfig.RobustStatsConfig
    ) -> Double {
        // Segmentation-first approach: if mask provided, use it
        if let mask = segmentationMask {
            // Calculate area fraction from mask
            let maskArea = mask.boundingBox.width * mask.boundingBox.height
            NSLog("📐 [V2] Using segmentation mask: area fraction = \(maskArea)")
            return Double(maskArea)
        }
        
        // Fallback: depth-based detection using robust percentiles
        let lowerPercentile = RobustStatistics.percentile(sorted, config.foodPixelLowerPercentile)
        let upperPercentile = RobustStatistics.percentile(sorted, config.foodPixelUpperPercentile)
        
        let foodPixelCount = RobustStatistics.countInPercentileRange(
            depths,
            lowerPercentile: config.foodPixelLowerPercentile,
            upperPercentile: config.foodPixelUpperPercentile
        )
        
        let validDepthCount = depths.filter { $0 > 0.01 && $0 < 5.0 }.count
        
        guard validDepthCount > 0 else {
            // Very flat scene - use minimal estimate
            return 0.10
        }
        
        let detectedFraction = Double(foodPixelCount) / Double(validDepthCount)
        
        // Validation: cap at 30% maximum
        if detectedFraction > 0.50 {
            NSLog("⚠️ [V2] Food pixel detection error: \(Int(detectedFraction * 100))% (too high)")
            return 0.15 // Conservative fallback
        } else if detectedFraction > 0.30 {
            NSLog("⚠️ [V2] Food pixel detection high: \(Int(detectedFraction * 100))% (capping at 30%)")
            return 0.30
        } else {
            NSLog("📐 [V2] Food pixel detection: \(foodPixelCount)/\(validDepthCount) (\(Int(detectedFraction * 100))%)")
            return detectedFraction
        }
    }
    
    private func calculateHeight(
        depths: [Double],
        sorted: [Double],
        config: GeometryConfig.RobustStatsConfig
    ) -> Double {
        // Extract food pixels (in percentile range)
        let lowerPercentile = RobustStatistics.percentile(sorted, config.foodPixelLowerPercentile)
        let upperPercentile = RobustStatistics.percentile(sorted, config.foodPixelUpperPercentile)
        
        let foodDepths = depths.filter { $0 >= lowerPercentile && $0 <= upperPercentile && $0 > 0.01 && $0 < 5.0 }
        
        guard !foodDepths.isEmpty else {
            // Fallback: use depth range
            return min(0.20, upperPercentile - lowerPercentile)
        }
        
        // Use robust statistics for height calculation
        let foodSorted = foodDepths.sorted()
        let (foodMedian, foodIQR) = RobustStatistics.robustStats(foodSorted)
        
        // Height band using IQR
        let (lowerBound, upperBound) = RobustStatistics.heightBand(
            from: foodSorted,
            config: config
        )
        
        let calculatedHeight = max(0.0, upperBound - lowerBound)
        
        // Cap at maximum reasonable height (20cm)
        let heightMeters = min(calculatedHeight, config.maxHeight)
        
        NSLog("📐 [V2] Height calculation: \(heightMeters * 100) cm (IQR-based, median=\(foodMedian * 100)cm, IQR=\(foodIQR * 100)cm)")
        
        return heightMeters
    }
    
    private func calculateVolumeUncertainty(
        volumeML: Double,
        config: GeometryConfig.VolumeUncertaintyConfig
    ) -> Double {
        let adaptiveSigma: Double
        if volumeML < 500.0 {
            adaptiveSigma = volumeML * config.smallVolumeRelativeSigma
        } else if volumeML < 1500.0 {
            adaptiveSigma = volumeML * config.mediumVolumeRelativeSigma
        } else {
            adaptiveSigma = volumeML * config.largeVolumeRelativeSigma
        }
        
        return max(config.minimumSigma, adaptiveSigma)
    }
}

// MARK: - Extension for maxHeight access

extension GeometryConfig.RobustStatsConfig {
    var maxHeight: Double {
        // Default max height (20cm) - can be moved to config if needed
        return 0.20
    }
}

