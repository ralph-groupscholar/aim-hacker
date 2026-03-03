import Foundation

public struct TargetCandidateDescriptor: Equatable {
    public let frame: CGRect
    public let classTokens: [String]

    public init(frame: CGRect, classTokens: [String]) {
        self.frame = frame
        self.classTokens = classTokens
    }
}

public struct TargetSelectionAnchors: Equatable {
    public let remainingLabelFrame: CGRect?
    public let startPromptFrame: CGRect?

    public init(remainingLabelFrame: CGRect? = nil, startPromptFrame: CGRect? = nil) {
        self.remainingLabelFrame = remainingLabelFrame
        self.startPromptFrame = startPromptFrame
    }
}

public enum TargetCandidateScorer {
    public static func selectBest(
        from candidates: [TargetCandidateDescriptor],
        webAreaFrame: CGRect,
        anchors: TargetSelectionAnchors = TargetSelectionAnchors()
    ) -> TargetCandidateDescriptor? {
        guard !candidates.isEmpty else {
            return nil
        }

        var filtered = candidates.filter { candidate in
            let frame = candidate.frame
            guard frame.width >= 30,
                  frame.height >= 30,
                  frame.width <= 170,
                  frame.height <= 170 else {
                return false
            }
            return candidate.classTokens.contains(where: { $0.hasPrefix("css-") })
        }

        if let startPrompt = anchors.startPromptFrame {
            let abovePrompt = filtered.filter { candidate in
                candidate.frame.maxY < startPrompt.minY - 8
            }
            if !abovePrompt.isEmpty {
                filtered = abovePrompt
            }
        } else if let remainingLabel = anchors.remainingLabelFrame {
            let belowRemaining = filtered.filter { candidate in
                candidate.frame.minY > remainingLabel.maxY + 12 &&
                    candidate.frame.maxY < webAreaFrame.maxY - 20
            }
            if !belowRemaining.isEmpty {
                filtered = belowRemaining
            }
        }

        guard !filtered.isEmpty else {
            return nil
        }

        var tokenFrequency: [String: Int] = [:]
        for candidate in filtered {
            for token in candidate.classTokens where token.hasPrefix("css-") {
                tokenFrequency[token, default: 0] += 1
            }
        }

        return filtered.max(by: { lhs, rhs in
            self.score(lhs, webAreaFrame: webAreaFrame, tokenFrequency: tokenFrequency) <
                self.score(rhs, webAreaFrame: webAreaFrame, tokenFrequency: tokenFrequency)
        })
    }

    static func score(
        _ candidate: TargetCandidateDescriptor,
        webAreaFrame: CGRect,
        tokenFrequency: [String: Int]
    ) -> CGFloat {
        let rect = candidate.frame
        let side = min(rect.width, rect.height)
        let idealSide: CGFloat = 68

        let sizePenalty = abs(side - idealSide) * 4
        let largePenalty: CGFloat = side > 90 ? (side - 90) * 8 : 0
        let aspectPenalty = abs(rect.width - rect.height) * 8
        let lowerBandPenalty: CGFloat = rect.midY > webAreaFrame.midY ? 120 : 0

        let tokenPenalty: CGFloat = candidate.classTokens.contains(where: { $0.contains("betiu") }) ? 300 : 0
        let frequencyReward: CGFloat = candidate.classTokens
            .filter { $0.hasPrefix("css-") }
            .reduce(0) { partial, token in
                partial + CGFloat(tokenFrequency[token, default: 0]) * 12
            }

        return frequencyReward - sizePenalty - largePenalty - aspectPenalty - lowerBandPenalty - tokenPenalty
    }
}
