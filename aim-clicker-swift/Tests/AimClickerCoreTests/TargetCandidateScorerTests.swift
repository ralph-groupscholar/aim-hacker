import Foundation
import Testing
@testable import AimClickerCore

@Suite("Target Candidate Scorer")
struct TargetCandidateScorerTests {
    @Test("prefers tighter target candidate over outer wrapper and thin lines")
    func prefersLikelyTarget() {
        let webFrame = CGRect(x: 217, y: 298, width: 1265, height: 1507)
        let candidates = [
            TargetCandidateDescriptor(frame: CGRect(x: 848, y: 566, width: 3, height: 100), classTokens: ["css-betiu1"]),
            TargetCandidateDescriptor(frame: CGRect(x: 799, y: 615, width: 101, height: 2), classTokens: ["css-betiu1"]),
            TargetCandidateDescriptor(frame: CGRect(x: 799, y: 566, width: 101, height: 100), classTokens: ["css-10u1hxc"]),
            TargetCandidateDescriptor(frame: CGRect(x: 816, y: 582, width: 67, height: 68), classTokens: ["css-12qoa4j"]),
            TargetCandidateDescriptor(frame: CGRect(x: 833, y: 599, width: 33, height: 34), classTokens: ["css-12qoa4j"]),
        ]

        let selected = TargetCandidateScorer.selectBest(from: candidates, webAreaFrame: webFrame)
        #expect(selected?.classTokens.first == "css-12qoa4j")
        #expect(selected?.frame.width == 67)
    }

    @Test("uses start prompt anchor to ignore lower-page candidates")
    func usesStartPromptAnchor() {
        let webFrame = CGRect(x: 217, y: 298, width: 1265, height: 1507)
        let candidates = [
            TargetCandidateDescriptor(frame: CGRect(x: 874, y: 748, width: 68, height: 68), classTokens: ["css-12qoa4j"]),
            TargetCandidateDescriptor(frame: CGRect(x: 1185, y: 1212, width: 68, height: 68), classTokens: ["css-foo"]),
        ]
        let anchors = TargetSelectionAnchors(
            remainingLabelFrame: nil,
            startPromptFrame: CGRect(x: 725, y: 820, width: 249, height: 21))

        let selected = TargetCandidateScorer.selectBest(from: candidates, webAreaFrame: webFrame, anchors: anchors)
        #expect(selected?.frame.origin.y == 748)
    }
}
