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
- Each learning method has clear UI and controls.
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

- Reset requires confirmation.

- TTS availability is checked and voices can be previewed.

- Speech recognition availability/status is shown.

- Online/offline indicator is shown for premium features.

- Copy logs exports the in-memory log buffer and is disabled when empty.



### 3.5. Statistics

**User scenario:**

1. The user opens **Statistics**.

2. The user sees summary metrics and the streak grid.



**Done criteria:**

- Metrics and grid reflect local progress data.

- The grid shows each card's current successful cluster streak.

- The most troublesome cards are highlighted (top 10 by attempts among not learned).



### 3.6. Training interruptions

**User scenario:**

1. The user opens **Statistics** or **Settings** during an active session.

2. Training pauses while those screens are open.

3. When the user returns, training resumes.



**Done criteria:**

- The active task runtime is disposed while the overlay is open.

- The session resumes from the next card on return.



## 4. Functional requirements



### 4.1. Card set

The system must include cards for:

- 0–99 (inclusive),

- round hundreds 100–900,

- round thousands 1000–9000.



### 4.2. Training rules

- Training uses two pools: **AllCards** (full content) and **Active** (study window).

- Active is filled from Backlog up to the active limit.

- Training selects only not-learned cards from Active.

- Card order uses `nextDue` to find the earliest due cards, then selects a random

  eligible card among those earliest due items from Active.

- The session finishes when all cards are learned.



#### 4.2.1. Card selection process

1. Load progress for the active language and build Active/Backlog from unlearned cards.

2. Filter Active to eligible cards (task constraints, availability).

3. Order eligible cards by `nextDue` (earliest first) and find the earliest due group.

4. Randomly select any eligible card from that earliest due group.

5. Build the next task variant based on availability and weights.



### 4.3. Progress rules

- Each card stores the last N **clusters**. A cluster aggregates correct / wrong / skipped counts

  within a time gap threshold.

- A cluster aggregates attempts within the configured time gap (`clusterMaxGapMinutes`).

- The scheduler is updated once per cluster (on cluster start). Additional attempts inside the same cluster update only cluster counters, not interval growth.

- Interval, ease, and `nextDue` are updated only when a new cluster is created.

- Inside an active cluster window, `nextDue` is shifted from the current attempt time (`now + currentInterval`) without multiplying interval/ease again.

- A cluster is successful if its accuracy is above the configured threshold.

- **Spaced success** counts only when enough days passed since the previous counted success.

- A card is learned only if it reaches both:

  - minimum spaced successes,

  - minimum interval length.

- Default interval ceiling is one week: `LearningParams.maxReviewIntervalDays = 7`.


#### 4.3.1. Default spaced parameters and daily learning estimate

Default values:
- `maxReviewIntervalDays = 7`
- `minSpacedSuccessClustersToLearn = 3`
- `minDaysBetweenCountedSuccesses = 1`
- `initialIntervalDays = 1.0`
- `initialEase = 1.3`
- `easeUpOnSuccess = 0.04`

If the learner studies one successful cluster per day, interval growth is:
1. Day 1: `1.34` days
2. Day 2: `1.85` days
3. Day 3: `2.63` days
4. Day 4: `3.83` days
5. Day 5: `5.75` days
6. Day 6: `7.00` days (clamped by max)

With these defaults, a card becomes learned in about **6 days** of successful daily practice:
- by Day 3 it reaches the required spaced-success count (`>= 3`),
- by Day 6 it reaches the required interval (`>= 7` days).

- Statistics must expose:

  - totalAttempts,

  - totalCorrect,

  - current consecutive successful cluster streak.



### 4.4. Exercises



The training system uses two orthogonal dimensions:



**Content (WHAT)** — defined by `TrainingItemType`:

- Numbers: digits (0-9), base (10-99), hundreds (100-900), thousands (1000-9000)

- Time: timeExact (on the hour), timeQuarter (:15/:45), timeHalf (:30), timeRandom (any time)



**Method (HOW)** — defined by `LearningMethod`:
- Number pronunciation (speech recognition)

- Value to text (multiple choice: number → words)

- Text to value (multiple choice: words → number)

- Listening (audio comprehension with TTS)

- Phrase pronunciation (premium, speech analysis)



Not all methods support all content types. See `itemtype_trainingtaskkind.md` for the compatibility matrix.



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



#### 4.4.4. Listening

- The system speaks the number or time with TTS.

- The learner selects the correct option from the choices.

- On correct selection, the answer is revealed on screen.

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

- debug-only forced learning method (for QA/testing).


### 5.2. Progress

For each card and language, store:

- learned flag,

- spaced scheduling fields (`intervalDays`, `nextDue`, `ease`, `spacedSuccessCount`, `lastCountedSuccessDay`),

- last N clusters of attempts (each cluster stores lastAnswerAt + correct/wrong/skipped counts),

- total attempts / correct totals derived from clusters.



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

- Users can complete training with any supported learning method.
- Progress persists and is restored after restart.

- Settings are available and affect training.

- Premium pronunciation works only online and shows pronunciation results correctly.

- The backend contract is implemented and handles both success and failure cases.
