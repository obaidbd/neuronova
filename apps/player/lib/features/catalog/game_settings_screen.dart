import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game_kind.dart';
import '../../game/content/bd_map.dart';
import '../../game/rules/path_recall.dart';
import '../../game/rules/difficulty.dart';
import '../../core/progress_store.dart';
import 'game_presentation.dart';

enum GameSettingsAction { saved, matchSetup }

class GameSettingsScreen extends StatefulWidget {
  const GameSettingsScreen({
    super.key,
    required this.kind,
    required this.store,
  });
  final GameKind kind;
  final ProgressStore store;
  @override
  State<GameSettingsScreen> createState() => _GameSettingsScreenState();
}

class _GameSettingsScreenState extends State<GameSettingsScreen> {
  late int? tier = difficultyPreset(
    widget.store.practiceTierFor(widget.kind.skillKey),
  );
  late bool untimed = widget.store.untimedFor(widget.kind.skillKey);
  late int duelPlayers = widget.store.duelPlayers;
  late bool mapAround = widget.store.mapPiecesAround;
  late int mapLook = widget.store.mapBoardLook;
  bool busy = false;
  late bool autoHandoff = widget.store.autoHandoffFor(widget.kind.skillKey);
  late int previewSeconds = widget.kind == GameKind.echoGrid
      ? widget.store.echoPreviewSeconds(0)
      : widget.kind == GameKind.pathRecall
      ? widget.store.previewSecondsFor(widget.kind.skillKey) ??
            (PathPuzzle.generate(
                      tier:
                          tier ??
                          widget.store.skillFor(widget.kind.skillKey).tier,
                      seed: 0,
                    ).previewMs /
                    1000)
                .ceil()
      : 4;

