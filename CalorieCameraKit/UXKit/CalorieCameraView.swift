import SwiftUI
import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif

/// Public SwiftUI surface for CalorieCameraKit that reacts to feature flags.
public struct CalorieCameraView: View {
    @StateObject private var coordinator: CalorieCameraCoordinator


    public init(
        config: CalorieConfig = .default,
        onResult: @escaping (CalorieResult) -> Void = { _ in },
        onCancel: (() -> Void)? = nil
    ) {
        _coordinator = StateObject(
            wrappedValue: CalorieCameraCoordinator(
                config: config,
                onResult: onResult,
                onCancel: onCancel
            )
        )
    }

    public var body: some View {
        ZStack {
            // Full-screen camera preview
#if canImport(AVFoundation) && canImport(UIKit)
            if let session = coordinator.previewSession {
                CameraPreviewContainer(session: session)
                    .ignoresSafeArea()
            } else {
                CameraPreviewPlaceholder(status: coordinator.statusMessage)
                    .ignoresSafeArea()
            }
#else
            CameraPreviewPlaceholder(status: coordinator.statusMessage)
                .ignoresSafeArea()
#endif

            // Overlay UI on top of camera
            VStack {
                // Top section: Title and microcopy
                VStack(spacing: 8) {
            Text("Calorie Camera")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)

                    Text("Scan your food for calories and macros.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 60)
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Status message overlay (if capturing or showing API status)
                if coordinator.isCapturing || coordinator.qualityProgress > 0 || !coordinator.statusMessage.isEmpty {
                    VStack(spacing: 8) {
                        if coordinator.qualityProgress > 0 {
                            ProgressView(value: coordinator.qualityProgress, total: 1.0)
                                .progressViewStyle(.linear)
                                .tint(.white)
                                .frame(width: 200)
                        }
                        
                        Text(coordinator.statusMessage)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                            .lineLimit(3)
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.bottom, 120)
                }
                
                // Result display (if available) - Forki Theme styling
                if let result = coordinator.lastResult {
                    VStack(alignment: .leading, spacing: 12) {
                        // DEBUG: Show detected label
                        if let firstItem = result.items.first {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("🔍 DEBUG: Detected Label")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.red)
                                Text("'\(firstItem.label)'")
                                    .font(.system(size: 10))
                                    .foregroundColor(firstItem.label == "Geometry" ? .red : .green)
                            }
                            .padding(6)
                            .background(Color.yellow.opacity(0.3))
                            .cornerRadius(6)
                        }
                        
                        // Title
                        Text("Nutrition Detected")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(red: 0.10, green: 0.13, blue: 0.20)) // #1A2332 - ForkiTheme textPrimary equivalent
                        
                        // Calories display
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(Int(result.total.mu))")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(Color(red: 0.48, green: 0.41, blue: 0.77)) // #7B68C4 - ForkiTheme.borderPrimary
                            Text("kcal")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(red: 0.10, green: 0.13, blue: 0.20)) // #1A2332
                        }
                        
                        // Show confidence if available
                        if result.total.sigma > 0 && result.total.mu > 0 {
                            Text("Confidence: \(Int(max(0, min(100, (1.0 - result.total.sigma / result.total.mu) * 100))))%")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(Color(red: 0.42, green: 0.45, blue: 0.50)) // #6B7280 - ForkiTheme.textSecondary equivalent
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.95)) // Light background like FoodDetailView
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color(red: 0.48, green: 0.41, blue: 0.77).opacity(0.2), lineWidth: 2) // ForkiTheme.borderPrimary opacity 0.2
                            )
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 120)
            }

                // VoI question overlay
            if let question = coordinator.voiQuestion {
                    VStack(spacing: 16) {
                        Text(question)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                        
                    HStack(spacing: 12) {
                            Button("No") {
                                coordinator.respondToVoI(false)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("voi-no")
                            
                            Button("Yes") {
                                coordinator.respondToVoI(true)
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("voi-yes")
                    }
                }
                .padding()
                    .background(Color.black.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 120)
            }

                // Bottom section: Buttons
                HStack(spacing: 16) {
                    // Secondary Button (left): Cancel (Forki theme: surface with border)
                    Button {
                        coordinator.cancel()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color(red: 0.10, green: 0.14, blue: 0.20).opacity(0.4)) // Forki surface
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(Color(red: 0.48, green: 0.41, blue: 0.77).opacity(0.4), lineWidth: 2) // Forki borderPrimary
                                    )
                            )
                    }
                    .disabled(!coordinator.canCancel)
                    .opacity(coordinator.canCancel ? 1.0 : 0.5)
                    
                    // Primary Button (right): Scan Food (Forki theme: standard mint)
                    Button {
                        coordinator.startCapture()
                    } label: {
                        Text("Scan Food")
                            .font(.system(size: 18, weight: .bold, design: .rounded)) // Match Log Food font style
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.553, green: 0.831, blue: 0.820), // #8DD4D1 - Mint gradient - ForkiTheme.actionLogFood
                                                Color(red: 0.435, green: 0.722, blue: 0.710)  // #6FB8B5 - Darker mint
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(Color(red: 0.478, green: 0.722, blue: 0.710), lineWidth: 2) // #7AB8B5 - Mint border
                                    )
                                    .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6) // Match Log Food shadow
                            )
                    }
                    .disabled(!coordinator.canStartCapture)
                    .opacity(coordinator.canStartCapture ? 1.0 : 0.5)
                    .accessibilityIdentifier("capture-button")
            }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .task {
            await coordinator.prepareSessionIfNeeded()
        }
        .onDisappear {
            coordinator.teardown()
        }
    }
}

// MARK: - Coordinator

@MainActor
private final class CalorieCameraCoordinator: ObservableObject {
    enum State: Equatable {
        case idle
        case ready
        case capturing
        case awaitingVoI
        case completed
        case failed(String)
    }

    private enum CaptureCoordinatorError: Error {
        case cameraUnavailable
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var statusMessage: String = "Preparing capture…"
    @Published private(set) var activePaths: [AnalysisPath] = []
    @Published private(set) var voiQuestion: String?
    @Published private(set) var lastResult: CalorieResult?
    @Published private(set) var qualityProgress: Double = 0.0
    #if canImport(AVFoundation) && canImport(UIKit)
    @Published private(set) var previewSession: AVCaptureSession?
    #endif

