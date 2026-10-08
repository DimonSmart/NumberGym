# ItemType vs LearningMethod

This matrix reflects `LearningMethod.supportedItemTypes` in code.

## Definitions

- `TrainingItemType`: what user trains (content type).
- `LearningMethod`: how user trains (interaction type).

## Compatibility matrix

| Item type | numberPronunciation | valueToText | textToValue | listening |
| --- | --- | --- | --- | --- |
| digits | Yes | Yes | Yes | Yes |
| base | Yes | Yes | Yes | Yes |
| hundreds | Yes | Yes | Yes | Yes |
| thousands | Yes | Yes | Yes | Yes |
| timeExact | Yes | Yes | Yes | Yes |
| timeQuarter | Yes | Yes | Yes | Yes |
| timeHalf | Yes | Yes | Yes | Yes |
| timeRandom | Yes | Yes | Yes | Yes |
| phone33x3 | Yes | No | No | No |
| phone3222 | Yes | No | No | No |
| phone2322 | Yes | No | No | No |

## Notes

- `timeRandom` and phone item types are rendered dynamically in session flow.
- Multiple-choice exercises do not require network access.
