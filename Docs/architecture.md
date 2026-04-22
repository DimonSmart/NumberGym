# Workspace Architecture

This document describes the target working shape of the repository during the monorepo migration.

## Working Units

Only these directories are active sources of truth:

- `apps/number_gym`
- `packages/trainer_core`
- `packages/number_gym_content`

These directories are intentionally frozen:

- `apps/verb_gym`
- `packages/verb_gym_content`

The old root Flutter app is transitional legacy code. It may still exist on disk until the cutover is complete, but new work should not be anchored to root `lib/`, root `test/`, or root platform folders.

## Responsibility Split

- `apps/number_gym`
  - app bootstrap
  - branding
  - app-specific screens and integration glue
  - app-level tests
- `packages/trainer_core`
  - training session orchestration
  - scheduling
  - progress and settings repositories
  - reusable runtime services
  - shared training UI shell
- `packages/number_gym_content`
  - number/time/phone content definitions
  - language resources
  - content-specific accepted variants and distractor rules
  - content tests

## Target Dependency Direction

- `apps/* -> packages/*`
- `packages/number_gym_content -> packages/trainer_core`
- `packages/trainer_core` must not depend on app-specific branding or content packages

`trainer_core` should remain reusable across multiple trainer apps. Branding, copy, assets, and content metadata belong in the app or content packages, not in the shared engine.

## Validation Flow

The root scripts are the supported way to validate the active workspace:

```powershell
pwsh ./tool/bootstrap.ps1
pwsh ./tool/analyze_all.ps1
pwsh ./tool/test_all.ps1
```

By default these scripts validate only the active migration path: `number_gym`, `trainer_core`, and `number_gym_content`.

## Operational Entry Point

For shipping tasks, `apps/number_gym` is the operational Flutter app.

- Phone/device runs should happen from `tool/run_number_gym.ps1`
- Web publishing should happen from `tool/publish_number_gym_web.ps1`

Legacy root build scripts must not build the root Flutter app anymore.

## Testing Boundaries

The intended long-term test split is:

- `packages/trainer_core/test`: shared algorithms and orchestration
- `packages/number_gym_content/test`: NumberGym-specific content rules
- `apps/number_gym/test`: app shell, branding, and integration behavior

Root `test/` is legacy and should disappear once the cutover is complete.

## Migration Rule

If a change can be expressed in `apps/*` or `packages/*`, put it there. Do not create new root-level product code while the cutover is in progress.