    var canStartCapture: Bool {
        switch state {
        case .ready, .completed:
            return true
        default:
            return false
        }
    }

    var canCancel: Bool {
        switch state {
        case .capturing, .awaitingVoI:
            return true
        default:
            return false
        }
    }

    var isCapturing: Bool {
        switch state {
        case .capturing, .awaitingVoI:
            return true
        default:
            return false
        }
    }

    private let config: CalorieConfig
    private let onResult: (CalorieResult) -> Void
    private let onCancel: (() -> Void)?
    private let qualityEstimator: CaptureQualityEstimator
    private let frameCaptureService: FrameCaptureService?
    private let analyzerClient: AnalyzerClient?
    private let routerEngine: AnalyzerRouter
    private let geometryEstimator: GeometryEstimatorV2
    private var pendingResult: CalorieResult?
    private var askedQuestions = 0

    init(
        config: CalorieConfig,
        onResult: @escaping (CalorieResult) -> Void,
        onCancel: (() -> Void)?
    ) {
        self.config = config
        self.onResult = onResult
        self.onCancel = onCancel
        self.qualityEstimator = CaptureQualityEstimator(parameters: config.captureQuality)
        self.analyzerClient = CalorieCameraCoordinator.makeAnalyzerClient()
        self.routerEngine = AnalyzerRouter(config: config)
        self.geometryEstimator = GeometryEstimatorV2(config: .default)
        self.frameCaptureService = CalorieCameraCoordinator.makeCaptureService()

        // Debug - show on screen if analyzer client is nil
        if self.analyzerClient == nil {
            statusMessage = "⚠️ ANALYZER CLIENT IS NIL - NO API CALLS"
            NSLog("❌❌❌ ANALYZER CLIENT IS NIL - NO API CALLS WILL BE MADE ❌❌❌")
        } else {
            NSLog("✅✅✅ ANALYZER CLIENT CREATED SUCCESSFULLY ✅✅✅")
        }

        updateActivePaths()
    }

    func prepareSessionIfNeeded() async {
        guard state == .idle else { return }
        statusMessage = "Calibrate camera and hold steady."
        qualityEstimator.reset()
        qualityProgress = 0.0
        do {
            if let captureService = frameCaptureService {
                guard captureService.isCameraAvailable() else {
                    throw CaptureCoordinatorError.cameraUnavailable
                }
                try await captureService.requestPermissions()
                try await captureService.startSession()
                #if canImport(AVFoundation) && canImport(UIKit)
                if let previewProvider = captureService as? CameraPreviewProviding {
                    previewSession = previewProvider.previewSession
                }
                #endif
            }
        } catch {
            state = .failed("Camera unavailable. Allow camera access in Settings.")
            statusMessage = "Camera access required."
            return
        }
        do {
            try await Task.sleep(for: .milliseconds(120))
        } catch { }
        state = .ready
        statusMessage = "Ready to capture."
    }

    func startCapture() {
        guard canStartCapture else { return }
        Task { await capture() }
    }

    func respondToVoI(_ answerYes: Bool) {
        guard state == .awaitingVoI, var result = pendingResult else { return }
        askedQuestions += 1
        let evidenceTag = answerYes ? "VoI-Confirmed" : "VoI-Rejected"
        let factor = answerYes ? 0.7 : 0.95

        result = applyVoIAdjustment(
            to: result,
            factor: factor,
            evidenceTag: evidenceTag
        )

        pendingResult = nil
        voiQuestion = nil
        finish(with: result)
    }

    func cancel() {
        switch state {
        case .capturing, .awaitingVoI:
            state = .idle
            statusMessage = "Capture cancelled."
            qualityEstimator.reset()
            qualityProgress = 0.0
            pendingResult = nil
            voiQuestion = nil
            onCancel?()
        default:
            break
        }
    }

    func teardown() {
        frameCaptureService?.stopSession()
        qualityEstimator.reset()
        qualityProgress = 0.0
        pendingResult = nil
        voiQuestion = nil
        #if canImport(AVFoundation) && canImport(UIKit)
        previewSession = nil
        #endif
        state = .idle
    }

