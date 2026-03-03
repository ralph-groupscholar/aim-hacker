import AppKit
import Foundation

public enum AXCoordinateConverter {
    public static func axToCocoa(_ rect: CGRect, maxY: CGFloat) -> CGRect {
        CGRect(x: rect.origin.x, y: maxY - rect.origin.y - rect.height, width: rect.width, height: rect.height)
    }
}

final class OverlayView: NSView {
    var highlightColor: NSColor = NSColor.systemRed.withAlphaComponent(0.28)

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.clear.setFill()
        dirtyRect.fill()

        let insetRect = self.bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: insetRect, xRadius: 16, yRadius: 16)

        self.highlightColor.setFill()
        path.fill()

        NSColor.systemRed.withAlphaComponent(0.8).setStroke()
        path.lineWidth = 2
        path.stroke()
    }
}

@MainActor
public final class OverlayWindowController {
    private let window: NSPanel
    private let overlayView: OverlayView

    public init() {
        self.window = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)

        self.overlayView = OverlayView(frame: .zero)

        self.window.contentView = self.overlayView
        self.window.isOpaque = false
        self.window.backgroundColor = .clear
        self.window.level = .screenSaver
        self.window.hasShadow = false
        self.window.ignoresMouseEvents = true
        self.window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.window.orderOut(nil)
    }

    public func show(axRect: CGRect) {
        let maxY = NSScreen.screens.map(\.frame.maxY).max() ?? 0
        let cocoaRect = AXCoordinateConverter.axToCocoa(axRect, maxY: maxY)

        self.window.setFrame(cocoaRect, display: true)
        self.overlayView.frame = CGRect(origin: .zero, size: cocoaRect.size)
        self.overlayView.needsDisplay = true

        if !self.window.isVisible {
            self.window.orderFrontRegardless()
        }
    }

    public func hide() {
        self.window.orderOut(nil)
    }
}
