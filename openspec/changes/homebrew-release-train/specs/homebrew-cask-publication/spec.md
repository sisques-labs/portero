# Homebrew Cask Publication Specification

## Purpose

Cross-repo publication of a correct, installable Homebrew Cask for Portero:
computing the release checksum, rendering `Casks/portero.rb`, and pushing it
to `sisques-labs/homebrew-tap` — stable channel only.

## Requirements

### Requirement: Stable-Only Publication
The system MUST publish or update the Cask only when `release_type=stable`.
Alpha and beta releases MUST NOT clone, modify, or push to
`sisques-labs/homebrew-tap`.

#### Scenario: Stable release updates the tap
- GIVEN a stable Release with its `.app.zip` asset was just published
- WHEN the Cask publication step runs
- THEN `sisques-labs/homebrew-tap/Casks/portero.rb` is updated and pushed

#### Scenario: Alpha/beta leaves the tap untouched
- GIVEN `release_type` is `alpha` or `beta`
- WHEN the workflow completes
- THEN no commit or push occurs against `sisques-labs/homebrew-tap`

### Requirement: Checksum Computation
The system MUST compute a valid 64-character SHA-256 checksum (`shasum -a
256`) of the released `.app.zip` asset and embed it in the Cask's `sha256`
field.

#### Scenario: Valid checksum embedded
- GIVEN the `.app.zip` asset for the stable release
- WHEN the checksum step runs
- THEN the resulting `sha256` value is exactly 64 hexadecimal characters and matches the asset

#### Scenario: Checksum length invariant holds on every regeneration
- GIVEN any stable release's `.app.zip` asset
- WHEN the Cask is regenerated
- THEN the resulting `sha256` MUST always be exactly 64 lowercase hexadecimal characters, computed fresh from that asset — never carried over or hardcoded from a prior release

### Requirement: Cask Correctness
The rendered Cask MUST use the correct `zap trash` path
`~/Library/Preferences/com.sisqueslabs.portero.plist`, MUST substitute the
current release's version and checksum, and MUST retain a `postflight`
stanza running `xattr -dr com.apple.quarantine` since the app is ad-hoc
signed without notarization.

#### Scenario: Zap path invariant holds on every regeneration
- GIVEN the app's `CFBundleIdentifier` is `com.sisqueslabs.portero`
- WHEN the Cask is regenerated
- THEN the `zap trash` path reads `~/Library/Preferences/com.sisqueslabs.portero.plist`, matching the bundle identifier exactly

#### Scenario: Quarantine strip preserved
- GIVEN the app is ad-hoc signed with no notarization
- WHEN the Cask is rendered
- THEN it MUST include a `postflight` block executing `xattr -dr com.apple.quarantine`

### Requirement: Cross-Repo Push
The system MUST clone or update the `sisques-labs/homebrew-tap` repository,
commit the regenerated `Casks/portero.rb`, and push using the
`HOMEBREW_TAP_TOKEN` secret received from the reusable workflow's `secrets:`
block.

#### Scenario: Push succeeds with valid token
- GIVEN a valid `HOMEBREW_TAP_TOKEN` with write access to the tap
- WHEN the push step runs
- THEN the commit lands on the tap's default branch

#### Scenario: Missing or invalid token fails fast
- GIVEN `HOMEBREW_TAP_TOKEN` is absent or lacks write access
- WHEN the push step runs
- THEN the workflow MUST fail with a clear, actionable error identifying the missing/invalid token, without silently skipping the tap update

### Requirement: Idempotent Regeneration
Re-running stable publication for a version whose Cask is already correct
MUST produce no functional diff.

#### Scenario: No-op on already-correct Cask
- GIVEN the existing hand-maintained Cask already matches what generation would produce for the current stable version
- WHEN the publication step runs again
- THEN the resulting commit, if any, is a no-op diff