    private func capture() async {
        state = .capturing
        qualityEstimator.reset()
        qualityProgress = 0.0
        // Reset temporal fusion state for new capture session
        geometryEstimator.resetTemporalState()
        statusMessage = "Move around the plate to hit quality threshold."

        let qualityStatus = await performQualityGate()
        if qualityStatus?.shouldStop == true {
            statusMessage = "Analyzing capture…"
        } else {
            statusMessage = "Analyzing best-effort capture…"
        }

        // Capture multiple frames for temporal fusion (V2 improvement)
        var capturedFrames: [CapturedFrame] = []
        if let captureService = frameCaptureService {
            // Capture 3 frames for temporal fusion
            for i in 0..<3 {
                do {
                    if let frame = try? await captureService.captureFrame() {
                        capturedFrames.append(frame)
                        NSLog("📸 [V2] Captured frame \(i + 1)/3")
                    }
                } catch {
                    print("[CalorieCamera] frame capture failed:", error)
                }
        }
        }
        
        // Use the last captured frame (or first if only one)
        let capturedFrame = capturedFrames.last ?? capturedFrames.first

        var analyzerObservation: AnalyzerObservation?
        var apiErrorMessage: String?
        if let analyzerClient {
            NSLog("🔄 Making API call to analyzer...")
            statusMessage = "Calling API..."
            do {
                if let frameData = capturedFrame?.rgbImage {
                    NSLog("📸 Sending RGB image (\(frameData.count) bytes)")
                    analyzerObservation = try await analyzerClient.analyze(
                        imageData: frameData,
                        mimeType: "image/jpeg"
                    )
                } else {
                    NSLog("🖼️ Sending placeholder image")
                    analyzerObservation = try await analyzerClient.analyze(
                        imageData: placeholderImageData(),
                        mimeType: "image/png"
                    )
                }
                if let obs = analyzerObservation {
                    let logMsg = "✅ API SUCCESS! Label: '\(obs.label)', Calories: \(obs.calories?.description ?? "nil"), Path: \(obs.path?.rawValue ?? "nil")"
                    NSLog(logMsg)
                    print(logMsg) // Also use print for visibility
                    
                    // CRITICAL: Log the exact label received
                    NSLog("🔑 [CalorieCameraView] CRITICAL: analyzerObservation.label = '\(obs.label)'")
                    print("🔑 [CalorieCameraView] CRITICAL: analyzerObservation.label = '\(obs.label)'")
                    
                    // Check if label is generic
                    let lowerLabel = obs.label.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    if lowerLabel == "geometry" || lowerLabel == "food" || lowerLabel == "meal" || lowerLabel.isEmpty {
                        let warnMsg = "⚠️ API returned generic label: '\(obs.label)' - this will be converted to 'Detected Food'"
                        NSLog(warnMsg)
                        print(warnMsg)
                        statusMessage = "API returned generic label"
                    } else {
                        let successMsg = "✅ API returned specific food label: '\(obs.label)'"
                        NSLog(successMsg)
                        print(successMsg)
                        statusMessage = "API succeeded: \(obs.label)"
                    }
                } else {
                    let errorMsg = "❌ API returned nil observation!"
                    NSLog(errorMsg)
                    print(errorMsg)
                    statusMessage = "API returned nil"
                }
            } catch {
                let errorDetails = "❌ API FAILED: \(error)"
                NSLog(errorDetails)
                print(errorDetails)
                apiErrorMessage = "\(error)"
                statusMessage = "API failed: \(error)"
                if let analyzerError = error as? AnalyzerClientError {
                    let details = "❌ Error details: \(analyzerError.localizedDescription)"
                    NSLog(details)
                    print(details)
                }
                // CRITICAL: Log the error type and message
                NSLog("❌ [CalorieCameraView] API Error type: \(type(of: error))")
                print("❌ [CalorieCameraView] API Error type: \(type(of: error))")
                NSLog("❌ [CalorieCameraView] API Error description: \(error.localizedDescription)")
                print("❌ [CalorieCameraView] API Error description: \(error.localizedDescription)")
            }
        } else {
            let errorMsg = "❌❌❌ ANALYZER CLIENT IS NIL - NO API CALLS WILL BE MADE ❌❌❌"
            NSLog(errorMsg)
            print(errorMsg)
            statusMessage = "⚠️ No analyzer client - API disabled"
        }

        // PRECISE: Use API label + Geometry Estimator V2 for nutrition
        // Step 1: Always run Geometry Estimator V2 to get precise volume and calories
        var geometryEstimate: GeometryEstimate?
        if let capturedFrame = capturedFrame {
            NSLog("📐 [PRECISE] Running Geometry Estimator V2 with \(capturedFrames.count) frames")
            print("📐 [PRECISE] Running Geometry Estimator V2 with \(capturedFrames.count) frames")
            
            // Process all frames for temporal fusion (V2 improvement)
            for (index, frame) in capturedFrames.enumerated() {
                NSLog("📐 [PRECISE] Processing frame \(index + 1)/\(capturedFrames.count)")
                print("📐 [PRECISE] Processing frame \(index + 1)/\(capturedFrames.count)")
                
                if let estimate = geometryEstimator.estimate(
                    from: frame,
                    priors: analyzerObservation?.priors
                ) {
                    geometryEstimate = estimate // Last estimate uses EMA-smoothed values
                    NSLog("✅ [PRECISE] Frame \(index + 1)/\(capturedFrames.count): volume=\(Int(estimate.volumeML))mL, calories=\(Int(estimate.calories))")
                    print("✅ [PRECISE] Frame \(index + 1)/\(capturedFrames.count): volume=\(Int(estimate.volumeML))mL, calories=\(Int(estimate.calories))")
                } else {
                    NSLog("⚠️ [PRECISE] Frame \(index + 1)/\(capturedFrames.count): Geometry estimate returned nil")
                    print("⚠️ [PRECISE] Frame \(index + 1)/\(capturedFrames.count): Geometry estimate returned nil")
                }
            }
            
            // Fallback to single frame if no frames processed
            if geometryEstimate == nil {
                NSLog("📐 [PRECISE] Trying single frame fallback")
                print("📐 [PRECISE] Trying single frame fallback")
                geometryEstimate = geometryEstimator.estimate(
                    from: capturedFrame,
                    priors: analyzerObservation?.priors
                )
                if let estimate = geometryEstimate {
                    NSLog("📐 [PRECISE] Single frame estimate: volume=\(Int(estimate.volumeML))mL, calories=\(Int(estimate.calories))")
                    print("📐 [PRECISE] Single frame estimate: volume=\(Int(estimate.volumeML))mL, calories=\(Int(estimate.calories))")
                }
            }
        } else {
            NSLog("⚠️ [PRECISE] No captured frame available")
            print("⚠️ [PRECISE] No captured frame available")
        }
        
        // Step 2: Get label from API if available, otherwise use geometry
        let finalLabel: String
        if let apiLabel = analyzerObservation?.label, !apiLabel.isEmpty {
            finalLabel = apiLabel
            NSLog("✅ [PRECISE] Using API label: '\(apiLabel)'")
            print("✅ [PRECISE] Using API label: '\(apiLabel)'")
        } else {
            finalLabel = geometryEstimate?.label ?? "Detected Food"
            NSLog("⚠️ [PRECISE] Using geometry/fallback label: '\(finalLabel)'")
            print("⚠️ [PRECISE] Using geometry/fallback label: '\(finalLabel)'")
        }
        
        // Step 3: Use Geometry Estimator V2 results for nutrition (calories, volume)
        // If geometry fails, fallback to API values if available
        guard let geometryEstimate = geometryEstimate else {
            NSLog("⚠️ [PRECISE] No geometry estimate available - falling back to API values")
            print("⚠️ [PRECISE] No geometry estimate available - falling back to API values")
            
            // Fallback: Use API values if available
            if let apiResult = analyzerObservation,
               let apiCalories = apiResult.calories,
               let apiSigma = apiResult.sigmaCalories,
               !apiResult.label.isEmpty {
                
                NSLog("✅ [PRECISE] Using API fallback: label='\(apiResult.label)', calories=\(Int(apiCalories))")
                print("✅ [PRECISE] Using API fallback: label='\(apiResult.label)', calories=\(Int(apiCalories))")
                
                let upperBound = apiCalories + 2 * apiSigma
                let finalLabel = apiResult.label
                
                // CRITICAL: Use API macros if available (they're per 100g, scale by portion size)
                // Scale factor = detected calories / API calories per 100g
                let proteinG: Double
                let carbsG: Double
                let fatsG: Double
                
                if let apiMacros = apiResult.macros,
                   let apiProtein = apiMacros.proteinG,
                   let apiCarbs = apiMacros.carbsG,
                   let apiFat = apiMacros.fatG,
                   apiCalories > 0 {
                    // API provides macros per 100g - scale them by portion size
                    // Scale factor = upperBound / apiCalories (portion size relative to 100g)
                    let scaleFactor = upperBound / apiCalories
                    proteinG = apiProtein * scaleFactor
                    carbsG = apiCarbs * scaleFactor
                    fatsG = apiFat * scaleFactor
                    
                    NSLog("📊 [PRECISE] Using API macros (scaled by portion):")
                    NSLog("📊 [PRECISE]   API macros per 100g: protein=\(apiProtein)g, carbs=\(apiCarbs)g, fat=\(apiFat)g")
                    NSLog("📊 [PRECISE]   Scale factor: \(String(format: "%.2f", scaleFactor)) (portion: \(Int(upperBound)) cal / \(Int(apiCalories)) cal per 100g)")
                    NSLog("📊 [PRECISE]   Scaled macros: protein=\(String(format: "%.1f", proteinG))g, carbs=\(String(format: "%.1f", carbsG))g, fat=\(String(format: "%.1f", fatsG))g")
                } else {
                    // Fallback: Calculate macros from calories using food-specific ratios
                    // For fruits/vegetables: ~1% protein, ~95% carbs, ~4% fats
                    // For general foods: 10% protein, 50% carbs, 40% fats
                    let isFruitOrVegetable = finalLabel.lowercased().contains("apple") ||
                                            finalLabel.lowercased().contains("orange") ||
                                            finalLabel.lowercased().contains("banana") ||
                                            finalLabel.lowercased().contains("fruit") ||
                                            finalLabel.lowercased().contains("vegetable")
                    
                    let totalCalories = upperBound
                    let proteinCalories: Double
                    let carbsCalories: Double
                    let fatsCalories: Double
                    
                    if isFruitOrVegetable {
                        // Fruits/vegetables: mostly carbs
                        proteinCalories = totalCalories * 0.01  // 1% protein
                        carbsCalories = totalCalories * 0.95    // 95% carbs
                        fatsCalories = totalCalories * 0.04     // 4% fats
                        NSLog("📊 [PRECISE] Using fruit/vegetable ratios (1% protein, 95% carbs, 4% fats)")
                    } else {
                        // General foods
                        proteinCalories = totalCalories * 0.10  // 10% protein
                        carbsCalories = totalCalories * 0.50    // 50% carbs
                        fatsCalories = totalCalories * 0.40     // 40% fats
                        NSLog("📊 [PRECISE] Using general food ratios (10% protein, 50% carbs, 40% fats)")
                    }
                    
                    proteinG = proteinCalories / 4.0  // 4 kcal/g protein
                    carbsG = carbsCalories / 4.0      // 4 kcal/g carbs
                    fatsG = fatsCalories / 9.0        // 9 kcal/g fats
                    
                    NSLog("📊 [PRECISE] Calculated macros from calories: protein=\(String(format: "%.1f", proteinG))g, carbs=\(String(format: "%.1f", carbsG))g, fat=\(String(format: "%.1f", fatsG))g")
                }
                
                var evidence = apiResult.evidence
                let macrosEvidence = "macros:protein:\(proteinG),carbs:\(carbsG),fat:\(fatsG)"
                evidence.append(macrosEvidence)
                evidence.append("APIFallback") // Mark as API fallback
                
                let item = ItemEstimate(
                    label: finalLabel,
                    volumeML: 0, // No volume from API
                    calories: upperBound,
                    sigma: apiSigma,
                    evidence: evidence
                )
                
                let result = CalorieResult(
                    items: [item],
                    total: (mu: upperBound, sigma: apiSigma)
                )
                
                finish(with: result)
                return
            } else {
                // Complete failure - no API, no geometry
                NSLog("❌ [PRECISE] Complete failure - no geometry, no API")
                print("❌ [PRECISE] Complete failure - no geometry, no API")
                finish(with: CalorieResult(items: [], total: (mu: 0, sigma: 100)))
                return
            }
        }
        
        // Use geometry-based calories (from V2 estimator)
        let geometryCalories = geometryEstimate.calories
        let geometrySigma = geometryEstimate.sigma
        let geometryVolumeML = geometryEstimate.volumeML
        
        // CRITICAL: Check for unreasonably high values (likely calculation error)
        // A single cookie should be ~30-50 calories, not 1000+
        let maxReasonableCalories = 1000.0  // Cap at 1000 calories for single food item
        let maxReasonableVolume = 1000.0   // Cap at 1000 mL for single food item
        
        if geometryCalories > maxReasonableCalories || geometryVolumeML > maxReasonableVolume {
            NSLog("⚠️⚠️⚠️ [PRECISE] WARNING: Geometry V2 returned suspiciously HIGH values!")
            print("⚠️⚠️⚠️ [PRECISE] WARNING: Geometry V2 returned suspiciously HIGH values!")
            NSLog("⚠️⚠️⚠️ [PRECISE]   Calories: \(geometryCalories) (expected < \(maxReasonableCalories), typical food is 50-500)")
            print("⚠️⚠️⚠️ [PRECISE]   Calories: \(geometryCalories) (expected < \(maxReasonableCalories), typical food is 50-500)")
            NSLog("⚠️⚠️⚠️ [PRECISE]   Volume: \(geometryVolumeML) mL (expected < \(maxReasonableVolume), typical food is 50-500)")
            print("⚠️⚠️⚠️ [PRECISE]   Volume: \(geometryVolumeML) mL (expected < \(maxReasonableVolume), typical food is 50-500)")
            NSLog("⚠️⚠️⚠️ [PRECISE]   This suggests a calculation error - falling back to API values")
            print("⚠️⚠️⚠️ [PRECISE]   This suggests a calculation error - falling back to API values")
            
            // If geometry values are too high, ALWAYS fallback to API if available
            if let apiResult = analyzerObservation,
               let apiCalories = apiResult.calories,
               let apiSigma = apiResult.sigmaCalories,
               apiCalories < maxReasonableCalories { // API has reasonable calories
                
                NSLog("✅ [PRECISE] Geometry values too high, using API values instead")
                print("✅ [PRECISE] Geometry values too high, using API values instead")
                
                let upperBound = min(apiCalories + 2 * apiSigma, maxReasonableCalories) // Cap upper bound too
                let finalLabel = apiResult.label
                
                // CRITICAL: Use API macros if available (scale by portion size)
                let proteinG: Double
                let carbsG: Double
                let fatsG: Double
                
                if let apiMacros = apiResult.macros,
                   let apiProtein = apiMacros.proteinG,
                   let apiCarbs = apiMacros.carbsG,
                   let apiFat = apiMacros.fatG,
                   apiCalories > 0 {
                    let scaleFactor = upperBound / apiCalories
                    proteinG = apiProtein * scaleFactor
                    carbsG = apiCarbs * scaleFactor
                    fatsG = apiFat * scaleFactor
                    NSLog("📊 [PRECISE] Using API macros (high geometry fallback, scaled): protein=\(String(format: "%.1f", proteinG))g, carbs=\(String(format: "%.1f", carbsG))g, fat=\(String(format: "%.1f", fatsG))g")
                } else {
                    // Fallback: food-specific ratios
                    let isFruitOrVegetable = finalLabel.lowercased().contains("apple") ||
                                            finalLabel.lowercased().contains("orange") ||
                                            finalLabel.lowercased().contains("banana") ||
                                            finalLabel.lowercased().contains("fruit") ||
                                            finalLabel.lowercased().contains("vegetable")
                    let totalCalories = upperBound
                    let (pCal, cCal, fCal) = isFruitOrVegetable ? 
                        (totalCalories * 0.01, totalCalories * 0.95, totalCalories * 0.04) :
                        (totalCalories * 0.10, totalCalories * 0.50, totalCalories * 0.40)
                    proteinG = pCal / 4.0
                    carbsG = cCal / 4.0
                    fatsG = fCal / 9.0
                    NSLog("📊 [PRECISE] Calculated macros (high geometry fallback): protein=\(String(format: "%.1f", proteinG))g, carbs=\(String(format: "%.1f", carbsG))g, fat=\(String(format: "%.1f", fatsG))g")
                }
                
                var evidence = apiResult.evidence
                let macrosEvidence = "macros:protein:\(proteinG),carbs:\(carbsG),fat:\(fatsG)"
                evidence.append(macrosEvidence)
                evidence.append("APIFallback-HighGeometry") // Mark as API fallback due to high geometry
                
                let item = ItemEstimate(
                    label: finalLabel,
                    volumeML: 0, // No volume from API
                    calories: upperBound,
                    sigma: apiSigma,
                    evidence: evidence
                )
                
                let result = CalorieResult(
                    items: [item],
                    total: (mu: upperBound, sigma: apiSigma)
                )
                
                finish(with: result)
                return
            }
        }
        
        // Check if geometry values are reasonable (minimum 20 calories for any food item)
        // A tangerine should be ~40-50 calories, so < 20 is definitely wrong
        if geometryCalories < 20 || geometryVolumeML < 20 {
            NSLog("⚠️⚠️⚠️ [PRECISE] WARNING: Geometry V2 returned suspiciously low values!")
            print("⚠️⚠️⚠️ [PRECISE] WARNING: Geometry V2 returned suspiciously low values!")
            NSLog("⚠️⚠️⚠️ [PRECISE]   Calories: \(geometryCalories) (expected > 20, typical food is 50-500)")
            print("⚠️⚠️⚠️ [PRECISE]   Calories: \(geometryCalories) (expected > 20, typical food is 50-500)")
            NSLog("⚠️⚠️⚠️ [PRECISE]   Volume: \(geometryVolumeML) mL (expected > 20, typical food is 50-500)")
            print("⚠️⚠️⚠️ [PRECISE]   Volume: \(geometryVolumeML) mL (expected > 20, typical food is 50-500)")
            
            // If geometry values are too low, ALWAYS fallback to API if available
            if let apiResult = analyzerObservation,
               let apiCalories = apiResult.calories,
               let apiSigma = apiResult.sigmaCalories,
               apiCalories >= 20 { // API has reasonable calories (minimum 20)
                
                NSLog("✅ [PRECISE] Geometry values too low, using API values instead")
                print("✅ [PRECISE] Geometry values too low, using API values instead")
                
                let upperBound = apiCalories + 2 * apiSigma
                let finalLabel = apiResult.label
                
                // CRITICAL: Use API macros if available (scale by portion size)
                let proteinG: Double
                let carbsG: Double
                let fatsG: Double
                
                if let apiMacros = apiResult.macros,
                   let apiProtein = apiMacros.proteinG,
                   let apiCarbs = apiMacros.carbsG,
                   let apiFat = apiMacros.fatG,
                   apiCalories > 0 {
                    let scaleFactor = upperBound / apiCalories
                    proteinG = apiProtein * scaleFactor
                    carbsG = apiCarbs * scaleFactor
                    fatsG = apiFat * scaleFactor
                    NSLog("📊 [PRECISE] Using API macros (low geometry fallback, scaled): protein=\(String(format: "%.1f", proteinG))g, carbs=\(String(format: "%.1f", carbsG))g, fat=\(String(format: "%.1f", fatsG))g")
                } else {
                    // Fallback: food-specific ratios
                    let isFruitOrVegetable = finalLabel.lowercased().contains("apple") ||
                                            finalLabel.lowercased().contains("orange") ||
                                            finalLabel.lowercased().contains("banana") ||
                                            finalLabel.lowercased().contains("fruit") ||
                                            finalLabel.lowercased().contains("vegetable")
                    let totalCalories = upperBound
                    let (pCal, cCal, fCal) = isFruitOrVegetable ? 
                        (totalCalories * 0.01, totalCalories * 0.95, totalCalories * 0.04) :
                        (totalCalories * 0.10, totalCalories * 0.50, totalCalories * 0.40)
                    proteinG = pCal / 4.0
                    carbsG = cCal / 4.0
                    fatsG = fCal / 9.0
                    NSLog("📊 [PRECISE] Calculated macros (low geometry fallback): protein=\(String(format: "%.1f", proteinG))g, carbs=\(String(format: "%.1f", carbsG))g, fat=\(String(format: "%.1f", fatsG))g")
                }
                
                var evidence = apiResult.evidence
                let macrosEvidence = "macros:protein:\(proteinG),carbs:\(carbsG),fat:\(fatsG)"
                evidence.append(macrosEvidence)
                evidence.append("APIFallback-LowGeometry") // Mark as API fallback due to low geometry
                
                let item = ItemEstimate(
                    label: finalLabel,
                    volumeML: geometryVolumeML, // Keep geometry volume even if low
                    calories: upperBound,
                    sigma: apiSigma,
                    evidence: evidence
                )
                
                let result = CalorieResult(
                    items: [item],
                    total: (mu: upperBound, sigma: apiSigma)
                )
                
                finish(with: result)
                return
            }
        }
        
        // Calculate upper bound (mean + 2×sigma) for conservative estimate
        // Cap at reasonable maximum to prevent absurd values
        let rawUpperBound = geometryCalories + 2 * geometrySigma
        let upperBound = min(rawUpperBound, 1000.0) // Cap at 1000 calories for single food item
        
        if rawUpperBound > 1000.0 {
            NSLog("⚠️ [PRECISE] Upper bound (\(Int(rawUpperBound))) exceeds 1000 cal, capping to 1000")
            print("⚠️ [PRECISE] Upper bound (\(Int(rawUpperBound))) exceeds 1000 cal, capping to 1000")
        }
        
        NSLog("📊 [PRECISE] Geometry V2 results:")
        print("📊 [PRECISE] Geometry V2 results:")
        NSLog("📊 [PRECISE]   Volume: \(Int(geometryVolumeML)) mL")
        print("📊 [PRECISE]   Volume: \(Int(geometryVolumeML)) mL")
        NSLog("📊 [PRECISE]   Calories (mean): \(Int(geometryCalories)) kcal")
        print("📊 [PRECISE]   Calories (mean): \(Int(geometryCalories)) kcal")
        NSLog("📊 [PRECISE]   Calories (upper bound): \(Int(upperBound)) kcal")
        print("📊 [PRECISE]   Calories (upper bound): \(Int(upperBound)) kcal")
        NSLog("📊 [PRECISE]   Uncertainty (sigma): \(Int(geometrySigma)) kcal")
        print("📊 [PRECISE]   Uncertainty (sigma): \(Int(geometrySigma)) kcal")
        
        // Step 4: Calculate macros from geometry volume using priors
        // Use priors from API if available, otherwise use geometry estimate's implicit priors
        let foodPriors = analyzerObservation?.priors
        
        // Calculate grams from volume using density prior
        let densityMu = foodPriors?.density.mu ?? 1.0  // Default 1.0 g/mL (water-like)
        let grams = geometryVolumeML * densityMu
        
        // Calculate macros: Use API macros if available, otherwise use food-specific ratios
        let proteinG: Double
        let carbsG: Double
        let fatsG: Double
        
        if let apiMacros = analyzerObservation?.macros,
           let apiProtein = apiMacros.proteinG,
           let apiCarbs = apiMacros.carbsG,
           let apiFat = apiMacros.fatG,
           let apiCalories = analyzerObservation?.calories,
           apiCalories > 0 {
            // Scale API macros (per 100g) to match geometry-based portion size
            let scaleFactor = upperBound / apiCalories
            proteinG = apiProtein * scaleFactor
            carbsG = apiCarbs * scaleFactor
            fatsG = apiFat * scaleFactor
            NSLog("📊 [PRECISE] Using API macros (scaled to geometry portion): protein=\(String(format: "%.1f", proteinG))g, carbs=\(String(format: "%.1f", carbsG))g, fat=\(String(format: "%.1f", fatsG))g")
        } else {
            // Fallback: Use food-specific ratios based on label
            let isFruitOrVegetable = finalLabel.lowercased().contains("apple") ||
                                    finalLabel.lowercased().contains("orange") ||
                                    finalLabel.lowercased().contains("banana") ||
                                    finalLabel.lowercased().contains("fruit") ||
                                    finalLabel.lowercased().contains("vegetable")
            
            let totalCaloriesFromMacros = upperBound
            let (proteinCalories, carbsCalories, fatsCalories): (Double, Double, Double)
            
            if isFruitOrVegetable {
                // Fruits/vegetables: mostly carbs
                proteinCalories = totalCaloriesFromMacros * 0.01  // 1% protein
                carbsCalories = totalCaloriesFromMacros * 0.95    // 95% carbs
                fatsCalories = totalCaloriesFromMacros * 0.04     // 4% fats
                NSLog("📊 [PRECISE] Using fruit/vegetable ratios (1% protein, 95% carbs, 4% fats)")
            } else {
                // General foods
                proteinCalories = totalCaloriesFromMacros * 0.10  // 10% protein
                carbsCalories = totalCaloriesFromMacros * 0.50    // 50% carbs
                fatsCalories = totalCaloriesFromMacros * 0.40     // 40% fats
                NSLog("📊 [PRECISE] Using general food ratios (10% protein, 50% carbs, 40% fats)")
            }
            
            proteinG = proteinCalories / 4.0  // 4 kcal/g protein
            carbsG = carbsCalories / 4.0      // 4 kcal/g carbs
            fatsG = fatsCalories / 9.0        // 9 kcal/g fats
        }
        
        NSLog("📊 [PRECISE] Calculated macros from geometry:")
        print("📊 [PRECISE] Calculated macros from geometry:")
        NSLog("📊 [PRECISE]   Protein: \(String(format: "%.1f", proteinG))g")
        print("📊 [PRECISE]   Protein: \(String(format: "%.1f", proteinG))g")
        NSLog("📊 [PRECISE]   Carbs: \(String(format: "%.1f", carbsG))g")
        print("📊 [PRECISE]   Carbs: \(String(format: "%.1f", carbsG))g")
        NSLog("📊 [PRECISE]   Fats: \(String(format: "%.1f", fatsG))g")
        print("📊 [PRECISE]   Fats: \(String(format: "%.1f", fatsG))g")
        
        // Store macros in evidence for bridge to extract
        var evidence = geometryEstimate.evidence
        let macrosEvidence = "macros:protein:\(proteinG),carbs:\(carbsG),fat:\(fatsG)"
        evidence.append(macrosEvidence)
        evidence.append("GeometryV2") // Mark as using V2 geometry
        
        // Add API evidence if available
        if let apiEvidence = analyzerObservation?.evidence {
            evidence.append(contentsOf: apiEvidence)
        }
        let finalEvidence = Array(Set(evidence)).sorted()
        
        // Create result with API label + Geometry V2 nutrition
        let item = ItemEstimate(
            label: finalLabel,
            volumeML: geometryVolumeML,
            calories: upperBound, // Upper bound for conservative estimate
            sigma: geometrySigma,
            evidence: finalEvidence
        )
        
        let result = CalorieResult(
            items: [item],
            total: (mu: upperBound, sigma: geometrySigma)
        )
        
        NSLog("✅ [PRECISE] Final result: label='\(finalLabel)', calories=\(Int(upperBound)), volume=\(Int(geometryVolumeML))mL")
        print("✅ [PRECISE] Final result: label='\(finalLabel)', calories=\(Int(upperBound)), volume=\(Int(geometryVolumeML))mL")

        // Debug output
        let debugMsg = """
        ═══════════════════════════════════════
        DEBUG: Final Result (PRECISE - API Label + Geometry V2)
        Label: '\(finalLabel)'
        Calories (upper bound): \(Int(upperBound))
        Calories (mean): \(Int(geometryCalories))
        Volume: \(Int(geometryVolumeML)) mL
        Evidence: \(finalEvidence)
        Analyzer observation: \(analyzerObservation != nil ? "YES" : "NO")
        """
        NSLog(debugMsg)
        print(debugMsg)
        
        if let obs = analyzerObservation {
            let obsMsg = """
              - Path: \(obs.path?.rawValue ?? "nil")
              - Label: '\(obs.label)'
              - Priors: \(obs.priors != nil ? "YES" : "NO")
            """
            NSLog(obsMsg)
            print(obsMsg)
        } else {
            let noObsMsg = "  ⚠️ NO ANALYZER OBSERVATION - API CALL FAILED OR NOT MADE"
            NSLog(noObsMsg)
            print(noObsMsg)
        }
        
        let geometryMsg = """
        Geometry V2 calories: \(Int(geometryCalories)) kcal
        Geometry V2 volume: \(Int(geometryVolumeML)) mL
        ═══════════════════════════════════════
        """
        NSLog(geometryMsg)
        print(geometryMsg)

        if analyzerObservation != nil {
            statusMessage = "✅ API worked! Path: \(analyzerObservation?.path?.rawValue ?? "?")"
        } else if apiErrorMessage != nil {
            statusMessage = "❌ API ERROR: \(apiErrorMessage?.prefix(50) ?? "unknown")"
        } else {
            statusMessage = "⚠️ API returned nil (no error but no result)"
        }

        if shouldAskVoI(for: result) {
            pendingResult = result
            voiQuestion = nextVoIQuestion()
            state = .awaitingVoI
            statusMessage = "Need extra clarification."
        } else {
            finish(with: result)
        }
    }

