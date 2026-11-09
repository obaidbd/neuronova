import 'dart:math';

import '../content/vocab.dart';

class WordPuzzle {
  WordPuzzle(this.item, this.lang, this.options, this.tier, this.seed);
  final VocabItem item;
  final String lang;
  final List<VocabItem> options;
  final int tier, seed;

  String get prompt => item.text(lang);
  bool get rtl => lang == 'ar';

  bool isCorrect(int i) {
    if (i < 0 || i >= options.length) throw ArgumentError('Illegal option');
    return options[i].id == item.id;
  }

  static List<String> languagesForTier(int t) =>
      t <= 3 ? ['en'] : (t <= 6 ? ['en', 'bn'] : ['en', 'bn', 'ar']);

  static WordPuzzle generate({required int tier, required int seed}) {
    final t = tier.clamp(1, 10);
    final rng = Random(seed);
    final maxDiff = t <= 3 ? 1 : (t <= 6 ? 2 : 3);
    final pool = vocab.where((v) => v.difficulty <= maxDiff).toList();
    final langs = languagesForTier(t);
    final item = pool[rng.nextInt(pool.length)];
    final lang = langs[rng.nextInt(langs.length)];
    final others = pool.where((v) => v.id != item.id).toList()..shuffle(rng);
    final options = [item, ...others.take(3)]..shuffle(rng);
    return WordPuzzle(item, lang, options, t, seed);
  }
}
