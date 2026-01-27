# Technical specification (Spec-Driven Development)

## 1. Product purpose
Build a mobile app that trains number skills in a foreign language. The app must develop four core skills:
1) listening comprehension of numbers,
2) reading numbers,
3) writing/entering numbers,
4) pronouncing numbers.
It also supports phrase pronunciation with pronunciation quality scoring.

## 2. Supported languages
- English (locale `en-US`).
- Spanish (locale `es-ES`).

The system must allow switching the learning language. All content and progress data must be scoped to the selected language.

## 3. User flows (UX)

### 3.1. Start training
**User scenario:**
1. The user opens the app and sees the intro screen.
2. The user taps **Start**.
3. The training screen opens with the first task.

**Done criteria:**
- **Start** enters an active training session.
- Training begins automatically after progress is loaded.

### 3.2. Complete a task
**User scenario:**
1. The user completes a task (selects an option or speaks an answer).
2. Feedback is shown (correct / wrong / timeout).
3. The next task appears after a short delay.

**Done criteria:**
- Each task type has clear UI and controls.
- Feedback is shown for every answer.

### 3.3. Stop training
**User scenario:**
1. The user taps **Stop**.
2. The session ends and the user returns to the intro screen.

**Done criteria:**
- The runtime stops cleanly.
- Progress is persisted.

### 3.4. Settings
**User scenario:**
1. The user opens **Settings**.
2. The user changes language, TTS voice, answer duration, or hint settings.
3. The user toggles premium phrases.
4. The user resets progress if needed.

**Done criteria:**
- Changes are stored locally.
- Reset clears only the selected language’s progress.

### 3.5. Statistics
**User scenario:**
1. The user opens **Statistics**.
2. The user sees summary metrics and the streak grid.

**Done criteria:**
- Metrics and grid reflect local progress data.

## 4. Functional requirements

### 4.1. Card set
The system must include cards for:
- 0–100 (inclusive),
- round hundreds 200–900,
- 1000, 10000, 100000, 1000000.

### 4.2. Training rules
- Training selects only not-learned cards.
- Card order is randomized.
- The session finishes when all cards are learned.

### 4.3. Progress rules
- Each card stores the last 10 attempts.
- A card is learned if the last 10 attempts are all correct.
- Statistics must expose:
  - totalAttempts,
  - totalCorrect,
  - current consecutive correct streak.

### 4.4. Exercises

#### 4.4.1. Number pronunciation
- Show the numeric prompt.
- The learner speaks the number.
- The system matches speech against acceptable answers:
  - number in words,
  - numeric form.
- A configurable answer timer is used.
- Timeout yields a “timeout” outcome.

#### 4.4.2. Number → Word (multiple choice)
- Prompt is the number in digits.
- Options are word forms.
- Correct when the selected option matches the expected word.

#### 4.4.3. Word → Number (multiple choice)
- Prompt is the number in words.
- Options are numeric values.
- Correct when the selected number matches the expected value.

#### 4.4.4. Listening numbers
- The system speaks the number with TTS.
- The learner selects the correct numeric option.
- On correct selection, the number is revealed on screen.
- The learner can replay the audio during the task.

#### 4.4.5. Phrase pronunciation (premium)
- The learner records a spoken phrase containing the number.
- This task does not affect card progress.
- Flow: record → stop → send → review → continue.
- Available only when the premium toggle is enabled and the device is online.

### 4.5. Task availability
- Speech recognition is available only when microphone permission is granted and the device supports speech recognition.
- TTS is available only when there are voices for the selected language.
- Phrase pronunciation requires an active internet connection.

## 5. Data requirements

### 5.1. Settings (local storage)
The system stores:
- selected learning language,
- answer duration (5–15 sec, step 5),
- hint streak threshold,
- premium pronunciation flag,
- selected TTS voice per language.

### 5.2. Progress
For each card and language, store:
- learned flag,
- lastAttempts (last 10 results),
- totalAttempts,
- totalCorrect.

## 6. Non-functional requirements
- Core modes (pronunciation / multiple choice / listening) must work offline if the device capabilities are available locally.
- Premium pronunciation requires online access.
- On network or service errors, the user receives a clear message and can retry manually.
- Progress must be stored locally without depending on the network.

## 7. Pronunciation scoring backend

### 7.1. Purpose
A standalone HTTP service accepts recorded audio and the expected text, then returns pronunciation quality metrics.

### 7.2. Request contract
- Method: `POST`
- Format: `multipart/form-data`
- Fields:
  - `expectedText`: the expected phrase,
  - `language`: locale (for example, `en-US`, `es-ES`),
  - `audio`: the audio file.

### 7.3. Response contract (success)
- JSON with at least:
  - `DisplayText`: recognized text (string),
  - `NBest`: list of pronunciation hypotheses,
    - `AccuracyScore`, `FluencyScore`, `CompletenessScore`, `PronScore`,
    - `Words`: list of words with scores,
      - `Word`, `AccuracyScore`, `ErrorType`,
      - `Phonemes`: list of phonemes with scores.

### 7.4. Errors and resilience
- On non-2xx responses, the client must:
  - show a clear error message,
  - return to a “ready to retry” state,
  - avoid automatic retries.
- Network failures follow the same behavior (manual retry only).

### 7.5. Quality and security
- The service must be reachable via HTTPS.
- Response times must be acceptable for an interactive flow (seconds).
- The service must handle invalid or incomplete payloads with predictable errors.

## 8. Definition of Done
- Users can complete training with any supported task type.
- Progress persists and is restored after restart.
- Settings are available and affect training.
- Premium pronunciation works only online and shows pronunciation results correctly.
- The backend contract is implemented and handles both success and failure cases.