    private func finish(with result: CalorieResult) {
        state = .completed
        statusMessage = "Capture complete."
        qualityProgress = 1.0
        lastResult = result
        
        // Debug: Log that we're calling onResult
        NSLog("✅ [CalorieCamera] Calling onResult with \(result.items.count) item(s), total calories: \(Int(result.total.mu))")
        onResult(result)
        NSLog("✅ [CalorieCamera] onResult called successfully")
    }

    private func updateActivePaths() {
        // Path badges removed - no longer displaying analysis paths
        activePaths = []
    }

    private func shouldAskVoI(for result: CalorieResult) -> Bool {
        guard config.flags.voiEnabled,
              askedQuestions == 0 else { return false }
        return result.totalRelativeUncertainty >= config.voiThreshold
    }

    private func nextVoIQuestion() -> String {
        if let candidate = config.askBinaryPool.first {
            return "Is the dish \(candidate)?"
        }
        return "Does this plate include sauce or dressing?"
    }

    private func applyVoIAdjustment(
        to result: CalorieResult,
        factor: Double,
        evidenceTag: String
    ) -> CalorieResult {
        guard let item = result.items.first else { return result }
        let adjustedSigma = max(item.sigma * factor, 1.0)
        let adjustedItem = ItemEstimate(
            id: item.id,
            label: item.label,
            volumeML: item.volumeML,
            calories: item.calories,
            sigma: adjustedSigma,
            evidence: Array(Set(item.evidence + [evidenceTag])).sorted()
        )
        let adjustedTotal = (mu: result.total.mu, sigma: max(result.total.sigma * factor, 1.0))
        return CalorieResult(items: [adjustedItem], total: adjustedTotal)
    }

