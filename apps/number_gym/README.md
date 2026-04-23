# Numbers Gym

Speech-driven training app for numbers, time, and phone formats.

## Purpose

Build fast and confident spoken responses with short sessions:
- user sees or hears a prompt;
- user answers by voice or multiple choice;
- progress is stored locally per language.

## Active architecture

- Languages: English (`en`), Spanish (`es`), French (`fr`), German (`de`), Hebrew (`he`).
- Shipping entrypoints live in `lib/app.dart` and `lib/main.dart`.
- Branded NumberGym screens currently live in `lib/features/...` and are being reduced toward an app-shell role.
- Shared runtime pieces are being moved into `../../packages/trainer_core`.
- NumberGym-specific content is being moved into `../../packages/number_gym_content`.
- `apps/number_gym` remains the source of truth for the shipped NumberGym UI until modular parity is complete.

## Structure

- `lib/main.dart`: Flutter bootstrap, Hive setup, error logging.
- `lib/app.dart`: app theme and branded bootstrap shell.
- `lib/features/intro/ui/screens/intro_screen.dart`: shipped intro/home flow for NumberGym.
- `lib/features/intro/ui/screens/about_screen.dart`: app-specific about screen and external links.
- `lib/features/training/...`: transitional NumberGym runtime and UI that is being split into app-specific and shared pieces.
- `test/`: app-level smoke, widget, and regression tests.

## Domain scope

- Exercise families:
  - `digits`, `base`, `hundreds`, `thousands`
  - `timeExact`, `timeQuarter`, `timeHalf`, `timeRandom`
  - `phone33x3`, `phone3222`, `phone2322`
- Exercise modes:
  - `speak`
  - `chooseFromPrompt`
  - `chooseFromAnswer`
  - `listenAndChoose`
  - `reviewPronunciation` for number families

Target ownership:

- `number_gym_content`: accepted variants, prompt aliases, phone spoken variants, random-time and phone generation, phrase materialization.
- `trainer_core`: reusable session engine, persistence abstractions, generic training flows, shared services.
- `apps/number_gym`: branding, launch flow, about screen, assets, app-level integration glue.

## Documentation

- [Specification](Docs/specification.md)
- [Architecture](Docs/architecture.md)
- [ExerciseFamily vs ExerciseMode](Docs/itemtype_learning_method.md)
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

## Run And Publish

Canonical root-level commands:

```powershell
pwsh ./tool/run_number_gym.ps1 -DeviceId <device-id>
pwsh ./tool/publish_number_gym_web.ps1
```

Direct app-local commands:

```powershell
cd apps/number_gym
flutter run -d <device-id>
flutter build web --release --base-href /NumberGym/
```

## Testing

Canonical workspace checks stay at repo root:

```powershell
pwsh ./tool/analyze_all.ps1
pwsh ./tool/test_all.ps1
cd apps/number_gym
flutter build apk --debug
pwsh ../tool/publish_number_gym_web.ps1 -DryRun
```
