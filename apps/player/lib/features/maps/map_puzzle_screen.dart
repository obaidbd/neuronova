import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/game_kind.dart';
import '../../core/progress_store.dart';
import '../../core/sfx.dart';
import '../../game/content/bd_map.dart';
import '../../game/rules/adaptive.dart';
import '../../game/rules/map_puzzle.dart';
import '../../game/rules/scoring.dart';
import '../catalog/game_presentation.dart';
import '../catalog/game_settings_screen.dart';
import '../gameplay/game_header.dart';
import '../gameplay/nova_board.dart';
import 'map_painters.dart';
import 'map_picker_screen.dart';

/// Build the map of Bangladesh from its regions: drag a piece from the tray
/// onto the map (or tap the piece, then tap its place), zoom in for crowded
/// areas, and choose divisions, districts or upazilas as the pieces.
class MapPuzzleScreen extends StatefulWidget {
  const MapPuzzleScreen({
    super.key,
    required this.store,
    this.map,
    this.selection,
    this.seed,
    this.sfx,
  });
  final ProgressStore store;

  /// Preloaded map data (tests); loaded from the app assets when null.
  final BdMap? map;
  final MapSelection? selection;
  final int? seed;
  final Sfx? sfx;

  @override
  State<MapPuzzleScreen> createState() => _MapPuzzleScreenState();
}

