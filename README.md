# NeuroNova

*Play. Think. Discover.* — a family-friendly puzzle adventure (spec: "Production-Ready Game Design & Development Master Specification v2.0").

## Status: Phase 1 + 2 (foundation and first playable)

Implemented in `apps/player` (Flutter):
- Design system (spec palette), guest-first "Play Now" flow, no registration.
- **Echo Grid** minigame: tiered config (3×3/4×4/5×5), seeded deterministic generator, validated evaluation.
- Interactive first-gate tutorial, result panel, score + XP, Nova Energy.
- Scoring per spec §16 (timed / untimed accessible), reduced XP on replays.
- Per-skill adaptive difficulty (spec §15) with unit tests.
- Local guest progress; rounds commit idempotently (no double XP).
- Colour-independent tile cues, semantic labels, untimed mode.

Not built yet: other five minigames, chapters/missions, Daily Challenge, Supabase backend, admin console, server-side validation, sharing, Flame scenes (Flutter widgets are used for now). XP is local-only until a server exists, so it is not tamper-proof.

## Run
```
cd apps/player
flutter pub get
flutter analyze && flutter test
flutter run -d chrome
```
