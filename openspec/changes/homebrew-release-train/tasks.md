# Tasks: Homebrew Release Train for Portero

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | PR 1 (workflows): ~180-260 · PR 2 (portero): ~150-220 |
| 400-line budget risk | Low (each PR individually stays under budget) |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 (workflows) → manual prereqs → PR 2 (portero) |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: Low

Split is repo-boundary-driven, not size-driven: `workflows` and `portero` are separate repositories, so a single PR is structurally impossible regardless of line count. Each PR stays comfortably under the 400-line budget on its own.

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Reusable `macos-cask-release.yml` in workflows | PR 1 | `actionlint .github/workflows/macos-cask-release.yml` | N/A — no runner until a caller exists | Delete the new workflow file |
| 2 | Manual branches + `HOMEBREW_TAP_TOKEN` secret | none (repo ops) | N/A — human/GitHub-settings action | N/A | Delete branches; remove secret |
| 3 | Caller workflow + build-app.sh + cask template in portero | PR 2 | `VERSION=9.9.9 Scripts/build-app.sh` then `swift build -c release` | Push to `develop` scratch branch → alpha prerelease | `git revert` the PR; delete `release.yml` |

## Phase 1: `sisques-labs/workflows` — Reusable Workflow (PR 1)

- [x] 1.1 Create `workflows/.github/workflows/macos-cask-release.yml` with `workflow_call` inputs (`app_name`, `cask_name`, `tap_repository`, `cask_template`, `build_script`, `release_type`, `next_version`, `runner`, `sync_branches_after_stable`), secret `HOMEBREW_TAP_TOKEN` (required: false), `permissions: contents: write`.
- [x] 1.2 Add build job on `${{ inputs.runner }}`: checkout consumer (`fetch-depth: 0`), guard duplicate tag, run `VERSION=${{ inputs.next_version }} ${{ inputs.build_script }}`, compute `shasum -a 256` of the `.app.zip`.
- [x] 1.3 Add release steps: atomic tag push (3-attempt retry + ancestor check), `softprops/action-gh-release` with the `.app.zip` asset, `generate_release_notes: true`, `prerelease` when `release_type != stable`; re-download the asset and assert its sha256 matches.
- [x] 1.4 Add stable-only tap steps: second checkout of `${{ inputs.tap_repository }}` at `path: tap` with `token: ${{ secrets.HOMEBREW_TAP_TOKEN }}` (fail fast with `::error::` if empty); render `${{ inputs.cask_template }}` into the Cask file inside the tap checkout, substituting `{{VERSION}}`/`{{SHA256}}`; validate `^  sha256 "[0-9a-f]{64}"$` with no residual `{{`; `git -C tap add` + commit-if-nonempty + push with fetch+rebase retry on non-fast-forward.
- [x] 1.5 Add stable-only sync step: fast-forward/merge `main` into each branch listed in `${{ inputs.sync_branches_after_stable }}`, skipping branches that do not exist.
- [x] 1.6 Lint `workflows/.github/workflows/macos-cask-release.yml` with `actionlint`; confirm inputs/secrets match design.md's Interfaces/Contracts section.

## Phase 2: Manual Prerequisites (non-code, blocks first stable run)

- [ ] 2.1 In `portero`: `git checkout -b develop && git push -u origin develop`; repeat for `staging`, both from current `main`.
- [ ] 2.2 Mint a fine-grained PAT or GitHub App token with `contents:write` scoped to `sisques-labs/homebrew-tap` only; add it as the `HOMEBREW_TAP_TOKEN` repository secret in portero's GitHub settings.
- [ ] 2.3 Confirmed: `sisques-labs/homebrew-tap`'s default branch is `main` (verified via `gh api`); no re-verification needed before wiring the push refspec in task 1.4.

## Phase 3: `portero` — Caller Workflow, Build Script, Cask Template (PR 2, depends on PR 1)

- [x] 3.1 Modify `portero/Resources/Info.plist`: set `CFBundleShortVersionString`/`CFBundleVersion` to the `0.0.0` dev sentinel, replacing the hardcoded `1.0`.
- [x] 3.2 Modify `portero/Scripts/build-app.sh`: read `VERSION` env (default `0.0.0-dev`), PlistBuddy-stamp the bundle copy of Info.plist before `codesign --sign -`, then `ditto` zip to `Portero-v${VERSION}.app.zip`.
- [x] 3.3 Create `portero/Packaging/cask.rb.tmpl`: sole source of the Cask body (name/desc/homepage/app stanza/`postflight { xattr -dr com.apple.quarantine }`/`zap trash ~/Library/Preferences/com.sisqueslabs.portero.plist`), with only `{{VERSION}}`/`{{SHA256}}` placeholders.
- [x] 3.4 Create `portero/.github/workflows/release.yml`: triggers on push to `develop`/`staging`/`main`; runs `release-train-detect@main`; on `should_release=true` calls `sisques-labs/workflows/.github/workflows/macos-cask-release.yml@main` (read-only) with `secrets: inherit` and the required inputs (`app_name`, `release_type`, `next_version`, `sync_branches_after_stable: develop,staging`). Note: depends on PR 1 having a stable `@main` ref before this can succeed at runtime.
- [x] 3.5 Local smoke test: `cd portero && VERSION=9.9.9 Scripts/build-app.sh`; assert `defaults read .build/Portero.app/Contents/Info CFBundleShortVersionString` reads `9.9.9`, `codesign --verify --deep .build/Portero.app` passes, zip round-trips.
- [x] 3.6 `swift build -c release` passes cleanly with the modified `Info.plist`/`build-app.sh` in place.

## Phase 4: Cross-Repo Verification (no code changes)

- [ ] 4.1 Push to `develop`; confirm `release_type=alpha`, `prerelease: true`, and `homebrew-tap/Casks/portero.rb` (read-only) is untouched.
- [ ] 4.2 After Phase 2 and PR 2 land, push to `main`; confirm tag, Release with `Portero-v{version}.app.zip`, regenerated `homebrew-tap/Casks/portero.rb` (read-only) with a fresh 64-char sha256, and `develop`/`staging` synced.
- [ ] 4.3 Re-run with no new commits; confirm `should_release=false` (no-op), per proposal success criteria.
- [ ] 4.4 `brew install --cask sisques-labs/tap/portero` installs, launches with no Gatekeeper block, reports the released version (not `1.0`).
