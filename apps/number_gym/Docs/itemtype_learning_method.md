# ItemType vs LearningMethod

This matrix reflects `LearningMethod.supportedItemTypes` in code.

## Definitions

- `TrainingItemType`: what user trains (content type).
- `LearningMethod`: how user trains (interaction type).

## Compatibility matrix

| Item type | numberPronunciation | valueToText | textToValue | listening | phrasePronunciation |
| --- | --- | --- | --- | --- | --- |
| digits | Yes | Yes | Yes | Yes | Yes |
| base | Yes | Yes | Yes | Yes | Yes |
| hundreds | Yes | Yes | Yes | Yes | Yes |
| thousands | Yes | Yes | Yes | Yes | Yes |
| timeExact | Yes | Yes | Yes | Yes | No |
| timeQuarter | Yes | Yes | Yes | Yes | No |
| timeHalf | Yes | Yes | Yes | Yes | No |
| timeRandom | Yes | Yes | Yes | Yes | No |
| phone33x3 | Yes | No | No | No | No |
| phone3222 | Yes | No | No | No | No |
| phone2322 | Yes | No | No | No | No |

## Notes

- `timeRandom` and phone item types are rendered dynamically in session flow.
- `phrasePronunciation` supports only numeric item types.
