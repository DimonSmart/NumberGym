# Domain glossary

- Card: A single training item representing a numeric concept, not just a raw number (for example, time, phone number, weight, price, dates, measurements), along with its accepted answers.
- Card ID (TrainingItemId): Unique identifier built from item type and number; used as the progress key.
- Item type: Number group used for scheduling and option generation (digits, base, hundreds, thousands).
- Active window (Active pool): Limited subset of unlearned cards eligible for selection; size is capped by activeLimit.
- Backlog: Remaining unlearned cards waiting to enter the Active window.
- Cluster: Aggregated attempts within a time gap, storing correct/wrong/skipped counts and lastAnswerAt.
- Cluster gap: Maximum time between attempts that still belong to the same cluster (clusterMaxGapMinutes).
- Spaced success: Counted success that advances spaced repetition only when enough days passed since the last counted success.
- Interval (intervalDays): Current spacing interval for a card, used to compute nextDue.
- nextDue: Due timestamp (ms since epoch) when a card becomes eligible again.
- Ease: Spacing multiplier that grows on success and shrinks on failure.
- Learned: Card state reached when spacedSuccessCount and intervalDays meet configured thresholds.
- Training task (TrainingTaskKind): Specific exercise type applied to a card during training (for example, "Number pronunciation", "Select the word", "Select the number", "Listening numbers").
- Number pronunciation: Speech-recognition task where the learner says the number aloud and matching is checked against accepted answers.
- Etalon: Reference pattern string for speech matching; supports syntax for decorative text `(...)`, variants `[...]`, and optional tokens `{...}`.
- Number to word ("Select the word"): Multiple-choice task where a number is shown and the correct written form is selected.
- Word to number ("Select the number"): Multiple-choice task where a written form is shown and the correct number is selected.
- Listening numbers: Audio comprehension task where a spoken number is played and the learner selects the matching option.
