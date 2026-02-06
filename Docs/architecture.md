# Architecture



This document describes the intended architecture of the app and the rules used for reviews.



## High-level structure



- **Feature-first** layout under `lib/features/`.

  - `lib/features/intro/`

  - `lib/features/training/`

- Each feature is **layered internally**:

  - `ui/` (Flutter widgets, screens, UI state)

  - `domain/` (pure business logic, entities, use cases, repository interfaces)

  - `data/` (implementations: persistence, DTOs, mappers, Hive adapters, repositories)

- Cross-feature and shared components:

  - `lib/core/` – shared utilities, base abstractions, shared widgets, common services

  - `lib/tts/` – text-to-speech integration and related helpers



## Dependency rules (must hold)



### Within a feature



- `ui` may depend on: `domain`, `core`, `tts`

- `data` may depend on: `domain`, `core`, `tts` (only when truly shared)

- `domain` may depend on: `core` only



### Forbidden dependencies



- `domain` must NOT depend on:

  - Flutter (`package:flutter/...`)

  - UI framework code (widgets, BuildContext)

  - persistence/infra (Hive, Box, platform channels, IO)

- `ui` must NOT access persistence directly:

  - No direct `Hive` / `Box` usage in `ui`

  - No direct data sources in `ui`

  - UI talks to `domain` via use cases / controllers, not via raw storage



### Cross-feature boundaries



- Features should not import each other directly.

- Shared behavior must go to `core/` (or be duplicated if truly feature-specific).

- `core/` must not depend on any feature module.



## State management



The app intentionally does not use external state-management frameworks

(no `provider`, `riverpod`, `bloc`, etc.).



### Global training state



- Global training state lives in `TrainingController` (`ChangeNotifier`).

- UI subscribes via `AnimatedBuilder` (or equivalent notifier listeners).

- Ownership / lifecycle:

  - `TrainingController` has a single owner at the training flow level.

  - The owner must call `dispose()` when the flow ends.



Rules:

- `TrainingController` should not become a "god object".

  - UI orchestration may live in the controller.

  - Business logic belongs to `domain` (use cases).

  - Persistence details belong to `data` (repositories, adapters).

- Avoid doing heavy work inside `notifyListeners()` chains.

- Avoid leaking listeners/streams: every subscription must be canceled/disposed.



### Local widget state



- Local, purely visual state may use `setState()` inside screens/widgets

  (e.g., settings toggles, local UI selections).

- If state affects multiple widgets/screens or must survive navigation,

  it should be lifted to a controller/use case instead of scattered `setState()`.



### Streams



- `StreamBuilder` may be used for narrow reactive sources (e.g., indicators).

- Streams must have a clear owner and be disposed/canceled when appropriate.



## Composition root and wiring



- The **composition root** is `main.dart`.

  - App initialization happens here (including Hive initialization and box opening).

- Dependencies are constructed in `main.dart` and passed into `NumbersTrainerApp`.

- Further dependencies are passed into features/screens via constructors.



Rules:

- Do not open Hive boxes lazily from UI code.

- Keep initialization order deterministic.

- Prefer passing a small number of "service bundle" objects rather than

  threading many individual dependencies through deep widget trees.



## Persistence (Hive)



- Hive types, adapters, and box access live in `data/` (or `core/` if truly shared).

- Domain models must not be Hive-annotated.

- Mapping between domain entities and storage DTOs happens in `data/` mappers.



## Testing expectations



- `domain` should be testable with plain Dart tests (no Flutter binding).

- `data` should have tests for mapping and repository behavior.

- `ui` tests are optional but recommended for critical flows.



## Review checklist



When reviewing changes, check:



1. Layer boundaries (`ui/domain/data`) are respected.

2. No forbidden imports in `domain`.

3. UI does not access Hive/data sources directly.

4. Controllers own lifecycle properly (`dispose`).

5. No cross-feature imports; shared code goes to `core`.

6. Wiring remains centralized in `main.dart` and stays predictable.

