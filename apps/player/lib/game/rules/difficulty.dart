/// Player progression is independent from these bounded puzzle presets.
String difficultyName(int? tier) => tier == null
    ? 'Auto'
    : tier <= 3
    ? 'Easy'
    : tier <= 6
    ? 'Normal'
    : 'Hard';
int? difficultyPreset(int? tier) => tier == null
    ? null
    : tier <= 3
    ? 2
    : tier <= 6
    ? 5
    : 8;
