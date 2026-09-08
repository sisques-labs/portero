# Tasks: App bundle icon for Portero.app

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~130 authored (generator script ~120, `Info.plist` +2, `build-app.sh` +5); `Resources/AppIcon.icns` is a generated binary asset excluded from authored risk count |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | auto-chain |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Icon asset, generator script, plist key, and build-script copy step land together as one additive slice | PR 1 | `swift build -c release` | `VERSION=9.9.9 Scripts/build-app.sh` then `codesign --verify --deep --strict .build/Portero.app` | `git revert` the commit — drops `CFBundleIconFile`, deletes `Resources/AppIcon.icns` and `Scripts/generate-app-icon.swift`, restores `build-app.sh`; no other file depends on the icon |

## Phase 1: Foundation — Icon Generator

- [x] 1.1 Create `Scripts/generate-app-icon.swift`: an `NSBezierPath`/`NSBitmapImageRep` renderer implementing the Placeholder Artwork Spec (1024x1024 canvas, centered 824x824 rounded plate at corner radius 185.4 filled `#1E5F74`, centered white door glyph rounded rect ~34% wide x ~58% tall at corner radius 24 with a knob circle radius ≈3% of the plate at ~72% of the door width). No font, no SF Symbols. Render each of the 10 required iconset sizes (`icon_16x16.png` through `icon_512x512@2x.png`) natively at its exact pixel size (no resampling) into `build/AppIcon.iconset/`, then invoke `iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns`.

## Phase 2: Core Implementation — Asset, Plist, Build Script

- [x] 2.1 Run `swift Scripts/generate-app-icon.swift` to produce `build/AppIcon.iconset/*.png` and `Resources/AppIcon.icns`. Verify with `iconutil -c iconset -o /tmp/v.iconset Resources/AppIcon.icns` (expect 10 PNGs) and `sips -g pixelWidth -g pixelHeight` per PNG to confirm exact dimensions.
- [x] 2.2 Commit the generated `Resources/AppIcon.icns` as a tracked binary asset.
- [x] 2.3 Edit `Resources/Info.plist`: add `CFBundleIconFile` / `AppIcon` between the existing `CFBundleExecutable` (line 15-16) and `CFBundlePackageType` (line 17-18) keys.
- [x] 2.4 Edit `Scripts/build-app.sh`: insert the comment plus `mkdir -p "$APP_BUNDLE/Contents/Resources"` and `cp Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"` between the PlistBuddy version stamp (line 25) and the `codesign --force --deep --sign -` invocation (line 27), preserving the pre-signing invariant.

## Phase 3: Verification

- [x] 3.1 Run `swift build -c release` — confirm it completes with no new build errors.
- [x] 3.2 Run `VERSION=9.9.9 Scripts/build-app.sh` — confirm the script completes successfully end to end.
- [x] 3.3 Confirm `.build/Portero.app/Contents/Resources/AppIcon.icns` exists immediately after the copy step, and `/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" .build/Portero.app/Contents/Info.plist` prints `AppIcon`.
- [x] 3.4 Run `codesign --verify --deep --strict .build/Portero.app` — confirm the ad-hoc signature is valid with the icon present.
- [x] 3.5 Manual inspection: copy `.build/Portero.app` to a fresh path (never inspect in place — Finder caches the stale generic icon), then view it in Finder and via "Get Info" — confirm it displays the placeholder icon, not the generic application icon. **Limitation**: this sandboxed CLI environment cannot render Finder/Get Info visually; verified via filesystem inspection instead — fresh-path copy at `/tmp/portero-icon-check/Portero.app` has `Contents/Resources/AppIcon.icns` present (`file` confirms "Mac OS X icon" type) and passes `codesign --verify --deep --strict`. Visual Finder confirmation should be done manually by a human with GUI access.
