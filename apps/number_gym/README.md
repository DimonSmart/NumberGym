# Numbers Gym

Speech-driven training app for numbers, time, and phone formats.

## Purpose

Build fast and confident spoken responses with short sessions:
- user sees or hears a prompt;
- user answers by voice or multiple choice;
- progress is stored locally per language.

## Active architecture

- Languages: English (`en`), Spanish (`es`), French (`fr`), German (`de`), Hebrew (`he`).
- Active app shell lives in `lib/app.dart`, `lib/main.dart`, and `lib/home_screen.dart`.
- NumberGym content lives in `../../packages/number_gym_content`.
- Shared repositories, matcher, scheduler, runtimes, and screens live in `../../packages/trainer_core`.
- `apps/number_gym` keeps branding, home/about screens, native assets, and shipping entrypoints.

## Structure

- `lib/main.dart`: Flutter bootstrap, Hive setup, error logging.
- `lib/app.dart`: `AppConfig` plus `TrainingAppDefinition` creation via `buildNumberGymAppDefinition`.
- `lib/home_screen.dart`: branded home shell that routes into `trainer_core` screens.
- `lib/features/intro/ui/screens/about_screen.dart`: app-specific about screen and external links.
- `test/`: app-shell smoke and navigation tests only.

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

`number_gym_content` owns accepted variants, prompt aliases, phone spoken variants,
dynamic random-time and phone generation, and phrase materialization.

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
