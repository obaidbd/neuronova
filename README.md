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


## Echo Grid local matches

Echo Grid now opens a setup screen (the first-time tutorial is still available).
Choose Solo, Friends (2–4 players sharing one device, taking turns), or Computer
(a simulated local opponent). Set 1–50 rounds per player before a match. Solo also
supports continuous play with no round or score limit and a **Finish run** button.

Each seat can choose 1–15 seconds of preview time; the setting is saved locally.
A ready screen hides the next pattern while the device changes hands. Each
perfect answer advances that player's level; a miss keeps the current level.
Difficulty grows through 20 levels, from 3×3 to 7×7 and up to 20 target tiles;
continuous play keeps running at level 20. The existing home-screen test-tier
option fixes puzzle difficulty for testing.

The header shows cumulative match points and each player's current level.
Standings rank highest **completed** level first, then total points; exact ties
share the win. Friends/computer matches keep scores within the current match and
do not award guest XP or alter the guest's saved adaptive skill. These are local
matches, with no online rooms or cross-device synchronization.

Use Flutter **3.47.9** (Dart 3.13.7), matching the project's creation SDK and the
pinned CI/web workflows. Build for root-domain hosting with:

```sh
cd apps/player
flutter pub get
flutter analyze
flutter test
flutter build web --release
```

Upload the contents of `apps/player/build/web/` to the website's document root.
For GitHub Pages under `/neuronova/`, use the existing Pages workflow instead;
its base path is different from a root-domain build.

The CI workflow builds and saves a root-domain `neuronova-web-root` artifact on
each push/PR. The Pages workflow deploys on pushes to `main`, once GitHub Pages
is enabled under **Settings → Pages → Source: GitHub Actions**. The existing
Pages deployment failed with HTTP 404 because Pages was not enabled. The current
`neuronova.muslimit.net` host must be connected separately; a repository build
does not automatically upload to that server.
