# aim-clicker

A macOS Swift app that automates Human Benchmark Aim Trainer using `axorc`.

## Behavior

- Detects when Safari is frontmost on **Human Benchmark Aim Trainer**.
- Uses Accessibility APIs to find the likely target circle and draws a translucent overlay on it.
- Uses `axorc` query mode to resolve a fresh target ref from the target's DOM class token.
- Intercepts `Tab` globally and uses `axorc --actions 'send click to <ref>;'` instead of passing `Tab` through.
- Optional `--auto-click` mode clicks each detected target automatically (up to 31 targets, then stops).

## Build and test

```bash
swift test
swift run aim-clicker
swift run aim-clicker --auto-click
```

## Permissions required

Enable Accessibility permissions for:

- the built `aim-clicker` process
- `axorc` (at `/Users/ralph/bin/axorc`)

Without Accessibility trust, overlay detection and click actions may fail.
