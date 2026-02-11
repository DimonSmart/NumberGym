# Domain glossary

- Card: one training item with prompt, accepted answers, and item type.
- Card ID (`TrainingItemId`): stable key built from item type plus value/time.
- Item type (`TrainingItemType`): content category (`digits`, `timeRandom`, `phone3222`, etc.).
- Learning method (`LearningMethod`): interaction type (`numberPronunciation`, `listening`, etc.).
- Cluster: aggregated attempts made within a short time gap.
- Cluster gap: max gap that still keeps attempts in same cluster.
- Mastery window: recent attempts window used to compute recent accuracy.
- Learned: state reached when min attempts and target accuracy are satisfied.
- Learned exclusion policy: learned cards are not scheduled in normal flow.
- Daily attempt limit: soft cap for attempts per day.
- Daily new-card limit: cap for cards first introduced today.
- Cooldown: temporary penalty for cards shown recently.
- Weakness boost: extra weight for cards below target accuracy.
- Session target cards: number of cards planned for current session block.
- Session stats: cards and duration persisted for daily aggregate.
- Streak: count of consecutive days with completed sessions.
- Phrase pronunciation: premium runtime that analyzes recording and does not affect card progress.
