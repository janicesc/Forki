import Foundation

/// Mock capture service for testing and simulator
@MainActor
public final class MockCaptureService: FrameCaptureService {

    public var shouldFail = false
    public var mockFrame: CapturedFrame?

    public init() {}

    public func isCameraAvailable() -> Bool {
        return true
    }

    public func requestPermissions() async throws {
        if shouldFail {
            throw CalorieCameraError.permissionDenied
        }
    }

    public func startSession() async throws {
        if shouldFail {
            throw CalorieCameraError.cameraUnavailable
        }
    }

    public func stopSession() {
        // No-op for mock
    }

    public func captureFrame() async throws -> CapturedFrame {
        if shouldFail {
            throw CalorieCameraError.captureFailure("Mock failure")
        }

        if let mockFrame = mockFrame {
            return mockFrame
        }

        // Generate simple mock frame
        let mockImageData = "Mock RGB Image Data".data(using: .utf8)!

        return CapturedFrame(
            timestamp: Date(),
            rgbImage: mockImageData,
            depthData: nil,
            cameraIntrinsics: nil,
            metadata: FrameMetadata(deviceOrientation: .portrait)
        )
    }
}
