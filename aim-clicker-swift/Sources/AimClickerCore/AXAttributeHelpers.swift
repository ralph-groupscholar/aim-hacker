import ApplicationServices
import Foundation

@MainActor
public enum AXAttributeHelpers {
    public static func attribute(_ element: AXUIElement, name: String) -> AnyObject? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        guard status == .success, let value else { return nil }
        return value
    }

    public static func string(_ element: AXUIElement, name: String) -> String? {
        self.attribute(element, name: name) as? String
    }

    public static func children(_ element: AXUIElement) -> [AXUIElement] {
        (self.attribute(element, name: kAXChildrenAttribute as String) as? [AXUIElement]) ?? []
    }

    public static func classTokens(_ element: AXUIElement) -> [String] {
        guard let raw = self.attribute(element, name: "AXDOMClassList") else {
            return []
        }

        if let tokens = raw as? [String] {
            return tokens.filter { !$0.isEmpty }
        }

        let described = String(describing: raw)
        if described.isEmpty {
            return []
        }

        return described
            .split(whereSeparator: { $0 == " " || $0 == "," || $0 == "\n" || $0 == "\t" })
            .map(String.init)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "[]\"'")) }
            .filter { !$0.isEmpty }
    }

    public static func frame(_ element: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?

        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let positionRef,
              let sizeRef,
              CFGetTypeID(positionRef) == AXValueGetTypeID(),
              CFGetTypeID(sizeRef) == AXValueGetTypeID() else {
            return nil
        }

        let axPosition = unsafeDowncast(positionRef, to: AXValue.self)
        let axSize = unsafeDowncast(sizeRef, to: AXValue.self)

        guard AXValueGetType(axPosition) == .cgPoint,
              AXValueGetType(axSize) == .cgSize else {
            return nil
        }

        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(axPosition, .cgPoint, &point)
        AXValueGetValue(axSize, .cgSize, &size)

        return CGRect(origin: point, size: size)
    }
}
