# Technical specification

## 1. Product purpose

Number Gym trains spoken and recognition skills with short cards:
- speaking from prompts;
- multiple-choice transformations;
- listening drills;
- premium pronunciation review for number phrases.

## 2. Supported languages

- English (`en`)
- Spanish (`es`)
- French (`fr`)
- German (`de`)
- Hebrew (`he`)

All progress and settings are scoped by selected language.

## 3. Domain model

- `ExerciseFamily`: stable content family boundary used for scheduling, progress, difficulty, and debug filters.
- `ExerciseId`: stable card key built from `moduleId`, `familyId`, and `variantId`.
- `ExerciseMode`: interaction mode selected per session.
- `ExerciseCard`: prompt, accepted answers, choice specs, and optional dynamic resolver.
- `TrainingAppDefinition`: app config plus language profiles, tokenizer, and exercise catalog.

## 4. Exercise families

### 4.1 Numbers

- `digits`: `0..9`
- `base`: `10..99`
- `hundreds`: `100..900` in steps of `100`
- `thousands`: `1000..9000` in steps of `1000`

### 4.2 Time

- `timeExact`
- `timeQuarter`
- `timeHalf`
- `timeRandom`

### 4.3 Phone formats

- `phone33x3`
- `phone3222`
- `phone2322`

## 5. Exercise modes

- `speak`
- `chooseFromPrompt`
- `chooseFromAnswer`
- `listenAndChoose`
- `reviewPronunciation`

Compatibility matrix: `Docs/itemtype_learning_method.md`.

- Number families support all modes.
- Time families support all modes except `reviewPronunciation`.
- Phone families support only `speak`.

## 6. Dynamic content rules

- `timeRandom` materializes a fresh displayed time when the card opens, but keeps a stable `progressId`.
- Phone families materialize fresh numbers and optional `+34` prefix while keeping a stable `progressId`.
- Number review phrases are materialized from language-owned templates.
- Accepted variants, prompt aliases, grouped phone hints, and language edge cases are owned by `number_gym_content`.

## 7. Session and scheduling rules

- Training starts only if there are remaining unlearned cards.
- Selection uses weighted random from eligible unlearned cards.
- Weight combines difficulty, weakness boost, new-card boost, recent mistakes, and cooldown.
- Learned cards are excluded from normal scheduling.
- Daily limits apply to attempts and newly introduced cards.

## 8. Progress and mastery

- Progress stores attempt clusters per `progressId`.
- Mastery requires minimum total attempts and recent accuracy above the family target.
- Phone families use a lower mastery target than number and time families.

## 9. Availability and settings

Stored values include:
- language;
- premium pronunciation enabled;
- forced debug mode (debug only);
- forced debug family (debug only);
- selected TTS voice per language;
- daily session stats per language;
- study streak per language;
- celebration counter.

Availability rules:
- speaking requires speech recognition;
- listening requires TTS for the selected language;
- pronunciation review requires internet plus the premium toggle.

## 10. Statistics

The app shows:
- total and learned card counts;
- daily completion summary;
- streak snapshot;
- learned progress per family.

## 11. Session lifecycle behavior

- Start: load availability, resolve a mode, and attach the first runtime.
- Completion: record progress, refresh stats, and continue until the session stops.
- Pause and overlays are handled inside `trainer_core`.
- Stop: persist session stats and return to the app shell.

## 12. Out of scope right now

- Automatic review of already learned cards in normal flow.
- Cloud sync.
- Multi-device conflict resolution.
