# ItemType vs LearningMethod

## Concept

### TrainingItemType — What we train (WHAT)

Defines the card content:

* Numbers: digits, base, hundreds, thousands
* Time: timeExact, timeQuarter, timeHalf, timeRandom

### LearningMethod — How we train (HOW)

Defines how the user interacts with the card:

* numberPronunciation — pronunciation with speech recognition
* valueToText — choose the text form (number → words)
* textToValue — choose the numeric value (words → number)
* listening — listening comprehension with choosing the correct option
* phrasePronunciation — phrase pronunciation with analysis (premium)

## Compatibility matrix

| Item type (WHAT) | numberPronunciation | valueToText | textToValue | listening | phrasePronunciation |
| ---------------- | ------------------- | ----------- | ----------- | --------- | ------------------- |
| **Numbers**      |                     |             |             |           |                     |
| digits           | Yes                 | Yes         | Yes         | Yes       | Yes                 |
| base             | Yes                 | Yes         | Yes         | Yes       | Yes                 |
| hundreds         | Yes                 | Yes         | Yes         | Yes       | Yes                 |
| thousands        | Yes                 | Yes         | Yes         | Yes       | Yes                 |
| **Time**         |                     |             |             |           |                     |
| timeExact        | Yes                 | Yes         | Yes         | Yes       | No                  |
| timeQuarter      | Yes                 | Yes         | Yes         | Yes       | No                  |
| timeHalf         | Yes                 | Yes         | Yes         | Yes       | No                  |
| timeRandom       | Yes                 | Yes         | Yes         | Yes       | No                  |
