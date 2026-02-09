import 'package:flutter_test/flutter_test.dart';
import 'package:number_gym/features/training/domain/session_progress_plan.dart';

void main() {
  test('target cards follow started and completed sessions', () {
    expect(
      SessionProgressPlan.targetCards(
        cardsCompletedToday: 0,
        sessionsCompleted: 0,
        sessionSize: 50,
      ),
      50,
    );
    expect(
      SessionProgressPlan.targetCards(
        cardsCompletedToday: 5,
        sessionsCompleted: 0,
        sessionSize: 50,
      ),
      50,
    );
    expect(
      SessionProgressPlan.targetCards(
        cardsCompletedToday: 50,
        sessionsCompleted: 1,
        sessionSize: 50,
      ),
      50,
    );
    expect(
      SessionProgressPlan.targetCards(
        cardsCompletedToday: 51,
        sessionsCompleted: 1,
        sessionSize: 50,
      ),
      100,
    );
    expect(
      SessionProgressPlan.targetCards(
        cardsCompletedToday: 100,
        sessionsCompleted: 2,
        sessionSize: 50,
      ),
      100,
    );
    expect(
      SessionProgressPlan.targetCards(
        cardsCompletedToday: 150,
        sessionsCompleted: 3,
        sessionSize: 50,
      ),
      150,
    );
  });

  test('cards to finish current session resume by 50-card blocks', () {
    expect(
      SessionProgressPlan.cardsToFinishCurrentSession(
        cardsCompletedToday: 0,
        sessionSize: 50,
      ),
      50,
    );
    expect(
      SessionProgressPlan.cardsToFinishCurrentSession(
        cardsCompletedToday: 5,
        sessionSize: 50,
      ),
      45,
    );
    expect(
      SessionProgressPlan.cardsToFinishCurrentSession(
        cardsCompletedToday: 50,
        sessionSize: 50,
      ),
      50,
    );
    expect(
      SessionProgressPlan.cardsToFinishCurrentSession(
        cardsCompletedToday: 60,
        sessionSize: 50,
      ),
      40,
    );
  });
}