class _MapPuzzleScreenState extends State<MapPuzzleScreen>
    with SingleTickerProviderStateMixin {
  BdMap? map;
  MapPuzzle? puzzle;
  late MapSelection selection;
  late final Sfx sfx = widget.sfx ?? createSfx();
  final TransformationController zoom = TransformationController();
  late final AnimationController pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  final GlobalKey _sceneKey = GlobalKey();
  bool muted = false;
  String? selectedId, hintId, wrongId;
  String status = '';
  int? gain;
  late String roundId;
  bool committed = false;
  Timer? _hintTimer, _wrongTimer;

  // Layout remembered from the last build, for hit-testing and zooming.
  MapProjection? _projection;
  Size _boardSize = Size.zero;
  Map<String, Path> _paths = {};

  String get _key => GameKind.mapPuzzle.skillKey;

  MapHelp _helpFromSettings() => mapHelpForTier(
    widget.store.practiceTierFor(_key) ?? widget.store.levelFor(_key),
  );

  /// Names drawn on the map are laid out by hand, so they must be laid out
  /// again when a fallback font (Bengali) arrives after the first frame.
  void _fontsChanged() {
    MapBoardPainter.clearLabels();
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(_fontsChanged);
    selection =
        widget.selection ??
        MapSelection.parse(widget.store.mapSelection) ??
        MapSelection.country;
    map = widget.map ?? BdMap.loadedOrNull;
    if (map != null) {
      _newPuzzle();
    } else {
      BdMap.load().then((m) {
        if (!mounted) return;
        map = m;
        // A saved choice from an older data set may no longer exist.
        if (m.piecesFor(selection).isEmpty) selection = MapSelection.country;
        _newPuzzle();
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_fontsChanged);
    _hintTimer?.cancel();
    _wrongTimer?.cancel();
    pulse.dispose();
    zoom.dispose();
    sfx.dispose();
    super.dispose();
  }

  void _newPuzzle() {
    final m = map!;
    puzzle = MapPuzzle(
      map: m,
      selection: selection,
      help: _helpFromSettings(),
      seed: widget.seed,
    );
    roundId = '${DateTime.now().microsecondsSinceEpoch}-${selection.key}';
    committed = false;
    gain = null;
    hintId = wrongId = null;
    zoom.value = Matrix4.identity();
    _projection = null;
    selectedId = puzzle!.order.first;
    status = '';
  }

  void _play(void Function() sound) {
    if (!muted) sound();
  }

  // ---- interaction ---------------------------------------------------------

  void _select(String id) => setState(() {
    selectedId = id;
    status = '';
  });

  /// Tap on the map: place the selected piece where the player tapped.
  void _tapBoard(Offset scenePoint) {
    final id = selectedId;
    if (id == null || puzzle == null || puzzle!.done) return;
    _place(id, scenePoint);
  }

  /// Drop of a dragged piece (global position of the finger).
  void _drop(String id, Offset global) {
    final box = _sceneKey.currentContext?.findRenderObject();
    if (box is! RenderBox) return;
    _place(id, box.globalToLocal(global));
  }

  void _place(String id, Offset scenePoint) {
    final pz = puzzle!;
    final proj = _projection;
    if (proj == null) return;
    final z = zoom.value.getMaxScaleOnAxis();
    final out = pz.tryPlace(
      id,
      proj.fromBoard(scenePoint),
      slack: 10 / (proj.scale * z),
    );
    switch (out) {
      case PlaceOutcome.placed:
        _play(sfx.match);
        HapticFeedback.lightImpact();
        hintId = null;
        final rest = pz.remaining;
        selectedId = rest.isEmpty ? null : rest.first;
        status = '';
        setState(() {});
        if (pz.done) _finish();
      case PlaceOutcome.wrong:
        _play(sfx.miss);
        HapticFeedback.selectionClick();
        final w = pz.lastWrong!;
        wrongId = w.id;
        status = pz.help.tellsWrongRegion
            ? 'That is ${w.en} — try again'
            : 'Not there — try again';
        _wrongTimer?.cancel();
        _wrongTimer = Timer(const Duration(milliseconds: 700), () {
          if (mounted) setState(() => wrongId = null);
        });
        setState(() {});
      case PlaceOutcome.missed:
        break;
    }
  }

  Future<void> _finish() async {
    _play(sfx.win);
    HapticFeedback.mediumImpact();
    final pz = puzzle!;
    final r = pz.result();
    final points = gameScore(
      accuracy: r.accuracy,
      timed: false,
      hints: r.hints,
    );
    if (!committed) {
      committed = true;
      final skill = widget.store.skillFor(_key);
      skill.record(RoundRecord(accuracy: r.accuracy, success: r.success));
      await widget.store.commitRound(
        roundId: roundId,
        score: points,
        xp: 0,
        skill: skill,
        skillKey: _key,
        levelUp: r.success,
      );
    }
    if (mounted) setState(() => gain = points);
  }

  /// A hint costs score: it pulses the selected piece's slot and zooms to it.
  void _hint() {
    final pz = puzzle!;
    final id = selectedId ?? (pz.remaining.isEmpty ? null : pz.remaining.first);
    if (id == null || pz.done) return;
    final u = pz.useHint(id);
    selectedId = id;
    hintId = id;
    status = 'Hint used — the slot is pulsing';
    pulse.repeat(reverse: true);
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(milliseconds: 3200), () {
      pulse.stop();
      if (mounted) setState(() => hintId = null);
    });
    _focusOn(u);
    setState(() {});
  }

  /// Centre the view on a region.
  void _focusOn(MapUnit u) {
    final proj = _projection;
    if (proj == null) return;
    final r = proj.rectToBoard(u.bounds);
    final z =
        (min(
                  _boardSize.width / max(r.width, 1),
                  _boardSize.height / max(r.height, 1),
                ) *
                .35)
            .clamp(1.0, 10.0);
    final c = r.center;
    zoom.value = Matrix4.identity()
      ..translateByDouble(_boardSize.width / 2, _boardSize.height / 2, 0, 1)
      ..scaleByDouble(z, z, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
  }

  void _zoomBy(double factor) {
    final cur = zoom.value.getMaxScaleOnAxis();
    final target = (cur * factor).clamp(1.0, 14.0);
    final k = target / cur;
    final c = Offset(_boardSize.width / 2, _boardSize.height / 2);
    final m = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(k, k, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
    zoom.value = m.multiplied(zoom.value);
  }

  Future<void> _chooseMap() async {
    final m = map;
    if (m == null) return;
    final picked = await Navigator.of(context).push<MapSelection>(
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(map: m, current: selection),
      ),
    );
    if (picked == null || !mounted) return;
    selection = picked;
    await widget.store.setMapSelection(picked.key);
    setState(_newPuzzle);
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<GameSettingsAction>(
      MaterialPageRoute(
        builder: (_) =>
            GameSettingsScreen(kind: GameKind.mapPuzzle, store: widget.store),
      ),
    );
    if (!mounted || puzzle == null) return;
    // A new help level starts a fresh puzzle; a new layout just redraws.
    if (_helpFromSettings() != puzzle!.help) {
      setState(_newPuzzle);
    } else {
      setState(() {});
    }
  }

  // ---- layout --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final pz = puzzle;
    return Scaffold(
      appBar: GameHeader(
        kind: GameKind.mapPuzzle,
        points: widget.store.pointsFor(_key),
        round: widget.store.roundsFor(_key) + 1,
        level: widget.store.levelFor(_key),
        difficulty: pz == null ? 'Auto' : pz.help.name,
        onSettings: _openSettings,
        animate: true,
        gain: gain,
        gainKey: pz == null ? null : roundId,
        extraActions: [
          IconButton(
            key: const Key('map-sound'),
            tooltip: muted ? 'Sound off' : 'Sound on',
            icon: Icon(
              muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              size: 23,
            ),
            onPressed: () => setState(() => muted = !muted),
          ),
        ],
      ),
      body: SafeArea(
        child: pz == null
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    child: Column(
                      children: widget.store.mapPiecesAround
                          ? [
                              _infoBar(pz),
                              const SizedBox(height: 2),
                              _statusLine(pz),
                              const SizedBox(height: 6),
                              Expanded(child: _around(pz)),
                            ]
                          : [
                              _infoBar(pz),
                              const SizedBox(height: 6),
                              _tray(pz),
                              const SizedBox(height: 4),
                              _statusLine(pz),
                              const SizedBox(height: 4),
                              Expanded(child: _board(pz)),
                            ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _infoBar(MapPuzzle pz) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              map!.titleFor(selection),
              key: const Key('map-title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            Text(
              '${pz.placed.length} / ${pz.total} placed',
              key: const Key('map-progress'),
              style: TextStyle(
                fontSize: 12,
                color: GameKind.mapPuzzle.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      IconButton(
        key: const Key('map-hint'),
        tooltip: 'Hint (costs points)',
        icon: const Icon(Icons.lightbulb_outline_rounded),
        onPressed: pz.done ? null : _hint,
      ),
      IconButton(
        key: const Key('map-change'),
        tooltip: 'Choose map',
        icon: const Icon(Icons.layers_outlined),
        onPressed: _chooseMap,
      ),
    ],
  );

  /// The pieces still to place, shuffled; drag one out or tap to select it.
  Widget _tray(MapPuzzle pz) {
    final rest = pz.remaining;
    return SizedBox(
      key: const Key('map-tray'),
      height: 98,
      child: rest.isEmpty
          ? const Center(
              child: Text(
                'All pieces placed!',
                style: TextStyle(color: NovaColors.textSecondary),
              ),
            )
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemExtent: 86,
              itemCount: rest.length,
              itemBuilder: (context, i) => _pieceCard(pz, rest[i]),
            ),
    );
  }

  Widget _pieceCard(MapPuzzle pz, String id, {bool compact = false}) {
    final u = pz.unit(id);
    final selected = id == selectedId;
    final card = _PieceCard(
      unit: u,
      color: colorOf(map!, u),
      selected: selected,
      showName: pz.help.namesOnPieces,
      compact: compact,
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 1 : 3),
      child: GestureDetector(
        key: Key('piece-$id'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _select(id),
        child: Draggable<String>(
          data: id,
          // In the scrolling tray sideways drags scroll; around the map any
          // direction drags the piece.
          affinity: compact ? null : Axis.vertical,
          dragAnchorStrategy: (d, c, p) => const Offset(40, 40),
          onDragStarted: () => _select(id),
          onDragEnd: (details) {
            if (details.wasAccepted) return;
            _drop(id, details.offset + const Offset(40, 40));
          },
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: 80,
              height: 80,
              child: CustomPaint(
                painter: PiecePainter(u, colorOf(map!, u), selected: true),
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: .35, child: card),
          child: card,
        ),
      ),
    );
  }

  /// The map in the middle with the next pieces placed on all four sides, so
  /// nothing scrolls. Free rows above and below take any spare height.
  Widget _around(MapPuzzle pz) => LayoutBuilder(
    builder: (context, c) {
      const cw = 54.0, ch = 64.0;
      final w = c.maxWidth, h = c.maxHeight;
      final mapW = max(w - 2 * cw, 120.0);
      final aspect = pz.bounds.height / pz.bounds.width;
      final mapNeeded = min(mapW * aspect, h - 2 * ch);
      final rows = max(1, ((h - mapNeeded) / (2 * ch)).floor());
      final mapH = max(h - 2 * rows * ch, 120.0);
      final cols = max(1, (w / cw).floor());
      final side = max(0, (mapH / ch).floor());
      final left = (w - cols * cw) / 2;
      final sideTop = rows * ch + (mapH - side * ch) / 2;
      // Where cards go, in the order the next pieces fill them.
      final spots = <Offset>[
        for (var r = 0; r < rows; r++)
          for (var k = 0; k < cols; k++) Offset(left + k * cw, r * ch),
        for (var k = 0; k < side; k++) Offset(w - cw, sideTop + k * ch),
        for (var r = rows - 1; r >= 0; r--)
          for (var k = cols - 1; k >= 0; k--)
            Offset(left + k * cw, h - (r + 1) * ch),
        for (var k = side - 1; k >= 0; k--) Offset(0, sideTop + k * ch),
      ];
      final shown = pz.remaining.take(spots.length).toList();
      return Stack(
        key: const Key('map-around'),
        children: [
          Positioned(
            left: cw,
            top: rows * ch,
            width: w - 2 * cw,
            height: mapH,
            child: _board(pz),
          ),
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: spots[i].dx,
              top: spots[i].dy,
              width: cw,
              height: ch,
              child: _pieceCard(pz, shown[i], compact: true),
            ),
        ],
      );
    },
  );

  Widget _statusLine(MapPuzzle pz) {
    final sel = selectedId == null ? null : pz.unit(selectedId!);
    final String text;
    if (pz.done) {
      text = 'Map complete!';
    } else if (status.isNotEmpty) {
      text = status;
    } else if (sel != null && pz.help.namesOnPieces) {
      text = 'Place: ${sel.nameBn()} · ${sel.en}';
    } else {
      text = 'Place the selected piece';
    }
    return Text(
      text,
      key: const Key('map-status'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: wrongId != null ? NovaColors.danger : GameKind.mapPuzzle.accent,
      ),
    );
  }

  Widget _board(MapPuzzle pz) => Stack(
    key: const Key('map-board'),
    children: [
      NovaBoardFrame(
        padding: EdgeInsets.zero,
        radius: 22,
        colors: const [Color(0xFFD6ECFA), Color(0xFFAED8F2)],
        borderColor: const Color(0xFFEAF6FD),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LayoutBuilder(
            builder: (context, c) {
              final size = Size(c.maxWidth, c.maxHeight);
              if (_projection == null || _boardSize != size) {
                _boardSize = size;
                _projection = MapProjection(pz.bounds, size);
                _paths = {
                  for (final u in pz.pieces)
                    u.id: pathOf(u, _projection!.toBoard),
                };
              }
              return DragTarget<String>(
                onWillAcceptWithDetails: (_) => true,
                onAcceptWithDetails: (d) =>
                    _drop(d.data, d.offset + const Offset(40, 40)),
                builder: (context, _, _) => InteractiveViewer(
                  transformationController: zoom,
                  minScale: 1,
                  maxScale: 14,
                  boundaryMargin: EdgeInsets.all(size.shortestSide * .3),
                  child: GestureDetector(
                    onTapUp: (d) => _tapBoard(d.localPosition),
                    child: SizedBox(
                      key: const Key('map-scene'),
                      width: size.width,
                      height: size.height,
                      child: CustomPaint(
                        key: _sceneKey,
                        painter: MapBoardPainter(
                          puzzle: pz,
                          map: map!,
                          projection: _projection!,
                          paths: _paths,
                          controller: zoom,
                          pulse: pulse,
                          hintId: hintId,
                          wrongId: wrongId,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      Positioned(
        right: 8,
        bottom: 8,
        child: Column(
          children: [
            _zoomButton(Icons.add_rounded, 'Zoom in', () => _zoomBy(1.6)),
            const SizedBox(height: 6),
            _zoomButton(
              Icons.remove_rounded,
              'Zoom out',
              () => _zoomBy(1 / 1.6),
            ),
            const SizedBox(height: 6),
            _zoomButton(
              Icons.fit_screen_rounded,
              'Show the whole map',
              () => zoom.value = Matrix4.identity(),
            ),
          ],
        ),
      ),
      if (pz.done) Positioned.fill(child: _donePanel(pz)),
    ],
  );

  Widget _zoomButton(IconData icon, String tip, VoidCallback onTap) => Material(
    color: NovaColors.background.withValues(alpha: .85),
    shape: const CircleBorder(),
    child: IconButton(
      key: Key(
        'map-zoom-${tip == 'Zoom in'
            ? 'in'
            : tip == 'Zoom out'
            ? 'out'
            : 'fit'}',
      ),
      tooltip: tip,
      icon: Icon(icon, size: 22),
      onPressed: onTap,
    ),
  );

  Widget _donePanel(MapPuzzle pz) {
    final r = pz.result();
    return Container(
      key: const Key('map-done'),
      decoration: BoxDecoration(
        color: const Color(0xE60B1426),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.emoji_events_rounded,
              color: NovaColors.gold,
              size: 52,
            ),
            const SizedBox(height: 6),
            Text(
              r.success ? 'Map complete!' : 'Map complete — keep practising!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${pz.total} pieces · ${r.mistakes} wrong tries · ${r.hints} hints',
              key: const Key('map-summary'),
              style: const TextStyle(color: NovaColors.textSecondary),
            ),
            if (gain != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+$gain points',
                  key: const Key('map-gain'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: GameKind.mapPuzzle.accent,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  key: const Key('map-again'),
                  onPressed: () => setState(_newPuzzle),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(130, 46),
                    backgroundColor: GameKind.mapPuzzle.accent,
                  ),
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Again'),
                ),
                OutlinedButton.icon(
                  key: const Key('map-choose-again'),
                  onPressed: _chooseMap,
                  icon: const Icon(Icons.layers_outlined),
                  label: const Text('Choose map'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A piece in the tray: its shape in its division's colour, and its name.
class _PieceCard extends StatelessWidget {
  const _PieceCard({
    required this.unit,
    required this.color,
    required this.selected,
    required this.showName,
    this.compact = false,
  });
  final bool compact;
  final MapUnit unit;
  final Color color;
  final bool selected;
  final bool showName;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    padding: compact
        ? const EdgeInsets.fromLTRB(2, 3, 2, 2)
        : const EdgeInsets.fromLTRB(4, 6, 4, 4),
    decoration: BoxDecoration(
      color: selected
          ? GameKind.mapPuzzle.accent.withValues(alpha: .18)
          : NovaColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: selected ? GameKind.mapPuzzle.accent : Colors.transparent,
        width: 2,
      ),
    ),
    child: Column(
      children: [
        Expanded(
          child: CustomPaint(
            size: const Size.square(56),
            painter: PiecePainter(unit, color, selected: selected),
          ),
        ),
        SizedBox(height: compact ? 1 : 3),
        SizedBox(
          height: compact ? 11 : 14,
          child: showName
              ? Text(
                  unit.nameBn(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: compact ? 9 : 11),
                )
              : null,
        ),
      ],
    ),
  );
}
