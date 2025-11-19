import Foundation
import CoreGraphics
import CoreImage
import simd

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Segmentation Types

/// A single segmented food instance
public struct FoodInstanceMask: Sendable, Identifiable {
    public let id: UUID
    public let maskImage: CGImage  // Binary mask
    public let confidence: Double  // 0-1
    public let boundingBox: CGRect // Normalized 0-1

    public init(
        id: UUID = UUID(),
        maskImage: CGImage,
        confidence: Double,
        boundingBox: CGRect
    ) {
        self.id = id
        self.maskImage = maskImage
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

/// Classification result for a food instance
public struct ClassResult: Sendable {
    public let topLabel: String
    public let confidence: Double
    public let mixture: [String: Double]?  // For mixed dishes

    public init(
        topLabel: String,
        confidence: Double,
        mixture: [String: Double]? = nil
    ) {
        self.topLabel = topLabel
        self.confidence = confidence
        self.mixture = mixture
    }
}

// MARK: - Protocols

/// Segments an image into individual food instances
public protocol Segmenter: Sendable {
    /// Segment captured frame into food instances
    ///
    /// - Parameter frame: RGB image with optional depth
    /// - Returns: Array of segmented food masks
    func segment(frame: CapturedFrame) async throws -> [FoodInstanceMask]
}

/// Classifies a food instance
public protocol Classifier: Sendable {
    /// Classify a segmented food instance
    ///
    /// - Parameters:
    ///   - instance: Segmented mask
    ///   - frames: Multiple frames for temporal coherence
    /// - Returns: Classification result
    func classify(
        instance: FoodInstanceMask,
        frames: [FrameSample]
    ) async throws -> ClassResult
}

/// Estimates volume from depth and mask
public protocol VolumeEstimator: Sendable {
    /// Estimate volume of segmented instance
    ///
    /// - Parameters:
    ///   - mask: Food instance mask
    ///   - depth: Depth map
    ///   - intrinsics: Camera intrinsics
    ///   - platePlane: Reference plane equation
    /// - Returns: Volume estimate with uncertainty
    func integrate(
        mask: FoodInstanceMask,
        depth: DepthData,
        intrinsics: CameraIntrinsics,
        platePlane: PlaneEquation?
    ) async throws -> VolumeEstimate
}

// MARK: - Supporting Types

/// Frame sample for multi-frame processing
public struct FrameSample: Sendable {
    public let pixelBuffer: Data  // RGB image data
    public let depth: DepthData?
    public let intrinsics: CameraIntrinsics?
    public let transform: simd_float4x4  // Camera pose
    public let timestamp: TimeInterval

    public init(
        pixelBuffer: Data,
        depth: DepthData?,
        intrinsics: CameraIntrinsics?,
        transform: simd_float4x4,
        timestamp: TimeInterval
    ) {
        self.pixelBuffer = pixelBuffer
        self.depth = depth
        self.intrinsics = intrinsics
        self.transform = transform
        self.timestamp = timestamp
    }
}

/// Plane equation: ax + by + cz + d = 0
public struct PlaneEquation: Sendable {
    public let normal: SIMD3<Float>  // (a, b, c)
    public let distance: Float       // d

    public init(normal: SIMD3<Float>, distance: Float) {
        self.normal = normal
        self.distance = distance
    }

    /// Distance from point to plane
    public func distanceToPoint(_ point: SIMD3<Float>) -> Float {
        return dot(normal, point) + distance
    }
}

// MARK: - Default Implementations (Stubs)

/// Default segmenter returns single "whole-plate" mask
public final class DefaultSegmenter: Segmenter {

    public init() {}

    public func segment(frame: CapturedFrame) async throws -> [FoodInstanceMask] {
        // TODO: Replace with CoreML segmentation model
        // For now, return single mask covering whole image

        guard let cgImage = createCGImage(from: frame.rgbImage) else {
            throw CalorieCameraError.processingFailed("Cannot create image")
        }

        let width = cgImage.width
        let height = cgImage.height

        // Create full-frame mask
        let maskImage = try createFullMask(width: width, height: height)

        return [FoodInstanceMask(
            maskImage: maskImage,
            confidence: 1.0,
            boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1)
        )]
    }

    private func createFullMask(width: Int, height: Int) throws -> CGImage {
        // Create white mask (all pixels = 255)
        let bytesPerPixel = 1
        let bytesPerRow = width * bytesPerPixel
        let bitmapData = [UInt8](repeating: 255, count: width * height)

        guard let dataProvider = CGDataProvider(data: Data(bitmapData) as CFData) else {
            throw CalorieCameraError.processingFailed("Cannot create data provider")
        }

        guard let maskImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: 0),
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            throw CalorieCameraError.processingFailed("Cannot create mask image")
        }

