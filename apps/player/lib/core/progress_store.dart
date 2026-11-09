import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../game/rules/adaptive.dart';

/// Local guest progress (spec §30). XP is local-only until a server exists.
class ProgressStore {
  ProgressStore(this._prefs);
  final SharedPreferences _prefs;

  static Future<ProgressStore> open() async =>
      ProgressStore(await SharedPreferences.getInstance());

  bool get tutorialDone => _prefs.getBool('tutorialDone') ?? false;
  Future<void> setTutorialDone() => _prefs.setBool('tutorialDone', true);

  int get xp => _prefs.getInt('xp') ?? 0;
  int get novaEnergy => _prefs.getInt('energy') ?? 0;
  int get bestScore => _prefs.getInt('best_echo_grid') ?? 0;
  int get completedRounds => _prefs.getInt('rounds') ?? 0;
  bool get untimedMode => _prefs.getBool('untimed') ?? false;
  Future<void> setUntimed(bool v) => _prefs.setBool('untimed', v);

  SkillState get memorySkill {
    final raw = _prefs.getString('skill_visual_memory');
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
  }) async {
    final done = _prefs.getStringList('committed') ?? <String>[];
    if (done.contains(roundId)) return false;
    done.add(roundId);
    if (done.length > 200) done.removeRange(0, done.length - 200);
    await _prefs.setStringList('committed', done);
    await _prefs.setInt('xp', xp + this.xp);
    await _prefs.setInt('energy', novaEnergy + (score >= 60 ? 10 : 3));
    await _prefs.setInt('rounds', completedRounds + 1);
    if (score > bestScore) await _prefs.setInt('best_echo_grid', score);
    await _prefs.setString('skill_visual_memory', jsonEncode(skill.toJson()));
    return true;
  }
}
