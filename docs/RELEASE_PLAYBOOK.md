# Release Playbook

## 1) Prepare Branch

1. Ensure tests pass.
2. Confirm docs are updated for behavior changes.
3. Confirm version references are aligned (`Info.plist`, project settings, scripts, README, changelog).

## 2) Update Changelog

- Add release section with:
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

Unit tests:

```bash
xcodebuild \
  -project BrewPackageManager/BrewPackageManager.xcodeproj \
  -scheme BrewPackageManager \
  -configuration Debug \
  -derivedDataPath .derived-audit-clean \
  CODE_SIGNING_ALLOWED=NO \
  test -only-testing:BrewPackageManagerTests
```

DMG build:

```bash
./create-dmg.sh
```

## 4) Smoke Test DMG

1. Install app from DMG into `/Applications`.
2. Launch and verify startup.
3. Run one real upgrade operation.
4. Validate pinned package skip behavior.
5. Open settings and verify diagnostics panel loads.

## 5) Publish

1. Commit release changes.
2. Create tag:

```bash
git tag v1.8.0
git push origin main --tags
```

3. Create GitHub release:
  - Title: `v1.8.0`
  - Body from changelog.
  - Attach DMG from `dmg/`.

## 6) Post-release

1. Monitor issues for first 48h.
2. Capture regressions and tag as release follow-ups.
3. Update `COMMUNITY_DEV_PLAN.md` milestone status if release included planned items.
