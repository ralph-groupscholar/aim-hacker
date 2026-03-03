import AppKit
import ApplicationServices
import Foundation

public struct AimTargetCandidate: Equatable {
    public let frame: CGRect
    public let classToken: String

    public init(frame: CGRect, classToken: String) {
        self.frame = frame
        self.classToken = classToken
    }
}

@MainActor
public final class AimTargetDetector {
    public init() {}

    public func isAimTrainerFrontmost() -> Bool {
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.bundleIdentifier == "com.apple.Safari"
        else {
            return false
        }

        let appElement = AXUIElementCreateApplication(front.processIdentifier)
        guard let windows = AXAttributeHelpers.attribute(appElement, name: kAXWindowsAttribute as String) as? [AXUIElement] else {
            return false
        }

        return windows.contains(where: { window in
            guard let title = AXAttributeHelpers.string(window, name: kAXTitleAttribute as String) else {
                return false
            }
            return title.localizedCaseInsensitiveContains("Human Benchmark") &&
                title.localizedCaseInsensitiveContains("Aim Trainer")
        })
    }

    public func detectTargetCandidate() -> AimTargetCandidate? {
        guard let safari = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.Safari" }) else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(safari.processIdentifier)
        guard let webArea = self.primaryWebArea(in: appElement),
              let webAreaFrame = AXAttributeHelpers.frame(webArea) else {
            return nil
        }

        let anchors = self.detectAnchors(in: webArea)

        var descriptors: [TargetCandidateDescriptor] = []
        self.collectCandidates(in: webArea, descriptors: &descriptors)

        guard let best = TargetCandidateScorer.selectBest(from: descriptors, webAreaFrame: webAreaFrame, anchors: anchors),
              let classToken = best.classTokens.first(where: { $0.hasPrefix("css-") && !$0.contains("betiu") }) ??
                  best.classTokens.first(where: { $0.hasPrefix("css-") }) ??
                  best.classTokens.first
        else {
            return nil
        }

        return AimTargetCandidate(frame: best.frame, classToken: classToken)
    }

    private func primaryWebArea(in appElement: AXUIElement) -> AXUIElement? {
        var bestWebArea: AXUIElement?
        var bestArea: CGFloat = 0

        func walk(_ element: AXUIElement, depth: Int = 0) {
            if depth > 24 { return }

            if AXAttributeHelpers.string(element, name: kAXRoleAttribute as String) == "AXWebArea",
               let frame = AXAttributeHelpers.frame(element)
            {
                let area = frame.width * frame.height
                if area > bestArea {
                    bestArea = area
                    bestWebArea = element
                }
            }

            for child in AXAttributeHelpers.children(element) {
                walk(child, depth: depth + 1)
            }
        }

        walk(appElement)
        return bestWebArea
    }

    private func detectAnchors(in root: AXUIElement) -> TargetSelectionAnchors {
        var remainingFrame: CGRect?
        var startPromptFrame: CGRect?

        func walk(_ element: AXUIElement, depth: Int = 0) {
            if depth > 24 { return }

            if AXAttributeHelpers.string(element, name: kAXRoleAttribute as String) == kAXStaticTextRole as String,
               let value = AXAttributeHelpers.string(element, name: kAXValueAttribute as String),
               let frame = AXAttributeHelpers.frame(element) {
                if value == "Remaining" {
                    remainingFrame = frame
                } else if value.localizedCaseInsensitiveContains("Click the target above to begin") {
                    startPromptFrame = frame
                }
            }

            for child in AXAttributeHelpers.children(element) {
                walk(child, depth: depth + 1)
            }
        }

        walk(root)
        return TargetSelectionAnchors(
            remainingLabelFrame: remainingFrame,
            startPromptFrame: startPromptFrame)
    }

    private func collectCandidates(in root: AXUIElement, descriptors: inout [TargetCandidateDescriptor], depth: Int = 0) {
        if depth > 24 { return }

        if AXAttributeHelpers.string(root, name: kAXRoleAttribute as String) == kAXGroupRole as String,
           let frame = AXAttributeHelpers.frame(root)
        {
            let classTokens = AXAttributeHelpers.classTokens(root)
            if !classTokens.isEmpty,
               frame.width >= 40,
               frame.width <= 220,
               frame.height >= 40,
               frame.height <= 220
            {
                descriptors.append(TargetCandidateDescriptor(frame: frame, classTokens: classTokens))
            }
        }

        for child in AXAttributeHelpers.children(root) {
            self.collectCandidates(in: child, descriptors: &descriptors, depth: depth + 1)
        }
    }
}
