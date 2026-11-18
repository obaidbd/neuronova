import 'package:flutter/material.dart';

import '../../core/game_kind.dart';

extension GamePresentation on GameKind {
  Color get accent => switch (this) {
    GameKind.echoGrid => const Color(0xFF54DBC0),
    GameKind.patternPortal => const Color(0xFFB8A0FF),
    GameKind.focusDash => const Color(0xFFFFA88B),
    GameKind.numberForge => const Color(0xFFF2CE7B),
    GameKind.wordQuest => const Color(0xFF8DC8FF),
    GameKind.pathRecall => const Color(0xFFEDA4D4),
    GameKind.flipMatch => const Color(0xFF9BE37A),
    GameKind.flipDuel => const Color(0xFFFFA05C),
    GameKind.mapPuzzle => const Color(0xFF4FD6E8),
  };
  String get category => switch (this) {
    GameKind.echoGrid => 'MEMORY',
    GameKind.patternPortal => 'LOGIC',
    GameKind.focusDash => 'FOCUS',
    GameKind.numberForge => 'NUMBERS',
    GameKind.wordQuest => 'WORDS',
    GameKind.pathRecall => 'SPATIAL',
    GameKind.flipMatch => 'PAIRS',
    GameKind.flipDuel => 'DUEL',
    GameKind.mapPuzzle => 'MAP',
  };
  String get description => switch (this) {
    GameKind.echoGrid => 'A little glow. A sharper memory. Remember the tiles and bring the pattern back to life.',
    GameKind.patternPortal => 'Spot the hidden rule in a sequence of shapes and unlock the next piece of the puzzle.',
    GameKind.focusDash => 'Find the right shapes in a sea of distractions. Give your attention a playful workout.',
    GameKind.numberForge => 'Turn quick thinking into number magic. Find the missing answer and make every equation click.',
    GameKind.wordQuest => 'Connect words with pictures and discover familiar things in English, বাংলা and العربية.',
    GameKind.pathRecall => 'Follow a trail with your eyes, then retrace it from memory. Every step is a new challenge.',
    GameKind.flipMatch => 'Flip the cards, remember where each fruit and animal hides, and match every pair.',
    GameKind.flipDuel => 'A memory duel on one shared board. Take turns flipping tiles, match pairs and out-remember a friend or the AI.',
    GameKind.mapPuzzle => 'Build the map of Bangladesh piece by piece: divisions, districts or upazilas, the whole country or just one area.',
  };
  List<String> get instructions => switch (this) {
    GameKind.echoGrid => [
      'Watch the glowing tiles for your chosen preview time.',
      'When they disappear, tap the same tiles and submit.',
      'Perfect rounds raise your level. Play solo, with friends, or against the computer.',
    ],
    GameKind.patternPortal => [
      'Look closely at the sequence of shapes.',
      'Work out which rule connects them.',
      'Choose the one option that correctly continues the pattern.',
    ],
    GameKind.focusDash => [
      'Read the target shape and colour above the board.',
      'Select every matching item, leaving distractions untouched.',
      'Submit your selection. Wrong taps reduce accuracy.',
    ],
    GameKind.numberForge => [
      'Read the equation and find the missing value.',
      'Calculate your answer and compare the options.',
      'Tap the correct option to complete the round.',
    ],
    GameKind.wordQuest => [
      'Read the word above the pictures.',
      'Choose the picture that matches its meaning.',
      'Higher difficulty introduces Bengali and Arabic words.',
    ],
    GameKind.pathRecall => [
      'Memorise the numbered route while it is visible.',
      'Start at S and tap neighbouring tiles to retrace it.',
      'Follow the direction shown; some levels ask you to walk backwards.',
    ],
    GameKind.flipMatch => [
      'Tap a card to flip it, then tap a second card.',
      'Matching pictures stay open; different ones flip back, so remember where they are.',
      'Find every pair. Fewer missed tries means a higher score.',
    ],
    GameKind.flipDuel => [
      'Flip two tiles each turn. A match scores a point and you go again.',
      'A miss shows both tiles for a second, then the turn passes.',
      'Most pairs wins. Play a friend on one device or the AI (Easy, Medium, Hard).',
    ],
    GameKind.mapPuzzle => [
      'Choose the whole country or one area, and divisions, districts or upazilas as pieces.',
      'Drag a piece from the tray onto the map, or tap a piece and then tap its place. Pinch or use + and − to zoom.',
      'Every piece placed is a new region learned. Fewer wrong tries and hints mean more points.',
    ],
  };
}
