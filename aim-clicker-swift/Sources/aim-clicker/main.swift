import AppKit
import AimClickerCore
import Foundation

struct LaunchOptions {
    let autoClickEnabled: Bool
}

enum LaunchOptionsParser {
    static func parse(arguments: [String]) -> LaunchOptions? {
        let flags = Set(arguments.dropFirst())

        if flags.contains("--help") || flags.contains("-h") {
            Self.printUsage()
            return nil
        }

        let allowed = Set(["--auto-click"])
        let unknown = flags.subtracting(allowed)
        if !unknown.isEmpty {
            fputs("Unknown argument(s): \(unknown.sorted().joined(separator: ", "))\n", stderr)
            Self.printUsage()
            return nil
        }

        return LaunchOptions(autoClickEnabled: flags.contains("--auto-click"))
    }

    private static func printUsage() {
        print("Usage: aim-clicker [--auto-click]")
        print("  --auto-click   Automatically click detected targets.")
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let options: LaunchOptions
    private var controller: AimClickerController?

    init(options: LaunchOptions) {
        self.options = options
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        self.controller = AimClickerController(
            options: AimClickerOptions(autoClickEnabled: self.options.autoClickEnabled))
        self.controller?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        self.controller?.stop()
    }
}

guard let options = LaunchOptionsParser.parse(arguments: CommandLine.arguments) else {
    Foundation.exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate(options: options)
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
