import '../domain/learning_language.dart';
import 'number_card.dart';
import 'number_words.dart';

const int numberCardMinId = 0;
const int numberCardMaxId = 100;
const int numberCardCount = numberCardMaxId - numberCardMinId + 1;

List<NumberCard> buildNumberCards() {
  return List<NumberCard>.generate(numberCardCount, (index) {
    final id = numberCardMinId + index;
    final prompt = id.toString();
    return NumberCard(
      id: id,
      prompt: prompt,
      answersByLanguage: <LearningLanguage, List<String>>{
        LearningLanguage.english: <String>[
          numberToEnglish(id),
          prompt,
        ],
        LearningLanguage.spanish: <String>[
          numberToSpanish(id),
          prompt,
        ],
      },
    );
  });
}
