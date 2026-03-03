# Aim Clicker JS (Chrome Extension)

Chrome extension version of the Swift aim clicker for Human Benchmark Aim Trainer.

## What it mirrors from the Swift app

- `Tab` interception on the Aim Trainer page: pressing `Tab` clicks the current target.
- Optional auto-click mode.
- Auto-click gate defaults:
  - minimum interval: `60ms`
  - maximum auto-click targets: `31`
- Target detection fallback modeled after Swift scoring (size + class-token heuristic).

## Speed-focused design

- Primary target path is direct: `[data-aim-target]`.
- Click path uses a single synthetic `mousedown` at target center (matches page handler).
- Uses both:
  - continuous fast loop
  - mutation-triggered microtask pass
  so new targets are picked up with minimal delay.

## Install (unpacked)

1. Open `chrome://extensions`.
2. Enable **Developer mode**.
3. Click **Load unpacked**.
4. Select:
   - `/Users/ralph/Documents/aim-clicker-js`

## Usage

- Open [https://humanbenchmark.com/tests/aim](https://humanbenchmark.com/tests/aim).
- Extension popup:
  - toggle auto-click
  - quick `Toggle Auto` button
  - set min interval and max targets
  - toggle tab interception
  - overlay is on by default (can be toggled off)
- Keyboard commands:
  - Toggle auto: `Ctrl+Shift+Y` (`Cmd+Shift+Y` on macOS)
  - Click now: `Ctrl+Shift+X` (`Cmd+Shift+X` on macOS)

You can rebind shortcuts at `chrome://extensions/shortcuts`.

## Tests

```bash
cd /Users/ralph/Documents/aim-clicker-js
npm test
```
