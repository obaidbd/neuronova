import 'package:flutter/material.dart';

enum GameKind {
  echoGrid,
  patternPortal,
  focusDash,
  numberForge,
  wordQuest,
  pathRecall,
  flipMatch,
}

extension GameKindInfo on GameKind {
  String get title => switch (this) {
    GameKind.echoGrid => 'Echo Grid',
    GameKind.patternPortal => 'Pattern Portal',
    GameKind.focusDash => 'Focus Dash',
    GameKind.numberForge => 'Number Forge',
    GameKind.wordQuest => 'Word Quest',
    GameKind.pathRecall => 'Path Recall',
    GameKind.flipMatch => 'Flip Match',
  };
  String get blurb => switch (this) {
    GameKind.echoGrid => 'Visual memory',
    GameKind.patternPortal => 'Logic & patterns',
    GameKind.focusDash => 'Attention',
    GameKind.numberForge => 'Numbers',
    GameKind.wordQuest => 'Words (EN · বাংলা · العربية)',
    GameKind.pathRecall => 'Spatial memory',
    GameKind.flipMatch => 'Pairs & memory',
  };
  String get skillKey => switch (this) {
    GameKind.echoGrid => 'visual_memory',
    GameKind.patternPortal => 'logic',
    GameKind.focusDash => 'attention',
    GameKind.numberForge => 'number_reasoning',
    GameKind.wordQuest => 'vocabulary',
    GameKind.pathRecall => 'spatial_memory',
    GameKind.flipMatch => 'pair_memory',
  };
  IconData get icon => switch (this) {
    GameKind.echoGrid => Icons.grid_view,
    GameKind.patternPortal => Icons.extension,
    GameKind.focusDash => Icons.center_focus_strong,
    GameKind.numberForge => Icons.calculate,
    GameKind.wordQuest => Icons.translate,
    GameKind.pathRecall => Icons.route,
    GameKind.flipMatch => Icons.flip,
  };

  /// Target completion time used by the timed score's speed factor.
  int targetMs(int tier) => switch (this) {
    GameKind.echoGrid => 8000 + tier * 1000,
    GameKind.patternPortal => 8000 + tier * 500,
    GameKind.focusDash => 10000 + tier * 1000,
    GameKind.numberForge => 7000 + tier * 800,
    GameKind.wordQuest => 5000 + tier * 300,
    GameKind.pathRecall => 8000 + tier * 1200,
    GameKind.flipMatch => 15000 + tier * 3000,
  };
}
