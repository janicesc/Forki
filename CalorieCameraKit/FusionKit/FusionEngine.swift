import Foundation

/// Fusion engine for combining estimates with uncertainty propagation
public final class FusionEngine: Sendable {

    private let config: CalorieConfig

    public init(config: CalorieConfig = .default) {
        self.config = config
    }

    // MARK: - Delta Method for Geometry

    /// Calculate calories from geometry using delta method for uncertainty propagation
    ///
    /// Formula: C = V × ρ × e
    /// Where:
    ///   V = volume (ml)
    ///   ρ = density (g/ml)
    ///   e = energy density (kcal/g)
    ///
    /// Delta method for σ_C:
    /// σ_C² = (∂C/∂V)²σ_V² + (∂C/∂ρ)²σ_ρ² + (∂C/∂e)²σ_e²
    ///
    /// Example:
    ///   V = 180 ± 30 ml
    ///   ρ = 0.85 ± 0.10 g/ml
    ///   e = 1.30 ± 0.05 kcal/g
    ///   → C ≈ 199 ± 39 kcal
    public func caloriesFromGeometry(
        volume: VolumeEstimate,
        priors: FoodPriors
    ) -> Estimate {
        let V = volume.muML
        let rho = priors.density.mu
        let e = priors.kcalPerG.mu

        // Mean: C = V × ρ × e
        let mu = V * rho * e

        // Partial derivatives
        let dC_dV = rho * e        // ∂C/∂V = ρ × e
        let dC_dRho = V * e        // ∂C/∂ρ = V × e
        let dC_dE = V * rho        // ∂C/∂e = V × ρ

        // Standard deviations
        let sigmaV = volume.sigmaML
        let sigmaRho = priors.density.sigma
        let sigmaE = priors.kcalPerG.sigma

        // Delta method: propagate uncertainty
        let variance = pow(dC_dV * sigmaV, 2) +
                      pow(dC_dRho * sigmaRho, 2) +
                      pow(dC_dE * sigmaE, 2)

        let sigma = sqrt(variance)

        return Estimate(mu: mu, sigma: sigma, source: .geometry)
    }

    // MARK: - Label-Based Estimate

    /// Calculate calories from package label
    ///
    /// Formula: C = (V / V_ref) × C_serving
    /// Where volume scales the serving size
    ///
    /// Uncertainty mainly from volume measurement
    public func caloriesFromLabel(
        volume: VolumeEstimate,
        kcalPerServing: Double,
        servingVolumeML: Double
    ) -> Estimate {
        // Mean
        let mu = (volume.muML / servingVolumeML) * kcalPerServing

        // Uncertainty primarily from volume measurement
        // σ_C = (C_serving / V_ref) × σ_V
        let sigma = (kcalPerServing / servingVolumeML) * volume.sigmaML

        return Estimate(mu: mu, sigma: sigma, source: .label)
    }

    // MARK: - Menu-Based Estimate

    /// Calculate calories from menu match
    ///
    /// Formula: C = C_menu × (V / V_ref)
    /// Where geometry provides portion scaling
    ///
    /// Higher uncertainty than label due to variation in preparation
    public func caloriesFromMenu(
        volume: VolumeEstimate,
        kcalPerItem: Double,
        referenceVolumeML: Double,
        preparationVariance: Double = 0.15  // 15% typical variance
    ) -> Estimate {
        // Portion factor
        let portionFactor = volume.muML / referenceVolumeML

        // Mean
        let mu = kcalPerItem * portionFactor

        // Uncertainty from both volume and preparation variance
        let sigmaFromVolume = (kcalPerItem / referenceVolumeML) * volume.sigmaML
        let sigmaFromPrep = kcalPerItem * portionFactor * preparationVariance

        let sigma = sqrt(pow(sigmaFromVolume, 2) + pow(sigmaFromPrep, 2))

        return Estimate(mu: mu, sigma: sigma, source: .menu)
    }

    // MARK: - Inverse-Variance Weighted Fusion

    /// Fuse multiple estimates using inverse-variance weighting
    ///
    /// Formula:
    ///   μ_fused = Σ(μ_i / σ_i²) / Σ(1 / σ_i²)
    ///   σ_fused = sqrt(1 / Σ(1 / σ_i²))
    ///
    /// With correlation penalty:
    ///   σ_fused *= correlationPenalty
    ///
    /// Property: Fused estimate has lower σ than any input if independent
    ///
    /// - Parameters:
    ///   - estimates: Array of estimates to fuse
    /// - Returns: Fused estimate with combined uncertainty
    public func fuse(_ estimates: [Estimate]) -> Estimate {
        guard !estimates.isEmpty else {
            return Estimate(mu: 0, sigma: .infinity, source: .geometry)
        }

        guard estimates.count > 1 else {
            return estimates[0]
        }

        // Filter out estimates with infinite uncertainty
        let validEstimates = estimates.filter { $0.sigma.isFinite && $0.sigma > 0 }

        guard !validEstimates.isEmpty else {
            return estimates[0]
        }

        // Inverse-variance weights
        let precisions = validEstimates.map { $0.precision }
        let sumPrecisions = precisions.reduce(0, +)

        // Weighted mean
        let muFused = zip(validEstimates, precisions)
            .map { estimate, precision in
                estimate.mu * precision
            }
            .reduce(0, +) / sumPrecisions

        // Fused uncertainty (lower than any individual if independent)
        var sigmaFused = sqrt(1.0 / sumPrecisions)

        // Apply correlation penalty if sources might be correlated
        if shouldApplyCorrelationPenalty(sources: validEstimates.map { $0.source }) {
            sigmaFused *= config.correlationPenalty
        }

        // Source is dominated by most precise estimate
        let dominantSource = validEstimates.max(by: { $0.precision < $1.precision })?.source ?? .geometry

        return Estimate(mu: muFused, sigma: sigmaFused, source: dominantSource)
    }

