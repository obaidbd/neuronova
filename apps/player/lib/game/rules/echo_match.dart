import 'dart:math';

/// A local match. Each seat has independent progress; ties remain ties.
class EchoPlayer {
  EchoPlayer(
    this.name, {
    this.computer = false,
    this.previewSeconds = 4,
    this.level = 1,
  });
  final String name;
  final bool computer;
  int previewSeconds;
  int level;
  int reachedLevel = 0;
  int points = 0;
  int rounds = 0;
}

class EchoMatch {
  EchoMatch({
    required this.players,
    int? roundLimit = 10,
    bool tutorial = false,
  }) : roundLimit = players.length == 1 && !players.first.computer && !tutorial
           ? null
           : roundLimit {
    if (players.isEmpty ||
        players.length > 4 ||
        (this.roundLimit != null && this.roundLimit! < 1)) {
      throw ArgumentError('Choose 1–4 players and a positive round limit');
    }
  }
  final List<EchoPlayer> players;
  final int? roundLimit;
  bool ended = false;
  int turn = 0;
  EchoPlayer get current => players[turn % players.length];
  int get round => turn ~/ players.length + 1;
  bool get finished =>
      ended || (roundLimit != null && turn >= roundLimit! * players.length);
  bool get canEnd => turn > 0 && turn % players.length == 0;
  void end() {
    if (!canEnd) throw StateError("Complete all players’ turns first");
    ended = true;
  }

  void record({required int score, required bool perfect}) {
    if (finished) throw StateError('Match finished');
    current.points += score.clamp(0, 100);
    current.rounds++;
    if (perfect) {
      current.reachedLevel = max(current.reachedLevel, current.level);
      current.level = min(20, current.level + 1);
    }
    turn++;
  }

  List<EchoPlayer> get standings => [...players]
    ..sort((a, b) {
      final level = b.reachedLevel.compareTo(a.reachedLevel);
      return level == 0 ? b.points.compareTo(a.points) : level;
    });
  List<EchoPlayer> get winners {
    final ranked = standings;
    return ranked
        .where(
          (p) =>
              p.reachedLevel == ranked.first.reachedLevel &&
              p.points == ranked.first.points,
        )
        .toList();
  }
}
