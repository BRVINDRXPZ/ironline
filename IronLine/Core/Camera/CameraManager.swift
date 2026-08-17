import AVFoundation
import Combine
import ImageIO

final class CameraManager: NSObject, ObservableObject {
    enum TrackingState: Equatable {
        case idle
        case requestingPermission
        case ready
        case tracking
        case trackingLost
        case denied
        case failed(String)
    }

    @Published private(set) var trackingState: TrackingState = .idle
    @Published private(set) var repsCompleted = 0
    @Published private(set) var repsAttempted = 0
    @Published private(set) var elbowAngle: Double?
    @Published private(set) var romProgress = 0.0
    @Published private(set) var lastFeedback: String?
    @Published private(set) var isSetActive = false

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.ironline.camera.session")
    private let outputQueue = DispatchQueue(label: "com.ironline.camera.frames", qos: .userInteractive)
    private let poseDetector = PoseDetector()
    private var repCounter = RepCounter()
    private var angleSmoother = AngleSmoother(windowSize: 5)
    private var configured = false

    func prepareAndStart() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            configureAndStartIfNeeded()
        case .notDetermined:
            trackingState = .requestingPermission
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.configureAndStartIfNeeded()
                    } else {
                        self.trackingState = .denied
                    }
                }
            }
        default:
            trackingState = .denied
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func beginSet() {
        repCounter.reset()
        angleSmoother.reset()
        repsCompleted = 0
        repsAttempted = 0
        lastFeedback = nil
        isSetActive = true
    }

    func endSet() {
        isSetActive = false
    }

    private func configureAndStartIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            do {
                if !self.configured {
                    try self.configureSession()
                    self.configured = true
                }
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                DispatchQueue.main.async {
                    self.trackingState = .ready
                }
            } catch {
                DispatchQueue.main.async {
                    self.trackingState = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .high

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.noCamera
        }

        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else { throw CameraError.cannotAddInput }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: outputQueue)

        guard session.canAddOutput(output) else { throw CameraError.cannotAddOutput }
        session.addOutput(output)

        if let connection = output.connection(with: .video), connection.isVideoMirroringSupported {
            connection.isVideoMirrored = false
        }
    }

    private func currentImageOrientation() -> CGImagePropertyOrientation {
        // First playable deliberately locks the capture experience to portrait.
        // Fewer degrees of freedom means easier threshold tuning and more honest tests.
        .right
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        do {
            guard let pose = try poseDetector.detect(
                in: pixelBuffer,
                orientation: currentImageOrientation()
            ) else {
                // Once pose tracking disappears, any in-flight rep is no longer
                // verifiable. Invalidate it immediately and require a fresh top
                // position after tracking resumes.
                let event = isSetActive ? repCounter.trackingLost() : nil
                let attempted = repCounter.repsAttempted

                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.trackingState = .trackingLost
                    self.elbowAngle = nil
                    self.romProgress = 0
                    self.repsAttempted = attempted

                    if case let .noRep(reason)? = event {
                        self.lastFeedback = "NO REP — \(reason)"
                    }
                }
                return
            }

            let angle = angleSmoother.add(pose.elbowAngle)
            let progress = repCounter.romProgress(for: angle)
            let event = isSetActive
                ? repCounter.update(angle: angle, confidence: pose.confidence)
                : nil

            let completed = repCounter.repsCompleted
            let attempted = repCounter.repsAttempted

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.trackingState = .tracking
                self.elbowAngle = angle
                self.romProgress = progress
                self.repsCompleted = completed
                self.repsAttempted = attempted

                switch event {
                case .counted(let rep):
                    self.lastFeedback = "REP \(rep) — VERIFIED"
                case .noRep(let reason):
                    self.lastFeedback = "NO REP — \(reason)"
                case .none:
                    break
                }
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.trackingState = .failed(error.localizedDescription)
            }
        }
    }
}

private enum CameraError: LocalizedError {
    case noCamera
    case cannotAddInput
    case cannotAddOutput

    var errorDescription: String? {
        switch self {
        case .noCamera: return "Back camera unavailable."
        case .cannotAddInput: return "Could not attach camera input."
        case .cannotAddOutput: return "Could not attach camera frame output."
        }
    }
}
