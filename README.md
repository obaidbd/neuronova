# NeuroNova

*Play. Think. Discover.* — a family-friendly puzzle adventure (spec: "Production-Ready Game Design & Development Master Specification v2.0").

## Status: Phase 1 + 2 + 3 (six core minigames, plus Flip Match)

`apps/player` (Flutter) now has all six minigames, each with a pure-Dart rules module, seeded deterministic generation and tests:

| Game | Skill | Validation |
|---|---|---|
| Echo Grid | visual memory | selection vs target set |
| Pattern Portal | logic | generator rejects any puzzle with more than one consistent continuation |
| Focus Dash | attention | target set derived from items; hit/wrong accuracy |
| Number Forge | numbers | exactly one option makes the equation true (deterministic evaluation) |
| Word Quest | vocabulary (EN/বাংলা/العربية) | one correct picture; starter vocab marked `draft` |
| Path Recall | spatial memory | self-avoiding route, legal-move checks, optional reverse mode |
| Flip Match | pair memory | seeded deal where every fruit / animal appears exactly twice; 3-12 pairs by tier; success at 70% of attempts right |

Also: design system, guest-first flow, tutorial, per-skill adaptive tiers, scoring (timed/untimed), idempotent local point commits, untimed accessible mode.

**Testing aid:** the home screen has a *Difficulty* dropdown (Adaptive or Test tier 1-10). Test tiers never change your saved skill.

Not built yet: chapters/missions (Phase 4), Daily Challenge, Supabase backend and server-side validation, admin console, sharing, Flame scenes. Scores are local-only and can be edited on the client. Arabic/Bengali vocabulary is a 12-item draft and needs human review; Arabic glyph rendering has not been checked on real devices.

## Run
```
cd apps/player
flutter pub get
flutter analyze && flutter test
flutter run -d chrome
```

## Try it in a browser
Open https://neuronova.muslimit.net/. The `Deploy web to neuronova.muslimit.net` workflow builds and uploads changes on pushes to `main` using the configured deployment secrets.


## Map Puzzle (Bangladesh)

The ninth card: build the map of Bangladesh piece by piece, like a physical map jigsaw.