        return maskImage
    }

    private func createCGImage(from data: Data) -> CGImage? {
        #if canImport(UIKit)
        guard let uiImage = UIKit.UIImage(data: data) else { return nil }
        return uiImage.cgImage
        #else
        return nil
        #endif
    }
}

/// Default classifier returns mock result
public final class DefaultClassifier: Classifier {

    public init() {}

    public func classify(
        instance: FoodInstanceMask,
        frames: [FrameSample]
    ) async throws -> ClassResult {
        // TODO: Replace with CoreML classification model
        // For now, return mock classification

        return ClassResult(
            topLabel: "rice:white_cooked",
            confidence: 0.9,
            mixture: nil
        )
    }
}

/// Volume estimator with proper 3D integration
public final class DefaultVolumeEstimator: VolumeEstimator {

    public init() {}

    public func integrate(
        mask: FoodInstanceMask,
        depth: DepthData,
        intrinsics: CameraIntrinsics,
        platePlane: PlaneEquation?
    ) async throws -> VolumeEstimate {
        // Proper 3D volume integration from depth map
        // Algorithm:
        // 1. For each pixel in mask
        // 2. Unproject to 3D world coordinates using depth + intrinsics
        // 3. Calculate height above plate plane (or min depth if no plane)
        // 4. Calculate pixel area in world space
        // 5. Sum volume contributions: V = Σ(pixel_area × height)

        let result = integrateVolume3D(
            mask: mask,
            depth: depth,
            intrinsics: intrinsics,
            platePlane: platePlane
        )

        return VolumeEstimate(
            muML: result.volumeML,
            sigmaML: result.uncertaintyML
        )
    }

