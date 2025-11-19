import Foundation

/// Robust statistics utilities using median and IQR instead of mean/std
public struct RobustStatistics: Sendable {
    /// Calculate median of a sorted array
    public static func median<T: FloatingPoint>(_ sorted: [T]) -> T {
        guard !sorted.isEmpty else { return 0 }
        let count = sorted.count
        if count % 2 == 0 {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2
        } else {
            return sorted[count / 2]
        }
    }
    
    /// Calculate interquartile range (IQR) from sorted array
    public static func iqr<T: FloatingPoint>(_ sorted: [T]) -> T {
        guard sorted.count >= 4 else {
            // For small arrays, use min-max range
            return sorted.last! - sorted.first!
        }
        
        let q1Index = sorted.count / 4
        let q3Index = sorted.count * 3 / 4
        
        let q1 = sorted[q1Index]
        let q3 = sorted[q3Index]
        
        return q3 - q1
    }
    
    /// Calculate percentile value from sorted array
    public static func percentile<T: FloatingPoint>(_ sorted: [T], _ p: Double) -> T {
        guard !sorted.isEmpty else { return 0 }
        guard p >= 0.0 && p <= 1.0 else {
            return p < 0.0 ? sorted.first! : sorted.last!
        }
        
        let index = max(0, min(sorted.count - 1, Int(Double(sorted.count) * p)))
        return sorted[index]
    }
    
    /// Calculate robust center (median) and spread (IQR) from array
    public static func robustStats<T: FloatingPoint>(_ values: [T]) -> (median: T, iqr: T) {
        let sorted = values.sorted()
        return (median: median(sorted), iqr: iqr(sorted))
    }
    
    /// Calculate height band using robust statistics
    /// Returns (lowerBound, upperBound) for food pixels
    public static func heightBand<T: FloatingPoint>(
        from sorted: [T],
        config: GeometryConfig.RobustStatsConfig
    ) -> (lower: T, upper: T) {
        guard !sorted.isEmpty else { return (0, 0) }
        
        let median = median(sorted)
        let iqr = iqr(sorted)
        
        // Use IQR-based bounds: median ± (multiplier * IQR)
        // Convert Double multiplier to T (FloatingPoint)
        // Handle Double and Float explicitly (the only types we use)
        let lowerMultiplier: T
        let upperMultiplier: T
        if T.self == Double.self {
            lowerMultiplier = config.heightBandLowerMultiplier as! T
            upperMultiplier = config.heightBandUpperMultiplier as! T
        } else {
            // For Float and other FloatingPoint types, convert via Float
            lowerMultiplier = Float(config.heightBandLowerMultiplier) as! T
            upperMultiplier = Float(config.heightBandUpperMultiplier) as! T
        }
        let lower = median - lowerMultiplier * iqr
        let upper = median + upperMultiplier * iqr
        
        return (lower, upper)
    }
    
    /// Count pixels in percentile range (for food pixel detection)
    public static func countInPercentileRange<T: FloatingPoint>(
        _ values: [T],
        lowerPercentile: Double,
        upperPercentile: Double
    ) -> Int {
        guard !values.isEmpty else { return 0 }
        
        let sorted = values.sorted()
        let lower = percentile(sorted, lowerPercentile)
        let upper = percentile(sorted, upperPercentile)
        
        return values.filter { $0 >= lower && $0 <= upper }.count
    }
}

