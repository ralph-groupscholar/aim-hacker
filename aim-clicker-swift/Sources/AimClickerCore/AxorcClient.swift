import Foundation

public protocol AxorcCommanding: AnyObject {
    func queryTargetRef(classToken: String) -> String?
    func click(ref: String) -> Bool
}

public enum AxorcOutputParser {
    public static func parseFirstRef(from output: String) -> String? {
        let pattern = #"ref=([0-9a-f]{9})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let ns = output as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: output, options: [], range: range),
              match.numberOfRanges > 1
        else {
            return nil
        }

        return ns.substring(with: match.range(at: 1))
    }
}

public enum AxorcSelectorBuilder {
    public static func selector(forClassToken classToken: String) -> String {
        let escaped = classToken.replacingOccurrences(of: "\"", with: "\\\"")
        return "AXWebArea AXGroup[AXDOMClassList*=\"\(escaped)\"], AXWebArea AXButton[AXDOMClassList*=\"\(escaped)\"]"
    }
}

public final class AxorcClient: AxorcCommanding {
    private let executablePath: String

    public init(executablePath: String = "/Users/ralph/bin/axorc") {
        self.executablePath = executablePath
    }

    public func queryTargetRef(classToken: String) -> String? {
        let selector = AxorcSelectorBuilder.selector(forClassToken: classToken)

        let result = self.run([
            "--app", "com.apple.Safari",
            "--selector", selector,
            "--limit", "1",
            "--cache-session",
            "--no-color",
        ])

        return AxorcOutputParser.parseFirstRef(from: result.output)
    }

    public func click(ref: String) -> Bool {
        let result = self.run(["--actions", "send click to \(ref);"])
        if result.exitCode == 0, result.output.contains("ok [1] send click to \(ref)") {
            return true
        }
        return false
    }

    private func run(_ arguments: [String]) -> (output: String, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: self.executablePath)
        process.arguments = arguments

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            return ("", -1)
        }

        process.waitUntilExit()

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: outData, encoding: .utf8) ?? ""
        let stderr = String(data: errData, encoding: .utf8) ?? ""

        return (stdout + (stderr.isEmpty ? "" : "\n" + stderr), process.terminationStatus)
    }
}
