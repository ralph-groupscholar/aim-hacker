import ApplicationServices
import Foundation

public enum MouseClicker {
    public static func clickCenter(of axRect: CGRect) {
        let point = CGPoint(x: axRect.midX, y: axRect.midY)
        self.click(at: point)
    }

    public static func click(at point: CGPoint) {
        guard let move = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left),
            let down = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseDown,
                mouseCursorPosition: point,
                mouseButton: .left),
            let up = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseUp,
                mouseCursorPosition: point,
                mouseButton: .left)
        else {
            return
        }

        move.post(tap: .cghidEventTap)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
