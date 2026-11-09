# NeuroNova

*Play. Think. Discover.* — a family-friendly puzzle adventure (spec: "Production-Ready Game Design & Development Master Specification v2.0").

## Status: Phase 1 + 2 + 3 (all six core minigames)

`apps/player` (Flutter) now has all six minigames, each with a pure-Dart rules module, seeded deterministic generation and tests:

| Game | Skill | Validation |
|---|---|---|
| Echo Grid | visual memory | selection vs target set |
| Pattern Portal | logic | generator rejects any puzzle with more than one consistent continuation |
| Focus Dash | attention | target set derived from items; hit/wrong accuracy |
| Number Forge | numbers | exactly one option makes the equation true (deterministic evaluation) |
| Word Quest | vocabulary (EN/বাংলা/العربية) | one correct picture; starter vocab marked `draft` |
| Path Recall | spatial memory | self-avoiding route, legal-move checks, optional reverse mode |

Also: design system, guest-first flow, tutorial, per-skill adaptive tiers, scoring (timed/untimed), idempotent local XP commits, untimed accessible mode.

**Testing aid:** the home screen has a *Difficulty* dropdown (Adaptive or Test tier 1-10). Test tiers never change your saved skill.

Not built yet: chapters/missions (Phase 4), Daily Challenge, Supabase backend and server-side validation, admin console, sharing, Flame scenes. XP is local-only and can be edited on the client. Arabic/Bengali vocabulary is a 12-item draft and needs human review; Arabic glyph rendering has not been checked on real devices.

## Run
```
cd apps/player
flutter pub get
flutter analyze && flutter test
flutter run -d chrome
```

## Try it in a browser
Enable GitHub Pages (Settings -> Pages -> Source: GitHub Actions); the `Deploy web demo` workflow then publishes the web build to `https://<owner>.github.io/neuronova/`.