  Future<void> save([
    GameSettingsAction action = GameSettingsAction.saved,
  ]) async {
    setState(() => busy = true);
    try {
      await widget.store.setPracticeTierFor(widget.kind.skillKey, tier);
      await widget.store.setUntimedFor(widget.kind.skillKey, untimed);
      await widget.store.setAutoHandoffFor(widget.kind.skillKey, autoHandoff);
      if (widget.kind == GameKind.flipDuel) {
        await widget.store.setDuelPlayers(duelPlayers);
      }
      if (widget.kind == GameKind.mapPuzzle) {
        await widget.store.setMapPiecesAround(mapAround);
        await widget.store.setMapBoardLook(mapLook);
      }
      if (widget.kind == GameKind.echoGrid) {
        await widget.store.setEchoPreviewSeconds(0, previewSeconds);
      }
      if (widget.kind == GameKind.pathRecall) {
        await widget.store.setPreviewSecondsFor(
          widget.kind.skillKey,
          previewSeconds,
        );
      }
      if (mounted) Navigator.of(context).pop(action);
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.kind;
    return Scaffold(
      appBar: AppBar(
        title: Text('${game.title} · Settings'),
        backgroundColor: NovaColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: NovaColors.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(game.icon, color: game.accent, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        game.blurb,
                        style: const TextStyle(
                          color: NovaColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                DropdownButtonFormField<int>(
                  key: const Key('game-difficulty'),
                  initialValue: tier ?? 0,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Difficulty',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Auto')),
                    DropdownMenuItem(value: 2, child: Text('Easy')),
                    DropdownMenuItem(value: 5, child: Text('Normal')),
                    DropdownMenuItem(value: 8, child: Text('Hard')),
                  ],
                  onChanged: busy
                      ? null
                      : (value) =>
                            setState(() => tier = value == 0 ? null : value),
                ),
                if (tier != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Your level keeps growing at this difficulty.',
                      style: TextStyle(
                        fontSize: 12,
                        color: NovaColors.textSecondary,
                      ),
                    ),
                  ),
                if (game == GameKind.mapPuzzle) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'How the empty board looks',
                    style: TextStyle(color: NovaColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    key: const Key('map-look'),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Names + borders')),
                      ButtonSegment(value: 1, label: Text('Borders')),
                      ButtonSegment(value: 2, label: Text('Blank')),
                    ],
                    selected: {mapLook},
                    onSelectionChanged: busy
                        ? null
                        : (s) => setState(() => mapLook = s.first),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Names + borders: every place is faintly tinted, outlined '
                      'and named (where the name fits; zoom in for small ones). '
                      'Borders: tinted and outlined, no names. Blank: one white '
                      'outline of the whole area, like the wooden puzzle.',
                      style: TextStyle(
                        fontSize: 12,
                        color: NovaColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Where the pieces wait',
                    style: TextStyle(color: NovaColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    key: const Key('map-layout'),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: true,
                        label: Text('Around the map'),
                        icon: Icon(Icons.border_outer_rounded, size: 18),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text('Scrolling tray'),
                        icon: Icon(Icons.view_carousel_outlined, size: 18),
                      ),
                    ],
                    selected: {mapAround},
                    onSelectionChanged: busy
                        ? null
                        : (s) => setState(() => mapAround = s.first),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Around the map: the map sits in the middle and the next '
                      'pieces are placed on all four sides, no scrolling. '
                      'Scrolling tray: one row of pieces above the map.',
                      style: TextStyle(
                        fontSize: 12,
                        color: NovaColors.textSecondary,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Difficulty: Easy puts names on the pieces, forgives near '
                      'misses and tells you which region a wrong drop landed in. '
                      'Normal has names on the pieces and tighter drops. Hard has '
                      'no names on the pieces and precise drops.',
                      style: TextStyle(
                        fontSize: 12,
                        color: NovaColors.textSecondary,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      BdMap.attribution,
                      key: Key('map-attribution'),
                      style: TextStyle(
                        fontSize: 11,
                        color: NovaColors.textSecondary,
                      ),
                    ),
                  ),
                ],
                if (game == GameKind.flipDuel) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Players when playing with friends',
                    style: TextStyle(color: NovaColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    key: const Key('duel-players'),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 2, label: Text('2 players')),
                      ButtonSegment(value: 3, label: Text('3 players')),
                      ButtonSegment(value: 4, label: Text('4 players')),
                    ],
                    selected: {duelPlayers},
                    onSelectionChanged: busy
                        ? null
                        : (s) => setState(() => duelPlayers = s.first),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Against the AI it is always you versus the AI.',
                      style: TextStyle(
                        fontSize: 12,
                        color: NovaColors.textSecondary,
                      ),
                    ),
                  ),
                ],
                // Flip Duel and Map Puzzle have no timer, handoff or seats.
                if (game != GameKind.flipDuel &&
                    game != GameKind.mapPuzzle) ...[
                  const SizedBox(height: 12),
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      key: const Key('game-untimed'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Relaxed scoring'),
                      subtitle: const Text('No speed bonus'),
                      value: untimed,
                      onChanged: busy
                          ? null
                          : (value) => setState(() => untimed = value),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<bool>(
                    key: const Key('game-turn-change'),
                    initialValue: autoHandoff,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Multiplayer turn change',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: true, child: Text('Automatic')),
                      DropdownMenuItem(
                        value: false,
                        child: Text('Tap Next player'),
                      ),
                    ],
                    onChanged: busy
                        ? null
                        : (value) =>
                              setState(() => autoHandoff = value ?? true),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'The next player presses Start when ready.',
                      style: TextStyle(
                        fontSize: 12,
                        color: NovaColors.textSecondary,
                      ),
                    ),
                  ),
                  if (game == GameKind.echoGrid ||
                      game == GameKind.pathRecall) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Preview time · ${previewSeconds}s',
                      style: const TextStyle(color: NovaColors.textSecondary),
                    ),
                    Slider(
                      key: const Key('solo-preview'),
                      min: 0,
                      max: 15,
                      divisions: 15,
                      value: previewSeconds.toDouble(),
                      label: '${previewSeconds}s',
                      onChanged: busy
                          ? null
                          : (value) =>
                                setState(() => previewSeconds = value.round()),
                    ),
                    const Text(
                      '0 = wait until you press Start',
                      style: TextStyle(
                        fontSize: 12,
                        color: NovaColors.textSecondary,
                      ),
                    ),
                  ],
                  OutlinedButton.icon(
                    key: const Key('match-settings'),
                    onPressed: busy
                        ? null
                        : () => save(GameSettingsAction.matchSetup),
                    icon: const Icon(Icons.group_outlined),
                    label: const Text('Players & rounds'),
                  ),
                  const Text(
                    'Start a new match',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: NovaColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 12),
                  title: const Text(
                    'How to play',
                    style: TextStyle(fontSize: 15),
                  ),
                  children: [
                    for (var i = 0; i < game.instructions.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${i + 1}.',
                              style: TextStyle(color: game.accent),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                game.instructions[i],
                                style: const TextStyle(
                                  color: NovaColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('save-game-settings'),
                  onPressed: busy ? null : () => save(),
                  style: FilledButton.styleFrom(backgroundColor: game.accent),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
