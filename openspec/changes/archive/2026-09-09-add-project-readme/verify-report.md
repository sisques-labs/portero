```yaml
schema: gentle-ai.verify-result/v1
verdict: pass
blockers: 0
critical_findings: 0
requirements: 4/4
scenarios: 6/6
test_command: none (no automated test suite; tdd: false)
build_command: swift build -c release
build_exit_code: 0
```

# Verify Report: add-project-readme

**Change**: Project README (installation, usage, development, requirements/license)

## Requirements Coverage

| Requirement | Status | Evidence |
|---|---|---|
| Root README documents installation | PASS | `README.md` "Installation" section: Homebrew (`brew install --cask sisques-labs/tap/portero`, matching `Packaging/cask.rb.tmpl` and the tap name confirmed in `openspec/changes/homebrew-release-train/design.md`) + manual `swift build -c release` |
| Root README documents usage | PASS | `README.md` "Usage" section: view/filter/kill, matching `StatusBarController.swift` and `FilterFieldView.swift` |
| Root README documents development setup | PASS | `README.md` "Development" section: `Sources/Portero` tree matches actual file layout; references `Scripts/build-app.sh`, `Scripts/generate-app-icon.swift`, `.github/workflows/release.yml` |
| Root README states requirements and license status | PASS | `README.md` "Requirements" states macOS 13 (matches `Package.swift` `.macOS(.v13)`); "License" states no `LICENSE` file present (confirmed: none exists in repo) |

## Build Verification

`swift build -c release` → exit 0, no source changes in this commit (docs-only).

## Findings

None.

## Notes

- Homebrew tap name (`sisques-labs/tap` → `sisques-labs/homebrew-tap` repo) verified against `openspec/changes/homebrew-release-train/design.md`, not guessed.
- No `LICENSE` file exists; the README discloses this rather than fabricating a license, per proposal scope.
