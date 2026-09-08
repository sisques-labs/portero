# Proposal: App bundle icon for Portero.app

## Intent

`Portero.app` ships with **zero icon assets** — no `.icns`, no `CFBundleIconFile` in `Resources/Info.plist`, and no `Contents/Resources/` in the assembled bundle. Finder, Applications, "Get Info", and the Homebrew cask listing therefore render the generic "unknown app" icon. With the Homebrew release train now live, this generic icon is the first thing a user sees when installing Portero. No brand artwork exists, so this change also produces the artwork.

## Scope

### In Scope

- Generate a **placeholder** `AppIcon.icns` during this change (no external artwork dependency).
- Commit it as `Resources/AppIcon.icns`.
- Declare `CFBundleIconFile` in `Resources/Info.plist`.
- Add a copy step in `Scripts/build-app.sh` creating `Contents/Resources/` and placing the icon there **before** `codesign`.

### Out of Scope

- The menu bar (`NSStatusItem`) glyph in `StatusBarController.swift:17`. The SF Symbol `door.left.hand.open` may silently resolve to `nil`; that is a separate, unconfirmed bug.
- Final brand identity / professional artwork (placeholder is intentionally replaceable).
- `Package.swift` `resources:` wiring — not needed for a bundle icon.
- Any change to `Packaging/cask.rb.tmpl` (the cask DSL needs no icon field).

## Capabilities

### New Capabilities

- `app-bundle-icon`: the `.app` bundle carries an icon asset and declares it, so Finder/Applications/Get Info render it instead of the generic placeholder.

### Modified Capabilities

- None.

## Approach

Render a simple glyph (SF Symbol or vector shape on a solid rounded-square background) to PNGs at the standard sizes, assemble an `AppIcon.iconset`, and convert with `iconutil -c icns`. Native Command Line Tools only — no Xcode, no new dependency. The generation is a one-time authoring step; the committed `.icns` is the build input. `build-app.sh` gains `mkdir -p "$APP_BUNDLE/Contents/Resources"` + `cp` inserted after the PlistBuddy stamps and before `codesign --force --deep --sign -`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `Resources/AppIcon.icns` | New | Generated placeholder icon |
| `Resources/Info.plist` | Modified | Add `CFBundleIconFile` |
| `Scripts/build-app.sh` | Modified | Create `Contents/Resources/`, copy icon pre-codesign |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Icon copied after `codesign`, invalidating the ad-hoc signature | Med | Enforce insertion before line 27; verify with `codesign --verify` |
| Malformed `.icns` (missing sizes) renders blank | Low | Build via `iconutil`, inspect in Finder |
| Finder icon cache shows stale generic icon | Med | Verify on a fresh copy / after cache reset, not in place |

## Rollback Plan

Fully revertible, no runtime or data impact: `git revert` the change commit. This drops `CFBundleIconFile`, deletes `Resources/AppIcon.icns`, and restores the prior `build-app.sh`. The bundle returns to the generic icon; the binary, signing flow, and cask are untouched.

## Dependencies

- macOS Command Line Tools (`iconutil`, `sips`) — already required by the existing build.

## Success Criteria

- [ ] `Scripts/build-app.sh` produces `Portero.app/Contents/Resources/AppIcon.icns`.
- [ ] `codesign --verify .build/Portero.app` passes after the icon copy.
- [ ] Finder shows a non-generic icon for the built `.app` and in "Get Info".
- [ ] `swift build -c release` still succeeds.
