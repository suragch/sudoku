import 'dart:math';

import '../models/game_enums.dart';
import '../models/sudoku_board.dart';
import 'deductive_grader.dart';
import 'puzzle_record.dart';
import 'sudoku_solver.dart';

class SymmetricItem {
  final int r1, c1, r2, c2;
  final bool isCenter;
  const SymmetricItem(this.r1, this.c1, this.r2, this.c2, this.isCenter);
}

class SudokuGenerator {
  final Random _random;

  SudokuGenerator([Random? random]) : _random = random ?? Random();

  static final List<SymmetricItem> symmetricItems = () {
    final items = <SymmetricItem>[];
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final r2 = 8 - r;
        final c2 = 8 - c;
        final idx1 = r * 9 + c;
        final idx2 = r2 * 9 + c2;
        if (idx1 < idx2) {
          items.add(SymmetricItem(r, c, r2, c2, false));
        } else if (idx1 == idx2) {
          items.add(SymmetricItem(r, c, r2, c2, true));
        }
      }
    }
    return items;
  }();

  /// Generates a fully solved 9x9 board with standard Sudoku rules.
  List<List<int>> generateSolvedBoard() {
    final board = List.generate(9, (_) => List<int>.filled(9, 0));

    // Fill the 3 independent diagonal 3x3 boxes with random permutations
    for (int box = 0; box < 9; box += 4) {
      final nums = List.generate(9, (i) => i + 1)..shuffle(_random);
      int idx = 0;
      final startR = (box ~/ 3) * 3;
      final startC = (box % 3) * 3;
      for (int r = 0; r < 3; r++) {
        for (int c = 0; c < 3; c++) {
          board[startR + r][startC + c] = nums[idx++];
        }
      }
    }

    // Solve the rest of the board using SudokuSolver
    final solved = SudokuSolver.solve(board);
    if (solved != null) {
      return solved;
    }

    // Fallback if random box placement was dead-end
    return generateSolvedBoard();
  }

  /// Generates a validated [SudokuPuzzleRecord] conforming to difficulty and symmetry invariants.
  SudokuPuzzleRecord? generatePuzzleRecord({
    required Difficulty targetDifficulty,
    String? id,
    int maxAttempts = 100,
  }) {
    final (minClues, maxClues) = switch (targetDifficulty) {
      Difficulty.easy => (32, 38),
      Difficulty.medium => (28, 32),
      Difficulty.hard => (24, 28),
      Difficulty.expert => (22, 26),
    };

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final solvedGrid = generateSolvedBoard();
      final puzzleGrid = List.generate(9, (r) => List<int>.from(solvedGrid[r]));
      final items = List<SymmetricItem>.from(symmetricItems)..shuffle(_random);

      int currentClues = 81;

      for (final item in items) {
        if (currentClues <= minClues) break;

        final val1 = puzzleGrid[item.r1][item.c1];
        final val2 = puzzleGrid[item.r2][item.c2];
        if (val1 == 0) continue;

        puzzleGrid[item.r1][item.c1] = 0;
        puzzleGrid[item.r2][item.c2] = 0;
        final removedCount = item.isCenter ? 1 : 2;

        if (SudokuSolver.countSolutions(puzzleGrid, maxCount: 2) == 1) {
          currentClues -= removedCount;

          // If targeting Easy, guard ceiling early
          if (targetDifficulty == Difficulty.easy && currentClues <= maxClues) {
            final pStr = SudokuSolver.formatGridToString(puzzleGrid);
            final grade = DeductiveGrader.gradePuzzle(pStr, maxAllowedDifficulty: Difficulty.easy);
            if (grade.difficulty != Difficulty.easy) {
              puzzleGrid[item.r1][item.c1] = val1;
              puzzleGrid[item.r2][item.c2] = val2;
              currentClues += removedCount;
            }
          }
        } else {
          puzzleGrid[item.r1][item.c1] = val1;
          puzzleGrid[item.r2][item.c2] = val2;
        }
      }

      if (currentClues >= minClues && currentClues <= maxClues) {
        final pStr = SudokuSolver.formatGridToString(puzzleGrid);
        final grade = DeductiveGrader.gradePuzzle(pStr);
        if (grade.isSolved && grade.difficulty == targetDifficulty) {
          final sStr = SudokuSolver.formatGridToString(solvedGrid);
          return SudokuPuzzleRecord(
            id: id ?? '${targetDifficulty.name}_0001',
            difficulty: targetDifficulty.name,
            clueCount: currentClues,
            puzzle: pStr,
            solution: sStr,
            hardestTechnique: grade.hardestTechnique ?? 'naked_single',
            techniquesUsed: grade.techniquesUsed,
          );
        }
      }
    }
    return null;
  }

  /// Generates a playable [SudokuBoard] for the given [difficulty] with 180° rotational symmetry.
  SudokuBoard generateBoard(Difficulty difficulty) {
    while (true) {
      final rec = generatePuzzleRecord(targetDifficulty: difficulty, maxAttempts: 150);
      if (rec != null) {
        return SudokuBoard.fromRecord(rec);
      }
    }
  }
}
