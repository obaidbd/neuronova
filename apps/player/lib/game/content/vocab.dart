/// Starter vocabulary. reviewStatus is "draft": every item (especially the
/// Arabic text with diacritics) must be checked by a qualified human before
/// a public release (spec §23).
class VocabItem {
  const VocabItem(
    this.id,
    this.emoji,
    this.en,
    this.bn,
    this.ar,
    this.difficulty,
  );
  final String id, emoji, en, bn, ar;
  final int difficulty; // 1..3
  static const reviewStatus = 'draft';
  static const contentVersion = 1;

  String text(String lang) => switch (lang) {
    'en' => en,
    'bn' => bn,
    'ar' => ar,
    _ => throw ArgumentError('lang $lang'),
  };
}

const vocab = <VocabItem>[
  VocabItem('book', '📖', 'book', 'বই', 'كِتَابٌ', 1),
  VocabItem('sun', '☀️', 'sun', 'সূর্য', 'شَمْسٌ', 1),
  VocabItem('moon', '🌙', 'moon', 'চাঁদ', 'قَمَرٌ', 1),
  VocabItem('water', '💧', 'water', 'পানি', 'مَاءٌ', 1),
  VocabItem('door', '🚪', 'door', 'দরজা', 'بَابٌ', 1),
  VocabItem('house', '🏠', 'house', 'বাড়ি', 'بَيْتٌ', 2),
  VocabItem('tree', '🌳', 'tree', 'গাছ', 'شَجَرَةٌ', 2),
  VocabItem('star', '⭐', 'star', 'তারা', 'نَجْمٌ', 2),
  VocabItem('fish', '🐟', 'fish', 'মাছ', 'سَمَكٌ', 2),
  VocabItem('apple', '🍎', 'apple', 'আপেল', 'تُفَّاحٌ', 3),
  VocabItem('flower', '🌸', 'flower', 'ফুল', 'زَهْرَةٌ', 3),
  VocabItem('mountain', '⛰️', 'mountain', 'পাহাড়', 'جَبَلٌ', 3),
];
