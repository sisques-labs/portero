# Proposal: Homebrew Release Train for Portero

## Intent

Portero ships by hand: `v0.1.0` and its Release asset were created manually, `Resources/Info.plist` is frozen at `1.0`, and `homebrew-tap/Casks/portero.rb` — though currently correct — is hand-maintained with no automation keeping it in sync with new releases going forward. Goal: tag-driven three-channel releases that also keep the Cask correct automatically, on every stable release, from here on.

## Scope

### In Scope
- New reusable workflow `macos-cask-release.yml` in `sisques-labs/workflows`, reusing `release-train-detect` as-is (develop→alpha, staging→beta, main→stable).
- Thin caller workflow in portero forwarding `HOMEBREW_TAP_TOKEN`.
- Info.plist version stamping (`CFBundleShortVersionString`/`CFBundleVersion`) plus `.app.zip` packaging in `Scripts/build-app.sh`, keeping ad-hoc `codesign --sign -`.
- Create long-lived `develop` and `staging` branches; stable→develop/staging sync after graduation.
- Regenerate `Casks/portero.rb` each stable release (64-char sha256 computed from the release asset, correct zap path derived from the app's bundle id, retained `postflight` quarantine strip).
- Changelog: GitHub `generate_release_notes: true` (no `cliff.toml`).

### Out of Scope
- Notarization / Developer ID signing.
- Homebrew Formula (build-from-source).
- Other apps consuming the new reusable workflow.
- Creating a portero test target (TDD disabled).

## Capabilities

### New Capabilities
- `macos-release-train`: channel detection, version stamping, build, package, tag, GitHub Release.
- `homebrew-cask-publication`: cross-repo Cask generation, checksum, and push to the tap.

### Modified Capabilities
- None (`openspec/specs/` is empty).

## Approach

Mirror `docker-release.yml`'s mechanics with a macOS payload: detect → stamp Info.plist → `swift build -c release` + `build-app.sh` → zip → atomic tag/commit push → `softprops/action-gh-release` (`prerelease` when channel ≠ stable) → on stable only, compute `shasum -a 256`, render the Cask from a template, and push to `sisques-labs/homebrew-tap` using `HOMEBREW_TAP_TOKEN`. Git tags stay the single source of truth; alpha/beta publish Releases but never touch the tap.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `sisques-labs/workflows/.github/workflows/macos-cask-release.yml` | New | Reusable release workflow |
| `sisques-labs/workflows/.github/actions/release-train-detect/` | Reused | No change |
| `portero/.github/workflows/release.yml` | New | Caller + secret forwarding |
| `portero/Scripts/build-app.sh` | Modified | Version stamp + zip |
| `portero/Resources/Info.plist` | Modified | Version becomes build-injected |
| `portero` branches `develop`, `staging` | New | Required by channel mapping |
| `sisques-labs/homebrew-tap/Casks/portero.rb` | Modified | Currently correct, hand-maintained; becomes generated |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `HOMEBREW_TAP_TOKEN` absent (manual pre-req, outside CI) | High | User mints PAT/App token with tap write scope before first stable run; workflow fails fast with a clear message |
| Token expiry/rotation unowned | Med | Document scope + expiry in tap README; fine-grained PAT limited to `homebrew-tap` |
| Ad-hoc signing → Gatekeeper warning | High | Keep Cask `postflight` `xattr -dr com.apple.quarantine` |
| New `develop`/`staging` unused, drift from `main` | Med | Automated stable→develop/staging sync step |
| First run diverges from the hand-maintained Cask | Low | Existing Cask verified correct (local clone + GitHub API); template renders the same content, so the first generated write is a no-op diff |
| Alpha/beta `.app.zip` mistaken for installable | Low | `prerelease: true`; tap only tracks stable |

## Rollback Plan

All changes are additive. Disable/delete `portero/.github/workflows/release.yml` to stop automation; delete `develop`/`staging` without affecting `main`; `git revert` `build-app.sh`, `Info.plist`, and any bad Cask commit; `gh release delete` + tag delete for a bad release. No persisted or consumer data involved.

## Dependencies

- **Manual pre-requisite, blocking, outside CI**: PAT or fine-grained GitHub App token with write access to `sisques-labs/homebrew-tap`, stored as portero repo secret `HOMEBREW_TAP_TOKEN`.
- PR A (`sisques-labs/workflows`) must merge before portero's caller can reference it.
- `release-train-detect` composite action, reused unchanged.

## Delivery Outline

Single-PR delivery is impossible (three repos). Strategy `auto-chain`:

1. **PR A — `sisques-labs/workflows`**: `macos-cask-release.yml`. Merges first.
2. **Branch step — portero**: create `develop`, `staging` from `main` (repo op, no PR).
3. **PR C — portero**: caller workflow + `build-app.sh`. Depends on A and step 2; splits further if the 400-line guard flags it at tasks time.

No hand-fix PR against `homebrew-tap` is needed: the existing Cask is already correct (see design decision 6), so the first stable run's regenerated write is expected to be a no-op diff.

## Success Criteria

- [ ] Push to `main` yields a tag, a Release with `Portero-v{version}.app.zip`, and a regenerated Cask whose 64-char sha256 matches the asset.
- [ ] `brew install --cask sisques-labs/tap/portero` installs and launches with no checksum or Gatekeeper block.
- [ ] Installed app reports the released version, not `1.0`.
- [ ] `develop`/`staging` pushes produce alpha/beta prereleases and leave the tap untouched.
- [ ] Re-run with no new commits is a no-op (`should_release=false`).
