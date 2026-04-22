# Numbers Gym

Speech-driven training app with short cards for numbers, time, and phone formats.

## Purpose

Build fast and confident spoken responses with short sessions:
- user sees or hears a prompt;
- user answers by voice or multiple choice;
- progress is stored locally per language.

## Current scope

- Languages: English (`en`), Spanish (`es`), French (`fr`), German (`de`), Hebrew (`he`).
- Content types:
  - numbers (`0..99`, round hundreds `100..900`, round thousands `1000..9000`);
  - time (`exact`, `quarter`, `half`, `random`);
  - phone (`3-3-3`, `3-2-2-2`, `2-3-2-2`).
- Learning methods:
  - number pronunciation;
  - value to text;
  - text to value;
  - listening;
  - phrase pronunciation (premium).

## Progress model

- Selection uses weighted random from eligible unlearned cards.
- Weight combines content difficulty, weakness boost, new-card boost, and cooldown penalty.
- A card becomes learned when total attempts and recent-accuracy thresholds are met.
- Learned cards are excluded from normal scheduling.
- Daily limits are applied to attempts and newly introduced cards.

## Structure

- `lib/app.dart`, `lib/main.dart`: composition root and app wiring.
- `lib/features/training/data`: repositories and storage models.
- `lib/features/training/domain`: scheduling, session orchestration, and runtime coordination.
- `lib/features/training/ui`: screens, view models, and widgets.

## Documentation

- [Specification](Docs/specification.md)
- [Architecture](Docs/architecture.md)
- [ItemType vs LearningMethod](Docs/itemtype_learning_method.md)
- [Domain glossary](Docs/glossary.md)

## Branding

Regenerate app icons and native splash assets manually:

```powershell
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

After `flutter_native_splash:create`, verify
`android:screenOrientation="portrait"` in
`android/app/src/main/AndroidManifest.xml` for `MainActivity`.
