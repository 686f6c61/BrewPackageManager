# Security policy

## Supported versions

Only the latest release line receives security fixes.

| Version | Supported |
|---------|-----------|
| 3.0.x   | Yes       |
| < 3.0   | No        |

## Threat model and accepted risks

BrewPackageManager executes the Homebrew binary on behalf of the user. That design imposes one deliberate trade-off, documented here so it is a decision and not an accident.

### App Sandbox is disabled (accepted risk)

The app is built with `ENABLE_APP_SANDBOX=NO`. This is required, not optional: the entire purpose of the app is to run `brew` (list, search, install, upgrade, cleanup, services), and the App Sandbox forbids executing arbitrary external binaries and reading Homebrew's prefix. A sandboxed build cannot do any useful work.

Mitigations in place:

- **No shell interpretation.** Commands run through `Process` with a direct `executableURL`; there is no `sh -c`, so user input is never parsed by a shell.
- **Argument hygiene.** User-typed input (search queries) is passed after an explicit `--` end-of-options separator so it cannot be interpreted as a `brew` flag.
- **Known brew locations only.** The Homebrew binary is resolved from standard installation paths, not from `PATH` or user-supplied locations.
- **Hardened Runtime** is enabled for Release builds.
- **No privilege escalation.** The app never asks for or uses elevated privileges; everything runs as the invoking user.
- **Network surface is minimal.** The only network call is an HTTPS request to the GitHub Releases API to check for app updates; release JSON is validated and nothing remote is executed. There is no auto-update: users download and install updates themselves.

### Local data

Operation history and settings are stored unencrypted in `UserDefaults`. They contain package names and timestamps only — no credentials and no personal data of third parties.

## Reporting a vulnerability

Please open a private security advisory on GitHub ([Security → Advisories](https://github.com/686f6c61/BrewPackageManager/security/advisories)) or contact the maintainer through the profile at [github.com/686f6c61](https://github.com/686f6c61). Reports are acknowledged as soon as possible and fixed in the next release.
