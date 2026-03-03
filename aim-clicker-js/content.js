(() => {
  "use strict";

  const Core = globalThis.AimClickerCore;
  if (!Core) {
    return;
  }

  const SETTINGS_KEY = "aimClickerSettings";
  const HEURISTIC_SCAN_INTERVAL_MS = 120;
  const START_PROMPT_SCAN_INTERVAL_MS = 150;
  const LOOP_INTERVAL_MS = 1000 / 60;

  const DEFAULT_SETTINGS = Core.DEFAULT_SETTINGS;

  const state = {
    settings: { ...DEFAULT_SETTINGS },
    currentTarget: null,
    lastClickAtMs: 0,
    lastClickedFrame: null,
    autoClicksThisRun: 0,
    totalClicks: 0,
    hasTarget: false,
    heuristicCacheAtMs: 0,
    heuristicCacheCandidate: null,
    promptCacheAtMs: 0,
    promptVisibleCache: false,
    immediatePassScheduled: false,
    lastLoopAtMs: 0,
    overlayEl: null,
    observer: null
  };

  function isAimContextActive() {
    return location.hostname === "humanbenchmark.com" && location.pathname.startsWith("/tests/aim");
  }

  function toPlainRect(rect) {
    return {
      left: rect.left,
      top: rect.top,
      right: rect.right,
      bottom: rect.bottom,
      width: rect.width,
      height: rect.height,
      x: rect.x,
      y: rect.y
    };
  }

  function rectIsVisible(rect) {
    if (!rect || rect.width <= 0 || rect.height <= 0) {
      return false;
    }

    return rect.bottom > 0 && rect.right > 0 && rect.left < window.innerWidth && rect.top < window.innerHeight;
  }

  function elementIsLikelyVisible(element) {
    if (!(element instanceof Element)) {
      return false;
    }

    const style = window.getComputedStyle(element);
    if (style.display === "none" || style.visibility === "hidden" || style.pointerEvents === "none") {
      return false;
    }

    const rect = element.getBoundingClientRect();
    return rectIsVisible(rect);
  }

  function classTokensFromElement(element) {
    if (!(element instanceof Element)) {
      return [];
    }

    if (element.classList && element.classList.length > 0) {
      return Array.from(element.classList);
    }

    const rawClassName = element.getAttribute("class") || "";
    return rawClassName.split(/\s+/).filter(Boolean);
  }

  function rectFromCenter(centerX, centerY, size) {
    const half = size / 2;
    return {
      left: centerX - half,
      top: centerY - half,
      right: centerX + half,
      bottom: centerY + half,
      width: size,
      height: size,
      x: centerX - half,
      y: centerY - half
    };
  }

  function pointIsVisible(x, y) {
    return x >= 0 && y >= 0 && x <= window.innerWidth && y <= window.innerHeight;
  }

  function inferTargetSize(target) {
    const nodes = [target, ...target.querySelectorAll("*")];
    let best = 0;

    for (const node of nodes) {
      if (!(node instanceof Element)) {
        continue;
      }

      const rect = node.getBoundingClientRect();
      const side = Math.max(rect.width, rect.height);
      if (Number.isFinite(side) && side > best && side >= 20 && side <= 260) {
        best = side;
      }

      const style = window.getComputedStyle(node);
      const width = Number.parseFloat(style.width || "");
      const height = Number.parseFloat(style.height || "");
      const styledSide = Math.max(width || 0, height || 0);
      if (Number.isFinite(styledSide) && styledSide > best && styledSide >= 20 && styledSide <= 260) {
        best = styledSide;
      }
    }

    if (best <= 0) {
      return 100;
    }

    return Math.max(40, Math.min(220, best));
  }

  function deriveFrameFromDescendants(target) {
    const nodes = [target, ...target.querySelectorAll("*")];
    let bestRect = null;
    let bestArea = 0;

    for (const node of nodes) {
      if (!(node instanceof Element)) {
        continue;
      }

      const rect = node.getBoundingClientRect();
      if (!rectIsVisible(rect) || rect.width < 20 || rect.height < 20 || rect.width > 260 || rect.height > 260) {
        continue;
      }

      const area = rect.width * rect.height;
      if (area > bestArea) {
        bestArea = area;
        bestRect = rect;
      }
    }

    return bestRect ? toPlainRect(bestRect) : null;
  }

  function deriveFrameFromAnchorPoint(target) {
    const anchorRect = target.getBoundingClientRect();
    const centerX = anchorRect.left + anchorRect.width / 2;
    const centerY = anchorRect.top + anchorRect.height / 2;

    if (!Number.isFinite(centerX) || !Number.isFinite(centerY) || !pointIsVisible(centerX, centerY)) {
      return null;
    }

    const size = inferTargetSize(target);
    const frame = rectFromCenter(centerX, centerY, size);
    return rectIsVisible(frame) ? frame : null;
  }

  function inferAimTargetFrame(target) {
    return deriveFrameFromDescendants(target) || deriveFrameFromAnchorPoint(target);
  }

  function detectDirectTarget() {
    const targets = document.querySelectorAll("[data-aim-target]");
    for (const target of targets) {
      if (!(target instanceof Element)) {
        continue;
      }

      const frame = inferAimTargetFrame(target);
      if (!frame) {
        continue;
      }

      const tokens = classTokensFromElement(target);
      return {
        element: target,
        frame,
        classTokens: tokens,
        classToken: Core.pickClassToken(tokens)
      };
    }

    return null;
  }

  function findTextElementExact(text) {
    if (!document.body) {
      return null;
    }

    const result = document.evaluate(
      `//*[normalize-space(text())="${text}"]`,
      document.body,
      null,
      XPathResult.FIRST_ORDERED_NODE_TYPE,
      null
    );
    return result.singleNodeValue instanceof Element ? result.singleNodeValue : null;
  }

  function findTextElementContains(text) {
    if (!document.body) {
      return null;
    }

    const result = document.evaluate(
      `//*[contains(normalize-space(text()), "${text}")]`,
      document.body,
      null,
      XPathResult.FIRST_ORDERED_NODE_TYPE,
      null
    );
    return result.singleNodeValue instanceof Element ? result.singleNodeValue : null;
  }

  function detectAnchors() {
    const remainingEl = findTextElementExact("Remaining");
    const startPromptEl = findTextElementContains("Click the target above to begin");

    return {
      remainingFrame: remainingEl && elementIsLikelyVisible(remainingEl) ? toPlainRect(remainingEl.getBoundingClientRect()) : null,
      startPromptFrame: startPromptEl && elementIsLikelyVisible(startPromptEl) ? toPlainRect(startPromptEl.getBoundingClientRect()) : null
    };
  }

  function detectHeuristicTarget(nowMs) {
    if (nowMs - state.heuristicCacheAtMs < HEURISTIC_SCAN_INTERVAL_MS) {
      return state.heuristicCacheCandidate;
    }

    state.heuristicCacheAtMs = nowMs;

    const webArea = document.querySelector(".desktop-only") || document.body;
    if (!(webArea instanceof Element)) {
      state.heuristicCacheCandidate = null;
      return null;
    }

    const webAreaFrame = toPlainRect(webArea.getBoundingClientRect());
    const anchors = detectAnchors();
    const rawCandidates = [];

    const elements = webArea.querySelectorAll('div[class*="css-"], button[class*="css-"]');
    for (const element of elements) {
      if (!(element instanceof Element)) {
        continue;
      }

      const frame = element.getBoundingClientRect();
      if (
        !rectIsVisible(frame) ||
        frame.width < 40 ||
        frame.width > 220 ||
        frame.height < 40 ||
        frame.height > 220
      ) {
        continue;
      }

      const classTokens = classTokensFromElement(element);
      if (!classTokens.some((token) => token.startsWith("css-"))) {
        continue;
      }

      rawCandidates.push({
        element,
        frame: toPlainRect(frame),
        classTokens
      });
    }

    let filtered = rawCandidates.filter((candidate) => {
      const frame = candidate.frame;
      return frame.width >= 30 && frame.width <= 170 && frame.height >= 30 && frame.height <= 170;
    });

    if (anchors.startPromptFrame) {
      const abovePrompt = filtered.filter(
        (candidate) => candidate.frame.bottom < anchors.startPromptFrame.top - 8
      );
      if (abovePrompt.length > 0) {
        filtered = abovePrompt;
      }
    } else if (anchors.remainingFrame) {
      const belowRemaining = filtered.filter(
        (candidate) =>
          candidate.frame.top > anchors.remainingFrame.bottom + 12 &&
          candidate.frame.bottom < webAreaFrame.bottom - 20
      );
      if (belowRemaining.length > 0) {
        filtered = belowRemaining;
      }
    }

    if (filtered.length === 0) {
      state.heuristicCacheCandidate = null;
      return null;
    }

    const tokenFrequency = {};
    for (const candidate of filtered) {
      for (const token of candidate.classTokens) {
        if (token.startsWith("css-")) {
          tokenFrequency[token] = (tokenFrequency[token] || 0) + 1;
        }
      }
    }

    let bestCandidate = null;
    let bestScore = -Infinity;

    for (const candidate of filtered) {
      const score = Core.scoreCandidate(candidate, webAreaFrame, tokenFrequency);
      if (score > bestScore) {
        bestScore = score;
        bestCandidate = candidate;
      }
    }

    if (!bestCandidate) {
      state.heuristicCacheCandidate = null;
      return null;
    }

    const pickedToken = Core.pickClassToken(bestCandidate.classTokens);
    state.heuristicCacheCandidate = {
      element: bestCandidate.element,
      frame: bestCandidate.frame,
      classTokens: bestCandidate.classTokens,
      classToken: pickedToken
    };

    return state.heuristicCacheCandidate;
  }

  function detectTarget(nowMs) {
    const direct = detectDirectTarget();
    if (direct) {
      return direct;
    }

    return detectHeuristicTarget(nowMs);
  }

  function ensureOverlay() {
    if (state.overlayEl) {
      return state.overlayEl;
    }

    const overlay = document.createElement("div");
    overlay.id = "aim-clicker-overlay";
    overlay.style.position = "fixed";
    overlay.style.zIndex = "2147483647";
    overlay.style.pointerEvents = "none";
    overlay.style.border = "2px solid rgba(255, 52, 52, 0.95)";
    overlay.style.background = "rgba(255, 52, 52, 0.18)";
    overlay.style.borderRadius = "16px";
    overlay.style.display = "none";
    overlay.style.boxSizing = "border-box";
    document.documentElement.appendChild(overlay);

    state.overlayEl = overlay;
    return overlay;
  }

  function hideOverlay() {
    if (state.overlayEl) {
      state.overlayEl.style.display = "none";
    }
  }

  function updateOverlay(target) {
    if (!state.settings.showOverlay || !target) {
      hideOverlay();
      return;
    }

    const overlay = ensureOverlay();
    overlay.style.left = `${target.frame.left}px`;
    overlay.style.top = `${target.frame.top}px`;
    overlay.style.width = `${target.frame.width}px`;
    overlay.style.height = `${target.frame.height}px`;
    overlay.style.display = "block";
  }

  function updateCurrentTarget(target) {
    state.currentTarget = target;
    state.hasTarget = Boolean(target);
    updateOverlay(target);
  }

  function dispatchMouseDownAt(target) {
    if (!target || !target.frame) {
      return false;
    }

    const x = target.frame.left + target.frame.width / 2;
    const y = target.frame.top + target.frame.height / 2;
    const dispatchTarget = document.elementFromPoint(x, y) || target.element;

    if (!(dispatchTarget instanceof Element)) {
      return false;
    }

    const eventInit = {
      bubbles: true,
      cancelable: true,
      composed: true,
      button: 0,
      buttons: 1,
      clientX: x,
      clientY: y,
      screenX: window.screenX + x,
      screenY: window.screenY + y,
      view: window
    };

    dispatchTarget.dispatchEvent(new MouseEvent("mousedown", eventInit));
    return true;
  }

  function registerClick(frame, isAutoClick) {
    state.lastClickAtMs = performance.now();
    state.lastClickedFrame = frame;
    state.totalClicks += 1;

    if (isAutoClick) {
      state.autoClicksThisRun += 1;
    }
  }

  function clickCurrentTarget(options = { isAutoClick: false }) {
    const nowMs = performance.now();
    const target = state.currentTarget || detectTarget(nowMs);
    if (!target) {
      return false;
    }

    if (!dispatchMouseDownAt(target)) {
      return false;
    }

    registerClick(target.frame, options.isAutoClick);
    updateCurrentTarget(null);
    return true;
  }

  function shouldAutoClickTarget(target, nowMs) {
    return Core.shouldAutoClickTarget({
      minimumIntervalMs: state.settings.autoClickMinimumIntervalMs,
      nowMs,
      lastClickAtMs: state.lastClickAtMs,
      lastClickedFrame: state.lastClickedFrame,
      targetFrame: target.frame
    });
  }

  function setAutoClickEnabled(enabled) {
    state.settings.autoClickEnabled = Boolean(enabled);
    void persistSettings();
  }

  function maybeDisableAutoClickOnLimit() {
    const maxTargets = Math.max(1, Number(state.settings.autoClickMaxTargets) || 1);
    if (state.autoClicksThisRun >= maxTargets) {
      setAutoClickEnabled(false);
    }
  }

  function maybeAutoClick(nowMs) {
    if (!state.settings.autoClickEnabled) {
      return;
    }

    const maxTargets = Math.max(1, Number(state.settings.autoClickMaxTargets) || 1);
    if (state.autoClicksThisRun >= maxTargets) {
      maybeDisableAutoClickOnLimit();
      return;
    }

    const target = state.currentTarget || detectTarget(nowMs);
    if (!target || !shouldAutoClickTarget(target, nowMs)) {
      return;
    }

    if (clickCurrentTarget({ isAutoClick: true })) {
      maybeDisableAutoClickOnLimit();
    }
  }

  function resetRunState() {
    state.autoClicksThisRun = 0;
    state.lastClickAtMs = 0;
    state.lastClickedFrame = null;
    state.heuristicCacheCandidate = null;
    state.heuristicCacheAtMs = 0;
  }

  function isStartPromptVisible(nowMs) {
    if (nowMs - state.promptCacheAtMs < START_PROMPT_SCAN_INTERVAL_MS) {
      return state.promptVisibleCache;
    }

    state.promptCacheAtMs = nowMs;
    const promptEl = findTextElementContains("Click the target above to begin");
    state.promptVisibleCache = Boolean(promptEl && elementIsLikelyVisible(promptEl));
    return state.promptVisibleCache;
  }

  function runFastPass(nowMs) {
    if (!isAimContextActive() || document.visibilityState !== "visible") {
      updateCurrentTarget(null);
      hideOverlay();
      resetRunState();
      return;
    }

    const target = detectTarget(nowMs);
    updateCurrentTarget(target);
    maybeAutoClick(nowMs);

    if (!target && isStartPromptVisible(nowMs)) {
      resetRunState();
    }
  }

  function scheduleImmediatePass() {
    if (state.immediatePassScheduled) {
      return;
    }

    state.immediatePassScheduled = true;
    queueMicrotask(() => {
      state.immediatePassScheduled = false;
      runFastPass(performance.now());
    });
  }

  function startLoop() {
    const tick = (nowMs) => {
      if (nowMs - state.lastLoopAtMs >= LOOP_INTERVAL_MS) {
        state.lastLoopAtMs = nowMs;
        runFastPass(nowMs);
      }
      window.requestAnimationFrame(tick);
    };

    window.requestAnimationFrame(tick);
  }

  function isTypingContext(target) {
    if (!(target instanceof Element)) {
      return false;
    }

    if (target.closest("input, textarea, [contenteditable='true'], [role='textbox']")) {
      return true;
    }

    const active = document.activeElement;
    if (active instanceof Element && active.closest("input, textarea, [contenteditable='true'], [role='textbox']")) {
      return true;
    }

    return false;
  }

  function onKeyDown(event) {
    if (!state.settings.tabInterceptEnabled) {
      return;
    }

    if (event.key !== "Tab" || event.defaultPrevented || event.ctrlKey || event.altKey || event.metaKey) {
      return;
    }

    if (!isAimContextActive() || document.visibilityState !== "visible") {
      return;
    }

    if (isTypingContext(event.target)) {
      return;
    }

    if (clickCurrentTarget({ isAutoClick: false })) {
      event.preventDefault();
      event.stopImmediatePropagation();
      event.stopPropagation();
    }
  }

  function normalizeSettings(partial) {
    return Core.normalizeSettings(state.settings, partial);
  }

  async function loadSettings() {
    try {
      const result = await chrome.storage.local.get(SETTINGS_KEY);
      const stored = result[SETTINGS_KEY];
      state.settings = normalizeSettings(stored || DEFAULT_SETTINGS);
    } catch (_) {
      state.settings = { ...DEFAULT_SETTINGS };
    }
  }

  async function persistSettings() {
    try {
      await chrome.storage.local.set({ [SETTINGS_KEY]: state.settings });
    } catch (_) {
      // Ignore storage errors in-page and continue with in-memory state.
    }
  }

  function getPublicState() {
    return {
      active: isAimContextActive(),
      hasTarget: state.hasTarget,
      autoClicksThisRun: state.autoClicksThisRun,
      totalClicks: state.totalClicks,
      settings: { ...state.settings }
    };
  }

  function onRuntimeMessage(message, _sender, sendResponse) {
    if (!message || typeof message.type !== "string") {
      return;
    }

    if (message.type === "aim:get-state") {
      sendResponse(getPublicState());
      return;
    }

    if (message.type === "aim:click-now") {
      const clicked = clickCurrentTarget({ isAutoClick: false });
      sendResponse({ clicked, state: getPublicState() });
      return;
    }

    if (message.type === "aim:toggle-auto") {
      setAutoClickEnabled(!state.settings.autoClickEnabled);
      sendResponse(getPublicState());
      return;
    }

    if (message.type === "aim:set-settings") {
      state.settings = normalizeSettings(message.settings);
      if (!state.settings.showOverlay) {
        hideOverlay();
      }
      void persistSettings();
      sendResponse(getPublicState());
      return;
    }
  }

  function bindObserver() {
    if (!document.documentElement || state.observer) {
      return;
    }

    state.observer = new MutationObserver(() => {
      scheduleImmediatePass();
    });

    state.observer.observe(document.documentElement, {
      childList: true,
      subtree: true
    });
  }

  function bindLifecycle() {
    document.addEventListener(
      "visibilitychange",
      () => {
        if (document.visibilityState === "visible") {
          scheduleImmediatePass();
        }
      },
      { passive: true }
    );

    window.addEventListener("keydown", onKeyDown, true);
  }

  async function init() {
    await loadSettings();
    bindLifecycle();
    bindObserver();
    chrome.runtime.onMessage.addListener(onRuntimeMessage);
    startLoop();
    scheduleImmediatePass();
  }

  if (document.readyState === "loading") {
    document.addEventListener(
      "DOMContentLoaded",
      () => {
        void init();
      },
      { once: true }
    );
  } else {
    void init();
  }
})();
