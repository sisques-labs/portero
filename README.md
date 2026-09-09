# Portero

Menu bar app for macOS to see and kill processes listening on network ports.

## Installation

### Homebrew (recommended)

```sh
brew install --cask sisques-labs/tap/portero
```

### Manual build

Requires the Swift 5.9+ toolchain (Xcode Command Line Tools are enough — no Xcode project needed):

```sh
git clone https://github.com/sisques-labs/portero.git
cd portero
swift build -c release
```

To produce a proper signed `.app` bundle (the same one Homebrew installs):

```sh
Scripts/build-app.sh
```

## Usage

Portero lives in the macOS menu bar. Click its icon to see every process currently listening on a network port:

- **View** — the list shows each listening port with the owning process.
- **Filter** — type in the filter field to narrow the list by port or process name.
- **Kill** — select an entry to terminate the process holding that port.

## Development

```text
Sources/Portero/
├── main.swift                   # entry point
├── AppDelegate.swift            # app lifecycle
├── Models/PortEntry.swift       # port/process data model
├── Services/
│   ├── PortMonitor.swift        # enumerates listening ports
│   ├── ProcessKiller.swift      # terminates a process
│   └── KillError.swift
└── UI/
    ├── StatusBarController.swift  # menu bar item + menu
    └── FilterFieldView.swift
```

Build and run locally with `swift build` / `swift run`. `Scripts/build-app.sh` assembles and ad-hoc codesigns the `.app` bundle (used both locally and in CI); `Scripts/generate-app-icon.swift` regenerates `Resources/AppIcon.icns`.

Releases are automated: a push to `develop`, `staging`, or `main` runs [`.github/workflows/release.yml`](.github/workflows/release.yml), which tags, builds, publishes a GitHub Release, and — on `main` — updates the [`sisques-labs/homebrew-tap`](https://github.com/sisques-labs/homebrew-tap) Cask. There is no manual release step.

There is no automated test suite yet (`swift build -c release` is the current validation step).

## Requirements

- macOS 13 (Ventura) or later.

## License

No `LICENSE` file is present in this repository yet.
