import Testing
@testable import AimClickerCore

@Suite("Selector Builder")
struct SelectorBuilderTests {
    @Test("builds selector with class token")
    func buildsSelector() {
        let selector = AxorcSelectorBuilder.selector(forClassToken: "css-10u1hxc")

        #expect(selector.contains("AXWebArea AXGroup"))
        #expect(selector.contains("AXDOMClassList*=\"css-10u1hxc\""))
        #expect(selector.contains(", AXWebArea AXButton"))
    }
}
