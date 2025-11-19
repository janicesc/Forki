import Foundation

/// Lightweight depth-based geometry estimator with proper uncertainty propagation.
/// Uses delta method to propagate volume, density, and energy uncertainties.
public final class GeometryEstimator {
    public struct Parameters {
        /// Estimated density in g/mL (default ~ water)
        public let density: Double
        /// Estimated energy per gram (kcal/g)
        public let energyPerGram: Double
        /// Relative volume uncertainty (σ_V = volume * relativeVolumeSigma)
        public let relativeVolumeSigma: Double
        /// Minimum σ if the relative value is too small
        public let minimumSigma: Double
        /// Fallback calories if depth is unavailable
        public let fallbackCalories: Double
        /// Evidence tags to attach when geometry succeeds
        public let evidence: [String]
        /// Evidence tags when geometry falls back
        public let fallbackEvidence: [String]
        /// Approximate real-world area represented by a single depth pixel (m²)
        public let pixelAreaEstimate: Double

        public init(
            density: Double = 1.0,
            energyPerGram: Double = 1.35,
            relativeVolumeSigma: Double = 0.25, // 25% volume uncertainty
            minimumSigma: Double = 80,
            fallbackCalories: Double = 420,
            evidence: [String] = ["Geometry", "Depth"],
            fallbackEvidence: [String] = ["Geometry", "Fallback"],
            pixelAreaEstimate: Double = 1.5e-6
        ) {
            self.density = density
            self.energyPerGram = energyPerGram
            self.relativeVolumeSigma = relativeVolumeSigma
            self.minimumSigma = minimumSigma
            self.fallbackCalories = fallbackCalories
            self.evidence = evidence
            self.fallbackEvidence = fallbackEvidence
            self.pixelAreaEstimate = pixelAreaEstimate
        }
    }

    private let parameters: Parameters
    private let fusionEngine: FusionEngine

    public init(parameters: Parameters = Parameters()) {
        self.parameters = parameters
        self.fusionEngine = FusionEngine(config: .default)
    }

    /// Estimate calories with proper uncertainty propagation using delta method
    ///
    /// If VLM priors are provided, uses them with their uncertainties.
    /// Otherwise falls back to default priors.
    public func estimate(
        from frame: CapturedFrame?,
        priors: FoodPriors? = nil
    ) -> GeometryEstimate {
        guard
            let frame,
            let depthData = frame.depthData,
            !depthData.depthMap.isEmpty
        else {
            return fallbackEstimate()
        }

        // Calculate volume from depth map
        let depths = depthData.depthMap.map(Double.init)
        let sorted = depths.sorted()
        let count = sorted.count
        let foregroundDepth = sorted[max(0, Int(Double(count) * 0.1) - 1)]
        let backgroundDepth = sorted[min(count - 1, Int(Double(count) * 0.9))]
        let heightMeters = max(0.0, backgroundDepth - foregroundDepth)

        // Convert depth map area into rough real-world area (square meters).
        let pixelArea = parameters.pixelAreaEstimate
        let areaMetersSquared = Double(depthData.width * depthData.height) * pixelArea
        let volumeMetersCubed = heightMeters * areaMetersSquared

        // Convert m³ → mL (1 m³ = 1,000,000 mL)
        let volumeML = max(10.0, volumeMetersCubed * 1_000_000.0)

        // Estimate volume uncertainty from depth measurement variability
        let volumeSigmaML = volumeML * parameters.relativeVolumeSigma

        // Create volume estimate
        let volumeEstimate = VolumeEstimate(muML: volumeML, sigmaML: volumeSigmaML)

        // Use VLM-provided priors if available, otherwise use defaults
        let foodPriors: FoodPriors
        if let vlmPriors = priors {
            foodPriors = vlmPriors
            NSLog("📐 Using VLM priors: ρ=\(vlmPriors.density.mu)±\(vlmPriors.density.sigma), e=\(vlmPriors.kcalPerG.mu)±\(vlmPriors.kcalPerG.sigma)")
        } else {
            // Use default priors with estimated uncertainties
            foodPriors = FoodPriors(
                density: PriorStats(mu: parameters.density, sigma: parameters.density * 0.20),
                kcalPerG: PriorStats(mu: parameters.energyPerGram, sigma: parameters.energyPerGram * 0.15)
            )
            NSLog("📐 Using default priors: ρ=\(parameters.density), e=\(parameters.energyPerGram)")
        }

        // Use delta method to propagate uncertainties: C = V × ρ × e
        let calorieEstimate = fusionEngine.caloriesFromGeometry(
            volume: volumeEstimate,
            priors: foodPriors
        )

        let finalSigma = max(parameters.minimumSigma, calorieEstimate.sigma)

        NSLog("📐 Volume: \(volumeML)±\(volumeSigmaML) mL → Calories: \(calorieEstimate.mu)±\(finalSigma)")

        let evidence = parameters.evidence

        return GeometryEstimate(
            label: "Geometry",
            volumeML: volumeML,
            calories: calorieEstimate.mu,
            sigma: finalSigma,
            evidence: evidence
        )
    }

    private func fallbackEstimate() -> GeometryEstimate {
        let evidence = parameters.fallbackEvidence
        let calories = parameters.fallbackCalories

        // Use reasonable uncertainty estimate for fallback
        let sigma = max(parameters.minimumSigma, calories * 0.50)  // 50% uncertainty for fallback

        return GeometryEstimate(
            label: "Geometry",
            volumeML: 350,
            calories: calories,
            sigma: sigma,
            evidence: evidence
        )
    }
}
