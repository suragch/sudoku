import 'dart:convert';

/// Represents a validated Sudoku puzzle record conforming to the engineering specification.
class SudokuPuzzleRecord {
  final String id;
  final String difficulty;
  final int clueCount;
  final String puzzle;
  final String solution;
  final String hardestTechnique;
  final Map<String, int> techniquesUsed;

  const SudokuPuzzleRecord({
    required this.id,
    required this.difficulty,
    required this.clueCount,
    required this.puzzle,
    required this.solution,
    required this.hardestTechnique,
    required this.techniquesUsed,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'difficulty': difficulty,
      'clue_count': clueCount,
      'puzzle': puzzle,
      'solution': solution,
      'hardest_technique': hardestTechnique,
      'techniques_used': techniquesUsed,
    };
  }

  factory SudokuPuzzleRecord.fromJson(Map<String, dynamic> json) {
    return SudokuPuzzleRecord(
      id: json['id'] as String,
      difficulty: json['difficulty'] as String,
      clueCount: json['clue_count'] as int,
      puzzle: json['puzzle'] as String,
      solution: json['solution'] as String,
      hardestTechnique: json['hardest_technique'] as String,
      techniquesUsed: Map<String, int>.from(json['techniques_used'] as Map),
    );
  }

  /// Generates a SQL insert statement for SQLite database.
  String toSqlInsert() {
    final escapedId = id.replaceAll("'", "''");
    final escapedDiff = difficulty.replaceAll("'", "''");
    final escapedPuzzle = puzzle.replaceAll("'", "''");
    final escapedSolution = solution.replaceAll("'", "''");
    final escapedHardest = hardestTechnique.replaceAll("'", "''");
    final escapedTechniques = jsonEncode(techniquesUsed).replaceAll("'", "''");

    return "INSERT INTO puzzles (id, difficulty, clue_count, puzzle, solution, hardest_technique, techniques_used) "
        "VALUES ('$escapedId', '$escapedDiff', $clueCount, '$escapedPuzzle', '$escapedSolution', '$escapedHardest', '$escapedTechniques');";
  }
}