    private func integrateVolume3D(
        mask: FoodInstanceMask,
        depth: DepthData,
        intrinsics: CameraIntrinsics,
        platePlane: PlaneEquation?
    ) -> (volumeML: Double, uncertaintyML: Double) {

        let width = depth.width
        let height = depth.height
        let depthMap = depth.depthMap
        let confidenceMap = depth.confidenceMap

        // Extract focal lengths and principal point
        let fx = intrinsics.focalLength.x
        let fy = intrinsics.focalLength.y
        let cx = intrinsics.principalPoint.x
        let cy = intrinsics.principalPoint.y

        var totalVolume_m3: Float = 0.0
        var totalUncertainty_m3: Float = 0.0
        var validPixelCount = 0

        // Find reference plane if not provided
        let referencePlane = platePlane ?? estimatePlatePlane(
            mask: mask,
            depthMap: depthMap,
            width: width,
            height: height,
            intrinsics: intrinsics
        )

        // Iterate through mask pixels
        let bbox = mask.boundingBox
        let xStart = max(0, Int(bbox.origin.x * CGFloat(width)))
        let yStart = max(0, Int(bbox.origin.y * CGFloat(height)))
        let xEnd = min(width, Int((bbox.origin.x + bbox.width) * CGFloat(width)))
        let yEnd = min(height, Int((bbox.origin.y + bbox.height) * CGFloat(height)))

        for y in yStart..<yEnd {
            for x in xStart..<xEnd {
                let idx = y * width + x

                guard idx < depthMap.count else { continue }

                // Check if pixel is in mask (we approximate with bounding box for now)
                // TODO: Read actual mask image pixels when available
                let isInMask = isPixelInMask(x: x, y: y, mask: mask, width: width, height: height)
                guard isInMask else { continue }

                let depthValue = depthMap[idx]

                // Validate depth
                guard depthValue > 0.01 && depthValue < 5.0 else { continue } // Valid range: 1cm to 5m

                // Get confidence if available
                let confidence = confidenceMap?[idx] ?? 1.0
                guard confidence > 0.3 else { continue } // Skip low-confidence pixels

                // Unproject pixel to 3D world coordinates
                let point3D = unproject(
                    x: Float(x),
                    y: Float(y),
                    depth: depthValue,
                    fx: fx,
                    fy: fy,
                    cx: cx,
                    cy: cy
                )

                // Calculate height above reference plane
                // The distance function returns signed distance
                // Negative distance means above the plane (food is closer than plate)
                let signedDistance = referencePlane.distanceToPoint(point3D)
                let height_m = max(0, -signedDistance) // Negate to get height

                // Calculate pixel area in world space at this depth
                // Area ≈ (depth / focal_length)²
                let pixelArea_m2 = pow(depthValue / fx, 2)

                // Volume contribution for this pixel
                let volumeContribution = pixelArea_m2 * height_m
                totalVolume_m3 += volumeContribution

                // Uncertainty contribution (from depth uncertainty + confidence)
                // σ_depth ≈ 1-5% of depth value for LiDAR, higher for other methods
                let depthUncertainty = estimateDepthUncertainty(depthValue, source: depth.source)
                let uncertaintyContribution = pixelArea_m2 * depthUncertainty * (1.0 / confidence)
                totalUncertainty_m3 += pow(uncertaintyContribution, 2)

                validPixelCount += 1
            }
        }

        // Convert m³ to mL (1 m³ = 1,000,000 mL)
        let volumeML = Double(totalVolume_m3) * 1_000_000

        // Propagate uncertainty (root sum of squares)
        let uncertaintyML = sqrt(Double(totalUncertainty_m3)) * 1_000_000

        // Add systematic uncertainty based on number of valid pixels
        // Fewer pixels = higher uncertainty
        let minPixelsForReliability = 100
        let pixelCountFactor = validPixelCount < minPixelsForReliability
            ? Double(minPixelsForReliability) / Double(max(validPixelCount, 1))
            : 1.0

        let adjustedUncertainty = uncertaintyML * pixelCountFactor

        // Add minimum absolute uncertainty (at least 5% of volume, or 1 mL for very small volumes)
        let minRelativeUncertainty = volumeML * 0.05
        let minAbsoluteUncertainty = max(1.0, minRelativeUncertainty)
        let finalUncertainty = max(adjustedUncertainty, minAbsoluteUncertainty)

        return (volumeML: volumeML, uncertaintyML: finalUncertainty)
    }

    /// Unproject 2D pixel + depth to 3D world coordinates
    private func unproject(
        x: Float,
        y: Float,
        depth: Float,
        fx: Float,
        fy: Float,
        cx: Float,
        cy: Float
    ) -> SIMD3<Float> {
        // Standard pinhole camera model unprojection
        // X = (x - cx) * depth / fx
        // Y = (y - cy) * depth / fy
        // Z = depth

        let worldX = (x - cx) * depth / fx
        let worldY = (y - cy) * depth / fy
        let worldZ = depth

        return SIMD3<Float>(worldX, worldY, worldZ)
    }

