# Proposal: Project README

## Intent

`README.md` currently has only a title and a single description line. Anyone landing on the repo — a potential user via the Homebrew cask, or a contributor — has no way to install, use, or build the project from the README alone. This change writes a real README covering installation, usage, development, and requirements/license.

## Scope

### In Scope

- Installation: Homebrew cask (`brew install --cask sisques-labs/portero/portero` pattern, matching `Packaging/cask.rb.tmpl`) and manual build via `swift build -c release`.
- Usage: what the app does from the menu bar — view listening ports, filter, kill a process.
- Development: local setup, `Sources/Portero` structure, `Scripts/build-app.sh`, `Scripts/generate-app-icon.swift`, how the release workflow (`.github/workflows/release.yml`) is triggered.
- Requirements: macOS 13+ (from `Package.swift`), no `Tests/` directory (no automated suite yet).
- License: repo has **no `LICENSE` file**. The README will state this honestly rather than claim a license that doesn't exist, and flag it as a follow-up decision for the maintainer.

### Out of Scope

- Adding a `LICENSE` file (separate decision, not implied by writing docs).
- Screenshots/GIFs of the running app (no rendering environment available in this session to capture real ones; placeholder callout instead if needed).
- CI badges beyond a simple release-workflow status badge (optional, low-risk addition only if trivial).

## Capabilities

### New Capabilities

- `project-readme`: the repository root documents install, usage, development, and requirements so a new user or contributor is self-sufficient without reading source.

### Modified Capabilities

- None.

## Approach

Single markdown file rewrite. Content is sourced directly from existing repo artifacts (`Package.swift`, `Scripts/build-app.sh`, `Packaging/cask.rb.tmpl`, `.github/workflows/release.yml`, `Sources/Portero` tree) — no new tooling, no code changes.

## Affected Areas

| Area | Impact | Description |
|------|--------|--------------|
| `README.md` | Modified | Full rewrite: install, usage, development, requirements/license |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Homebrew install instructions drift from the actual cask/tap name | Low | Copied verbatim from `Packaging/cask.rb.tmpl` and the release workflow, not guessed |
| Claiming a license that doesn't exist | Low | README explicitly states "no license file yet" instead of fabricating one |

## Rollback Plan

Fully revertible: `git revert` the change commit. No runtime, build, or data impact — documentation only.

## Dependencies

None.

## Success Criteria

- [ ] README explains how to install via Homebrew and via manual `swift build`.
- [ ] README explains what the app does and how to use it from the menu bar.
- [ ] README explains how to develop/build locally and points to the release workflow.
- [ ] README states macOS 13+ requirement and the current (absent) license status.
- [ ] No factual claim in the README is unverifiable against the current repo state.
