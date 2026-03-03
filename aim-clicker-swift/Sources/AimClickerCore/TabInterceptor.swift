import AppKit
import Foundation

@MainActor
public final class TabInterceptor {
    public typealias Handler = () -> Bool

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let handler: Handler

    private static var retainedSelf: TabInterceptor?

    public init(handler: @escaping Handler) {
        self.handler = handler
    }

    public func start() {
        guard self.eventTap == nil else { return }

        let callback: CGEventTapCallBack = { _, type, event, _ in
            guard type == .keyDown else {
                return Unmanaged.passUnretained(event)
            }

            let keycode = event.getIntegerValueField(.keyboardEventKeycode)
            guard keycode == 48 else {
                return Unmanaged.passUnretained(event)
            }

            guard let instance = TabInterceptor.retainedSelf else {
                return Unmanaged.passUnretained(event)
            }

            let shouldIntercept = instance.handler()
            if shouldIntercept {
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        let mask = (1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: nil)
        else {
            return
        }

        TabInterceptor.retainedSelf = self
        self.eventTap = tap

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            return
        }

        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    public func stop() {
        if let eventTap = self.eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let source = self.runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }

        self.runLoopSource = nil
        self.eventTap = nil
        TabInterceptor.retainedSelf = nil
    }
}