    /// Check if pixel is inside mask (reads actual mask image)
    private func isPixelInMask(
        x: Int,
        y: Int,
        mask: FoodInstanceMask,
        width: Int,
        height: Int
    ) -> Bool {
        // Try to read actual mask pixel value
        // Mask image should be grayscale where white (255) = inside, black (0) = outside

        let maskImage = mask.maskImage
        let maskWidth = maskImage.width
        let maskHeight = maskImage.height

        // Scale coordinates to mask image dimensions
        let maskX = Int((Float(x) / Float(width)) * Float(maskWidth))
        let maskY = Int((Float(y) / Float(height)) * Float(maskHeight))

        // Bounds check
        guard maskX >= 0 && maskX < maskWidth &&
              maskY >= 0 && maskY < maskHeight else {
            return false
        }

        // Read pixel value from mask CGImage
        if let pixelValue = readMaskPixel(image: maskImage, x: maskX, y: maskY) {
            // Threshold: consider pixel in mask if value > 128 (50% gray)
            return pixelValue > 128
        }

        // Fallback to bounding box if mask reading fails
        let bbox = mask.boundingBox
        let xNorm = Float(x) / Float(width)
        let yNorm = Float(y) / Float(height)

        return xNorm >= Float(bbox.origin.x) &&
               xNorm <= Float(bbox.origin.x + bbox.width) &&
               yNorm >= Float(bbox.origin.y) &&
               yNorm <= Float(bbox.origin.y + bbox.height)
    }

    /// Read a single pixel value from grayscale mask image
    private func readMaskPixel(image: CGImage, x: Int, y: Int) -> UInt8? {
        // Validate image format
        guard image.bitsPerComponent == 8,
              image.bitsPerPixel == 8,
              let dataProvider = image.dataProvider,
              let data = dataProvider.data else {
            return nil
        }

        let bytes = CFDataGetBytePtr(data)
        let bytesPerRow = image.bytesPerRow
        let offset = y * bytesPerRow + x

        // Bounds check
        guard offset >= 0 && offset < CFDataGetLength(data) else {
            return nil
        }

        return bytes?[offset]
    }

    /// Estimate plate plane from depth data
    private func estimatePlatePlane(
        mask: FoodInstanceMask,
        depthMap: [Float],
        width: Int,
        height: Int,
        intrinsics: CameraIntrinsics
    ) -> PlaneEquation {
        // Simple heuristic: Find minimum depth in bottom 20% of mask
        // This approximates the plate surface

        let bbox = mask.boundingBox
        let xStart = Int(bbox.origin.x * CGFloat(width))
        let yStart = Int((bbox.origin.y + bbox.height * 0.8) * CGFloat(height)) // Bottom 20%
        let xEnd = Int((bbox.origin.x + bbox.width) * CGFloat(width))
        let yEnd = Int((bbox.origin.y + bbox.height) * CGFloat(height))

        var minDepth: Float = Float.infinity

        for y in yStart..<min(yEnd, height) {
            for x in xStart..<min(xEnd, width) {
                let idx = y * width + x
                if idx < depthMap.count {
                    let depth = depthMap[idx]
                    if depth > 0.01 && depth < 5.0 {
                        minDepth = min(minDepth, depth)
                    }
                }
            }
        }

        // Plate plane perpendicular to camera Z-axis at min depth
        // Normal pointing toward camera: (0, 0, 1)
        // Plane equation: n·p + d = 0
        // For plane at z = minDepth: (0,0,1)·(x,y,z) + d = 0 → z + d = 0 → d = -minDepth

        // Handle case where no valid depth found
        if minDepth.isInfinite {
            // Default to 0.5m plate distance
            return PlaneEquation(
                normal: SIMD3<Float>(0, 0, 1),
                distance: -0.5
            )
        }

        return PlaneEquation(
            normal: SIMD3<Float>(0, 0, 1),
            distance: -minDepth
        )
    }

    /// Estimate depth uncertainty based on sensor type
    private func estimateDepthUncertainty(_ depth: Float, source: DepthSource) -> Float {
        switch source {
        case .lidar:
            // LiDAR: 1-3% of depth
            return depth * 0.02
        case .stereo:
            // Stereo: 3-5% of depth
            return depth * 0.04
        case .structureFromMotion:
            // SfM: 5-10% of depth
            return depth * 0.075
        case .monocular:
            // Monocular depth estimation: 10-20% of depth
            return depth * 0.15
        }
    }
}

// MARK: - Error Extension

extension CalorieCameraError {
    static func processingFailed(_ message: String) -> CalorieCameraError {
        return .detectionFailure(message)
    }
}
