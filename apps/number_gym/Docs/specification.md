# Technical specification

## 1. Product purpose

Numbers Gym trains spoken and recognition skills with short cards:
- pronunciation;
- listening;
- multiple-choice transformations (value <-> text);
- premium phrase pronunciation analysis.

## 2. Supported languages

- English (`en`)
- Spanish (`es`)
- French (`fr`)
- German (`de`)
- Hebrew (`he`)

All progress and settings are scoped by selected language.

## 3. Training content

### 3.1 Numbers

- digits: `0..9`
- base: `10..99`
- hundreds: `100..900` (step 100)
- thousands: `1000..9000` (step 1000)

### 3.2 Time

- `timeExact`
- `timeQuarter`
- `timeHalf`
- `timeRandom`

### 3.3 Phone formats

- `phone33x3`
- `phone3222`
- `phone2322`

## 4. Learning methods

- `numberPronunciation`
- `valueToText`
- `textToValue`
- `listening`
- `phrasePronunciation` (premium)

Compatibility matrix: `Docs/itemtype_learning_method.md`.

## 5. Session and scheduling rules

- Training starts only if there are remaining unlearned cards.
- Next card is chosen by weighted random from eligible unlearned cards.
- Card weight factors:
  - base type weight;
  - weakness boost (relative to target accuracy);
  - new-card boost;
  - recent mistake boost;
  - repeat cooldown penalty.
- Daily controls:
  - attempt limit;
  - new-card limit.

Learned cards are excluded from normal scheduling.

## 6. Progress and mastery

For each card, progress stores attempt clusters:
- `correctCount`, `wrongCount`, `skippedCount`;
- `lastAnswerAt`;
- `firstAttemptAt`;
- `learned`, `learnedAt`.

Mastery requires:
- minimum total attempts;
- recent accuracy above item-type target.

## 7. Task availability

- Speech tasks require speech recognition availability.
- Listening tasks require TTS availability for selected language.
- Phrase pronunciation requires internet and premium toggle.

If forced debug method/type is incompatible or unavailable, session is paused
with explicit error text.

## 8. Settings (local)

Stored values include:
- language;
- answer duration;
- hint streak threshold;
- premium pronunciation enabled;
- forced debug learning method (debug only);
- forced debug item type (debug only);
- selected TTS voice per language;
- daily session stats per language;
- study streak per language;
- celebration counter.

## 9. Statistics

The app shows:
- total and learned card counts;
- daily completion summary;
- session stats;
- streak snapshot;
- queue diagnostics from progress data.

## 10. Session lifecycle behavior

- Start: warm availability, reset session counters, attach first runtime.
- Completion: record progress, show feedback, optionally queue celebration.
- Pause/overlay: dispose active runtime and disable keep-awake.
- Stop: persist session stats, clear runtime/feedback, reset selection state.

## 11. Out of scope right now

- Automatic review of already learned cards in normal flow.
- Cloud sync.
- Multi-device conflict resolution.
