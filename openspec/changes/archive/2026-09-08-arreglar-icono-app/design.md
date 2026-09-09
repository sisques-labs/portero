# Design: App bundle icon for Portero.app

## Technical Approach

Three additive pieces: (1) a committed `Resources/AppIcon.icns` placeholder plus the deterministic Swift/AppKit generator that produced it, (2) a `CFBundleIconFile` declaration in `Resources/Info.plist`, (3) a two-line copy step in `Scripts/build-app.sh` placed strictly before `codesign`. No new dependency: the Swift toolchain is already a hard build requirement, and `iconutil`/`sips` ship with Command Line Tools. The menu bar `NSStatusItem` glyph is untouched per proposal scope.

## Architecture Decisions

| # | Decision | Choice | Rejected | Rationale |
|---|---|---|---|---|
| 1 | Artwork generator | `Scripts/generate-app-icon.swift`, run with `swift Scripts/generate-app-icon.swift`; draws pure `NSBezierPath` geometry into `NSBitmapImageRep` and writes the 10 iconset PNGs, then `iconutil -c icns` packs them | ImageMagick/`magick`; hand-committed opaque PNG blobs; `sips`-only (cannot draw) | Swift is already required by `swift build -c release`, so this adds zero tooling. Pure geometry means no font and no SF Symbols catalog lookup — `NSImage(systemSymbolName:)` returning `nil` silently is exactly the unconfirmed out-of-scope bug, so the generator must not depend on it. Committing the generator keeps the placeholder reproducible and editable instead of magic bytes. |
| 2 | Build-time vs. committed | Generate **once**, commit `Resources/AppIcon.icns` as a static repo asset. `build-app.sh` never renders | Render the icon inside `build-app.sh` on every build | The Homebrew cask pins the `sha256` of the `ditto` zip. A build-time render makes icon bytes a function of the OS/toolchain of whoever builds, so identical source could produce different zips and a cask hash that does not reproduce. There is no test suite (`tdd: false`), so the fewer moving parts in the single script that produces the shipped artifact, the better. Tradeoff accepted: a small binary blob in git, and refreshing the placeholder is a manual `swift Scripts/generate-app-icon.swift` re-run. |
| 3 | Plist key | `CFBundleIconFile` = `AppIcon` (no extension) | `CFBundleIconName` | `CFBundleIconName` addresses an asset-catalog entry compiled by `actool`; this repo has no `.xcassets` and no Xcode, so it would point at nothing. `CFBundleIconFile` resolves a literal file in `Contents/Resources/`. |
| 4 | Copy-step placement | Insert `mkdir -p` + `cp` **after** the PlistBuddy stamps (line 25) and **before** `codesign --force --deep --sign -` (line 27) | Copy after `codesign`; copy before the stamps | Mutating anything under `Contents/` after signing invalidates the ad-hoc signature — the same constraint that already forces version stamping to precede signing (homebrew-release-train `design.md`, decision 3). Placing it immediately above `codesign` makes the pre-signing invariant visible at the one line where it can be broken. `set -euo pipefail` means a missing `Resources/AppIcon.icns` aborts the build loudly rather than silently shipping a generic icon. |

## Placeholder Artwork Spec

1024×1024 canvas. Centered 824×824 rounded plate, corner radius 185.4 (macOS Big Sur icon grid), filled solid `#1E5F74`. Centered white (`#FFFFFF`) door glyph: rounded rect ~34% of the plate wide × ~58% tall, corner radius 24, with a filled knob circle (radius ≈3% of the plate) at ~72% of the door width, vertical mid-height. No text, no font, no system symbol — fully deterministic across machines.

Required iconset members (all 10, exact `iconutil` names):

```
icon_16x16.png(16)      icon_16x16@2x.png(32)
icon_32x32.png(32)      icon_32x32@2x.png(64)
icon_128x128.png(128)   icon_128x128@2x.png(256)
icon_256x256.png(256)   icon_256x256@2x.png(512)
icon_512x512.png(512)   icon_512x512@2x.png(1024)
```

