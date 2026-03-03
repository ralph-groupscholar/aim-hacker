const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const core = require("../core.js");

test("pickClassToken prefers css token without betiu", () => {
  const token = core.pickClassToken(["foo", "css-betiu123", "css-target777"]);
  assert.equal(token, "css-target777");
});

test("pickClassToken falls back to first token when no css token exists", () => {
  const token = core.pickClassToken(["foo", "bar"]);
  assert.equal(token, "foo");
});

test("framesAreNearlyEqual uses strict < 1 tolerance", () => {
  const a = { left: 10, top: 20, width: 100, height: 100 };
  const b = { left: 10.9, top: 20.9, width: 100.9, height: 100.9 };
  const c = { left: 11, top: 20, width: 100, height: 100 };

  assert.equal(core.framesAreNearlyEqual(a, b), true);
  assert.equal(core.framesAreNearlyEqual(a, c), false);
});

test("normalizeSettings coerces and clamps values", () => {
  const base = core.DEFAULT_SETTINGS;
  const next = core.normalizeSettings(base, {
    autoClickEnabled: 1,
    tabInterceptEnabled: 0,
    showOverlay: "yes",
    autoClickMinimumIntervalMs: -25,
    autoClickMaxTargets: 0
  });

  assert.equal(next.autoClickEnabled, true);
  assert.equal(next.tabInterceptEnabled, false);
  assert.equal(next.showOverlay, true);
  assert.equal(next.autoClickMinimumIntervalMs, 0);
  assert.equal(next.autoClickMaxTargets, 1);
});

test("scoreCandidate penalizes betiu token heavily", () => {
  const webArea = { top: 0, height: 500 };
  const tokenFrequency = { "css-good": 2, "css-betiu": 2 };

  const good = {
    frame: { top: 120, width: 68, height: 68 },
    classTokens: ["css-good"]
  };
  const bad = {
    frame: { top: 120, width: 68, height: 68 },
    classTokens: ["css-betiu"]
  };

  const goodScore = core.scoreCandidate(good, webArea, tokenFrequency);
  const badScore = core.scoreCandidate(bad, webArea, tokenFrequency);
  assert.ok(goodScore > badScore);
});

test("shouldAutoClickTarget respects interval and duplicate-frame gate", () => {
  const frameA = { left: 100, top: 100, width: 50, height: 50 };
  const frameB = { left: 150, top: 150, width: 50, height: 50 };

  assert.equal(
    core.shouldAutoClickTarget({
      minimumIntervalMs: 60,
      nowMs: 100,
      lastClickAtMs: 70,
      lastClickedFrame: frameA,
      targetFrame: frameB
    }),
    false
  );

  assert.equal(
    core.shouldAutoClickTarget({
      minimumIntervalMs: 60,
      nowMs: 200,
      lastClickAtMs: 70,
      lastClickedFrame: frameA,
      targetFrame: { ...frameA }
    }),
    false
  );

  assert.equal(
    core.shouldAutoClickTarget({
      minimumIntervalMs: 60,
      nowMs: 200,
      lastClickAtMs: 70,
      lastClickedFrame: frameA,
      targetFrame: frameB
    }),
    true
  );
});

test("manifest loads core.js before content.js", () => {
  const manifestPath = path.join(__dirname, "..", "manifest.json");
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  const contentScript = manifest.content_scripts[0];

  assert.ok(Array.isArray(contentScript.js));
  assert.deepEqual(contentScript.js.slice(0, 2), ["core.js", "content.js"]);
});