    private static func makeAnalyzerClient() -> AnalyzerClient? {
        // Dual Analyzer Client: Next.js API (primary) → Supabase Edge Function (fallback)
        let supabaseURL = "https://uisjdlxdqfovuwurmdop.supabase.co/functions/v1"
        let supabaseAPIKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVpc2pkbHhkcWZvdnV3dXJtZG9wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg5MDkyODYsImV4cCI6MjA3NDQ4NTI4Nn0.WaACHNXUWh5ZXKu5aZf1EjolXvWdD7R5mbNqBebnIuI"
        
        // Check for Next.js API URL from environment (optional)
        let nextjsURLString = ProcessInfo.processInfo.environment["NEXTJS_API_URL"]
        let nextjsURL = nextjsURLString.flatMap { URL(string: $0) }
        
        guard let supabaseURLParsed = URL(string: supabaseURL) else {
            NSLog("❌ Failed to create Supabase URL")
            return nil
        }

        NSLog("🔄 [DualAnalyzer] Creating DualAnalyzerClient")
        if let nextjsURL = nextjsURL {
            NSLog("🔄 [DualAnalyzer] Next.js API URL configured: \(nextjsURL.absoluteString)")
        } else {
            NSLog("🔄 [DualAnalyzer] Next.js API URL not configured, using Supabase only")
        }
        NSLog("🔄 [DualAnalyzer] Supabase URL: \(supabaseURL)")

        return DualAnalyzerClient(
            configuration: DualAnalyzerClient.Configuration(
                nextjsAPIURL: nextjsURL,
                supabaseURL: supabaseURLParsed,
                supabaseAPIKey: supabaseAPIKey,
                timeout: 20.0
            )
        )
    }

