import Testing
@testable import AimClickerCore

@Suite("Axorc Output Parser")
struct AxorcOutputParserTests {
    @Test("extracts first ref from selector output")
    func extractsFirstRef() {
        let output = """
        stats app=com.apple.Safari selector=\"AXWebArea AXGroup\" elapsed_ms=120.45 traversed=612 matched=2 shown=2
        [1] AXGroup ref=abc123def name=\"Group\"
        [2] AXGroup ref=01234abcf name=\"Group\"
        """

        let ref = AxorcOutputParser.parseFirstRef(from: output)
        #expect(ref == "abc123def")
    }

    @Test("returns nil when ref is missing")
    func returnsNilWithoutRef() {
        let output = "stats app=com.apple.Safari selector=\"x\" elapsed_ms=10.0 traversed=1 matched=0 shown=0\nNo matching elements."
        let ref = AxorcOutputParser.parseFirstRef(from: output)
        #expect(ref == nil)
    }
}
