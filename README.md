# Numbers Trainer

Speech-driven training app for practicing spoken answers with short cards. It starts with
number pronunciation (0-100) in English and Spanish and is built to expand into other
everyday formats.

## Purpose

Build accurate, confident speech through quick drills: the user sees a prompt, answers
aloud, and repeats until the response is learned.

## Concept

- A session draws from the set of not-yet-learned cards in random order.
- Once a card is consistently answered correctly, it drops out of the session.
- Cards can represent numbers, simple expressions, measurements, and time formats,
  allowing multiple levels and domains without changing the flow.

## Structure

- `lib/app.dart`, `lib/main.dart`: app entry wiring.
- `lib/features/training/data`: card definitions, repositories, and Hive adapters.
- `lib/features/training/domain`: domain types and controller logic.
- `lib/features/training/ui`: screens and widgets for training, settings, and statistics.

## Card range

The single source of truth for the card range lives in
`lib/features/training/data/number_cards.dart`.
