import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../game/rules/adaptive.dart';
import '../game/rules/scoring.dart';

/// Local guest progress (spec §30). XP is local-only until a server exists.
class ProgressStore {
  ProgressStore(this._prefs);
  final SharedPreferences _prefs;

  static Future<ProgressStore> open() async =>
      ProgressStore(await SharedPreferences.getInstance());

  int echoPreviewSeconds(int seat) =>
      (_prefs.getInt('echo_preview_$seat') ?? 4).clamp(0, 15);
  Future<void> setEchoPreviewSeconds(int seat, int seconds) async {
    await _prefs.setInt('echo_preview_$seat', seconds.clamp(0, 15));
  }

  int? previewSecondsFor(String game) =>
      _prefs.getInt('preview_$game')?.clamp(0, 15);
  Future<void> setPreviewSecondsFor(String game, int seconds) async {
    await _prefs.setInt('preview_$game', seconds.clamp(0, 15));
  }

  String? get lastPlayedGame => _prefs.getString('last_played_game');
  Future<void> setLastPlayedGame(String game) =>
      _prefs.setString('last_played_game', game);

  bool get tutorialDone => _prefs.getBool('tutorialDone') ?? false;
  Future<void> setTutorialDone() => _prefs.setBool('tutorialDone', true);

  int get xp => _prefs.getInt('xp') ?? 0;
  int get novaEnergy => _prefs.getInt('energy') ?? 0;
  int bestFor(String skillKey) =>
      _prefs.getInt('best_points_$skillKey') ??
      ((_prefs.getInt('best_$skillKey') ?? 0) / 10).round().clamp(
        0,
        maxRoundScore,
      );
  int levelFor(String game) {
    final value = _prefs.getInt('level_$game') ?? skillFor(game).tier;
    return value < 1 ? 1 : value;
  }

  int pointsFor(String game) => _prefs.getInt('points_$game') ?? 0;
  int xpFor(String game) => _prefs.getInt('xp_$game') ?? 0;
  int roundsFor(String game) => _prefs.getInt('rounds_$game') ?? 0;
  int get bestScore => bestFor('visual_memory');
  int get completedRounds => _prefs.getInt('rounds') ?? 0;
  bool get untimedMode => _prefs.getBool('untimed') ?? false;
  Future<void> setUntimed(bool v) => _prefs.setBool('untimed', v);

  bool untimedFor(String game) =>
      _prefs.getBool('untimed_$game') ?? untimedMode;
  Future<void> setUntimedFor(String game, bool value) async {
    await _prefs.setBool('untimed_$game', value);
  }

  bool autoHandoffFor(String game) =>
      _prefs.getBool('auto_handoff_$game') ?? true;
  Future<void> setAutoHandoffFor(String game, bool value) async {
    await _prefs.setBool('auto_handoff_$game', value);
  }

  int? practiceTierFor(String game) {
    final value = _prefs.getInt('practice_$game');
    return value?.clamp(1, 10);
  }

  Future<void> setPracticeTierFor(String game, int? tier) async {
    if (tier == null) {
      await _prefs.remove('practice_$game');
    } else {
      await _prefs.setInt('practice_$game', tier.clamp(1, 10));
    }
  }

  SkillState get memorySkill => skillFor('visual_memory');

  SkillState skillFor(String key) {
    final raw = _prefs.getString('skill_$key');
    if (raw == null) return SkillState();
    try {
      return SkillState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return SkillState(); // corrupted cache -> start fresh
    }
  }

  /// Idempotent per [roundId]: the same completion never awards twice.
  Future<bool> commitRound({
    required String roundId,
    required int score,
    required int xp,
    required SkillState skill,
    String skillKey = 'visual_memory',
    bool levelUp = false,
  }) async {
    final previousLevel = levelFor(skillKey);
    final awardedScore = score.clamp(0, maxRoundScore);
    final done = _prefs.getStringList('committed') ?? <String>[];
    if (done.contains(roundId)) return false;
    done.add(roundId);
    if (done.length > 200) done.removeRange(0, done.length - 200);
    await _prefs.setStringList('committed', done);
    await _prefs.setInt('xp', xp + this.xp);
    await _prefs.setInt('energy', novaEnergy + (awardedScore >= 6 ? 10 : 3));
    await _prefs.setInt('rounds', completedRounds + 1);
    await _prefs.setInt('points_$skillKey', pointsFor(skillKey) + awardedScore);
    await _prefs.setInt('xp_$skillKey', xpFor(skillKey) + xp);
    await _prefs.setInt('rounds_$skillKey', roundsFor(skillKey) + 1);
    await _prefs.setInt('level_$skillKey', previousLevel + (levelUp ? 1 : 0));
    if (awardedScore > bestFor(skillKey)) {
      await _prefs.setInt('best_points_$skillKey', awardedScore);
    }
    await _prefs.setString('skill_$skillKey', jsonEncode(skill.toJson()));
    return true;
  }
}
