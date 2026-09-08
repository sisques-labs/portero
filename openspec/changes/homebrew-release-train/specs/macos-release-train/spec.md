# Macos Release Train Specification

## Purpose

Tag-driven, three-channel (alpha/develop, beta/staging, stable/main) release
automation for Portero: detects whether a channel needs a release, stamps the
app version, builds and packages the `.app.zip`, and publishes a GitHub
Release. Implemented as a reusable workflow (`macos-cask-release.yml` in
`sisques-labs/workflows`) called by a thin workflow in `portero`.

## Requirements

### Requirement: Channel Detection
The reusable workflow MUST invoke the existing `release-train-detect`
composite action, unchanged, to resolve `should_release`, `release_type`,
`next_version`, and `next_tag` for the triggering branch, mapping
`develop`→alpha, `staging`→beta, `main`→stable.

#### Scenario: New commits on develop
- GIVEN unreleased commits exist on `develop` since the last alpha tag
- WHEN the caller workflow runs on `develop`
- THEN `release-train-detect` reports `should_release=true`, `release_type=alpha`, and a `next_tag` incrementing the alpha channel

#### Scenario: No unreleased commits
- GIVEN no commits exist since the last tag on the triggering branch
- WHEN the caller workflow runs
- THEN `should_release=false` AND no version stamp, build, tag, or Release is produced

### Requirement: Caller Secret and Output Forwarding
The portero caller workflow MUST invoke the reusable workflow with `secrets:
inherit` or explicit `HOMEBREW_TAP_TOKEN` forwarding, and MUST NOT re-implement
detection, stamping, build, or release logic locally.

#### Scenario: Caller forwards tap token
- GIVEN the reusable workflow requires `HOMEBREW_TAP_TOKEN` for stable-channel publication
- WHEN portero's caller workflow invokes `macos-cask-release.yml`
- THEN the caller's `secrets:` block passes `HOMEBREW_TAP_TOKEN` through unchanged

### Requirement: Version Stamping
When `should_release=true`, the workflow MUST write `next_version` into
`Resources/Info.plist`'s `CFBundleShortVersionString` and `next_tag` (or its
numeric build form) into `CFBundleVersion` before building, replacing the
current hardcoded `1.0`.

#### Scenario: Stamp precedes build
- GIVEN `next_version` is `1.2.0` and `next_tag` is `v1.2.0`
- WHEN the workflow stamps `Info.plist`
- THEN `CFBundleShortVersionString` reads `1.2.0` AND `CFBundleVersion` reflects the release tag before `swift build -c release` runs

### Requirement: Build and Package
The workflow MUST run `swift build -c release` and package the app via
`Scripts/build-app.sh`, producing an ad-hoc signed `.app.zip`, without
notarization.

#### Scenario: Successful package
- GIVEN the stamped source builds cleanly
- WHEN `build-app.sh` runs
- THEN an ad-hoc codesigned `Portero-v{version}.app.zip` artifact is produced

#### Scenario: Build failure aborts release
- GIVEN `swift build -c release` fails
- WHEN the workflow reaches the build step
- THEN the workflow MUST fail before tagging, releasing, or touching the tap

### Requirement: Tag and GitHub Release
On `should_release=true`, the workflow MUST create and push the git tag
`next_tag`, then create a GitHub Release attaching the `.app.zip`, with
`generate_release_notes: true` and `prerelease: true` when `release_type` is
not `stable`.

#### Scenario: Stable release is not marked prerelease
- GIVEN `release_type=stable` on `main`
- WHEN the Release is created
- THEN `prerelease` is `false` AND release notes are auto-generated

#### Scenario: Alpha/beta release is marked prerelease
- GIVEN `release_type` is `alpha` or `beta`
- WHEN the Release is created
- THEN `prerelease` is `true`

### Requirement: Stable Branch Sync
After a successful stable-channel release, the workflow MUST sync `main` back
into `develop` and `staging` to prevent drift.

#### Scenario: Sync after stable release
- GIVEN a stable release just published from `main`
- WHEN the sync step runs
- THEN `develop` and `staging` are fast-forwarded or merged to include the released commit

#### Scenario: Sync skipped for non-stable channels
- GIVEN `release_type` is `alpha` or `beta`
- WHEN the workflow completes
- THEN no branch sync is attempted
