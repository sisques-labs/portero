# Spec Delta: project-readme

## ADDED Requirements

### Requirement: Root README documents installation
The repository root `README.md` MUST document at least one Homebrew installation path and one manual build path.

#### Scenario: Homebrew installation
- **GIVEN** a user has Homebrew installed
- **WHEN** they follow the README's installation section
- **THEN** the documented command installs Portero from the `sisques-labs/homebrew-tap` tap without requiring them to read source code

#### Scenario: Manual build
- **GIVEN** a user has Swift 5.9+ toolchain installed and no Homebrew
- **WHEN** they follow the README's manual build instructions
- **THEN** `swift build -c release` (or the documented equivalent) succeeds using only commands listed in the README

### Requirement: Root README documents usage
The README MUST describe what the running application does and how a user interacts with it from the menu bar.

#### Scenario: New user reads usage section
- **GIVEN** a user has installed and launched Portero
- **WHEN** they read the README's usage section
- **THEN** they understand how to view listening ports, filter the list, and kill a process, without needing to inspect `Sources/`

### Requirement: Root README documents development setup
The README MUST describe how a contributor builds and runs the project locally, including the role of `Scripts/build-app.sh` and the release workflow.

#### Scenario: Contributor sets up locally
- **GIVEN** a contributor has cloned the repository
- **WHEN** they follow the README's development section
- **THEN** they can build the `.app` bundle locally and locate the relevant source directories without additional guidance

### Requirement: Root README states requirements and license status
The README MUST state the minimum macOS version and MUST NOT claim a license the repository does not have.

#### Scenario: License status is checked
- **GIVEN** the repository has no `LICENSE` file at the time of this change
- **WHEN** a reader checks the README's license section
- **THEN** it accurately states no license file is present, rather than asserting a specific license
