# BrewPackageManager Docs

This directory contains developer-facing documentation for the application and the 2.0 release train.

## Document Map

- `APP_OVERVIEW.md`
  - Product scope, runtime requirements, terminology, and core user journeys.
- `ARCHITECTURE.md`
  - Layered architecture, concurrency model, startup flow, and the current 2.0 UI/runtime model.
- `MODULE_REFERENCE.md`
  - Folder-by-folder and file-by-file reference of the codebase.
- `WORKFLOWS.md`
  - End-to-end runtime workflows (refresh, upgrades, search/install, services, cleanup, updates).
- `DEVELOPMENT_GUIDE.md`
  - Local setup, build/test commands, Docker audit commands, and coding expectations.
- `TESTING_STRATEGY.md`
  - Automated and manual test strategy, smoke checks, and diagnostics collection.
- `RELEASE_PLAYBOOK.md`
  - Release checklist and repeatable process for shipping DMGs.
- `AUDIT_2_0.md`
  - Current audit results, external-tool findings, resolved legacy status, and 2.0 release blockers.

## Suggested Reading Order

1. `APP_OVERVIEW.md`
2. `ARCHITECTURE.md`
3. `AUDIT_2_0.md`
4. `MODULE_REFERENCE.md`
5. `WORKFLOWS.md`
6. `DEVELOPMENT_GUIDE.md`
7. `TESTING_STRATEGY.md`
8. `RELEASE_PLAYBOOK.md`

## Maintenance Rule

When a change alters behavior, architecture, release steps, or contributor workflow, update the corresponding file in this folder in the same pull request.
