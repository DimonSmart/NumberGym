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

## Legacy Surface Still Mirrored

Current repo state is still largely a mirror migration, not a finished extraction:

- `lib/` at the repository root and `apps/number_gym/lib/` still mirror almost the same Dart surface.
- Only these NumberGym files are reduced to package shims today:
  - `core/theme/app_palette.dart`
  - `core/logging/app_logger.dart`
  - `core/logging/app_log_buffer.dart`
  - `features/training/data/card_progress.dart`
  - `features/training/ui/widgets/training_background.dart`
  - `tts/voices_ready.dart`
- Root-only legacy leftovers still present in `lib/tts/`:
  - `voices_ready_stub.dart`
  - `voices_ready_web.dart`

The largest generic-looking areas that still exist as app-local legacy implementations instead of direct `trainer_core` use are:

- storage and progress: `progress_repository.dart`, `settings_repository.dart`, `progress_manager.dart`
- daily/session/streak helpers: `day_key.dart`, `daily_session_stats.dart`, `daily_study_summary.dart`, `session_progress_plan.dart`, `session_lifecycle_tracker.dart`, `session_stats_recorder.dart`, `study_streak.dart`, `study_streak_service.dart`
- reusable services: `tts_service.dart`, `speech_service.dart`, `audio_recorder_service.dart`, `azure_speech_service.dart`, `sound_wave_service.dart`, `keep_awake_service.dart`, `internet_checker.dart`, `card_timer.dart`, `answer_matcher.dart`, `feedback_coordinator.dart`, `runtime_coordinator.dart`
- generic training flow: `task_availability.dart`, `task_card_flow.dart`, `task_progress_recorder.dart`, `task_runtime.dart`, `task_scheduler.dart`, `training_services.dart`, `training_stats_loader.dart`
- generic training UI: `training_screen.dart`, `settings_screen.dart`, `statistics_screen.dart`, `debug_settings_screen.dart`

The main NumberGym-specific areas that are still local and not yet split away from the legacy mirror are:

- bootstrap and branded app shell: `lib/main.dart`, `lib/app.dart`, `features/intro/ui/screens/intro_screen.dart`, `features/intro/ui/screens/about_screen.dart`
- NumberGym content/data: `number_cards.dart`, `phone_cards.dart`, `time_cards.dart`
- NumberGym content orchestration: `training_catalog.dart`, `task_registry.dart`, `task_runtime_factory.dart`, `training_task.dart`, `training_item.dart`, `training_outcome.dart`, `training_state.dart`, `training_session.dart`
- NumberGym-specific tasks and runtimes under `features/training/domain/tasks/` and `features/training/domain/runtimes/`
- NumberGym language material under `features/training/languages/`

## Next extraction candidates

- low-risk shared domain helpers that are already generic in naming and behavior
- settings/progress abstractions after storage semantics are aligned
- generic training flow pieces that do not contain NumberGym-specific copy or layout
- NumberGym content generation into `number_gym_content`

## Guardrails

- Do not change the shipped NumberGym UI while moving code.
- Do not move NumberGym-specific branding or copy into `trainer_core`.
- Do not delete root legacy code until `apps/number_gym` reaches modular parity and `apps/verb_gym` builds as a separate scaffold app.
