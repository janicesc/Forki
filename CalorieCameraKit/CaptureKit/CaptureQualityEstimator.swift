import Foundation

/// Aggregates per-frame metrics to determine when capture quality is sufficient.
public final class CaptureQualityEstimator: @unchecked Sendable {
    private let parameters: CaptureQualityParameters
    private var maxParallax: Double = 0.0
    private var maxDepthCoverage: Double = 0.0
    private var consecutiveStableTracking: Int = 0

    public init(parameters: CaptureQualityParameters = CaptureQualityParameters()) {
        self.parameters = parameters
    }

    /// Reset the accumulated metrics for a new capture session.
    public func reset() {
        maxParallax = 0.0
        maxDepthCoverage = 0.0
        consecutiveStableTracking = 0
    }

    /// Evaluate a new sample and return the current quality status.
    public func evaluate(sample: CaptureQualitySample) -> CaptureQualityStatus {
        maxParallax = max(maxParallax, max(sample.parallax, 0.0))
        maxDepthCoverage = max(maxDepthCoverage, clamp(sample.depthCoverage))

        if sample.trackingState.isStable {
            consecutiveStableTracking += 1
        } else {
            consecutiveStableTracking = 0
        }

        let parallaxScore = clamp(maxParallax / parameters.parallaxTarget)
        let depthScore = clamp(maxDepthCoverage / parameters.depthCoverageTarget)
        let trackingScore = sample.trackingState.qualityScore

        let totalWeight = max(parameters.parallaxWeight + parameters.depthWeight + parameters.trackingWeight, 0.001)
        let weightedScore = clamp(
            (parallaxScore * parameters.parallaxWeight +
             depthScore * parameters.depthWeight +
             trackingScore * parameters.trackingWeight) / totalWeight
        )

        let meetsTracking = consecutiveStableTracking >= parameters.minimumStableFrames
        let meetsParallax = parallaxScore >= 1.0
        let meetsDepth = depthScore >= 1.0
        let shouldStop = weightedScore >= parameters.stopThreshold && meetsTracking
        let progress = clamp(weightedScore / max(parameters.stopThreshold, 0.001))

        return CaptureQualityStatus(
            score: weightedScore,
            progress: progress,
            shouldStop: shouldStop,
            meetsParallax: meetsParallax,
            meetsDepth: meetsDepth,
            meetsTracking: meetsTracking
        )
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0.0), 1.0)
    }
}
