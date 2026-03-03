# Aim Clicker

This repository contains two implementations of an aim-target click helper for the Human Benchmark Aim Trainer:

- `aim-clicker-swift`: a macOS Swift executable that uses Accessibility APIs and `axorc`
- `aim-clicker-js`: a Chrome extension version focused on low-latency detection/clicking

## Repository layout

- `aim-clicker-swift/` - Swift package, executable target `aim-clicker`, and unit tests
- `aim-clicker-js/` - Chrome extension source and Node test suite

## Quick start

### Swift app

```bash
cd aim-clicker-swift
swift test
swift run aim-clicker
```

Optional auto-click mode:

```bash
swift run aim-clicker --auto-click
```

See additional setup notes in [aim-clicker-swift/README.md](aim-clicker-swift/README.md).

### Chrome extension

```bash
cd aim-clicker-js
npm test
```

Load unpacked in Chrome via `chrome://extensions` (Developer mode), then select `aim-clicker-js/`.

See full usage details in [aim-clicker-js/README.md](aim-clicker-js/README.md).
