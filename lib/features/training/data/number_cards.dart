import '../domain/learning_language.dart';
import 'number_card.dart';
import 'number_words.dart';

List<SpeakNumberTask> buildNumberCards() {
  final ids = <int>[];
  // 0 - 100
  for (var i = 0; i <= 100; i++) {
    ids.add(i);
  }
  // 200 - 900
  for (var i = 200; i < 1000; i += 100) {
    ids.add(i);
  }
  // Powers of 10
  ids.add(1000);
  ids.add(10000);
  ids.add(100000);
  ids.add(1000000);

  return ids.map((id) {
    final prompt = id.toString();
    final english = numberToEnglish(id);
    final spanish = numberToSpanish(id);
    
    // Normalize spaces for simpler matching if needed, 
    // but the speech engine usually returns standard spacing.
    // We add prompt (digits) as an answer too? 
    // Usually "100" is spoken as "one hundred".
    // The original code added `prompt` as an answer.
    // If I say "hundred" for 100, is it correct? 
    // Original code: [numberToEnglish(id), prompt]
    // So "100" string is a valid answer.
    
    return SpeakNumberTask(
      id: id,
      prompt: prompt,
      answersByLanguage: <LearningLanguage, List<String>>{
        LearningLanguage.english: <String>[
          english,
          prompt,
        ],
        LearningLanguage.spanish: <String>[
          spanish,
          prompt,
        ],
      },
    );
  }).toList();
}
