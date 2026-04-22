# Architecture

This document describes the current implementation, not a target-state design.

## High-level layout

- Feature-first structure under `lib/features/`.
- Main feature is `lib/features/training/`.
- Layers inside feature:
  - `ui/`: screens, widgets, view models;
  - `domain/`: session orchestration, task scheduling, runtimes, business rules;
  - `data/`: repositories and local persistence models.

## Runtime flow

- `main.dart` builds repositories/services and creates app root.
- `TrainingController` (`ChangeNotifier`) is the UI-facing facade.
- `TrainingSession` is the core orchestrator of one training flow.
- `TrainingSession` delegates focused responsibilities to small domain components:
  - `TaskScheduler`;
  - `ProgressManager`;
  - `TaskCardFlow`;
  - `TaskProgressRecorder`;
  - `SessionLifecycleTracker`;
  - `SessionStatsRecorder`;
  - `RuntimeCoordinator`;
  - `FeedbackCoordinator`.

## Dependency policy

The project is intentionally pragmatic and close to a monolith for delivery speed.

- Preferred direction:
  - `ui -> domain`;
  - `domain -> data` through repository interfaces;
  - persistence details stay in `data`.
- Practical exceptions exist:
  - some domain orchestration classes use Flutter/runtime packages directly
    (`kDebugMode`, speech package models).

When reviewing changes, prefer reducing coupling and moving pure logic into small
testable classes rather than enforcing strict layering at any cost.

## State management

- Global training state is exposed by `TrainingController`.
- UI subscribes via `ChangeNotifier` listeners.
- Per-task runtime state is owned by `RuntimeCoordinator` and passed through
  immutable `TaskState` objects.

## Persistence

- Local persistence uses Hive.
- Settings and progress are scoped by selected language.
- Session daily stats and streak are stored in settings storage.

## Testing expectations

- Domain helpers and coordinators should have focused unit tests.
- Session-level behavior should be covered by integration-like domain tests
  (for example `training_session_behavior_test.dart`).
- Repository/storage behavior should be covered separately.

## Review checklist

1. Is responsibility split clear, or did a god object grow again?
2. Are new dependencies truly needed in each class?
3. Is storage access still behind repositories?
4. Are edge cases covered by tests (timeouts, unavailable services, empty pools)?
5. Does documentation stay aligned with actual behavior?
