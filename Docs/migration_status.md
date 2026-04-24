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

## Validation Snapshot

Validated on April 24, 2026 with the supported workspace flow:

```powershell
pwsh ./tool/analyze_all.ps1
pwsh ./tool/test_all.ps1
```

Current result:

- `packages/trainer_core`: analyze green, 20 tests green
- `packages/number_gym_content`: analyze green, 10 tests green
- `apps/number_gym`: analyze green, 70 tests green

## Current Cutover State

The migration is no longer at the "mirror only" stage. The active NumberGym runtime already uses the shared package contracts for bootstrapping, catalog definition, stats loading, and training orchestration.

Current live runtime shape:

- `apps/number_gym/lib/app.dart` defines `numberGymConfig` and `numberGymDefinition`
- `apps/number_gym/lib/main.dart` opens Hive boxes from `numberGymConfig`
- `packages/number_gym_content` is the live source of NumberGym catalog, family ids, and supported languages
- `features/intro/ui/screens/intro_screen.dart` now uses shared `ProgressRepository`, `SettingsRepository`, and `TrainingStatsLoader(catalog: appDefinition.catalog)`
- intro menu navigation already opens package screens for settings, statistics, and debug
- `features/intro/ui/screens/about_screen.dart` already reads copy and URLs from `AppConfig`
- `features/training/ui/screens/training_screen.dart` keeps the branded NumberGym shell but runs on `TrainerController`
- branded training view-models and widgets already consume `trainer_core` state models such as `SpeakState`, `ChoiceState`, `ListenAndChooseState`, `ReviewPronunciationState`, `TrainingFeedback`, `TrainingCelebration`, and `SessionStats`
- silent auto-stop has been restored in `trainer_core` and is covered by `packages/trainer_core/test/trainer_auto_stop_test.dart`

## Extracted Or Directly Shared

These pieces are already extracted or are used directly from packages in the active runtime path:

- `AppConfig` / `TrainingAppDefinition`
- `AppPalette`
- logging primitives
- `CardProgress` and its Hive adapter
- `TrainingBackground`
- `VoicesReady`
- shared repositories: progress + settings
- shared session/daily helpers: summary, streak, session progress, stats recording
- shared training orchestration: scheduler, progress manager, task card flow, task progress recorder, `TrainerController`, `TrainerSession`
- NumberGym content definition and language material in `packages/number_gym_content`

Some of the older NumberGym files still exist as local mirrors on disk, but they are no longer the active runtime source of truth.

## Runtime-Owned Local Surface

These areas are still intentionally app-local because they are part of the branded NumberGym shell rather than reusable engine code:

- bootstrap and branded app shell: `apps/number_gym/lib/main.dart`, `apps/number_gym/lib/app.dart`
- branded intro/about flow: `features/intro/ui/screens/intro_screen.dart`, `features/intro/ui/screens/about_screen.dart`
- branded training shell: `features/training/ui/screens/training_screen.dart`
- branded training widgets and view-models under `features/training/ui/`
- local reward media resolution and slider peek behavior
- NumberGym branding/assets under the app

This is the surface that should remain after the engine/content cutover is complete.

## Legacy Still On Disk

The largest remaining problem is no longer "missing shared abstractions". It is leftover legacy code and tests that still mirror the old app-local engine.

### Dead local UI already removed

The old app-local settings/statistics/debug UI that became unreachable after the `IntroScreen` cutover has now been deleted:

- `apps/number_gym/lib/features/training/ui/screens/settings_screen.dart`
- `apps/number_gym/lib/features/training/ui/screens/statistics_screen.dart`
- `apps/number_gym/lib/features/training/ui/screens/debug_settings_screen.dart`
- `apps/number_gym/lib/features/training/ui/screens/training_item_type_x.dart`
- `apps/number_gym/lib/features/training/ui/screens/widgets/stats_card_surface.dart`
- `apps/number_gym/lib/features/training/ui/screens/widgets/streak_card.dart`

### App-local legacy engine still present on disk

These directories still contain the old NumberGym engine mirror:

- `apps/number_gym/lib/features/training/domain/`
- `apps/number_gym/lib/features/training/data/`
- `apps/number_gym/lib/features/training/languages/`

Most of that code is no longer needed by the active app runtime. It remains mainly because legacy tests still import it directly.

### Root legacy mirror still present

The repository root still contains transitional legacy code:

- root `lib/`
- root `test/`
- root `lib/tts/voices_ready_stub.dart`
- root `lib/tts/voices_ready_web.dart`

Root `test/` is not part of the supported validation flow anymore, so it can silently drift if it is not removed.

## Test Split Status

The test split has started, but it is not finished.

Already moved to `packages/trainer_core/test`:

- `answer_matcher_test.dart`
- `card_timer_test.dart`
- `daily_study_summary_test.dart`
- `day_key_test.dart`
- `session_lifecycle_tracker_test.dart`
- `session_progress_plan_test.dart`
- `session_stats_recorder_test.dart`
- `study_streak_test.dart`
- `trainer_auto_stop_test.dart`

Already moved to `packages/number_gym_content/test`:

- `number_gym_definition_test.dart`
- `number_words_test.dart`
- `time_words_test.dart`

Still sitting in `apps/number_gym/test` as legacy-domain tests:

- `answer_matcher_test.dart` (duplicate coverage now exists in `trainer_core`)
- `number_pronunciation_runtime_test.dart`
- `phone_cards_test.dart`
- `progress_manager_cluster_test.dart`
- `progress_repository_test.dart`
- `settings_repository_test.dart`
- `task_card_flow_test.dart`
- `task_progress_recorder_test.dart`
- `task_scheduler_test.dart`
- `training_celebration_formatter_test.dart`
- `training_services_test.dart`
- `training_session_behavior_test.dart`
- `training_stats_loader_test.dart`

Tests that should remain app-level after cleanup:

- `celebration_media_resolver_test.dart`
- `slider_peek_test.dart`
- `training_feedback_view_model_test.dart`
- widget/integration tests such as `widget_test.dart`

## What Remains To Do

The next steps are now straightforward:

1. Finish moving legacy tests to the correct package boundaries.
   - Move shared engine tests to `packages/trainer_core/test`.
   - Move NumberGym content tests to `packages/number_gym_content/test`.
   - Rewrite `training_session_behavior_test.dart` against `TrainerSession` / `TrainerController` instead of mechanically carrying the old test forward.
   - Leave only app-shell, branding, and integration coverage in `apps/number_gym/test`.

2. Remove the old app-local engine mirror once tests stop depending on it.
   - Delete `apps/number_gym/lib/features/training/domain/`
   - Delete `apps/number_gym/lib/features/training/data/`
   - Delete `apps/number_gym/lib/features/training/languages/`
   - Delete obsolete test helpers that only support the old engine

3. Remove the root legacy mirror last.
   - Delete root `lib/`
   - Delete root `test/`
   - Delete root-only `tts` leftovers

## Guardrails

- Do not change the shipped NumberGym UI while removing the remaining legacy mirror.
- Do not move NumberGym-specific branding, reward media, or app copy into `trainer_core`.
- Do not keep compatibility layers around once the active runtime is already on package contracts.
- Do not delete root legacy code until `apps/number_gym` no longer depends on the old mirror and `apps/verb_gym` still builds as a separate scaffold app.
