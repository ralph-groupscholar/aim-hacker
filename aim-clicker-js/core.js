(function initAimClickerCore(globalScope) {
  "use strict";

  const DEFAULT_SETTINGS = Object.freeze({
    autoClickEnabled: false,
    autoClickMinimumIntervalMs: 60,
    autoClickMaxTargets: 31,
    tabInterceptEnabled: true,
    showOverlay: true
  });

  function pickClassToken(tokens) {
    const list = Array.isArray(tokens) ? tokens : [];

    const cssPreferred = list.find((token) => token.startsWith("css-") && !token.includes("betiu"));
    if (cssPreferred) {
      return cssPreferred;
    }

    const cssFallback = list.find((token) => token.startsWith("css-"));
    if (cssFallback) {
      return cssFallback;
    }

    return list[0] || "";
  }

  function framesAreNearlyEqual(lhs, rhs) {
    if (!lhs || !rhs) {
      return false;
    }

    return (
      Math.abs(lhs.left - rhs.left) < 1 &&
      Math.abs(lhs.top - rhs.top) < 1 &&
      Math.abs(lhs.width - rhs.width) < 1 &&
      Math.abs(lhs.height - rhs.height) < 1
    );
  }

  function scoreCandidate(candidate, webAreaFrame, tokenFrequency) {
    const rect = candidate.frame;
    const side = Math.min(rect.width, rect.height);
    const idealSide = 68;
    const tokenFreq = tokenFrequency || {};

    const sizePenalty = Math.abs(side - idealSide) * 4;
    const largePenalty = side > 90 ? (side - 90) * 8 : 0;
    const aspectPenalty = Math.abs(rect.width - rect.height) * 8;
    const lowerBandPenalty = rect.top + rect.height / 2 > webAreaFrame.top + webAreaFrame.height / 2 ? 120 : 0;
    const tokenPenalty = candidate.classTokens.some((token) => token.includes("betiu")) ? 300 : 0;
    const frequencyReward = candidate.classTokens
      .filter((token) => token.startsWith("css-"))
      .reduce((sum, token) => sum + (tokenFreq[token] || 0) * 12, 0);

    return frequencyReward - sizePenalty - largePenalty - aspectPenalty - lowerBandPenalty - tokenPenalty;
  }

  function normalizeSettings(baseSettings, partialSettings) {
    const next = {
      ...(baseSettings || DEFAULT_SETTINGS),
      ...(partialSettings || {})
    };

    next.autoClickEnabled = Boolean(next.autoClickEnabled);
    next.tabInterceptEnabled = Boolean(next.tabInterceptEnabled);
    next.showOverlay = Boolean(next.showOverlay);
    next.autoClickMinimumIntervalMs = Math.max(0, Number(next.autoClickMinimumIntervalMs) || 0);
    next.autoClickMaxTargets = Math.max(1, Number(next.autoClickMaxTargets) || 1);

    return next;
  }

  function shouldAutoClickTarget(options) {
    const minimumIntervalMs = Math.max(0, Number(options.minimumIntervalMs) || 0);
    const nowMs = Number(options.nowMs) || 0;
    const lastClickAtMs = Number(options.lastClickAtMs) || 0;

    if (nowMs - lastClickAtMs < minimumIntervalMs) {
      return false;
    }

    if (options.lastClickedFrame && framesAreNearlyEqual(options.lastClickedFrame, options.targetFrame)) {
      return false;
    }

    return true;
  }

  const api = {
    DEFAULT_SETTINGS,
    pickClassToken,
    framesAreNearlyEqual,
    scoreCandidate,
    normalizeSettings,
    shouldAutoClickTarget
  };

  if (typeof module !== "undefined" && module.exports) {
    module.exports = api;
  }

  globalScope.AimClickerCore = api;
})(typeof globalThis !== "undefined" ? globalThis : this);
