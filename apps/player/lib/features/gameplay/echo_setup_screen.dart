import 'package:flutter/material.dart';

import '../../core/progress_store.dart';
import '../../app/theme.dart';
import '../../game/rules/echo_match.dart';
import 'echo_grid_screen.dart';
import 'round_shell.dart';
import '../../core/game_kind.dart';

class EchoSetupScreen extends StatefulWidget {
  const EchoSetupScreen({
    super.key,
    required this.store,
    this.tierOverride,
    this.kind = GameKind.echoGrid,
  });
  final GameKind kind;
  final ProgressStore store;
  final int? tierOverride;
  @override
  State<EchoSetupScreen> createState() => _EchoSetupScreenState();
}

class _EchoSetupScreenState extends State<EchoSetupScreen> {
  String mode = 'Solo';
  int count = 2;
  int rounds = 10;
  bool starting = false;
  late final seconds = List.generate(
    4,
    (i) => widget.kind == GameKind.echoGrid
        ? widget.store.echoPreviewSeconds(i)
        : widget.store.previewSecondsFor(widget.kind.skillKey) ?? 4,
  );
  bool get hasPreview =>
      widget.kind == GameKind.echoGrid || widget.kind == GameKind.pathRecall;
  final names = List.generate(
    4,
    (i) => TextEditingController(text: 'Player ${i + 1}'),
  );
  int get seats => mode == 'Solo'
      ? 1
      : mode == 'Computer'
      ? 2
      : count;

  @override
  void dispose() {
    for (final name in names) {
      name.dispose();
    }
    super.dispose();
  }

  Future<void> start() async {
    setState(() => starting = true);
    try {
      for (var i = 0; widget.kind == GameKind.echoGrid && i < seats; i++) {
        await widget.store.setEchoPreviewSeconds(i, seconds[i]);
      }
      if (widget.kind == GameKind.pathRecall && seats == 1) {
        await widget.store.setPreviewSecondsFor(
          widget.kind.skillKey,
          seconds[0],
        );
      }
      if (!mounted) return;
      final match = EchoMatch(
        roundLimit: mode == 'Solo' ? null : rounds,
        players: List.generate(
          seats,
          (i) => EchoPlayer(
            mode == 'Computer' && i == 1
                ? 'Computer'
                : names[i].text.trim().isEmpty
                ? 'Player ${i + 1}'
                : names[i].text.trim(),
            computer: mode == 'Computer' && i == 1,
            previewSeconds: seconds[i],
            level: mode == 'Solo'
                ? widget.store.levelFor(widget.kind.skillKey)
                : 1,
          ),
        ),
      );
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => widget.kind == GameKind.echoGrid
              ? EchoGridScreen(
                  store: widget.store,
                  match: match,
                  tierOverride: widget.tierOverride,
                )
              : RoundShell(
                  kind: widget.kind,
                  store: widget.store,
                  match: match,
                  tierOverride: widget.tierOverride,
                ),
        ),
      );
    } finally {
      if (mounted) setState(() => starting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Match settings')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final m in ['Solo', 'Friends', 'Computer'])
                  ChoiceChip(
                    label: Text(m),
                    selected: mode == m,
                    onSelected: (_) => setState(() => mode = m),
                  ),
              ],
            ),
            if (mode == 'Friends') ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final n in [2, 3, 4])
                    ChoiceChip(
                      label: Text('$n players'),
                      selected: count == n,
                      onSelected: (_) => setState(() => count = n),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            if (mode == 'Solo')
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Continuous play · No round limit',
                  style: TextStyle(color: NovaColors.textSecondary),
                ),
              ),
            if (mode != 'Solo') ...[
              Text(
                '$rounds rounds per player · ${rounds * seats} turns total',
                key: const Key('round-count'),
              ),
              Slider(
                key: const Key('match-rounds'),
                min: 1,
                max: 50,
                divisions: 49,
                value: rounds.toDouble(),
                label: '$rounds',
                onChanged: (v) => setState(() => rounds = v.round()),
              ),
            ],
            const SizedBox(height: 12),
            for (var i = 0; i < seats; i++)
              Card(
                color: NovaColors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (mode == 'Computer' && i == 1)
                        const Text('Computer')
                      else
                        TextField(
                          controller: names[i],
                          maxLength: 20,
                          decoration: InputDecoration(
                            labelText: 'Player ${i + 1}',
                            counterText: '',
                          ),
                        ),
                      if (hasPreview) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Preview · ${seconds[i]}s (0 = manual)',
                          style: const TextStyle(
                            color: NovaColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        Slider(
                          key: Key('preview-$i'),
                          min: 0,
                          max: 15,
                          divisions: 15,
                          value: seconds[i].toDouble(),
                          label: '${seconds[i]}s',
                          onChanged: (v) =>
                              setState(() => seconds[i] = v.round()),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('start-match'),
              onPressed: starting ? null : start,
              child: const Text('Start game'),
            ),
          ],
        ),
      ),
    ),
  );
}