    // MARK: - Correlation Detection

    /// Check if sources are likely correlated (same underlying measurement)
    private func shouldApplyCorrelationPenalty(sources: [Source]) -> Bool {
        let uniqueSources = Set(sources)

        // If menu and geometry both present, they might be correlated
        // (menu might be based on typical portions measured geometrically)
        if uniqueSources.contains(.menu) && uniqueSources.contains(.geometry) {
            return true
        }

        // Label is typically independent
        return false
    }

    // MARK: - Meal Totals

    /// Sum multiple items with proper uncertainty propagation
    ///
    /// For independent items:
    ///   μ_total = Σ μ_i
    ///   σ_total = sqrt(Σ σ_i²)
    public func sumItems(_ items: [ItemEstimate]) -> (mu: Double, sigma: Double) {
        let muTotal = items.map { $0.calories }.reduce(0, +)

        // Uncertainty adds in quadrature for independent measurements
        let varianceTotal = items.map { pow($0.sigma, 2) }.reduce(0, +)
        let sigmaTotal = sqrt(varianceTotal)

        return (muTotal, sigmaTotal)
    }
}

// MARK: - Router

/// Routes computation to appropriate sources based on evidence
public final class Router: Sendable {

    private let config: CalorieConfig

    public init(config: CalorieConfig = .default) {
        self.config = config
    }

    /// Choose which sources to use based on available evidence
    ///
    /// Priority:
    ///   1. Label (barcode) - most reliable
    ///   2. Menu - good if high confidence match
    ///   3. Geometry - always available as fallback
    ///
    /// - Parameter evidence: Available evidence for this item
    /// - Returns: Ordered list of sources to try
    public func choosePaths(evidence: RouterEvidence) -> [Source] {
        guard config.flags.routerEnabled else {
            // Router disabled, use all available
            return [.geometry]
        }

        var paths: [Source] = []

        // 1. Label (barcode) is most reliable
        if evidence.hasBarcode {
            let labelWeight = config.routerWeights.label
            if labelWeight >= 0.5 {
                paths.append(.label)
            }
        }

        // 2. Menu if good match
        if evidence.hasMenuMatch {
            let menuWeight = config.routerWeights.menu
            let menuConfidence = evidence.confidences[.menu] ?? 0.0

            if menuWeight * menuConfidence >= 0.4 {
                paths.append(.menu)
            }
        }

        // 3. Geometry always an option if quality sufficient
        if evidence.geometryQuality >= 0.5 {
            let geoWeight = config.routerWeights.geo
            if geoWeight >= 0.5 {
                paths.append(.geometry)
            }
        }

        // Fallback: use geometry if nothing else
        if paths.isEmpty {
            paths.append(.geometry)
        }

        return paths
    }

    /// Decide if multiple sources should be fused or use single best
    public func shouldFuse(paths: [Source]) -> Bool {
        // Fuse if we have independent sources
        // Don't fuse if only one source or all correlated
        guard paths.count >= 2 else { return false }

        // Don't fuse menu + geometry (likely correlated)
        if paths.contains(.menu) && paths.contains(.geometry) && paths.count == 2 {
            return false
        }

        return true
    }
}

// MARK: - Value of Information

/// Determines when to ask user for additional information
public struct ValueOfInformation: Sendable {

    /// Decide if we should ask a binary question to reduce uncertainty
    ///
    /// Ask if relative uncertainty σ/μ >= threshold
    ///
    /// Example:
    ///   estimate: 200 ± 60 kcal
    ///   relUncertainty: 60/200 = 0.30
    ///   threshold: 0.27
    ///   → shouldAsk = true
    ///
    /// - Parameters:
    ///   - estimate: Current estimate with uncertainty
    ///   - threshold: Relative uncertainty threshold
    ///   - config: Configuration with question pool
    /// - Returns: Optional question key if asking is worthwhile
    public static func shouldAsk(
        estimate: Estimate,
        threshold: Double,
        config: CalorieConfig
    ) -> String? {
        guard config.flags.voiEnabled else { return nil }
        guard !config.askBinaryPool.isEmpty else { return nil }

        let relUncertainty = estimate.relativeUncertainty

        if relUncertainty >= threshold {
            // Return first question from pool
            // TODO: More sophisticated selection based on expected information gain
            return config.askBinaryPool.first
        }

        return nil
    }

    /// Calculate expected reduction in uncertainty from binary question
    ///
    /// E[σ_after] ≈ σ_before × sqrt(0.5)  (simplified)
    ///
    /// TODO: Full Bayesian treatment with prior on answer probabilities
    public static func expectedUncertaintyReduction(
        currentSigma: Double,
        questionType: String
    ) -> Double {
        // Simplified: binary question reduces uncertainty by ~30%
        return currentSigma * 0.7
    }
}
