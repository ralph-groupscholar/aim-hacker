const statusEl = document.getElementById("status");
const autoEnabledEl = document.getElementById("auto-enabled");
const tabEnabledEl = document.getElementById("tab-enabled");
const overlayEnabledEl = document.getElementById("overlay-enabled");
const minIntervalEl = document.getElementById("min-interval");
const maxTargetsEl = document.getElementById("max-targets");
const hasTargetEl = document.getElementById("has-target");
const autoClicksEl = document.getElementById("auto-clicks");
const totalClicksEl = document.getElementById("total-clicks");
const toggleAutoButton = document.getElementById("toggle-auto");
const clickNowButton = document.getElementById("click-now");
const refreshButton = document.getElementById("refresh");

const AIM_URL_RE = /^https:\/\/humanbenchmark\.com\/.*/i;

function setStatus(message, isError = false) {
  statusEl.textContent = message;
  statusEl.classList.toggle("error", isError);
}

async function getActiveTab() {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  return tab || null;
}

async function sendToAimTab(message) {
  const tab = await getActiveTab();
  if (!tab || !tab.id || !AIM_URL_RE.test(tab.url || "")) {
    throw new Error("Open Human Benchmark and keep this popup active.");
  }

  return chrome.tabs.sendMessage(tab.id, message);
}

function renderState(snapshot) {
  autoEnabledEl.checked = Boolean(snapshot.settings.autoClickEnabled);
  tabEnabledEl.checked = Boolean(snapshot.settings.tabInterceptEnabled);
  overlayEnabledEl.checked = Boolean(snapshot.settings.showOverlay);
  minIntervalEl.value = String(snapshot.settings.autoClickMinimumIntervalMs ?? 60);
  maxTargetsEl.value = String(snapshot.settings.autoClickMaxTargets ?? 31);
  hasTargetEl.textContent = snapshot.hasTarget ? "Yes" : "No";
  autoClicksEl.textContent = String(snapshot.autoClicksThisRun ?? 0);
  totalClicksEl.textContent = String(snapshot.totalClicks ?? 0);

  if (snapshot.active) {
    setStatus("Connected to Aim Trainer tab.");
  } else {
    setStatus("Tab is open, but not on /tests/aim.", true);
  }
}

async function refresh() {
  try {
    const state = await sendToAimTab({ type: "aim:get-state" });
    renderState(state);
  } catch (error) {
    setStatus(error.message || "Unable to reach content script.", true);
  }
}

async function pushSettings() {
  const settings = {
    autoClickEnabled: autoEnabledEl.checked,
    tabInterceptEnabled: tabEnabledEl.checked,
    showOverlay: overlayEnabledEl.checked,
    autoClickMinimumIntervalMs: Number(minIntervalEl.value),
    autoClickMaxTargets: Number(maxTargetsEl.value)
  };

  try {
    const state = await sendToAimTab({ type: "aim:set-settings", settings });
    renderState(state);
  } catch (error) {
    setStatus(error.message || "Unable to apply settings.", true);
  }
}

autoEnabledEl.addEventListener("change", () => {
  void pushSettings();
});

tabEnabledEl.addEventListener("change", () => {
  void pushSettings();
});

overlayEnabledEl.addEventListener("change", () => {
  void pushSettings();
});

minIntervalEl.addEventListener("change", () => {
  void pushSettings();
});

maxTargetsEl.addEventListener("change", () => {
  void pushSettings();
});

clickNowButton.addEventListener("click", async () => {
  try {
    const result = await sendToAimTab({ type: "aim:click-now" });
    renderState(result.state);
    setStatus(result.clicked ? "Clicked current target." : "No target available right now.", !result.clicked);
  } catch (error) {
    setStatus(error.message || "Unable to click target.", true);
  }
});

toggleAutoButton.addEventListener("click", async () => {
  try {
    const state = await sendToAimTab({ type: "aim:toggle-auto" });
    renderState(state);
    setStatus(state.settings.autoClickEnabled ? "Auto-click enabled." : "Auto-click disabled.");
  } catch (error) {
    setStatus(error.message || "Unable to toggle auto-click.", true);
  }
});

refreshButton.addEventListener("click", () => {
  void refresh();
});

void refresh();
