# ItemType vs TrainingTaskKind

## Концепция

### TrainingItemType — Объект тренировки (ЧТО)
Определяет **содержание карточки** — конкретные числа или время:
- **Числа**: `digits`, `base`, `hundreds`, `thousands`
- **Время**: `timeExact`, `timeQuarter`, `timeHalf`, `timeRandom`

### TrainingTaskKind — Способ тренировки (КАК)
Определяет **метод взаимодействия** с карточкой — как пользователь тренируется:
- **numberPronunciation** — произношение с распознаванием речи
- **valueToText** — выбор текстовой формы из вариантов (число → слова)
- **textToValue** — выбор числового значения из вариантов (слова → число)
- **listening** — распознавание на слух с выбором правильного варианта
- **phrasePronunciation** — произношение фразы с анализом (premium)

## Матрица совместимости

| Item type (объект) | numberPronunciation | valueToText | textToValue | listening | phrasePronunciation |
| --- | --- | --- | --- | --- | --- |
| **Numbers** | | | | | |
| digits | Yes | Yes | Yes | Yes | Yes |
| base | Yes | Yes | Yes | Yes | Yes |
| hundreds | Yes | Yes | Yes | Yes | Yes |
| thousands | Yes | Yes | Yes | Yes | Yes |
| **Time** | | | | | |
| timeExact | Yes | Yes | Yes | Yes | No |
| timeQuarter | Yes | Yes | Yes | Yes | No |
| timeHalf | Yes | Yes | Yes | Yes | No |
| timeRandom | Yes | Yes | Yes | Yes | No |
