# Current Numbers Gym behavior

## Purpose
Numbers Gym is a training app for practicing number skills in a foreign language. Today it trains:
- listening comprehension of numbers,
- reading numbers (number → word),
- writing/entering numbers (word → number),
- pronouncing numbers (speech recognition),
- pronouncing numbers inside phrases (premium pronunciation).【F:lib/features/training/domain/training_task.dart†L1-L36】【F:lib/features/training/domain/runtimes/number_pronunciation_runtime.dart†L1-L72】

Supported learning languages: English and Spanish (locales `en-US` and `es-ES`).【F:lib/features/training/domain/learning_language.dart†L1-L37】

## Main screens and flows

### 1) Intro (start screen)
- Shows the branded background, title, and a short description.
- The **Start** button opens the training screen.
- The menu provides navigation to **Statistics** and **Settings**.【F:lib/features/intro/ui/screens/intro_screen.dart†L1-L139】

### 2) Training
- The header shows how many cards are learned and how many remain.
- The main block displays the current task (type depends on the active runtime).
- The bottom area shows status text and a **Stop** button, which ends the session and returns to the intro screen.
- The menu opens **Statistics** or **Settings**; training pauses while those screens are open and resumes afterward.【F:lib/features/training/ui/screens/training_screen.dart†L1-L342】【F:lib/features/training/domain/training_session.dart†L118-L206】

### 3) Settings
- Select learning language (English / Spanish).
- Text-to-speech section:
  - checks TTS availability,
  - lets the user pick a system voice,
  - provides a voice preview button.
- Speech recognition section:
  - checks availability of speech recognition,
  - shows the status/error.
- **Premium pronunciation phrases** toggle (includes phrase tasks; requires internet).
- Online/offline indicator updated every 5 seconds.
- Answer timer setting (5–15 seconds, step 5).
- Hint streak setting: show a hint for the first N correct answers in a row.
- Copy logs button (debugging).
- Reset progress for the selected language (with confirmation).【F:lib/features/training/ui/screens/settings_screen.dart†L1-L548】【F:lib/features/training/domain/services/internet_checker.dart†L1-L15】

### 4) Statistics
- Summary metrics: total attempts, correct answers, and accuracy.
- Streak grid: shows each card with color-coded progress and the current consecutive correct count.
- A red border highlights the most troublesome cards (top 10 by attempts among not learned).【F:lib/features/training/ui/screens/statistics_screen.dart†L1-L350】

## Exercise types and validation rules

### 1) Number pronunciation
- Shows the numeric prompt and expected tokens.
- The learner speaks; speech recognition runs automatically.
- Validation matches recognized text against expected tokens (number in words and the numeric form).
- Uses the configured answer timer.
- Timeout results in a “timeout” outcome.【F:lib/features/training/domain/runtimes/number_pronunciation_runtime.dart†L1-L233】【F:lib/features/training/data/number_cards.dart†L24-L44】

### 2) Number → Word (select the word)
- Prompt is the number in digits; options are the word forms.
- A selection is correct when it matches the expected option (case/whitespace insensitive).
- Uses the answer timer; timeout produces “timeout”.【F:lib/features/training/domain/runtimes/multiple_choice_runtime.dart†L1-L93】【F:lib/features/training/domain/training_session.dart†L300-L348】

### 3) Word → Number (select the number)
- Prompt is the word form; options are numeric values.
- Validation compares the selected value to the correct number (exact match).【F:lib/features/training/domain/training_session.dart†L350-L409】【F:lib/features/training/domain/runtimes/multiple_choice_runtime.dart†L1-L93】

### 4) Listening numbers
- The app speaks the number using TTS.
- The learner selects the correct numeric option.
- Uses the answer timer.
- After a correct answer, the number is revealed on screen, then feedback is shown and the task completes.
- The learner can replay the audio while the task is active.【F:lib/features/training/domain/runtimes/listening_numbers_runtime.dart†L1-L123】【F:lib/features/training/ui/widgets/listening_numbers_view.dart†L1-L108】

### 5) Phrase pronunciation (premium)
- The learner records a phrase that contains the number.
- Only available when **Premium pronunciation phrases** is enabled and the device is online.
- Flow: record → stop → send recording → review result → continue.
- This task **does not affect card progress** (`affectsProgress = false`).【F:lib/features/training/domain/task_state.dart†L86-L139】【F:lib/features/training/domain/runtimes/phrase_pronunciation_runtime.dart†L1-L188】

## Progress rules and card selection
- Cards include numbers 0–100, round hundreds (200–900), and 1000/10000/100000/1000000.【F:lib/features/training/data/number_cards.dart†L1-L22】
- Progress is tracked per card; the last 10 attempts are stored.
- A card is considered learned when the last 10 attempts are all correct.
- Training pulls only not-learned cards in random order.
- When all cards are learned, the session finishes (“All cards learned”).【F:lib/features/training/domain/progress_manager.dart†L1-L170】【F:lib/features/training/ui/view_models/training_status_view_model.dart†L13-L33】

## Local data storage
- Settings and progress are stored locally via Hive.
- Settings include:
  - learning language,
  - answer duration,
  - hint streak threshold,
  - premium pronunciation toggle,
  - selected TTS voice per language,
  - debug-only “Force task type”.【F:lib/features/training/data/settings_repository.dart†L1-L118】
- Progress includes:
  - learned flag,
  - last attempts list (up to 10),
  - totalAttempts/totalCorrect counters.【F:lib/features/training/data/card_progress.dart†L1-L59】【F:lib/features/training/data/progress_repository.dart†L1-L82】

## Pronunciation scoring backend integration
- The app uploads a recorded audio file and the expected phrase text to a remote service.
- HTTP POST multipart fields:
  - `expectedText`: the phrase string,
  - `language`: locale (for example, `en-US`, `es-ES`),
  - `audio`: the recorded file.
- On success, the service returns JSON with recognition and scoring data (DisplayText, NBest, Words/Phonemes).
- Non-2xx or network errors show an error message on screen; the user can retry manually. No automatic retries are performed.【F:lib/features/training/domain/services/azure_speech_service.dart†L1-L45】【F:lib/features/training/domain/pronunciation_models.dart†L1-L92】【F:lib/features/training/domain/runtimes/phrase_pronunciation_runtime.dart†L118-L157】【F:lib/features/training/ui/screens/training_screen.dart†L315-L327】
