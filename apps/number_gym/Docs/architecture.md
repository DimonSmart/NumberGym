# Architecture

This document describes the current active implementation.

## High-level layout

- `apps/number_gym` is the branded shell.
- `packages/number_gym_content` owns NumberGym content and dynamic card generation.
- `packages/trainer_core` owns the shared training engine, matcher, repositories, and reusable screens.

Inside `apps/number_gym/lib`, only the shell stays local:
- `main.dart`: bootstrap, Hive registration, guarded startup;
- `app.dart`: `AppConfig` and `TrainingAppDefinition` composition;
- `home_screen.dart`: branded landing page and navigation;
- `features/intro/ui/screens/about_screen.dart`: app-specific about page.

## Runtime flow

- `main.dart` initializes Flutter bindings, error logging, and Hive boxes.
- `app.dart` creates `numberGymConfig` and `numberGymDefinition` through `buildNumberGymAppDefinition(...)`.
- `NumberGymHomeScreen` shows branded entry actions and opens `trainer_core` screens:
  - `TrainingScreen`
  - `SettingsScreen`
  - `StatisticsScreen`
  - `DebugSettingsScreen`
- `trainer_core` reads the catalog from `number_gym_content`, then runs scheduling, runtime selection, matching, progress, and statistics.

## Dependency policy

- `apps/number_gym` should depend on package APIs, not re-implement training domain logic locally.
- `number_gym_content` may depend on `trainer_core` models, but owns NumberGym-specific wording and generation rules.
- `trainer_core` stays product-neutral and only grows when NumberGym cannot be expressed through the existing exercise model.

This is intentionally a package split, not a compatibility layer. The app shell should not keep a second copy of training models or scheduling code.

## Testing expectations

- `packages/trainer_core/test`: matcher, learning params, scheduling/progress behavior.
- `packages/number_gym_content/test`: family coverage, language resources, dynamic cards, accepted variants.
- `apps/number_gym/test`: app-shell smoke, navigation, branding, and integration-level checks only.

## Persistence and shipping

- Local persistence uses Hive boxes opened by the app shell.
- Shipping entrypoints stay at repo root:
  - `tool/run_number_gym.ps1`
  - `tool/publish_number_gym_web.ps1`

## Review checklist

1. Does `apps/number_gym` stay a shell instead of rebuilding training logic locally?
2. Does new NumberGym-specific behavior belong in `number_gym_content` instead of `trainer_core`?
3. Is `trainer_core` still generic and minimal?
4. Are tests placed at the package boundary that owns the behavior?
5. Do root shipping scripts still work after the change?
