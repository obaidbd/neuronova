/// One finished round as seen by the adaptive engine.
class RoundRecord {
  const RoundRecord({
    required this.accuracy,
    required this.success,
    this.usedHint = false,
  });
  final double accuracy;
  final bool success;
  final bool usedHint;
}

/// Per-skill adaptive state (spec §15). Tier changes by at most one.
class SkillState {
  SkillState({this.tier = 1, List<RoundRecord>? recent})
    : recent = List.of(recent ?? const []);

  static const minTier = 1;
  static const maxTier = 10;

  int tier;
  final List<RoundRecord> recent;

  void record(RoundRecord r) {
    recent.add(r);
    if (recent.length > 5) recent.removeAt(0);
    tier = nextTier();
  }

  int nextTier() {
    if (recent.length >= 3) {
      final lastThree = recent.sublist(recent.length - 3);
      if (lastThree.every((r) => !r.success)) {
        return (tier - 1).clamp(minTier, maxTier);
      }
    }
    if (recent.length == 5) {
      final avg = recent.map((r) => r.accuracy).reduce((a, b) => a + b) / 5;
      final hints = recent.where((r) => r.usedHint).length;
      final independent = recent.where((r) => !r.usedHint).length;
      if (avg >= 0.8 && hints <= 1 && independent >= 3) {
        return (tier + 1).clamp(minTier, maxTier);
      }
      if (avg < 0.5) return (tier - 1).clamp(minTier, maxTier);
    }
    return tier;
  }

  Map<String, dynamic> toJson() => {
    'tier': tier,
    'recent': [
      for (final r in recent)
        {'a': r.accuracy, 's': r.success, 'h': r.usedHint},
    ],
  };

  factory SkillState.fromJson(Map<String, dynamic> j) => SkillState(
    tier: (j['tier'] as int?) ?? 1,
    recent: [
      for (final r in (j['recent'] as List? ?? const []))
        RoundRecord(
          accuracy: (r['a'] as num).toDouble(),
          success: r['s'] as bool,
          usedHint: r['h'] as bool? ?? false,
        ),
    ],
  );
}
