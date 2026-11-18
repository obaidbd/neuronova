import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game_kind.dart';
import '../../game/content/bd_map.dart';
import '../catalog/game_presentation.dart';

/// Chooses what to build: the whole country or one area, and which regions
/// (divisions, districts or upazilas) are the pieces.
class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key, required this.map, required this.current});
  final BdMap map;
  final MapSelection current;

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late String? scopeId = widget.current.scopeId;
  late MapLevel level = widget.current.level;

  BdMap get map => widget.map;
  Color get accent => GameKind.mapPuzzle.accent;

  /// A scope's levels are always finer than the scope itself.
  void _setScope(String? id) {
    setState(() {
      scopeId = id;
      final ok = map.levelsFor(id);
      if (!ok.contains(level)) level = ok.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selection = MapSelection(scopeId: scopeId, level: level);
    final count = map.piecesFor(selection).length;
    final valid = map.levelsFor(scopeId);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a map'),
        backgroundColor: NovaColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                const Text(
                  'Region',
                  style: TextStyle(color: NovaColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Bangladesh'),
                      selected: true,
                      onSelected: (_) {},
                    ),
                    const ChoiceChip(
                      label: Text('World · coming soon'),
                      selected: false,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  key: const Key('map-scope'),
                  initialValue: scopeId ?? 'all',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Area',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('Whole of Bangladesh'),
                    ),
                    for (final d in map.divisions) ...[
                      DropdownMenuItem(
                        value: d.id,
                        child: Text('${d.en} Division · ${d.bn}'),
                      ),
                      for (final z in map.districts.where(
                        (z) => z.parent == d.id,
                      ))
                        DropdownMenuItem(
                          value: z.id,
                          child: Text('      ${z.en} District · ${z.bn}'),
                        ),
                    ],
                  ],
                  onChanged: (v) => _setScope(v == 'all' ? null : v),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Pieces',
                  style: TextStyle(color: NovaColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final l in MapLevel.values)
                      ChoiceChip(
                        key: Key('level-${l.name}'),
                        label: Text(
                          '${l.label} · '
                          '${map.piecesFor(MapSelection(scopeId: scopeId, level: l)).length}',
                        ),
                        selected: level == l,
                        selectedColor: accent.withValues(alpha: .35),
                        onSelected: valid.contains(l)
                            ? (_) => setState(() => level = l)
                            : null,
                      ),
                    const ChoiceChip(
                      label: Text('Villages · coming soon'),
                      selected: false,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '$count pieces',
                  key: const Key('map-piece-count'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
                if (count > 150)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'A big puzzle! Try one division first, then the whole country.',
                      style: TextStyle(
                        fontSize: 12,
                        color: NovaColors.textSecondary,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('map-start'),
                  onPressed: () => Navigator.of(context).pop(selection),
                  style: FilledButton.styleFrom(backgroundColor: accent),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
