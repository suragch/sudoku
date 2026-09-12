import 'game_enums.dart';

class DifficultyStats {
  final int gamesStarted;
  final int gamesWon;
  final int? bestTimeSeconds;
  final int totalTimeSeconds;
  final int currentStreak;
  final int bestStreak;

  const DifficultyStats({
    this.gamesStarted = 0,
    this.gamesWon = 0,
    this.bestTimeSeconds,
    this.totalTimeSeconds = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
  });

  int get averageTimeSeconds =>
      gamesWon > 0 ? (totalTimeSeconds / gamesWon).round() : 0;

  double get winRate =>
      gamesStarted > 0 ? (gamesWon / gamesStarted) * 100 : 0.0;

  DifficultyStats copyWith({
    int? gamesStarted,
    int? gamesWon,
    int? bestTimeSeconds,
    int? totalTimeSeconds,
    int? currentStreak,
    int? bestStreak,
  }) {
    return DifficultyStats(
      gamesStarted: gamesStarted ?? this.gamesStarted,
      gamesWon: gamesWon ?? this.gamesWon,
      bestTimeSeconds: bestTimeSeconds ?? this.bestTimeSeconds,
      totalTimeSeconds: totalTimeSeconds ?? this.totalTimeSeconds,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
    );
  }

  Map<String, dynamic> toJson() => {
        'gamesStarted': gamesStarted,
        'gamesWon': gamesWon,
        'bestTimeSeconds': bestTimeSeconds,
        'totalTimeSeconds': totalTimeSeconds,
        'currentStreak': currentStreak,
        'bestStreak': bestStreak,
      };

  factory DifficultyStats.fromJson(Map<String, dynamic> json) =>
      DifficultyStats(
        gamesStarted: json['gamesStarted'] as int? ?? 0,
        gamesWon: json['gamesWon'] as int? ?? 0,
        bestTimeSeconds: json['bestTimeSeconds'] as int?,
        totalTimeSeconds: json['totalTimeSeconds'] as int? ?? 0,
        currentStreak: json['currentStreak'] as int? ?? 0,
        bestStreak: json['bestStreak'] as int? ?? 0,
      );
}

class GameStats {
  final Map<Difficulty, DifficultyStats> byDifficulty;

  GameStats({Map<Difficulty, DifficultyStats>? byDifficulty})
      : byDifficulty = byDifficulty ??
            {
              for (final d in Difficulty.values) d: const DifficultyStats(),
            };

  DifficultyStats forDifficulty(Difficulty difficulty) =>
      byDifficulty[difficulty] ?? const DifficultyStats();

  GameStats recordGameStarted(Difficulty difficulty) {
    final current = forDifficulty(difficulty);
    final updated = current.copyWith(gamesStarted: current.gamesStarted + 1);
    final map = Map<Difficulty, DifficultyStats>.from(byDifficulty);
    map[difficulty] = updated;
    return GameStats(byDifficulty: map);
  }

  GameStats recordWin(Difficulty difficulty, int elapsedSeconds) {
    final current = forDifficulty(difficulty);
    final newBest = current.bestTimeSeconds == null
        ? elapsedSeconds
        : (elapsedSeconds < current.bestTimeSeconds!
            ? elapsedSeconds
            : current.bestTimeSeconds);
    final newStreak = current.currentStreak + 1;
    final updated = current.copyWith(
      gamesWon: current.gamesWon + 1,
      bestTimeSeconds: newBest,
      totalTimeSeconds: current.totalTimeSeconds + elapsedSeconds,
      currentStreak: newStreak,
      bestStreak: newStreak > current.bestStreak ? newStreak : current.bestStreak,
    );
    final map = Map<Difficulty, DifficultyStats>.from(byDifficulty);
    map[difficulty] = updated;
    return GameStats(byDifficulty: map);
  }

  Map<String, dynamic> toJson() {
    return {
      for (final entry in byDifficulty.entries)
        entry.key.name: entry.value.toJson(),
    };
  }

  factory GameStats.fromJson(Map<String, dynamic> json) {
    final map = <Difficulty, DifficultyStats>{};
    for (final d in Difficulty.values) {
      if (json.containsKey(d.name)) {
        map[d] = DifficultyStats.fromJson(json[d.name] as Map<String, dynamic>);
      } else {
        map[d] = const DifficultyStats();
      }
    }
    return GameStats(byDifficulty: map);
  }
}
