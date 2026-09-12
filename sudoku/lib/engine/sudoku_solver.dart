class SudokuSolver {
  static const int allMask = 0x1FF; // 9 bits: 0 to 8

  static int _boxIndex(int r, int c) => (r ~/ 3) * 3 + (c ~/ 3);

  /// Solves the given 9x9 [grid] (0 for empty cells).
  /// Returns a solved 9x9 grid or null if no solution exists.
  static List<List<int>>? solve(List<List<int>> grid) {
    final board = List.generate(9, (r) => List<int>.from(grid[r]));
    final rowMask = List<int>.filled(9, 0);
    final colMask = List<int>.filled(9, 0);
    final boxMask = List<int>.filled(9, 0);

    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final val = board[r][c];
        if (val > 0) {
          final bit = 1 << (val - 1);
          final b = _boxIndex(r, c);
          if ((rowMask[r] & bit) != 0 || (colMask[c] & bit) != 0 || (boxMask[b] & bit) != 0) {
            return null; // Invalid initial grid
          }
          rowMask[r] |= bit;
          colMask[c] |= bit;
          boxMask[b] |= bit;
        }
      }
    }

    if (_solveBacktrack(board, rowMask, colMask, boxMask)) {
      return board;
    }
    return null;
  }

  static bool _solveBacktrack(
    List<List<int>> board,
    List<int> rowMask,
    List<int> colMask,
    List<int> boxMask,
  ) {
    int bestR = -1;
    int bestC = -1;
    int minCandidates = 10;
    int bestCandidatesMask = 0;

    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (board[r][c] == 0) {
          final b = _boxIndex(r, c);
          final used = rowMask[r] | colMask[c] | boxMask[b];
          final candidates = (~used) & allMask;
          final count = _popCount(candidates);

          if (count == 0) {
            return false; // Dead end
          }
          if (count < minCandidates) {
            minCandidates = count;
            bestR = r;
            bestC = c;
            bestCandidatesMask = candidates;
            if (count == 1) break;
          }
        }
      }
      if (minCandidates == 1) break;
    }

    if (bestR == -1) {
      return true; // All cells filled!
    }

    final b = _boxIndex(bestR, bestC);
    int cand = bestCandidatesMask;
    while (cand > 0) {
      final bit = cand & -cand; // extract lowest set bit
      final digit = _bitToDigit(bit);
      board[bestR][bestC] = digit;
      rowMask[bestR] |= bit;
      colMask[bestC] |= bit;
      boxMask[b] |= bit;

      if (_solveBacktrack(board, rowMask, colMask, boxMask)) {
        return true;
      }

      // Backtrack
      board[bestR][bestC] = 0;
      rowMask[bestR] &= ~bit;
      colMask[bestC] &= ~bit;
      boxMask[b] &= ~bit;

      cand &= ~bit;
    }

    return false;
  }

  /// Counts the number of solutions for [grid], up to [maxCount].
  /// Useful to verify uniqueness without exploring entire search trees.
  static int countSolutions(List<List<int>> grid, {int maxCount = 2}) {
    final board = List.generate(9, (r) => List<int>.from(grid[r]));
    final rowMask = List<int>.filled(9, 0);
    final colMask = List<int>.filled(9, 0);
    final boxMask = List<int>.filled(9, 0);

    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final val = board[r][c];
        if (val > 0) {
          final bit = 1 << (val - 1);
          final b = _boxIndex(r, c);
          if ((rowMask[r] & bit) != 0 || (colMask[c] & bit) != 0 || (boxMask[b] & bit) != 0) {
            return 0; // Conflict
          }
          rowMask[r] |= bit;
          colMask[c] |= bit;
          boxMask[b] |= bit;
        }
      }
    }

    int solutions = 0;
    void backtrack() {
      if (solutions >= maxCount) return;

      int bestR = -1;
      int bestC = -1;
      int minCandidates = 10;
      int bestCandidatesMask = 0;

      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          if (board[r][c] == 0) {
            final b = _boxIndex(r, c);
            final used = rowMask[r] | colMask[c] | boxMask[b];
            final candidates = (~used) & allMask;
            final count = _popCount(candidates);

            if (count == 0) return;
            if (count < minCandidates) {
              minCandidates = count;
              bestR = r;
              bestC = c;
              bestCandidatesMask = candidates;
              if (count == 1) break;
            }
          }
        }
        if (minCandidates == 1) break;
      }

      if (bestR == -1) {
        solutions++;
        return;
      }

      final b = _boxIndex(bestR, bestC);
      int cand = bestCandidatesMask;
      while (cand > 0 && solutions < maxCount) {
        final bit = cand & -cand;
        final digit = _bitToDigit(bit);
        board[bestR][bestC] = digit;
        rowMask[bestR] |= bit;
        colMask[bestC] |= bit;
        boxMask[b] |= bit;

        backtrack();

        board[bestR][bestC] = 0;
        rowMask[bestR] &= ~bit;
        colMask[bestC] &= ~bit;
        boxMask[b] &= ~bit;

        cand &= ~bit;
      }
    }

    backtrack();
    return solutions;
  }

  static bool hasUniqueSolution(List<List<int>> grid) {
    return countSolutions(grid, maxCount: 2) == 1;
  }

  static int _popCount(int mask) {
    int count = 0;
    while (mask > 0) {
      count += mask & 1;
      mask >>= 1;
    }
    return count;
  }

  static int _bitToDigit(int bit) {
    int digit = 1;
    while (bit > 1) {
      bit >>= 1;
      digit++;
    }
    return digit;
  }
}
