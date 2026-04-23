# Migration Status

This file tracks the live cutover from the legacy single-app layout to the two-app workspace layout.

## Baseline

- Shipping NumberGym source of truth: `apps/number_gym`
- Shared engine target: `packages/trainer_core`
- Number content target: `packages/number_gym_content`
- Verb scaffold target: `apps/verb_gym` + `packages/verb_gym_content`

Before each structural move, validate the current NumberGym behavior from `apps/number_gym`:

- intro screen layout and assets
- start training flow
- settings
- statistics
- about screen
- web build and Pages publish

## Already extracted

- `AppPalette` now comes from `trainer_core`
- logging primitives now come from `trainer_core`
- `CardProgress` and its Hive adapter now come from `trainer_core`
- `TrainingBackground` now comes from `trainer_core`
- `VoicesReady` now comes from `trainer_core`

These extractions are intentionally done through local shim files inside `apps/number_gym` so the rest of the app can keep stable imports during the migration.

## Next extraction candidates

- low-risk shared domain helpers that are already generic in naming and behavior
- settings/progress abstractions after storage semantics are aligned
- generic training flow pieces that do not contain NumberGym-specific copy or layout
- NumberGym content generation into `number_gym_content`

## Guardrails

- Do not change the shipped NumberGym UI while moving code.
- Do not move NumberGym-specific branding or copy into `trainer_core`.
- Do not delete root legacy code until `apps/number_gym` reaches modular parity and `apps/verb_gym` builds as a separate scaffold app.
