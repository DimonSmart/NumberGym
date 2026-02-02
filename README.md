# Numbers Gym

Speech-driven training app for practicing spoken answers with short cards. It starts with
number pronunciation (0-100) in English and Spanish and is built to expand into other
everyday formats.

## Purpose

Build accurate, confident speech through quick drills: the user sees a prompt, answers
aloud, and repeats until the response is learned.

## Concept

- The app maintains two pools: a full card pool (all available content) and an
  active window used for current study.
- A session draws from the active window; `nextDue` determines the next item
  type, then a random card of that type is selected.
- Card progress is updated after each attempt via spaced repetition; clusters
  are stored for streak and analytics.
- Learned cards drop out of the active window and are replaced from the backlog.
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
