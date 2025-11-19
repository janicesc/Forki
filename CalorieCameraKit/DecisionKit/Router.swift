import Foundation

public struct GeometryEstimate {
    public let label: String
    public let volumeML: Double
    public let calories: Double
    public let sigma: Double
    public let evidence: [String]

    public init(label: String, volumeML: Double, calories: Double, sigma: Double, evidence: [String]) {
        self.label = label
        self.volumeML = volumeML
        self.calories = calories
        self.sigma = sigma
        self.evidence = evidence
    }
}

public struct RoutedEstimate {
    public let label: String
    public let calories: Double
    public let sigma: Double
    public let evidence: [String]

    public init(label: String, calories: Double, sigma: Double, evidence: [String]) {
        self.label = label
        self.calories = calories
        self.sigma = sigma
        self.evidence = evidence
    }
}

public struct AnalyzerFusionResult {
    public let geometry: GeometryEstimate
    public let routed: RoutedEstimate
    public let fusedCalories: Double
    public let fusedSigma: Double
    public let evidence: [String]
}

public struct AnalyzerRouter {
    private let config: CalorieConfig

    public init(config: CalorieConfig) {
        self.config = config
    }

    public func fuse(
        geometry: GeometryEstimate,
        analyzerObservation: AnalyzerObservation?
    ) -> AnalyzerFusionResult {
        guard
            config.flags.routerEnabled,
            let observation = analyzerObservation
        else {
            return AnalyzerFusionResult(
                geometry: geometry,
                routed: RoutedEstimate(
                    label: geometry.label,
                    calories: geometry.calories,
                    sigma: geometry.sigma,
                    evidence: geometry.evidence
                ),
                fusedCalories: geometry.calories,
                fusedSigma: geometry.sigma,
                evidence: geometry.evidence
            )
        }

        // Route based on detection path
        let routed: RoutedEstimate

        NSLog("🔀 ROUTER: Path = \(observation.path?.rawValue ?? "nil"), Calories = \(observation.calories ?? -1), Sigma = \(observation.sigmaCalories ?? -1)")

        switch observation.path {
        case .label:
            // Label Path: Use OCR-extracted calories from nutrition label
            if let calories = observation.calories, let sigma = observation.sigmaCalories {
                NSLog("🔀 ROUTER: Label path - using backend calories: \(calories)")
                routed = RoutedEstimate(
                    label: observation.label,
                    calories: calories,
                    sigma: sigma,
                    evidence: Array(Set(observation.evidence + observation.metaUsed + ["Label"])).sorted()
                )
            } else {
                NSLog("🔀 ROUTER: Label path - NO calories/sigma, falling back to geometry: \(geometry.calories)")
                // Fallback to geometry if label reading failed
                routed = RoutedEstimate(
                    label: observation.label,
                    calories: geometry.calories,
                    sigma: geometry.sigma,
                    evidence: Array(Set(observation.evidence + geometry.evidence)).sorted()
                )
            }

        case .menu:
            // Menu Path: Use restaurant menu database calories
            if let calories = observation.calories, let sigma = observation.sigmaCalories {
                routed = RoutedEstimate(
                    label: observation.label,
                    calories: calories,
                    sigma: sigma,
                    evidence: Array(Set(observation.evidence + observation.metaUsed + ["Menu"])).sorted()
                )
            } else {
                // Fallback to geometry if menu lookup failed
                routed = RoutedEstimate(
                    label: observation.label,
                    calories: geometry.calories,
                    sigma: geometry.sigma,
                    evidence: Array(Set(observation.evidence + geometry.evidence)).sorted()
                )
            }

        case .geometry, .none:
            // Geometry Path: Use camera volume × VLM priors (already in geometry)
            let analyzerSigma = max(geometry.sigma * 0.8, 1.0)
            routed = RoutedEstimate(
                label: observation.label,
                calories: geometry.calories, // Geometry now uses VLM priors
                sigma: analyzerSigma,
                evidence: Array(Set(observation.evidence + observation.metaUsed + geometry.evidence)).sorted()
            )
        }

        if !config.flags.mixtureEnabled {
            return AnalyzerFusionResult(
                geometry: geometry,
                routed: routed,
                fusedCalories: routed.calories,
                fusedSigma: routed.sigma,
                evidence: routed.evidence
            );
        }

        // For Label and Menu paths, we trust those more than geometry
        // So we might want to use routed directly without fusion
        if observation.path == .label || observation.path == .menu {
            NSLog("🔀 ROUTER: Returning Label/Menu path directly: \(routed.calories) cal")
            // Use routed estimate directly (don't mix with geometry)
            return AnalyzerFusionResult(
                geometry: geometry,
                routed: routed,
                fusedCalories: routed.calories,
                fusedSigma: routed.sigma,
                evidence: routed.evidence
            )
        }

        // For Geometry path, use inverse-variance fusion
        let invVarGeometry = 1.0 / pow(geometry.sigma, 2)
        let invVarRouted = 1.0 / pow(routed.sigma, 2)
        let combinedMu = (geometry.calories * invVarGeometry + routed.calories * invVarRouted) / (invVarGeometry + invVarRouted)
        let combinedSigma = sqrt(1.0 / (invVarGeometry + invVarRouted)) * max(config.correlationPenalty, 1.0)
        let combinedEvidence = Array(Set(geometry.evidence + routed.evidence + ["Analyzer"])).sorted()

        return AnalyzerFusionResult(
            geometry: geometry,
            routed: routed,
            fusedCalories: combinedMu,
            fusedSigma: combinedSigma,
            evidence: combinedEvidence
        )
    }
}
