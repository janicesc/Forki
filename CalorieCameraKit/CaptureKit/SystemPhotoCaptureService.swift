#if canImport(AVFoundation) && canImport(UIKit)
import AVFoundation
import UIKit
import ImageIO

/// Types that can surface an `AVCaptureSession` for UI preview purposes.
public protocol CameraPreviewProviding: AnyObject {
    var previewSession: AVCaptureSession { get }
}

public enum PhotoCaptureError: Error {
    case cameraUnavailable
    case permissionDenied
    case captureFailed
    case sessionNotRunning
}

public final class SystemPhotoCaptureService: NSObject, @unchecked Sendable, FrameCaptureService, CameraPreviewProviding {
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "CalorieCameraKit.SystemPhotoCaptureService", qos: .userInitiated)
    private var photoDelegate: PhotoCaptureDelegate?

    public override init() {
        super.init()
    }

    public var previewSession: AVCaptureSession {
        session
    }

    public func isCameraAvailable() -> Bool {
        bestCameraDevice() != nil
    }

    public func requestPermissions() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted { throw PhotoCaptureError.permissionDenied }
        default:
            throw PhotoCaptureError.permissionDenied
        }
    }

    public func startSession() async throws {
        try await configureSessionIfNeeded()
        try await MainActor.run {
            guard !session.isRunning else { return }
            session.startRunning()
        }
    }

    public func stopSession() {
        Task {
            await MainActor.run {
                if session.isRunning {
                    session.stopRunning()
                }
            }
        }
    }

    public func captureFrame() async throws -> CapturedFrame {
        guard session.isRunning else { throw PhotoCaptureError.sessionNotRunning }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CapturedFrame, Error>) in
            sessionQueue.async(execute: { [weak self] in
                guard let self else {
                    continuation.resume(throwing: PhotoCaptureError.captureFailed)
                    return
                }

                let settings = AVCapturePhotoSettings()
                settings.isHighResolutionPhotoEnabled = true
                if self.photoOutput.isDepthDataDeliverySupported {
                    settings.isDepthDataDeliveryEnabled = true
                }

                let delegate = PhotoCaptureDelegate { result in
                    switch result {
                    case .success(let frame):
                        continuation.resume(returning: frame)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }

                self.photoDelegate = delegate
                self.photoOutput.capturePhoto(with: settings, delegate: delegate)
            })
        }
    }

    private func configureSessionIfNeeded() async throws {
        try await MainActor.run {
            guard session.inputs.isEmpty else { return }

            session.beginConfiguration()
            session.sessionPreset = .photo

            guard let device = bestCameraDevice() else {
                session.commitConfiguration()
                throw PhotoCaptureError.cameraUnavailable
            }

            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }

            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }
            photoOutput.isHighResolutionCaptureEnabled = true
            if photoOutput.isDepthDataDeliverySupported {
                photoOutput.isDepthDataDeliveryEnabled = true
            }

            session.commitConfiguration()
        }
    }

    /// Select the best camera device with depth support
    private func bestCameraDevice() -> AVCaptureDevice? {
        // iPhone 12 Pro and later: Try to get LiDAR-enabled camera
        if #available(iOS 15.4, *) {
            if let device = AVCaptureDevice.default(.builtInLiDARDepthCamera, for: .video, position: .back) {
                return device
            }
        }

        // Try dual/triple camera (has depth support on Pro models)
        if let device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
            return device
        }

        if let device = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back) {
            return device
        }

        // Fallback to wide angle (no depth)
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<CapturedFrame, Error>) -> Void

    init(completion: @escaping (Result<CapturedFrame, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            completion(.failure(error))
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            completion(.failure(PhotoCaptureError.captureFailed))
            return
        }

        let exifMetadata = MetadataExtractor.exifDictionary(from: photo.metadata)
        let exposureDuration = MetadataExtractor.timeInterval(fromExif: exifMetadata, key: "ExposureTime")
        let isoValue = MetadataExtractor.firstFloat(fromExif: exifMetadata, key: "ISOSpeedRatings")
        let brightness = MetadataExtractor.float(fromExif: exifMetadata, key: "BrightnessValue")

        let metadata = FrameMetadata(
            exposureDuration: exposureDuration,
            iso: isoValue,
            brightness: brightness,
            deviceOrientation: OrientationMapper.current
        )

        let captured = CapturedFrame(
            rgbImage: data,
            depthData: DepthExtractor.depthData(from: photo),
            cameraIntrinsics: nil,
            metadata: metadata
        )

        completion(.success(captured))
    }
}

private enum OrientationMapper {
    static var current: DeviceOrientation {
        switch UIDevice.current.orientation {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return .unknown
        }
    }
}

private enum MetadataExtractor {
    static func exifDictionary(from metadata: [AnyHashable: Any]) -> [String: Any]? {
        metadata[kCGImagePropertyExifDictionary as String] as? [String: Any]
    }

    static func timeInterval(fromExif metadata: [String: Any]?, key: String) -> TimeInterval? {
        guard let number = metadata?[key] as? NSNumber else { return nil }
        return number.doubleValue
    }

    static func float(fromExif metadata: [String: Any]?, key: String) -> Float? {
        guard let number = metadata?[key] as? NSNumber else { return nil }
        return number.floatValue
    }

    static func firstFloat(fromExif metadata: [String: Any]?, key: String) -> Float? {
        if let numbers = metadata?[key] as? [NSNumber], let first = numbers.first {
            return first.floatValue
        }
        if let number = metadata?[key] as? NSNumber {
            return number.floatValue
        }
        return nil
    }
}

private enum DepthExtractor {
    static func depthData(from photo: AVCapturePhoto) -> DepthData? {
        guard let depth = photo.depthData else { return nil }
        guard let map = depth.disparityPixelBuffer() else { return nil }
        CVPixelBufferLockBaseAddress(map, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(map, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(map) else { return nil }
        let width = CVPixelBufferGetWidth(map)
        let height = CVPixelBufferGetHeight(map)
        let count = width * height

        let buffer = baseAddress.assumingMemoryBound(to: Float32.self)
        let floatBuffer = UnsafeBufferPointer(start: buffer, count: count)
        let array = Array(floatBuffer)

        return DepthData(
            width: width,
            height: height,
            depthMap: array.map { Float($0) },
            confidenceMap: nil,
            source: .lidar
        )
    }
}

private extension AVDepthData {
    func disparityPixelBuffer() -> CVPixelBuffer? {
        let disparity = depthDataType == kCVPixelFormatType_DisparityFloat32
        ? self
        : converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32)
        return disparity.depthDataMap
    }
}

#endif
