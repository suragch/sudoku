enum Difficulty {
  easy,
  medium,
  hard,
  expert;

  String get displayName {
    switch (this) {
      case Difficulty.easy:
        return 'Easy';
      case Difficulty.medium:
        return 'Medium';
      case Difficulty.hard:
        return 'Hard';
      case Difficulty.expert:
        return 'Expert';
    }
  }

  int get clueTarget {
    switch (this) {
      case Difficulty.easy:
        return 38;
      case Difficulty.medium:
        return 32;
      case Difficulty.hard:
        return 27;
      case Difficulty.expert:
        return 24;
    }
  }
}

enum InputMode {
  cellFirst,
  digitFirst,
}

enum GameStatus {
  playing,
  paused,
  completed,
}