    private static let placeholderImage: Data = {
        Data(
            base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/w8AAwMB/6XGMZkAAAAASUVORK5CYII="
        ) ?? Data()
    }()

    private func placeholderImageData() -> Data {
        Self.placeholderImage
    }

    private static func makeCaptureService() -> FrameCaptureService? {
        #if canImport(AVFoundation) && canImport(UIKit)
        return SystemPhotoCaptureService()
        #else
        return nil
        #endif
    }

    private func performQualityGate() async -> CaptureQualityStatus? {
        var latestStatus: CaptureQualityStatus?
        for sample in generateMockQualitySamples() {
            guard state == .capturing else { break }
            let status = qualityEstimator.evaluate(sample: sample)
            latestStatus = status
            updateQualityStatus(status)

            if status.shouldStop {
                break
            }

            try? await Task.sleep(for: .milliseconds(90))
        }
        return latestStatus
    }

    private func updateQualityStatus(_ status: CaptureQualityStatus) {
        qualityProgress = status.progress

        if status.shouldStop {
            statusMessage = "Quality locked. Processing capture…"
            return
        }

        if !status.meetsTracking {
            statusMessage = "Hold steady to restore tracking…"
        } else if !status.meetsParallax {
            statusMessage = "Move around the plate for more viewpoints."
        } else if !status.meetsDepth {
            statusMessage = "Lower the device slightly to capture depth."
        } else {
            statusMessage = "Gathering more frames…"
        }
    }

