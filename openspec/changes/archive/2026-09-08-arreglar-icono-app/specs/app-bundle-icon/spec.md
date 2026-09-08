# App Bundle Icon Specification

## Purpose

Defines the icon asset, its declaration in the bundle's `Info.plist`, and the
build-script step that places the icon inside the assembled `Portero.app`
bundle, so Finder, Applications, "Get Info", and the Homebrew cask listing
render a distinct icon instead of the generic "unknown app" placeholder.

## Requirements

### Requirement: Icon Asset

The repository MUST contain a valid `.icns` icon asset at
`Resources/AppIcon.icns`, built with `iconutil`/`sips` (Command Line Tools
only) and containing the standard macOS icon sizes.

#### Scenario: Icon asset is present and valid

- GIVEN a checkout of the repository
- WHEN `Resources/AppIcon.icns` is inspected
- THEN the file MUST exist
- AND `iconutil -c iconset` (or equivalent inspection) MUST succeed against it, confirming it is a well-formed `.icns` with multiple icon sizes

### Requirement: Icon Declaration in Info.plist

`Resources/Info.plist` MUST declare `CFBundleIconFile` referencing the icon
asset's base name (without extension), so the assembled bundle knows which
resource file to use as its icon.

#### Scenario: Info.plist declares the icon file

- GIVEN `Resources/Info.plist`
- WHEN the plist is parsed
- THEN it MUST contain a `CFBundleIconFile` key
- AND its string value MUST match the base name of `Resources/AppIcon.icns` (i.e. `AppIcon`)

### Requirement: Icon Copied Into Bundle Before Signing

`Scripts/build-app.sh` MUST create `Contents/Resources/` inside the app
bundle and copy `Resources/AppIcon.icns` into it, and this step MUST occur
before the `codesign --force --deep --sign -` invocation, so the icon is
covered by the ad-hoc code signature and the signature is never invalidated
by a later file addition.

#### Scenario: Build script places the icon before codesign

- GIVEN a fresh run of `Scripts/build-app.sh`
- WHEN the script executes
- THEN `.build/Portero.app/Contents/Resources/AppIcon.icns` MUST exist immediately after the copy step
- AND the copy step MUST execute before the `codesign` invocation in the script

#### Scenario: Codesign verification succeeds after the icon copy

- GIVEN a built `.build/Portero.app` produced by `Scripts/build-app.sh`
- WHEN `codesign --verify .build/Portero.app` is run
- THEN it MUST exit successfully, confirming the icon addition did not break the signature

### Requirement: Build Succeeds With Icon Present

Adding the icon asset, plist key, and copy step MUST NOT break the existing
Swift build.

#### Scenario: Release build still succeeds

- GIVEN the repository with the icon asset, plist change, and build script change applied
- WHEN `swift build -c release` is run
- THEN it MUST complete successfully with no new build errors

### Requirement: Bundle Renders a Non-Generic Icon

The assembled `.app` bundle MUST present the placeholder icon (not the
generic system icon) when inspected by Finder.

#### Scenario: Finder shows the placeholder icon

- GIVEN a `.build/Portero.app` bundle built by `Scripts/build-app.sh`
- WHEN it is viewed in Finder or via "Get Info" (on a fresh copy or after clearing the icon cache)
- THEN it MUST display the placeholder icon instead of the generic application icon
