//
//  CoreMLFoodClassifier.swift
//  CalorieCameraKit
//
//  Created by Janice C on 10/30/25.
//

import Foundation
import CoreML
import Vision
#if canImport(UIKit)
import UIKit
#endif

// Use ClassResult from Segmentation.swift
// Note: CoreMLFoodClassifier uses the Segmentation protocol types

public final class CoreMLFoodClassifier: Classifier {
    private let vnModel: VNCoreMLModel
    private let topK: Int

    public init(model: MLModel, topK: Int = 3) throws {
        self.vnModel = try VNCoreMLModel(for: model)
        self.topK = topK
    }

    /// Classify a single food instance with frames for temporal coherence
    public func classify(
        instance: FoodInstanceMask,
        frames: [FrameSample]
    ) async throws -> ClassResult {
        // Prefer CGImage → Vision handles resizing/cropping internally.
        if let cgImage = cgImage(from: instance) {
            return try classify(cgImage: cgImage)
        }

        // Fallback: if CGImage failed but we can make a pixel buffer, use that.
        if let pb = try? pixelBuffer(from: instance) {
            return try classify(pixelBuffer: pb)
        }

        // Final fallback
        return ClassResult(topLabel: "unknown", confidence: 0.0, mixture: nil)
    }

    // MARK: - Core classification paths

    private func classify(cgImage: CGImage) throws -> ClassResult {
        let request = VNCoreMLRequest(model: vnModel)
        request.imageCropAndScaleOption = .centerCrop

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        return makeResult(from: request)
    }

    private func classify(pixelBuffer: CVPixelBuffer) throws -> ClassResult {
        let request = VNCoreMLRequest(model: vnModel)
        request.imageCropAndScaleOption = .centerCrop

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try handler.perform([request])

        return makeResult(from: request)
    }

    private func makeResult(from request: VNRequest) -> ClassResult {
        guard let results = request.results as? [VNClassificationObservation],
              let best = results.first else {
            return ClassResult(topLabel: "unknown", confidence: 0.0, mixture: nil)
        }

        let top = Array(results.prefix(topK))
        let canonical = Self.canonicalize(best.identifier)
        
        // Build mixture dictionary from top-K results
        var mixture: [String: Double] = [:]
        for result in top {
            let key = Self.canonicalize(result.identifier)
            mixture[key] = Double(result.confidence)
        }
        
        return ClassResult(
            topLabel: canonical,
            confidence: Double(best.confidence),
            mixture: mixture.count > 1 ? mixture : nil
        )
    }

    // MARK: - Helpers

    /// Convert "Korean Braised Tofu" -> "korean_braised_tofu"
    private static func canonicalize(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }

    /// Try to get a CGImage from the instance mask.
    /// Uses the maskImage from FoodInstanceMask (Segmentation.swift type)
    private func cgImage(from instance: FoodInstanceMask) -> CGImage? {
        // Use the maskImage directly (it's a CGImage)
        return instance.maskImage
    }

    /// As a fallback, make a pixel buffer from the mask image.
    private func pixelBuffer(from instance: FoodInstanceMask) throws -> CVPixelBuffer {
        #if canImport(UIKit)
        // Convert mask CGImage to CVPixelBuffer
        let maskImage = instance.maskImage
        let width = maskImage.width
        let height = maskImage.height

        var pb: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pb)
        guard status == kCVReturnSuccess, let pixelBuffer = pb else {
            throw NSError(domain: "CoreMLFoodClassifier", code: -11, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate pixel buffer"])
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            throw NSError(domain: "CoreMLFoodClassifier", code: -12, userInfo: [NSLocalizedDescriptionKey: "Context creation failed"])
        }

        ctx.draw(maskImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelBuffer
        #else
        throw NSError(domain: "CoreMLFoodClassifier", code: -13, userInfo: [NSLocalizedDescriptionKey: "UIKit not available"])
        #endif
    }
}

#if canImport(UIKit)
private extension UIImage {
    func precomposedCGImage() -> CGImage? {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let img = renderer.image { _ in self.draw(in: CGRect(origin: .zero, size: size)) }
        return img.cgImage
    }
}
#endif