    private func generateMockQualitySamples() -> [CaptureQualitySample] {
        let params = config.captureQuality
        let steps = max(params.minimumStableFrames + 3, 5)
        let parallaxStep = params.parallaxTarget / Double(steps - 1)
        let depthStep = params.depthCoverageTarget / Double(steps)

        var samples: [CaptureQualitySample] = []
        var parallax = 0.0
        var depth = params.depthCoverageTarget * 0.4

        for index in 0..<steps {
            parallax = min(params.parallaxTarget * 1.1, parallax + parallaxStep)
            depth = min(1.0, depth + depthStep)
            let state: TrackingState = index < 1 ? .limited : .normal

            samples.append(
                CaptureQualitySample(
                    timestamp: Date(),
                    parallax: parallax,
                    trackingState: state,
                    depthCoverage: depth
                )
            )
        }

        return samples
    }
}

#if canImport(AVFoundation) && canImport(UIKit)
private struct CameraPreviewSurface: View {
    let session: AVCaptureSession?
    let status: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let session {
                CameraPreviewContainer(session: session)
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            } else {
                CameraPreviewPlaceholder(status: status)
            }
            LinearGradient(
                colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
                .allowsHitTesting(false)
                .opacity(session == nil ? 0.7 : 1.0)

            Text(status)
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.92))
                .padding(12)
        }
        .frame(height: 320)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08))
        )
        .animation(.easeInOut(duration: 0.25), value: session != nil)
    }
}

