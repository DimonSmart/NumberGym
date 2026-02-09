# Numbers Gym

Speech-driven training app for practicing spoken answers with short cards. It starts with
number pronunciation (0-100) in English and Spanish and is built to expand into other
everyday formats.

## Purpose

Build accurate, confident speech through quick drills: the user sees a prompt, answers
aloud, and repeats until the response is learned.

## Concept

- A session selects the next card from the full eligible set using weighted
  probability (no active/backlog queues).
- Card weights combine type difficulty, weak-spot priority, novelty control,
  and anti-repeat cooldown.
- A card becomes learned by mastery rules: minimum total attempts plus recent
  accuracy threshold (difficulty-dependent).
- Learned cards still appear with a small probability for retention checks;
  mistakes can return them to learning.
- Daily work is limited by clear caps: total attempts and new cards per day.
- Cards can represent numbers, simple expressions, measurements, and time formats,
  allowing multiple levels and domains without changing the flow.

## Structure

- `lib/app.dart`, `lib/main.dart`: app entry wiring.
- `lib/features/training/data`: card definitions, repositories, and Hive adapters.
- `lib/features/training/domain`: domain types and controller logic.
- `lib/features/training/ui`: screens and widgets for training, settings, and statistics.

## Card range

The primary number range is fully covered from 0 to 99. Beyond that, the app
also supports round hundreds (100, 200, ... , 900) and round thousands
(1000, 2000, ... , 9000). The single source of truth for the card range lives in
`lib/features/training/data/number_cards.dart`.

## Documentation

- [Specification](Docs/specification.md)
- [Domain glossary](Docs/glossary.md)
