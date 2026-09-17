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

  /// High-level logical category for this difficulty tier.
  String get logicalTier {
    switch (this) {
      case Difficulty.easy:
        return 'Singles Logic';
      case Difficulty.medium:
        return 'Subsets & Intersections';
      case Difficulty.hard:
        return 'Single-Digit Patterns';
      case Difficulty.expert:
        return 'Chains & Wings';
    }
  }

  /// Primary deductive techniques required to solve this tier.
  String get techniquesSummary {
    switch (this) {
      case Difficulty.easy:
        return 'Naked & Hidden Singles';
      case Difficulty.medium:
        return 'Pointing Pairs, Box/Line & Pairs';
      case Difficulty.hard:
        return 'X-Wing, Skyscraper & Kite';
      case Difficulty.expert:
        return 'XY-Wing, Unique Rectangles & AIC';
    }
  }

  /// Human-friendly explanation of the tier's deductive requirements.
  String get description {
    switch (this) {
      case Difficulty.easy:
        return 'Solvable purely through direct singles deduction without complex subsets. Great for warmups.';
      case Difficulty.medium:
        return 'Requires identifying locked candidate intersections and pair eliminations to make progress.';
      case Difficulty.hard:
        return 'Demands multi-row/column geometric patterns (X-Wing, Skyscraper, Kite) and candidate quads.';
      case Difficulty.expert:
        return 'Master-level puzzles requiring bi-value wings, unique rectangles, and alternating inference chains.';
    }
  }

  /// @deprecated Difficulty in this engine is determined by deductive logic techniques, not clue counts.
  @Deprecated('Difficulty is determined by logical techniques, not clue count.')
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