- **Choose the map** (layers button, or the first screen): the *whole country* or a single *division* or *district*, with *divisions* (8), *districts* (64) or *upazilas* (544) as the pieces. Inside an area only finer levels are offered (for example the upazilas of one district). Villages and the world map are not available yet (see below).
- **Play:** the map sits in the middle and the next pieces wait on all four sides of it (shuffled, coloured by division, nothing scrolls; placing a piece brings the next one into its card). In Settings you can switch to a *scrolling tray*, one row of pieces above the map, instead. Drag a piece onto the map, or tap a piece and then tap its place. Pinch, drag and the **+ / −** buttons zoom the map for crowded areas; the fit button shows the whole map again. A **hint** (bulb) zooms to and pulses the right place and costs score.
- **The board:** like the physical puzzle, there are no names on the empty board. On *Easy* and *Normal* every place is faintly tinted (in its division's colour) with a hairline border, so you can see how big each place is; on *Hard* the board is one blank outline of the whole area. Pieces appear in their places (with their names once there is room to read them) as you build the map.
- **Difficulty** (Settings): *Easy* adds names on the pieces, generous drops and tells you which region a wrong drop landed in; *Normal* has names on the pieces with tighter drops; *Hard* has the blank outline, no names until a piece is placed, and precise drops.
- **Scoring:** same system as the other games: 0-10 points from accuracy (pieces per attempt) and hints, a level-up for 70% or better, points count up in the shared header.
- **Data:** boundaries from the Bangladesh Bureau of Statistics / OCHA ROAP via geoBoundaries (CC BY 3.0 IGO, shown in the game's Settings), Bengali names from nuhil/bangladesh-geocode (MIT). Both are simplified into three small JSON files (about 360 KB) in `apps/player/assets/maps/bd/` by `scripts/build_bd_map.py`; see `assets/maps/ATTRIBUTION.md`. Works offline.

## Flip Duel (two players or vs AI)

The eighth card in the home grid. A shared 6 × 6 green board of 18 fruit / animal pairs with purple "?" tokens. Tap two tokens per turn; a match removes the pair, scores +1 and keeps the turn, a miss shows both tokens for one second and passes the turn. The game ends when every pair is gone and the higher score wins (equal scores are a draw).

- **Same look and system as the other games:** the shared header (game icon, points | round | level, level bar, Settings), the same Settings screen (Difficulty Auto / Easy / Normal / Hard sets the bot), and the same points and endless level system. A finished game **against the AI** earns 0-10 points by your share of the pairs and a level-up for a win; **Auto** difficulty follows your level (low levels meet an easy bot, higher levels a perfect memory). Two-player games never change saved progress.
- **Modes:** *vs AI* (Easy / Medium / Hard) or *friends* on one device. The number of friends (2, 3 or 4 players) is chosen in the game's Settings; the screen's mode bar switches between vs AI and friends. With three or four players the scoreboard shows one coloured card per player and a tie for first place is reported for everyone tied. The bot only knows tiles it has actually seen flipped and forgets some of them (Easy remembers 30%, Medium 65%, Hard everything); it finishes a pair when it remembers both halves.
- **On screen:** both scores, a turn indicator, mode and difficulty selectors, sound toggle and Restart. The board is sized to fit a portrait phone without scrolling.
- **Feel:** 3D flip animation, tap bounce, haptic ticks, a particle burst on matches, shrink-away removal, points counting up in the header. Reduced motion is respected.
- **Sound:** flip, match, mismatch and win effects are synthesized with the Web Audio API in code (no audio files). Mobile builds and tests are silent for now.

### One board look across the games

The green plastic board, recessed round slots and purple-back 3D tokens of Flip Duel are shared components (`nova_board.dart`). Flip Match now uses the same tokens and board; Echo Grid, Path Recall and Focus Dash put their grids on the same green board.

## Echo Grid local matches

Echo Grid now opens a setup screen (the first-time tutorial is still available).
Choose Solo, Friends (2–4 players sharing one device, taking turns), or Computer
(a simulated local opponent). Set 1–50 rounds per player for friends or computer matches. Solo always
continues without a round or score limit; there is no finish-run button.

Each seat can choose 0–15 seconds of preview time; the setting is saved locally.
Home game icons open gameplay directly. Echo Grid starts a solo continuous run;
its in-game Settings button provides preview controls and **Players & rounds**
for a new match.
A ready screen hides the next pattern while the device changes hands. Each
perfect answer advances that player's level; a miss keeps the current level.
Puzzle configurations grow from 3×3 to 7×7 with up to 20 target tiles. Player
levels continue beyond 20; board size stays bounded for readability. The game
settings offer Auto, Easy, Normal and Hard difficulty presets.

Player panels show cumulative match points and current levels. Shared-device
matches place four players at four corners, three players at three corners, or
two players at opposite ends of the grid. Seat colours stay fixed and the active
player is highlighted through previews, recall and result reveals.
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
python3 ../../scripts/prepare_web_release.py build/web
```

Upload the contents of `apps/player/build/web/` to the website's document root.
The deployment workflow uses a root-domain build (`--base-href "/"`).

The CI workflow analyzes, tests and builds the player on each push/PR. The
server deployment workflow uploads the web build directly on pushes to `main`
that change the player application, without using GitHub artifact storage.

## Game library and individual settings

The home screen has six compact, icon-only game cards. Tooltips and accessible
labels identify each game; mobile shows three cards per row. Each icon starts
its game immediately, using its saved preferences. The Settings icon inside each
game opens difficulty, relaxed scoring and instructions. Save returns to gameplay;
an unfinished round restarts so memory previews are not lost while in settings.
Completed results and awarded points are retained. Echo Grid's settings also offer
solo preview time and a player/round setup for starting a new match.

Each game shows its own point total as a number. Round totals are tracked
separately by game; old best scores and legacy XP remain stored but hidden.
Earlier round totals cannot be reconstructed from the old aggregate data.
Shared-device Echo Grid matches retain their independent per-player match scores.

## Web update caching

The production host sets long cache lifetimes for JavaScript. Release preparation
adds content hashes to both the Flutter bootstrap and main bundle filenames, so
new HTML loads the matching new application rather than a cached earlier build.
The bootstrap no longer registers an offline app-shell worker; the HTML retires
only the worker for this app scope. Local scores, preferences and XP are retained.
Both CI and server deployment run the release preparation step after building.

## Manual memory previews and endless solo rounds

Echo Grid and Path Recall accept preview time **0** in game settings. The pattern
or numbered route remains visible until **Start** is pressed; recall scoring time
starts then. Positive preview times continue to switch automatically. Path Recall
now has an explicit **Submit** button and Undo, laid out to stay visible on small
portrait screens. It scores only when the player submits a nonempty route.

Solo Echo Grid ignores any legacy finite round limit and keeps adding rounds and
points after level 20. Group round limits are unchanged. Each game's round number
continues from its saved round total. Icons appear next to game titles, and web
release preparation versions fonts/assets and browser icon URLs as well as scripts
to avoid the production host's long-lived stale icon cache.

## Scoring pace

New rounds award **0–10 points**, with no separate XP reward. Accuracy earns the points;
speed can only modify an accurate answer, so a completely wrong answer earns
zero points. Hints reduce rewards. Group matches use the same point cap.
Existing accumulated points and XP are retained. Legacy per-round best scores
are displayed on the new ten-point scale without deleting their original values.

## Points-only display and endless player levels

Gameplay and results show the point number without XP, best-score or accuracy
panels. New gameplay awards points only; legacy XP values are retained but hidden.
Successful solo rounds raise a separately saved player level with no configured
upper bound. Incorrect rounds and difficulty changes do not reduce that level.
The settings offer **Auto, Easy, Normal, Hard**. Auto keeps adaptive puzzle
difficulty; the other choices use a fixed preset without capping player levels.
Puzzle generators keep their existing safe bounds for screen size and content.

## Compact game header

All six games share one header with the game icon, point number, round and level
next to Settings. Game names and full metric labels remain available through
tooltips and accessibility labels. The separate large point panel and round/level
rows are removed, leaving more room for the board. Multiplayer player seats stay
around the grid; the header shows the current player's points and level.

### Shared-device matches in every game

All six games expose Players & rounds in their in-game settings, with solo, 2–4 friends, or computer play. Two seats sit above/below the board; three/four occupy fixed corners. Start and Submit stay beside the active player's name, and seats stay visible while tall puzzles scroll in the middle. At each handoff the puzzle and its clock wait for that player's Start, without an additional readiness page. Settings offers Automatic (the default) or Tap Next player separately for each game. In automatic mode the result appears for 1.2 seconds, then the next seat receives Start; the final turn opens standings automatically. Manual mode keeps Next player / View results beside the active seat. Opening settings pauses this handoff. A zero-second memory preview still waits for Start before recall. Group points and levels are independent of saved solo progress; fixed rounds end with the existing level-first standings.

### Player experience: Fresh Spark

The ink/mint/gold palette, fixed three-column icon launcher, date-based Today's pick, and remembered Continue action make the next step easier to find. Every game shows quiet five-level checkpoint progress; in solo play there is no separate result page: points, round and level update live in the header (points count up, the level bar slides), a small Correct / Not quite pill with the earned points and, when wrong, the right answer appears above the puzzle, and the next round starts by itself after a short pause (tap the pill to skip; relaxed/untimed mode waits for a Next round tap). A flame streak appears from two correct answers in a row (a miss simply resets it, no penalty), "+N" floats up beside the points, the level label pulses on level-up, and after a miss the chosen card and the right card are marked and a practical tip is shown. Three choice games use two-column answer cards, Focus Dash highlights its target and selected count, and Path Recall displays route progress. Motion respects reduced-motion preferences. See [the design plan](docs/PLAYER_EXPERIENCE.md) for the rationale and validation scope.

## Contributing

Contributions are welcome. Open an issue first for larger changes. Before sending
a pull request, run from `apps/player`:

```sh
flutter analyze
flutter test
```

Native-speaker review of the draft Arabic and Bengali Word Quest vocabulary is
especially appreciated; please open an issue to discuss corrections.

Pull requests from first-time contributors need a maintainer's approval before CI runs.

## Security

Please report vulnerabilities privately; see [SECURITY.md](SECURITY.md).
Do not commit secrets of any kind.

## License

Released under the [MIT License](LICENSE). The NeuroNova name and logo are not
licensed for use as your own branding.
