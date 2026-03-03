import ApplicationServices
import Foundation

@MainActor
public final class AimClickerController {
    private let options: AimClickerOptions
    private let detector: AimTargetDetector
    private let axorc: AxorcCommanding
    private let overlay: OverlayWindowController
    private lazy var tabInterceptor: TabInterceptor = TabInterceptor { [weak self] in
        self?.handleTabPress() ?? false
    }

    private var timer: Timer?
    private var currentRef: String?
    private var currentClassToken: String?
    private var currentTargetFrame: CGRect?
    private var isAimContextActive: Bool = false
    private var autoClickGate: AutoClickGate
    private var autoClickLimiter: AutoClickLimiter

    public init(
        options: AimClickerOptions = AimClickerOptions(),
        detector: AimTargetDetector = AimTargetDetector(),
        axorc: AxorcCommanding = AxorcClient(),
        overlay: OverlayWindowController = OverlayWindowController())
    {
        self.options = options
        self.detector = detector
        self.axorc = axorc
        self.overlay = overlay
        self.autoClickGate = AutoClickGate(minimumInterval: options.autoClickMinimumInterval)
        self.autoClickLimiter = AutoClickLimiter(maxClicks: options.autoClickMaxTargets)
    }

    public func start() {
        _ = AXIsProcessTrusted()
        self.autoClickGate.reset()
        self.autoClickLimiter = AutoClickLimiter(maxClicks: self.options.autoClickMaxTargets)

        self.tabInterceptor.start()

        self.timer = Timer.scheduledTimer(withTimeInterval: 0.20, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        self.timer?.tolerance = 0.08
    }

    public func stop() {
        self.timer?.invalidate()
        self.timer = nil
        self.tabInterceptor.stop()
        self.overlay.hide()
    }

    private func tick() {
        guard self.detector.isAimTrainerFrontmost() else {
            self.isAimContextActive = false
            self.currentClassToken = nil
            self.currentRef = nil
            self.currentTargetFrame = nil
            self.autoClickGate.reset()
            self.autoClickLimiter = AutoClickLimiter(maxClicks: self.options.autoClickMaxTargets)
            self.overlay.hide()
            return
        }

        self.isAimContextActive = true

        guard let candidate = self.detector.detectTargetCandidate() else {
            self.currentClassToken = nil
            self.currentRef = nil
            self.currentTargetFrame = nil
            self.overlay.hide()
            return
        }

        self.overlay.show(axRect: candidate.frame)
        self.currentTargetFrame = candidate.frame
        self.maybeAutoClick(targetFrame: candidate.frame)

        guard self.currentClassToken != candidate.classToken else {
            return
        }

        self.currentClassToken = candidate.classToken
        self.currentRef = self.axorc.queryTargetRef(classToken: candidate.classToken)
    }

    private func handleTabPress() -> Bool {
        guard self.isAimContextActive else {
            return false
        }

        // Fast path: local click is effectively immediate and avoids process-spawn latency.
        if let frame = self.currentTargetFrame {
            MouseClicker.clickCenter(of: frame)
            self.currentClassToken = nil
            return true
        }

        // Fallback path: if no geometry is cached, fall back to axorc ref click.
        if let ref = self.currentRef, self.axorc.click(ref: ref) {
            self.currentClassToken = nil
            return true
        }

        return false
    }

    private func maybeAutoClick(targetFrame: CGRect) {
        guard self.options.autoClickEnabled else {
            return
        }

        if self.autoClickLimiter.hasReachedLimit {
            self.stop()
            return
        }

        let now = Date().timeIntervalSinceReferenceDate
        guard self.autoClickGate.shouldClick(frame: targetFrame, now: now) else {
            return
        }

        MouseClicker.clickCenter(of: targetFrame)
        let reachedLimit = self.autoClickLimiter.registerClick()
        self.currentClassToken = nil
        if reachedLimit {
            self.stop()
        }
    }
}
