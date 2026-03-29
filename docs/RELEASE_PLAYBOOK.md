# Release Playbook

## 1) Prepare Branch

1. Ensure tests pass.
2. Run the Docker audit lane and capture logs.
3. Confirm docs are updated for behavior changes.
4. Confirm version references are aligned (`Info.plist`, project settings, scripts, README, changelog).

## 2) Update Changelog

- Add a release section with:
  - Fixed
  - Changed
  - Added (if applicable)
- Include notable runtime-impacting fixes and user-visible changes.

## 3) Build and Validate

Debug build:

```bash
xcodebuild \
  -project BrewPackageManager/BrewPackageManager.xcodeproj \
  -scheme BrewPackageManager \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Full tests:

```bash
xcodebuild \
  -project BrewPackageManager/BrewPackageManager.xcodeproj \
  -scheme BrewPackageManager \
  -destination 'platform=macOS' \
  -derivedDataPath .derived-audit-2 \
  test
```

Docker audit:

```bash
./scripts/audit-swift-in-docker.sh
```

DMG build:

```bash
./create-dmg.sh
```

## 4) Smoke Test DMG

1. Install app from DMG into `/Applications`.
2. Launch and verify startup.
3. Run one real update operation.
4. Validate pinned-package skip behavior.
5. Validate cleanup/service flows.
6. Verify screenshots/README if they changed for the release.

## 5) Publish

1. Commit release changes.
2. Create tag:

```bash
git tag v2.0.0
git push origin main --tags
```

3. Create GitHub release:
  - Title: `v2.0.0`
  - Body from changelog.
  - Attach DMG from `dmg/`.

## 6) Post-release

1. Monitor issues for the first 48h.
2. Capture regressions and tag them as release follow-ups.
3. Update `docs/AUDIT_2_0.md` and the release notes if the shipped scope or follow-up priorities changed during release stabilization.
