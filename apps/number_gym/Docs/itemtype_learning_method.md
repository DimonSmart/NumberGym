# ExerciseFamily vs ExerciseMode

This matrix reflects `ExerciseFamily.supportedModes` in the active catalog.

## Definitions

- `ExerciseFamily`: what user trains.
- `ExerciseMode`: how the user trains it.

## Compatibility matrix

| Exercise family | speak | chooseFromPrompt | chooseFromAnswer | listenAndChoose | reviewPronunciation |
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

- `timeRandom` and phone families are re-materialized dynamically when a card opens.
- `reviewPronunciation` is enabled only for number families.
