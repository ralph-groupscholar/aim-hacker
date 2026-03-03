const SETTINGS_KEY = "aimClickerSettings";

const DEFAULT_SETTINGS = {
  autoClickEnabled: false,
  autoClickMinimumIntervalMs: 60,
  autoClickMaxTargets: 31,
  tabInterceptEnabled: true,
  showOverlay: false
};

const AIM_URL_RE = /^https:\/\/humanbenchmark\.com\/.*/i;

async function ensureDefaultSettings() {
  const result = await chrome.storage.local.get(SETTINGS_KEY);
  if (!result[SETTINGS_KEY]) {
    await chrome.storage.local.set({ [SETTINGS_KEY]: DEFAULT_SETTINGS });
  }
}

async function sendToActiveTab(message) {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab || !tab.id || !AIM_URL_RE.test(tab.url || "")) {
    return;
  }

  try {
    await chrome.tabs.sendMessage(tab.id, message);
  } catch (_) {
    // Ignore tabs without an active content script context.
  }
}

chrome.runtime.onInstalled.addListener(() => {
  void ensureDefaultSettings();
});

chrome.commands.onCommand.addListener((command) => {
  if (command === "toggle-auto-click") {
    void sendToActiveTab({ type: "aim:toggle-auto" });
    return;
  }

  if (command === "click-current-target") {
    void sendToActiveTab({ type: "aim:click-now" });
  }
});