@available(iOS 13.0, *)
private struct CameraPreviewContainer: UIViewRepresentable {
    final class PreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            // swiftlint:disable:next force_cast
            layer as! AVCaptureVideoPreviewLayer
        }
    }

    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        configure(layer: view.videoPreviewLayer)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.videoPreviewLayer.session !== session {
            uiView.videoPreviewLayer.session = session
        }
        configure(layer: uiView.videoPreviewLayer)
    }

    private func configure(layer: AVCaptureVideoPreviewLayer) {
        layer.session = session
        layer.videoGravity = .resizeAspectFill
        if layer.connection?.isVideoOrientationSupported == true {
            layer.connection?.videoOrientation = .portrait
        }
    }
}
#endif

private struct CameraPreviewPlaceholder: View {
    let status: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.6),
                    Color.black.opacity(0.85)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 12) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 42))
                    .foregroundStyle(.white.opacity(0.8))
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
        }
    }
}

private enum AnalysisPath: String, CaseIterable, Identifiable {
    case analyzer
    case router
    case label
    case menu
    case geometry
    case mixture

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .analyzer:
            return "Analyzer"
        case .router:
            return "Router"
        case .label:
            return "Label"
        case .menu:
            return "Menu"
        case .geometry:
            return "Geometry"
        case .mixture:
            return "Mixture"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .analyzer:
            return "Analyzer path active"
        case .router:
            return "Router path active"
        case .label:
            return "Label path active"
        case .menu:
            return "Menu path active"
        case .geometry:
            return "Geometry path active"
        case .mixture:
            return "Mixture fusion active"
        }
    }

    var badgeColor: Color {
        switch self {
        case .analyzer:
            return .teal
        case .router:
            return .blue
        case .label:
            return .purple
        case .menu:
            return .orange
        case .geometry:
            return .green
        case .mixture:
            return .pink
        }
    }
}