Each PNG is rendered natively at its exact pixel size from the vector code (no resampling); `sips -g pixelWidth -g pixelHeight` verifies dimensions before packing.

## Data Flow

Authoring (one-time, manual):

    generate-app-icon.swift ──→ build/AppIcon.iconset/*.png ──→ iconutil -c icns
                                                                      │
                                                    Resources/AppIcon.icns (committed)

Build (`Scripts/build-app.sh`, every run):

    swift build -c release
      │
      ├─ mkdir Contents/MacOS   ← binary
      ├─ cp Resources/Info.plist → Contents/Info.plist
      ├─ PlistBuddy stamp CFBundleShortVersionString / CFBundleVersion   (L24-25)
      ├─ mkdir -p Contents/Resources ; cp Resources/AppIcon.icns  ← NEW   (insert here)
      │        ══════ signing boundary: no Contents/ writes past this line ══════
      ├─ codesign --force --deep --sign -                                (L27)
      └─ ditto -c -k --sequesterRsrc --keepParent → Portero-vX.app.zip

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `Resources/AppIcon.icns` | Create | Committed placeholder icon, build input |
| `Scripts/generate-app-icon.swift` | Create | Deterministic generator; not invoked by the build |
| `Resources/Info.plist` | Modify | Add `CFBundleIconFile` = `AppIcon` between `CFBundleExecutable` and `CFBundlePackageType` |
| `Scripts/build-app.sh` | Modify | Two lines + comment inserted between L25 and L27 |

## Interfaces / Contracts

`Resources/Info.plist` insertion:

```xml
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
```

`Scripts/build-app.sh` insertion (after L25, before L27):

```bash
# The icon must land in the bundle before codesign — mutating Contents/ after
# signing invalidates the signature (same constraint as the version stamp above;
# see homebrew-release-train design.md, decision 3).
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
```

## Testing Strategy

No test target exists (`openspec/config.yaml`: `tdd: false`, empty `test_command`), so verification is build + command assertions + manual inspection.

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | None | No test target configured |
| Asset | `.icns` completeness | `iconutil -c iconset -o /tmp/v.iconset Resources/AppIcon.icns` → 10 PNGs; `sips -g pixelWidth` per file |
| Build | Compilation unaffected | `swift build -c release` |
| Script | Icon present and signature intact | `VERSION=9.9.9 Scripts/build-app.sh`; `test -f .build/Portero.app/Contents/Resources/AppIcon.icns`; `PlistBuddy -c "Print :CFBundleIconFile" .build/Portero.app/Contents/Info.plist` → `AppIcon`; `codesign --verify --deep --strict .build/Portero.app` |
| Manual | Rendering | Copy `.build/Portero.app` to a fresh path (never inspect in place — Finder icon cache serves the stale generic icon), then Finder + Get Info |

## Threat Matrix

Included because the change edits a shell script; no row is materially applicable.

| Boundary | Applicability | Design response |
|---|---|---|
| Documentation-like paths | N/A — no name-based file classification; the only new path is one fixed literal | — |
| Git repository selection | N/A — no `git` invocation added; `build-app.sh` keeps its single `cd "$(dirname "$0")/.."` | — |
| Commit state | N/A — no commit automation added | — |
| Push state | N/A — no push automation added | — |
| PR commands | N/A — no `gh` automation added | — |

The one real boundary is the signing-order invariant, owned by decision 4 and verified by `codesign --verify --deep --strict`.

## Migration / Rollout

No data migration, no feature flag, no runtime behavior change. Additive only: one new asset, one new authoring script, two small edits.

**Rollback**: `git revert` the change commit. That drops `CFBundleIconFile`, deletes `Resources/AppIcon.icns`, and restores `build-app.sh`. The bundle returns to the generic Finder icon; the binary, signing flow, zip, and cask template are untouched. Nothing outside the built bundle reads the icon, so no coordinated release step is required.

## Open Questions

- [ ] Placeholder palette (`#1E5F74` teal) is an arbitrary reasonable default — confirm or override before the icon becomes the public cask face.
