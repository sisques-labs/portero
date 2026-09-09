# Exploration: App icon missing (menu bar + Dock/Finder)

## Current State

Portero is an SPM-only macOS menu bar (status item) app, `LSUIElement=true` and `NSApp.setActivationPolicy(.accessory)` (`Sources/Portero/AppDelegate.swift:9`) — by design it has **no Dock icon and no Cmd-Tab entry** while running. That's intentional, not a bug.

Code already attempts a menu bar glyph: `Sources/Portero/UI/StatusBarController.swift:17` sets `button.image = NSImage(systemSymbolName: "door.left.hand.open", accessibilityDescription: "Portero")`. `NSImage(systemSymbolName:)` returns `nil` silently if that symbol name doesn't exist in the SF Symbols catalog on the running OS — if so, `button.image` never gets set and the status item shows blank. That's a cheap, testable hypothesis that directly matches the user's literal complaint ("no se ve", not "no me gusta").

Repo-wide search confirms **zero icon assets exist anywhere**: no `.icns` (`**/*.icns` → no matches), no `.xcassets`/`AppIcon` catalog (`**/*.xcassets/**` → no matches). `Resources/Info.plist` has no `CFBundleIconFile`/`CFBundleIconName` key at all. `Scripts/build-app.sh` never creates `Contents/Resources/` in the assembled `.app` and never copies any icon — it only copies the binary + `Info.plist`, stamps version via `PlistBuddy`, then `codesign`s. With no `CFBundleIconFile`, the bundle falls back to the generic Finder "unknown app" icon in Applications/Get Info/the Homebrew cask listing. Since the app is `LSUIElement`, "app icon" here can only mean (a) the Finder/bundle icon and/or (b) the menu bar glyph — never a Dock icon.

Prior SDD change `homebrew-release-train` (`openspec/changes/homebrew-release-train/design.md`, `proposal.md`) touched `Scripts/build-app.sh` and `Info.plist` for version stamping only; it never raised or touched icons.

## Affected Areas

- `Sources/Portero/AppDelegate.swift:9` — confirms no Dock icon by design; context only.
- `Sources/Portero/UI/StatusBarController.swift:16-18` — current SF Symbol placeholder for the menu bar glyph.
- `Resources/Info.plist` — missing `CFBundleIconFile` (needed for a Finder/bundle icon).
- `Scripts/build-app.sh` — never creates `Contents/Resources/` or copies an icon; any fix must add this **before** the existing `codesign --force --deep --sign -` call (same ordering constraint documented in `design.md` decision 3 — mutating the bundle after signing invalidates the ad-hoc signature).
- `Package.swift` — no `resources:` entry; a custom SPM-resource image for the status item would emit a companion `.bundle` that `build-app.sh` doesn't currently copy into `Contents/Resources/`.
- `Packaging/cask.rb.tmpl` — no icon field needed for the Homebrew cask DSL; not directly affected.
- No source icon artwork (logo/PNG/SVG) exists in the repo for either target.

## Approaches

1. **Finder/Dock `.app` bundle icon only (.icns)** — add `Resources/AppIcon.icns`, `CFBundleIconFile` in Info.plist, copy step in `build-app.sh` pre-codesign.
   - Pros: fixes Applications/Finder/Get Info/Homebrew cask appearance; low-risk, isolated.
   - Cons: doesn't touch the menu bar glyph — the only icon visible while running.
   - Effort: Low (once artwork exists).

2. **Menu bar (`NSStatusItem`) glyph only** — verify/fix the SF Symbol name, or swap to a custom template `NSImage` via SPM resources.
   - Pros: fixes what the user actually sees day-to-day; may be a one-line fix if root cause is an invalid symbol name.
   - Cons: doesn't fix the generic bundle icon in Finder/Applications/cask listing.
   - Effort: Low if symbol-name bug; Medium if custom artwork + resource wiring needed.

3. **Both** — `.icns` for the bundle + custom template image for the status item.
   - Pros: complete, consistent branding.
   - Cons: needs real source artwork for both; larger two-track effort.
   - Effort: Medium, mostly gated on artwork availability.

## Recommendation

Cannot pick one yet — the request is genuinely ambiguous between "Dock/Finder icon" and "menu bar glyph," and no artwork exists for either. Ask the user first. If forced to guess: verify approach 2's cheap hypothesis (nil SF Symbol) first since it matches the literal complaint, then scope `.icns` work separately once artwork is confirmed.

## Risks

- Root-cause ambiguity: a silently-nil SF Symbol (code bug) vs. no icon asset existing (content gap) require different fixes.
- No icon source artwork exists in-repo for either target — a design/content dependency, not just engineering.
- Any bundle mutation added to `build-app.sh` must precede `codesign` or it invalidates the ad-hoc signature.
- A custom SPM-resource image would need explicit handling in `build-app.sh` to land in `Contents/Resources/`, or it's missing at runtime.

## Ready for Proposal

No — needs one clarifying round-trip with the user first.

## Open Questions for User

1. Is the missing icon the **Dock/Finder `.app` bundle icon** (Applications, Get Info, Homebrew cask page), the **menu bar (status bar) icon** (the glyph next to the clock while running), or **both**? (Portero has no Dock presence by design, so a Dock icon would only ever show in Finder/Applications, never in the Dock itself while running.)
2. Do you already have icon artwork (logo, PNG/SVG, brand file) to use, or should placeholder/generated artwork be created as part of this change?
3. If it's the menu bar icon: keep it a native monochrome "template" icon (macOS convention, like the current SF Symbol attempt), or go full-color custom?
