# Design: Homebrew Release Train for Portero

## Technical Approach

Three repos, one path. `portero/.github/workflows/release.yml` (caller, on push to `develop`/`staging`/`main`) runs `release-train-detect@main`, then calls the new reusable `sisques-labs/workflows/.github/workflows/macos-cask-release.yml@main` on `macos-14`. The reusable workflow builds through the consumer's own `Scripts/build-app.sh`, so local and CI builds share one packaging path. Git tags remain the single source of truth; `homebrew-tap/Casks/portero.rb` becomes generated output, never hand-edited — the same relationship `docker-release.yml` gives `package.json`.

## Architecture Decisions

| # | Decision | Choice | Rejected | Rationale |
|---|---|---|---|---|
| 1 | Reusable workflow ref | `@main` | `@v1` pinned tag | `release-train.yml` already calls `docker-release.yml@main`, `release-train-detect@main`, `trivy-scan@main`. The workflows repo has no release tagging discipline to pin against; diverging would create a versioning contract for one consumer. Tradeoff accepted: a breaking edit reaches portero immediately. |
| 2 | Cask generation | Render whole file from `portero/Packaging/cask.rb.tmpl` with `{{VERSION}}`/`{{SHA256}}` substituted | In-place `sed` of two fields; heredoc inside workflow YAML | Full render makes the tap a mirror, so a hand-edit is unambiguously an error. Template lives in **portero**, not workflows (app-specific `desc`/bundle id/zap would break workflow reusability) and not the tap (the tap holds only generated output). URL stays Ruby `#{version}`, so only two substitutions exist. |
| 3 | Version stamping | `Scripts/build-app.sh` reads `VERSION` env (default `0.0.0-dev`), PlistBuddy-stamps the **bundle copy** of Info.plist *before* `codesign` | CI-only stamping step; committing a bumped `Resources/Info.plist` | One packaging path for local and CI. Stamping after signing invalidates the signature. Nothing outside the built bundle reads the version, so no release commit is needed in portero — the push is tag-only and cannot retrigger the workflow. |
| 4 | Changelog | `generate_release_notes: true` | git-cliff + new `cliff.toml` | Zero new config; `docker-release.yml` already uses exactly this on its no-cliff path. Single-package app, no CHANGELOG.md consumer. |
| 5 | Tap write | Second `actions/checkout` (`repository: sisques-labs/homebrew-tap`, `path: tap`, `token: HOMEBREW_TAP_TOKEN`), commit, push direct to its default branch | Open a PR on the tap | One atomic release step, mirroring `docker-release.yml`'s direct release push. **Tradeoff, accepted explicitly: no review gate on the tap.** Mitigated by post-render validation, empty-diff no-op, and single-commit revert. |
| 6 | Existing Cask | No hand-fix PR (proposal's PR B is dropped) | Manual pre-fix PR | Decision 2 regenerates the entire file, so a hand-fix is work that the first stable run discards. Evidence: the local clone `homebrew-tap/Casks/portero.rb` already carries a valid 64-char sha256 and the correct `com.sisqueslabs.portero.plist` zap path, contradicting the proposal's premise — remote state must be checked, not assumed. |
| 7 | `develop`/`staging` | Human runs `git checkout -b develop && git push -u origin develop` (same for `staging`) | Automated branch creation in CI | Branch creation is a repo operation no SDD phase or workflow performs. It is a tasks.md item and a hard prerequisite: the caller cannot fire on branches that do not exist. |

## Data Flow

```
push(main)                                   macos-14 runner                       homebrew-tap
   │                                                │                                    │
   ├─ detect job ── release-train-detect@main ──────┤                                    │
   │    should_release / release_type / next_version│                                    │
   ├─ (false) ─→ stop                               │                                    │
   └─ (true) ─→ macos-cask-release.yml@main ────────┤                                    │
                  1. checkout consumer (depth 0)    │                                    │
                  2. guard duplicate tag            │                                    │
                  3. VERSION=x Scripts/build-app.sh │ swift build → stamp → sign → ditto  │
                  4. shasum -a 256 → SHA_LOCAL      │                                    │
                  5. git push --atomic refs/tags/vX │                                    │
                  6. gh-release + .app.zip asset    │                                    │
                  7. re-download asset, assert sha  │                                    │
                  8. stable only: render template ──┼──→ git -C tap add/commit/push ────→│
                  9. stable only: sync main → develop, staging
```

Alpha/beta stop after step 6 with `prerelease: true`; the tap is never touched off `main`.

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `workflows/.github/workflows/macos-cask-release.yml` | Create | Reusable macOS build + release + cask publication |
| `portero/.github/workflows/release.yml` | Create | Caller on `develop`/`staging`/`main`; forwards `HOMEBREW_TAP_TOKEN` |
| `portero/Packaging/cask.rb.tmpl` | Create | Sole source of Cask body (name/desc/homepage/app/postflight/zap) |
| `portero/Scripts/build-app.sh` | Modify | `VERSION` env, PlistBuddy stamp before `codesign`, `ditto` zip |
| `portero/Resources/Info.plist` | Modify | `CFBundleShortVersionString`/`CFBundleVersion` → `0.0.0` dev sentinel |
| `homebrew-tap/Casks/portero.rb` | Generated | Overwritten by the first stable run; no manual PR |
| portero branches `develop`, `staging` | Create (manual) | Human `git push -u origin <branch>` before first run |

## Interfaces / Contracts

```yaml
# macos-cask-release.yml — workflow_call
inputs:  app_name (req) | cask_name | tap_repository ("sisques-labs/homebrew-tap")
         cask_template ("Packaging/cask.rb.tmpl") | build_script ("Scripts/build-app.sh")
         release_type (req) | next_version (req) | runner ("macos-14")
         sync_branches_after_stable ("")   # comma-separated; missing branches skipped
secrets: HOMEBREW_TAP_TOKEN (required: false — fail fast with ::error:: when release_type=stable and empty)
permissions: contents: write
```

```bash
VERSION=0.2.0 Scripts/build-app.sh   # → .build/Portero.app + .build/Portero-v0.2.0.app.zip
```

Template placeholders: `{{VERSION}}`, `{{SHA256}}` only. Post-render gate: file must match `^  sha256 "[0-9a-f]{64}"$` and contain no residual `{{`; otherwise fail before any tap commit.

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | None | No test target; `openspec/config.yaml` sets `tdd: false` |
| Script | `build-app.sh` stamping, signature, zip | Local `VERSION=9.9.9 Scripts/build-app.sh`; assert `defaults read .build/Portero.app/Contents/Info CFBundleShortVersionString`, `codesign --verify --deep`, unzip round-trip |
| Integration | Channel routing, no-op re-run | Push to `develop` → alpha prerelease, tap untouched; re-push with no commits → `should_release=false` |
| E2E | Cask correctness | `brew install --cask sisques-labs/tap/portero`, launch, verify version and no Gatekeeper block |

## Threat Matrix

| Boundary | Applicability | Design response | Verification |
|---|---|---|---|
| Documentation-like paths | N/A — no name-based file classification; the only generated path is a fixed rendered Cask | — | — |
| Git repository selection | Applicable — two checkouts in one job | Every tap operation uses explicit `git -C tap …`; never ambient cwd. Abort if `tap/.git` is absent | Manual run asserting consumer repo has zero staged changes after the tap commit |
| Commit state | Applicable | `git -C tap add Casks/<name>.rb` only — never `commit -a`; empty diff skips the commit (idempotent re-run). Consumer repo makes no release commit at all | Re-run same stable version → tap diff empty, no commit created |
| Push state | Applicable | Consumer: `git push --atomic origin refs/tags/${TAG}` with docker-release's 3-attempt retry and ancestor check. Tap: explicit `HEAD:refs/heads/<default>`; non-fast-forward → one fetch+rebase, then fail loud | Concurrent-push rehearsal on a scratch branch |
| PR commands | N/A — no `gh pr` automation anywhere in this change | — | — |

## Migration / Rollout

No data migration. Order: (1) merge workflows PR A; (2) human creates `develop` + `staging`; (3) human mints `HOMEBREW_TAP_TOKEN` (fine-grained, `homebrew-tap` contents:write) as a portero repo secret; (4) merge portero PR C; (5) first stable push regenerates the Cask. Rollback: delete `release.yml`, revert the tap commit, `gh release delete` + tag delete.

## Resolved Risks

- **Proposal's "broken Cask" premise: false, confirmed.** Verified against both the local clone at `homebrew-tap` (clean, up to date with `origin/main`) and the GitHub API directly. `Casks/portero.rb` has a valid 64-character `sha256` and the correct `com.sisqueslabs.portero.plist` zap path — no bug exists. The proposal and spec have been corrected accordingly; this change's motivation is automation (keeping the Cask in sync with future tags), not a bugfix.

## Open Questions

- [ ] Confirm the tap's default branch name (`main` assumed) before hardcoding the push refspec.
