import '../models/deductive_hint.dart';
import '../models/game_enums.dart';
import '../models/sudoku_board.dart';

/// Result returned by [DeductiveGrader.gradePuzzle].
class GradeResult {
  final bool isSolved;
  final bool isStalled;
  final Difficulty? difficulty;
  final String? hardestTechnique;
  final Map<String, int> techniquesUsed;
  final int clueCount;
  final String puzzle;
  final String solution;
  final Map<int, List<int>> remainingCandidates;

  const GradeResult({
    required this.isSolved,
    required this.isStalled,
    required this.difficulty,
    required this.hardestTechnique,
    required this.techniquesUsed,
    required this.clueCount,
    required this.puzzle,
    required this.solution,
    this.remainingCandidates = const {},
  });

  @override
  String toString() {
    return 'GradeResult(solved: $isSolved, stalled: $isStalled, diff: ${difficulty?.name}, hardest: $hardestTechnique, clues: $clueCount, techniques: $techniquesUsed)';
  }
}

/// Deterministic, rule-based logical grading engine for 9x9 Sudoku puzzles.
/// Attempts to solve the board step-by-step using human deductive techniques
/// in strict ascending order of cognitive difficulty.
class DeductiveGrader {
  // Precomputed geometry tables
  static final List<int> _rowOf = List.generate(81, (i) => i ~/ 9);
  static final List<int> _colOf = List.generate(81, (i) => i % 9);
  static final List<int> _boxOf = List.generate(81, (i) => (i ~/ 27) * 3 + ((i % 9) ~/ 3));

  // 27 units: 0..8 rows, 9..17 cols, 18..26 boxes
  static final List<List<int>> _units = [
    // 9 rows
    for (int r = 0; r < 9; r++) List.generate(9, (c) => r * 9 + c),
    // 9 cols
    for (int c = 0; c < 9; c++) List.generate(9, (r) => r * 9 + c),
    // 9 boxes
    for (int b = 0; b < 9; b++) [
      for (int r = (b ~/ 3) * 3; r < (b ~/ 3) * 3 + 3; r++)
        for (int c = (b % 3) * 3; c < (b % 3) * 3 + 3; c++)
          r * 9 + c,
    ],
  ];

  // For each cell, indices of its 3 units
  static final List<List<int>> _unitsOf = List.generate(81, (i) {
    final r = _rowOf[i];
    final c = _colOf[i];
    final b = _boxOf[i];
    return [r, 9 + c, 18 + b];
  });

  // For each cell, list of 20 peers
  static final List<List<int>> _peersOf = List.generate(81, (i) {
    final peerSet = <int>{};
    for (final u in _unitsOf[i]) {
      for (final cell in _units[u]) {
        if (cell != i) peerSet.add(cell);
      }
    }
    return peerSet.toList();
  });

  // Fast O(1) peer lookup
  static final List<List<bool>> _sees = List.generate(81, (i) {
    final list = List<bool>.filled(81, false);
    for (final p in _peersOf[i]) {
      list[p] = true;
    }
    return list;
  });

  static const Map<String, int> _techniqueRank = {
    'naked_single': 1,
    'hidden_single': 2,
    'pointing_pair': 10,
    'box_line_reduction': 11,
    'naked_pair': 12,
    'hidden_pair': 13,
    'naked_triple': 14,
    'hidden_triple': 15,
    'naked_quad': 20,
    'hidden_quad': 21,
    'x_wing': 22,
    'swordfish': 23,
    'skyscraper': 24,
    'two_string_kite': 25,
    'unique_rectangle': 30,
    'xy_wing': 31,
    'xyz_wing': 32,
    'w_wing': 33,
    'simple_aic': 34,
  };

  /// Grades the given 81-character puzzle string (using '.' or '0' for blanks).
  /// If [maxAllowedDifficulty] is set, stops early if puzzle requires a higher tier.
  static GradeResult gradePuzzle(String puzzleStr, {Difficulty? maxAllowedDifficulty}) {
    if (puzzleStr.length != 81) {
      throw ArgumentError('Sudoku puzzle string must be exactly 81 characters.');
    }

    final values = List<int>.filled(81, 0);
    final candidates = List<int>.filled(81, 0x1FF); // 9 bits set
    int emptyCount = 0;
    int clueCount = 0;

    for (int i = 0; i < 81; i++) {
      final code = puzzleStr.codeUnitAt(i);
      if (code >= 49 && code <= 57) {
        final d = code - 48;
        values[i] = d;
        candidates[i] = 1 << (d - 1);
        clueCount++;
      } else {
        values[i] = 0;
        emptyCount++;
      }
    }

    // Constraint propagation on initial clues
    for (int i = 0; i < 81; i++) {
      final d = values[i];
      if (d > 0) {
        final mask = ~(1 << (d - 1));
        for (final p in _peersOf[i]) {
          if (values[p] == d) {
            // Contradiction in initial clues
            return GradeResult(
              isSolved: false,
              isStalled: true,
              difficulty: null,
              hardestTechnique: null,
              techniquesUsed: {},
              clueCount: clueCount,
              puzzle: puzzleStr,
              solution: '',
            );
          }
          candidates[p] &= mask;
        }
      }
    }

    // Verify no empty cell has 0 candidates
    for (int i = 0; i < 81; i++) {
      if (values[i] == 0 && candidates[i] == 0) {
        return GradeResult(
          isSolved: false,
          isStalled: true,
          difficulty: null,
          hardestTechnique: null,
          techniquesUsed: {},
          clueCount: clueCount,
          puzzle: puzzleStr,
          solution: '',
        );
      }
    }

    final techniquesUsed = <String, int>{};

    void recordTechnique(String name) {
      techniquesUsed[name] = (techniquesUsed[name] ?? 0) + 1;
    }

    void setCellValue(int cell, int digit) {
      values[cell] = digit;
      candidates[cell] = 1 << (digit - 1);
      emptyCount--;
      final mask = ~(1 << (digit - 1));
      for (final p in _peersOf[cell]) {
        candidates[p] &= mask;
      }
    }

    // --- Deductive Techniques ---

    // 1. Naked Single
    bool applyNakedSingle() {
      for (int i = 0; i < 81; i++) {
        if (values[i] == 0) {
          final cand = candidates[i];
          if ((cand & (cand - 1)) == 0 && cand > 0) {
            final digit = _bitToDigit(cand);
            setCellValue(i, digit);
            recordTechnique('naked_single');
            return true;
          }
        }
      }
      return false;
    }

    // 2. Hidden Single
    bool applyHiddenSingle() {
      for (int u = 0; u < 27; u++) {
        final unit = _units[u];
        for (int d = 1; d <= 9; d++) {
          final bit = 1 << (d - 1);
          int count = 0;
          int lastCell = -1;
          for (final cell in unit) {
            if (values[cell] == d) {
              count = -1;
              break;
            }
            if (values[cell] == 0 && (candidates[cell] & bit) != 0) {
              count++;
              lastCell = cell;
              if (count > 1) break;
            }
          }
          if (count == 1) {
            setCellValue(lastCell, d);
            recordTechnique('hidden_single');
            return true;
          }
        }
      }
      return false;
    }

    // 3. Pointing Pair / Triple (Box -> Line)
    bool applyPointingTuple() {
      for (int b = 0; b < 9; b++) {
        final boxCells = _units[18 + b];
        for (int d = 1; d <= 9; d++) {
          final bit = 1 << (d - 1);
          int count = 0;
          int sameRow = -1;
          int sameCol = -1;
          bool rowMatch = true;
          bool colMatch = true;
          for (final c in boxCells) {
            if (values[c] == 0 && (candidates[c] & bit) != 0) {
              count++;
              final r = _rowOf[c];
              final col = _colOf[c];
              if (sameRow == -1) {
                sameRow = r;
              } else if (sameRow != r) {
                rowMatch = false;
              }
              if (sameCol == -1) {
                sameCol = col;
              } else if (sameCol != col) {
                colMatch = false;
              }
            }
          }
          if (count >= 2 && count <= 3) {
            if (rowMatch && sameRow != -1) {
              bool changed = false;
              final rowUnit = _units[sameRow];
              for (final c in rowUnit) {
                if (_boxOf[c] != b && values[c] == 0 && (candidates[c] & bit) != 0) {
                  candidates[c] &= ~bit;
                  changed = true;
                }
              }
              if (changed) {
                recordTechnique('pointing_pair');
                return true;
              }
            }
            if (colMatch && sameCol != -1) {
              bool changed = false;
              final colUnit = _units[9 + sameCol];
              for (final c in colUnit) {
                if (_boxOf[c] != b && values[c] == 0 && (candidates[c] & bit) != 0) {
                  candidates[c] &= ~bit;
                  changed = true;
                }
              }
              if (changed) {
                recordTechnique('pointing_pair');
                return true;
              }
            }
          }
        }
      }
      return false;
    }

    // 4. Box-Line Reduction (Claiming: Line -> Box)
    bool applyBoxLineReduction() {
      for (int u = 0; u < 18; u++) {
        final lineCells = _units[u];
        for (int d = 1; d <= 9; d++) {
          final bit = 1 << (d - 1);
          int count = 0;
          int sameBox = -1;
          bool boxMatch = true;
          for (final c in lineCells) {
            if (values[c] == 0 && (candidates[c] & bit) != 0) {
              count++;
              final b = _boxOf[c];
              if (sameBox == -1) {
                sameBox = b;
              } else if (sameBox != b) {
                boxMatch = false;
              }
            }
          }
          if (count >= 2 && count <= 3 && boxMatch && sameBox != -1) {
            bool changed = false;
            final boxCells = _units[18 + sameBox];
            for (final c in boxCells) {
              final inLine = (u < 9) ? (_rowOf[c] == u) : (_colOf[c] == (u - 9));
              if (!inLine && values[c] == 0 && (candidates[c] & bit) != 0) {
                candidates[c] &= ~bit;
                changed = true;
              }
            }
            if (changed) {
              recordTechnique('box_line_reduction');
              return true;
            }
          }
        }
      }
      return false;
    }

    // 5. Naked Pair
    bool applyNakedPair() {
      for (int u = 0; u < 27; u++) {
        final unit = _units[u];
        final bivalueCells = <int>[];
        for (final c in unit) {
          if (values[c] == 0 && _popCount(candidates[c]) == 2) {
            bivalueCells.add(c);
          }
        }
        if (bivalueCells.length >= 2) {
          for (int i = 0; i < bivalueCells.length; i++) {
            for (int j = i + 1; j < bivalueCells.length; j++) {
              final c1 = bivalueCells[i];
              final c2 = bivalueCells[j];
              if (candidates[c1] == candidates[c2]) {
                final mask = candidates[c1];
                bool changed = false;
                for (final other in unit) {
                  if (other != c1 && other != c2 && values[other] == 0 && (candidates[other] & mask) != 0) {
                    candidates[other] &= ~mask;
                    changed = true;
                  }
                }
                if (changed) {
                  recordTechnique('naked_pair');
                  return true;
                }
              }
            }
          }
        }
      }
      return false;
    }

    // 6. Naked Triple
    bool applyNakedTriple() {
      for (int u = 0; u < 27; u++) {
        final unit = _units[u];
        final smallCells = <int>[];
        for (final c in unit) {
          if (values[c] == 0) {
            final pc = _popCount(candidates[c]);
            if (pc >= 2 && pc <= 3) smallCells.add(c);
          }
        }
        if (smallCells.length >= 3) {
          for (int i = 0; i < smallCells.length; i++) {
            for (int j = i + 1; j < smallCells.length; j++) {
              for (int k = j + 1; k < smallCells.length; k++) {
                final c1 = smallCells[i];
                final c2 = smallCells[j];
                final c3 = smallCells[k];
                final unionMask = candidates[c1] | candidates[c2] | candidates[c3];
                if (_popCount(unionMask) == 3) {
                  bool changed = false;
                  for (final other in unit) {
                    if (other != c1 && other != c2 && other != c3 &&
                        values[other] == 0 && (candidates[other] & unionMask) != 0) {
                      candidates[other] &= ~unionMask;
                      changed = true;
                    }
                  }
                  if (changed) {
                    recordTechnique('naked_triple');
                    return true;
                  }
                }
              }
            }
          }
        }
      }
      return false;
    }

    // 7. Hidden Pair
    bool applyHiddenPair() {
      for (int u = 0; u < 27; u++) {
        final unit = _units[u];
        for (int d1 = 1; d1 <= 8; d1++) {
          final b1 = 1 << (d1 - 1);
          final cells1 = <int>[];
          for (final c in unit) {
            if (values[c] == 0 && (candidates[c] & b1) != 0) cells1.add(c);
          }
          if (cells1.length != 2) continue;

          for (int d2 = d1 + 1; d2 <= 9; d2++) {
            final b2 = 1 << (d2 - 1);
            final cells2 = <int>[];
            for (final c in unit) {
              if (values[c] == 0 && (candidates[c] & b2) != 0) cells2.add(c);
            }
            if (cells2.length == 2 && cells1[0] == cells2[0] && cells1[1] == cells2[1]) {
              final pairMask = b1 | b2;
              final c1 = cells1[0];
              final c2 = cells1[1];
              if ((candidates[c1] & ~pairMask) != 0 || (candidates[c2] & ~pairMask) != 0) {
                candidates[c1] &= pairMask;
                candidates[c2] &= pairMask;
                recordTechnique('hidden_pair');
                return true;
              }
            }
          }
        }
      }
      return false;
    }

    // 8. Hidden Triple
    bool applyHiddenTriple() {
      for (int u = 0; u < 27; u++) {
        final unit = _units[u];
        for (int d1 = 1; d1 <= 7; d1++) {
          final b1 = 1 << (d1 - 1);
          final s1 = [for (final c in unit) if (values[c] == 0 && (candidates[c] & b1) != 0) c];
          if (s1.isEmpty || s1.length > 3) continue;

          for (int d2 = d1 + 1; d2 <= 8; d2++) {
            final b2 = 1 << (d2 - 1);
            final s2 = [for (final c in unit) if (values[c] == 0 && (candidates[c] & b2) != 0) c];
            if (s2.isEmpty || s2.length > 3) continue;

            for (int d3 = d2 + 1; d3 <= 9; d3++) {
              final b3 = 1 << (d3 - 1);
              final s3 = [for (final c in unit) if (values[c] == 0 && (candidates[c] & b3) != 0) c];
              if (s3.isEmpty || s3.length > 3) continue;

              final unionCells = <int>{...s1, ...s2, ...s3};
              if (unionCells.length == 3) {
                final mask = b1 | b2 | b3;
                bool changed = false;
                for (final c in unionCells) {
                  if ((candidates[c] & ~mask) != 0) {
                    candidates[c] &= mask;
                    changed = true;
                  }
                }
                if (changed) {
                  recordTechnique('hidden_triple');
                  return true;
                }
              }
            }
          }
        }
      }
      return false;
    }

    // 9. Naked Quad
    bool applyNakedQuad() {
      for (int u = 0; u < 27; u++) {
        final unit = _units[u];
        final smallCells = <int>[];
        for (final c in unit) {
          if (values[c] == 0) {
            final pc = _popCount(candidates[c]);
            if (pc >= 2 && pc <= 4) smallCells.add(c);
          }
        }
        if (smallCells.length >= 4) {
          for (int i = 0; i < smallCells.length; i++) {
            for (int j = i + 1; j < smallCells.length; j++) {
              for (int k = j + 1; k < smallCells.length; k++) {
                for (int l = k + 1; l < smallCells.length; l++) {
                  final c1 = smallCells[i];
                  final c2 = smallCells[j];
                  final c3 = smallCells[k];
                  final c4 = smallCells[l];
                  final unionMask = candidates[c1] | candidates[c2] | candidates[c3] | candidates[c4];
                  if (_popCount(unionMask) == 4) {
                    bool changed = false;
                    for (final other in unit) {
                      if (other != c1 && other != c2 && other != c3 && other != c4 &&
                          values[other] == 0 && (candidates[other] & unionMask) != 0) {
                        candidates[other] &= ~unionMask;
                        changed = true;
                      }
                    }
                    if (changed) {
                      recordTechnique('naked_quad');
                      return true;
                    }
                  }
                }
              }
            }
          }
        }
      }
      return false;
    }

    // 10. Hidden Quad
    bool applyHiddenQuad() {
      for (int u = 0; u < 27; u++) {
        final unit = _units[u];
        for (int d1 = 1; d1 <= 6; d1++) {
          final b1 = 1 << (d1 - 1);
          final s1 = [for (final c in unit) if (values[c] == 0 && (candidates[c] & b1) != 0) c];
          if (s1.isEmpty || s1.length > 4) continue;

          for (int d2 = d1 + 1; d2 <= 7; d2++) {
            final b2 = 1 << (d2 - 1);
            final s2 = [for (final c in unit) if (values[c] == 0 && (candidates[c] & b2) != 0) c];
            if (s2.isEmpty || s2.length > 4) continue;

            for (int d3 = d2 + 1; d3 <= 8; d3++) {
              final b3 = 1 << (d3 - 1);
              final s3 = [for (final c in unit) if (values[c] == 0 && (candidates[c] & b3) != 0) c];
              if (s3.isEmpty || s3.length > 4) continue;

              for (int d4 = d3 + 1; d4 <= 9; d4++) {
                final b4 = 1 << (d4 - 1);
                final s4 = [for (final c in unit) if (values[c] == 0 && (candidates[c] & b4) != 0) c];
                if (s4.isEmpty || s4.length > 4) continue;

                final unionCells = <int>{...s1, ...s2, ...s3, ...s4};
                if (unionCells.length == 4) {
                  final mask = b1 | b2 | b3 | b4;
                  bool changed = false;
                  for (final c in unionCells) {
                    if ((candidates[c] & ~mask) != 0) {
                      candidates[c] &= mask;
                      changed = true;
                    }
                  }
                  if (changed) {
                    recordTechnique('hidden_quad');
                    return true;
                  }
                }
              }
            }
          }
        }
      }
      return false;
    }

    // 11. X-Wing
    bool applyXWing() {
      for (int d = 1; d <= 9; d++) {
        final bit = 1 << (d - 1);
        // Row-based X-Wing
        final rowPairs = <int, List<int>>{};
        for (int r = 0; r < 9; r++) {
          final cols = <int>[];
          for (int c = 0; c < 9; c++) {
            final idx = r * 9 + c;
            if (values[idx] == 0 && (candidates[idx] & bit) != 0) cols.add(c);
          }
          if (cols.length == 2) rowPairs[r] = cols;
        }
        final rList = rowPairs.keys.toList();
        for (int i = 0; i < rList.length; i++) {
          for (int j = i + 1; j < rList.length; j++) {
            final r1 = rList[i];
            final r2 = rList[j];
            final cols1 = rowPairs[r1]!;
            final cols2 = rowPairs[r2]!;
            if (cols1[0] == cols2[0] && cols1[1] == cols2[1]) {
              final c1 = cols1[0];
              final c2 = cols1[1];
              bool changed = false;
              for (int r = 0; r < 9; r++) {
                if (r != r1 && r != r2) {
                  final idx1 = r * 9 + c1;
                  final idx2 = r * 9 + c2;
                  if (values[idx1] == 0 && (candidates[idx1] & bit) != 0) {
                    candidates[idx1] &= ~bit;
                    changed = true;
                  }
                  if (values[idx2] == 0 && (candidates[idx2] & bit) != 0) {
                    candidates[idx2] &= ~bit;
                    changed = true;
                  }
                }
              }
              if (changed) {
                recordTechnique('x_wing');
                return true;
              }
            }
          }
        }

        // Col-based X-Wing
        final colPairs = <int, List<int>>{};
        for (int c = 0; c < 9; c++) {
          final rows = <int>[];
          for (int r = 0; r < 9; r++) {
            final idx = r * 9 + c;
            if (values[idx] == 0 && (candidates[idx] & bit) != 0) rows.add(r);
          }
          if (rows.length == 2) colPairs[c] = rows;
        }
        final cList = colPairs.keys.toList();
        for (int i = 0; i < cList.length; i++) {
          for (int j = i + 1; j < cList.length; j++) {
            final c1 = cList[i];
            final c2 = cList[j];
            final rows1 = colPairs[c1]!;
            final rows2 = colPairs[c2]!;
            if (rows1[0] == rows2[0] && rows1[1] == rows2[1]) {
              final r1 = rows1[0];
              final r2 = rows1[1];
              bool changed = false;
              for (int c = 0; c < 9; c++) {
                if (c != c1 && c != c2) {
                  final idx1 = r1 * 9 + c;
                  final idx2 = r2 * 9 + c;
                  if (values[idx1] == 0 && (candidates[idx1] & bit) != 0) {
                    candidates[idx1] &= ~bit;
                    changed = true;
                  }
                  if (values[idx2] == 0 && (candidates[idx2] & bit) != 0) {
                    candidates[idx2] &= ~bit;
                    changed = true;
                  }
                }
              }
              if (changed) {
                recordTechnique('x_wing');
                return true;
              }
            }
          }
        }
      }
      return false;
    }

    // 12. Swordfish
    bool applySwordfish() {
      for (int d = 1; d <= 9; d++) {
        final bit = 1 << (d - 1);
        // Row-based Swordfish
        final rowMap = <int, List<int>>{};
        for (int r = 0; r < 9; r++) {
          final cols = <int>[];
          for (int c = 0; c < 9; c++) {
            final idx = r * 9 + c;
            if (values[idx] == 0 && (candidates[idx] & bit) != 0) cols.add(c);
          }
          if (cols.length >= 2 && cols.length <= 3) rowMap[r] = cols;
        }
        final rList = rowMap.keys.toList();
        for (int i = 0; i < rList.length; i++) {
          for (int j = i + 1; j < rList.length; j++) {
            for (int k = j + 1; k < rList.length; k++) {
              final r1 = rList[i];
              final r2 = rList[j];
              final r3 = rList[k];
              final colSet = <int>{...rowMap[r1]!, ...rowMap[r2]!, ...rowMap[r3]!};
              if (colSet.length == 3) {
                bool changed = false;
                for (final c in colSet) {
                  for (int r = 0; r < 9; r++) {
                    if (r != r1 && r != r2 && r != r3) {
                      final idx = r * 9 + c;
                      if (values[idx] == 0 && (candidates[idx] & bit) != 0) {
                        candidates[idx] &= ~bit;
                        changed = true;
                      }
                    }
                  }
                }
                if (changed) {
                  recordTechnique('swordfish');
                  return true;
                }
              }
            }
          }
        }

        // Col-based Swordfish
        final colMap = <int, List<int>>{};
        for (int c = 0; c < 9; c++) {
          final rows = <int>[];
          for (int r = 0; r < 9; r++) {
            final idx = r * 9 + c;
            if (values[idx] == 0 && (candidates[idx] & bit) != 0) rows.add(r);
          }
          if (rows.length >= 2 && rows.length <= 3) colMap[c] = rows;
        }
        final cList = colMap.keys.toList();
        for (int i = 0; i < cList.length; i++) {
          for (int j = i + 1; j < cList.length; j++) {
            for (int k = j + 1; k < cList.length; k++) {
              final c1 = cList[i];
              final c2 = cList[j];
              final c3 = cList[k];
              final rowSet = <int>{...colMap[c1]!, ...colMap[c2]!, ...colMap[c3]!};
              if (rowSet.length == 3) {
                bool changed = false;
                for (final r in rowSet) {
                  for (int c = 0; c < 9; c++) {
                    if (c != c1 && c != c2 && c != c3) {
                      final idx = r * 9 + c;
                      if (values[idx] == 0 && (candidates[idx] & bit) != 0) {
                        candidates[idx] &= ~bit;
                        changed = true;
                      }
                    }
                  }
                }
                if (changed) {
                  recordTechnique('swordfish');
                  return true;
                }
              }
            }
          }
        }
      }
      return false;
    }

    // 13. Skyscraper
    bool applySkyscraper() {
      for (int d = 1; d <= 9; d++) {
        final bit = 1 << (d - 1);
        // Row-based Skyscraper
        final rowPairs = <int, List<int>>{};
        for (int r = 0; r < 9; r++) {
          final cols = <int>[];
          for (int c = 0; c < 9; c++) {
            final idx = r * 9 + c;
            if (values[idx] == 0 && (candidates[idx] & bit) != 0) cols.add(c);
          }
          if (cols.length == 2) rowPairs[r] = cols;
        }
        final rList = rowPairs.keys.toList();
        for (int i = 0; i < rList.length; i++) {
          for (int j = i + 1; j < rList.length; j++) {
            final r1 = rList[i];
            final r2 = rList[j];
            final c1 = rowPairs[r1]!;
            final c2 = rowPairs[r2]!;
            int sharedCol = -1;
            int roofCol1 = -1;
            int roofCol2 = -1;
            if (c1[0] == c2[0] && c1[1] != c2[1]) {
              sharedCol = c1[0]; roofCol1 = c1[1]; roofCol2 = c2[1];
            } else if (c1[1] == c2[1] && c1[0] != c2[0]) {
              sharedCol = c1[1]; roofCol1 = c1[0]; roofCol2 = c2[0];
            } else if (c1[0] == c2[1] && c1[1] != c2[0]) {
              sharedCol = c1[0]; roofCol1 = c1[1]; roofCol2 = c2[0];
            } else if (c1[1] == c2[0] && c1[0] != c2[1]) {
              sharedCol = c1[1]; roofCol1 = c1[0]; roofCol2 = c2[1];
            }
            if (sharedCol != -1) {
              final tower1 = r1 * 9 + roofCol1;
              final tower2 = r2 * 9 + roofCol2;
              if (!_sees[tower1][tower2]) {
                bool changed = false;
                for (int k = 0; k < 81; k++) {
                  if (k != tower1 && k != tower2 && _sees[tower1][k] && _sees[tower2][k]) {
                    if (values[k] == 0 && (candidates[k] & bit) != 0) {
                      candidates[k] &= ~bit;
                      changed = true;
                    }
                  }
                }
                if (changed) {
                  recordTechnique('skyscraper');
                  return true;
                }
              }
            }
          }
        }

        // Col-based Skyscraper
        final colPairs = <int, List<int>>{};
        for (int c = 0; c < 9; c++) {
          final rows = <int>[];
          for (int r = 0; r < 9; r++) {
            final idx = r * 9 + c;
            if (values[idx] == 0 && (candidates[idx] & bit) != 0) rows.add(r);
          }
          if (rows.length == 2) colPairs[c] = rows;
        }
        final cList = colPairs.keys.toList();
        for (int i = 0; i < cList.length; i++) {
          for (int j = i + 1; j < cList.length; j++) {
            final c1 = cList[i];
            final c2 = cList[j];
            final r1 = colPairs[c1]!;
            final r2 = colPairs[c2]!;
            int sharedRow = -1;
            int roofRow1 = -1;
            int roofRow2 = -1;
            if (r1[0] == r2[0] && r1[1] != r2[1]) {
              sharedRow = r1[0]; roofRow1 = r1[1]; roofRow2 = r2[1];
            } else if (r1[1] == r2[1] && r1[0] != r2[0]) {
              sharedRow = r1[1]; roofRow1 = r1[0]; roofRow2 = r2[0];
            } else if (r1[0] == r2[1] && r1[1] != r2[0]) {
              sharedRow = r1[0]; roofRow1 = r1[1]; roofRow2 = r2[0];
            } else if (r1[1] == r2[0] && r1[0] != r2[1]) {
              sharedRow = r1[1]; roofRow1 = r1[0]; roofRow2 = r2[1];
            }
            if (sharedRow != -1) {
              final tower1 = roofRow1 * 9 + c1;
              final tower2 = roofRow2 * 9 + c2;
              if (!_sees[tower1][tower2]) {
                bool changed = false;
                for (int k = 0; k < 81; k++) {
                  if (k != tower1 && k != tower2 && _sees[tower1][k] && _sees[tower2][k]) {
                    if (values[k] == 0 && (candidates[k] & bit) != 0) {
                      candidates[k] &= ~bit;
                      changed = true;
                    }
                  }
                }
                if (changed) {
                  recordTechnique('skyscraper');
                  return true;
                }
              }
            }
          }
        }
      }
      return false;
    }

    // 14. 2-String Kite
    bool applyTwoStringKite() {
      for (int d = 1; d <= 9; d++) {
        final bit = 1 << (d - 1);
        final rowPairs = <int, List<int>>{};
        for (int r = 0; r < 9; r++) {
          final cols = <int>[];
          for (int c = 0; c < 9; c++) {
            final idx = r * 9 + c;
            if (values[idx] == 0 && (candidates[idx] & bit) != 0) cols.add(c);
          }
          if (cols.length == 2) rowPairs[r] = cols;
        }

        final colPairs = <int, List<int>>{};
        for (int c = 0; c < 9; c++) {
          final rows = <int>[];
          for (int r = 0; r < 9; r++) {
            final idx = r * 9 + c;
            if (values[idx] == 0 && (candidates[idx] & bit) != 0) rows.add(r);
          }
          if (rows.length == 2) colPairs[c] = rows;
        }

        for (final rEntry in rowPairs.entries) {
          final r = rEntry.key;
          final rCols = rEntry.value;
          for (final cEntry in colPairs.entries) {
            final c = cEntry.key;
            final cRows = cEntry.value;

            // Row and Col must not share a candidate cell
            if (rCols.contains(c) || cRows.contains(r)) continue;

            for (int rIdx = 0; rIdx < 2; rIdx++) {
              final cBox = rCols[rIdx];
              final cOuter = rCols[1 - rIdx];
              final cellInRow = r * 9 + cBox;
              final boxR = _boxOf[cellInRow];

              for (int cIdx = 0; cIdx < 2; cIdx++) {
                final rBox = cRows[cIdx];
                final rOuter = cRows[1 - cIdx];
                final cellInCol = rBox * 9 + c;

                // The two joint cells must be in the same box
                if (_boxOf[cellInCol] == boxR) {
                  // The outer cells must be outside that box
                  final outerRowCell = r * 9 + cOuter;
                  final outerColCell = rOuter * 9 + c;
                  if (_boxOf[outerRowCell] != boxR && _boxOf[outerColCell] != boxR) {
                    final targetCell = rOuter * 9 + cOuter;
                    if (values[targetCell] == 0 && (candidates[targetCell] & bit) != 0) {
                      candidates[targetCell] &= ~bit;
                      recordTechnique('two_string_kite');
                      return true;
                    }
                  }
                }
              }
            }
          }
        }
      }
      return false;
    }

    // 15. XY-Wing (Y-Wing)
    bool applyXYWing() {
      final bivalues = <int>[];
      for (int i = 0; i < 81; i++) {
        if (values[i] == 0 && _popCount(candidates[i]) == 2) {
          bivalues.add(i);
        }
      }

      for (final p in bivalues) {
        final candP = candidates[p];
        final pD1 = _lowestBit(candP);
        final pD2 = candP ^ pD1;

        final pincers = [for (final q in bivalues) if (q != p && _sees[p][q]) q];
        for (int i = 0; i < pincers.length; i++) {
          for (int j = i + 1; j < pincers.length; j++) {
            final q1 = pincers[i];
            final q2 = pincers[j];
            final candQ1 = candidates[q1];
            final candQ2 = candidates[q2];

            int zBit = 0;
            if ((candQ1 & pD1) != 0 && (candQ1 & pD2) == 0 &&
                (candQ2 & pD2) != 0 && (candQ2 & pD1) == 0) {
              final z1 = candQ1 ^ pD1;
              final z2 = candQ2 ^ pD2;
              if (z1 == z2) zBit = z1;
            } else if ((candQ1 & pD2) != 0 && (candQ1 & pD1) == 0 &&
                       (candQ2 & pD1) != 0 && (candQ2 & pD2) == 0) {
              final z1 = candQ1 ^ pD2;
              final z2 = candQ2 ^ pD1;
              if (z1 == z2) zBit = z1;
            }

            if (zBit != 0) {
              bool changed = false;
              for (int x = 0; x < 81; x++) {
                if (x != p && x != q1 && x != q2 && _sees[q1][x] && _sees[q2][x]) {
                  if (values[x] == 0 && (candidates[x] & zBit) != 0) {
                    candidates[x] &= ~zBit;
                    changed = true;
                  }
                }
              }
              if (changed) {
                recordTechnique('xy_wing');
                return true;
              }
            }
          }
        }
      }
      return false;
    }

    // 16. XYZ-Wing
    bool applyXYZWing() {
      final bivalues = <int>[];
      final trivalues = <int>[];
      for (int i = 0; i < 81; i++) {
        if (values[i] == 0) {
          final pc = _popCount(candidates[i]);
          if (pc == 2) {
            bivalues.add(i);
          } else if (pc == 3) {
            trivalues.add(i);
          }
        }
      }

      for (final p in trivalues) {
        final candP = candidates[p];
        final pincers = [for (final q in bivalues) if (_sees[p][q] && (candidates[q] & ~candP) == 0) q];
        if (pincers.length < 2) continue;

        for (int i = 0; i < pincers.length; i++) {
          for (int j = i + 1; j < pincers.length; j++) {
            final q1 = pincers[i];
            final q2 = pincers[j];
            final candQ1 = candidates[q1];
            final candQ2 = candidates[q2];
            final commonZ = candQ1 & candQ2;
            if (_popCount(commonZ) == 1 && (candQ1 | candQ2) == candP) {
              bool changed = false;
              for (int x = 0; x < 81; x++) {
                if (x != p && x != q1 && x != q2 && _sees[p][x] && _sees[q1][x] && _sees[q2][x]) {
                  if (values[x] == 0 && (candidates[x] & commonZ) != 0) {
                    candidates[x] &= ~commonZ;
                    changed = true;
                  }
                }
              }
              if (changed) {
                recordTechnique('xyz_wing');
                return true;
              }
            }
          }
        }
      }
      return false;
    }

    // 17. W-Wing
    bool applyWWing() {
      final bivalues = <int>[];
      for (int i = 0; i < 81; i++) {
        if (values[i] == 0 && _popCount(candidates[i]) == 2) {
          bivalues.add(i);
        }
      }

      for (int i = 0; i < bivalues.length; i++) {
        for (int j = i + 1; j < bivalues.length; j++) {
          final c1 = bivalues[i];
          final c2 = bivalues[j];
          if (_sees[c1][c2]) continue;
          if (candidates[c1] == candidates[c2]) {
            final mask = candidates[c1];
            final d1Bit = _lowestBit(mask);
            final d2Bit = mask ^ d1Bit;

            for (final strongDigit in [d1Bit, d2Bit]) {
              final elimDigit = mask ^ strongDigit;
              for (int u = 0; u < 27; u++) {
                final unit = _units[u];
                final sCells = <int>[];
                for (final c in unit) {
                  if (values[c] == 0 && (candidates[c] & strongDigit) != 0) {
                    sCells.add(c);
                  }
                }
                if (sCells.length == 2) {
                  final s1 = sCells[0];
                  final s2 = sCells[1];
                  final match = (_sees[c1][s1] && _sees[c2][s2] && c1 != s1 && c2 != s2) ||
                                (_sees[c1][s2] && _sees[c2][s1] && c1 != s2 && c2 != s1);
                  if (match) {
                    bool changed = false;
                    for (int x = 0; x < 81; x++) {
                      if (x != c1 && x != c2 && _sees[c1][x] && _sees[c2][x]) {
                        if (values[x] == 0 && (candidates[x] & elimDigit) != 0) {
                          candidates[x] &= ~elimDigit;
                          changed = true;
                        }
                      }
                    }
                    if (changed) {
                      recordTechnique('w_wing');
                      return true;
                    }
                  }
                }
              }
            }
          }
        }
      }
      return false;
    }

    // 18. Unique Rectangle (Type 1 & Type 2)
    bool applyUniqueRectangle() {
      for (int r1 = 0; r1 < 8; r1++) {
        for (int r2 = r1 + 1; r2 < 9; r2++) {
          for (int c1 = 0; c1 < 8; c1++) {
            for (int c2 = c1 + 1; c2 < 9; c2++) {
              final p11 = r1 * 9 + c1;
              final p12 = r1 * 9 + c2;
              final p21 = r2 * 9 + c1;
              final p22 = r2 * 9 + c2;

              if (values[p11] != 0 || values[p12] != 0 || values[p21] != 0 || values[p22] != 0) {
                continue;
              }

              final b11 = _boxOf[p11];
              final b12 = _boxOf[p12];
              final b21 = _boxOf[p21];
              final b22 = _boxOf[p22];

              final boxSet = {b11, b12, b21, b22};
              if (boxSet.length != 2) continue;

              final corners = [p11, p12, p21, p22];

              // Type 1: 3 corners have {A, B}, 4th has {A, B, ...}
              for (int targetIdx = 0; targetIdx < 4; targetIdx++) {
                final otherIdxs = [0, 1, 2, 3]..remove(targetIdx);
                final m0 = candidates[corners[otherIdxs[0]]];
                if (_popCount(m0) == 2 &&
                    candidates[corners[otherIdxs[1]]] == m0 &&
                    candidates[corners[otherIdxs[2]]] == m0) {
                  final targetCell = corners[targetIdx];
                  if ((candidates[targetCell] & m0) == m0 && candidates[targetCell] != m0) {
                    candidates[targetCell] &= ~m0;
                    recordTechnique('unique_rectangle');
                    return true;
                  }
                }
              }

              // Type 2: 2 corners have {A, B}, the other 2 have {A, B, X}
              for (int i = 0; i < 4; i++) {
                for (int j = i + 1; j < 4; j++) {
                  final cA = corners[i];
                  final cB = corners[j];
                  if (_popCount(candidates[cA]) == 2 && candidates[cA] == candidates[cB]) {
                    final pairMask = candidates[cA];
                    final otherIdxs = [0, 1, 2, 3]..remove(i)..remove(j);
                    final cC = corners[otherIdxs[0]];
                    final cD = corners[otherIdxs[1]];
                    if ((candidates[cC] & pairMask) == pairMask &&
                        (candidates[cD] & pairMask) == pairMask &&
                        _popCount(candidates[cC]) == 3 &&
                        candidates[cC] == candidates[cD]) {
                      final xBit = candidates[cC] ^ pairMask;
                      bool changed = false;
                      for (int k = 0; k < 81; k++) {
                        if (k != cC && k != cD && _sees[cC][k] && _sees[cD][k]) {
                          if (values[k] == 0 && (candidates[k] & xBit) != 0) {
                            candidates[k] &= ~xBit;
                            changed = true;
                          }
                        }
                      }
                      if (changed) {
                        recordTechnique('unique_rectangle');
                        return true;
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      return false;
    }

    // 19. Simple AIC / Simple Colors
    bool applySimpleColors() {
      for (int d = 1; d <= 9; d++) {
        final bit = 1 << (d - 1);
        final graph = <int, List<int>>{};
        for (int u = 0; u < 27; u++) {
          final unit = _units[u];
          final unitCells = <int>[];
          for (final c in unit) {
            if (values[c] == 0 && (candidates[c] & bit) != 0) unitCells.add(c);
          }
          if (unitCells.length == 2) {
            final u1 = unitCells[0];
            final u2 = unitCells[1];
            graph.putIfAbsent(u1, () => []).add(u2);
            graph.putIfAbsent(u2, () => []).add(u1);
          }
        }

        if (graph.isEmpty) continue;

        final visited = <int, int>{};
        for (final startNode in graph.keys) {
          if (visited.containsKey(startNode)) continue;

          final component = <int>[];
          final queue = <int>[startNode];
          visited[startNode] = 0;
          component.add(startNode);

          while (queue.isNotEmpty) {
            final curr = queue.removeAt(0);
            final currColor = visited[curr]!;
            for (final neighbor in graph[curr]!) {
              if (!visited.containsKey(neighbor)) {
                visited[neighbor] = 1 - currColor;
                component.add(neighbor);
                queue.add(neighbor);
              }
            }
          }

          if (component.length < 2) continue;

          final color0 = [for (final c in component) if (visited[c] == 0) c];
          final color1 = [for (final c in component) if (visited[c] == 1) c];

          // Color Wrap (Color 0 conflict)
          bool color0Conflict = false;
          for (int i = 0; i < color0.length; i++) {
            for (int j = i + 1; j < color0.length; j++) {
              if (_sees[color0[i]][color0[j]]) {
                color0Conflict = true;
                break;
              }
            }
            if (color0Conflict) break;
          }
          if (color0Conflict) {
            bool changed = false;
            for (final c in color0) {
              if ((candidates[c] & bit) != 0) {
                candidates[c] &= ~bit;
                changed = true;
              }
            }
            if (changed) {
              recordTechnique('simple_aic');
              return true;
            }
          }

          // Color Wrap (Color 1 conflict)
          bool color1Conflict = false;
          for (int i = 0; i < color1.length; i++) {
            for (int j = i + 1; j < color1.length; j++) {
              if (_sees[color1[i]][color1[j]]) {
                color1Conflict = true;
                break;
              }
            }
            if (color1Conflict) break;
          }
          if (color1Conflict) {
            bool changed = false;
            for (final c in color1) {
              if ((candidates[c] & bit) != 0) {
                candidates[c] &= ~bit;
                changed = true;
              }
            }
            if (changed) {
              recordTechnique('simple_aic');
              return true;
            }
          }

          // Color Trap
          bool trapChanged = false;
          final compSet = component.toSet();
          for (int x = 0; x < 81; x++) {
            if (!compSet.contains(x) && values[x] == 0 && (candidates[x] & bit) != 0) {
              bool sees0 = false;
              for (final c0 in color0) {
                if (_sees[x][c0]) { sees0 = true; break; }
              }
              if (sees0) {
                bool sees1 = false;
                for (final c1 in color1) {
                  if (_sees[x][c1]) { sees1 = true; break; }
                }
                if (sees1) {
                  candidates[x] &= ~bit;
                  trapChanged = true;
                }
              }
            }
          }
          if (trapChanged) {
            recordTechnique('simple_aic');
            return true;
          }
        }
      }
      // Bivalue Alternating Inference Chains (XY-Chain)
      final bivalues = <int>[];
      for (int i = 0; i < 81; i++) {
        if (values[i] == 0 && _popCount(candidates[i]) == 2) {
          bivalues.add(i);
        }
      }

      if (bivalues.length >= 3) {
        for (final start in bivalues) {
          final candStart = candidates[start];
          final b1 = _lowestBit(candStart);
          final b2 = candStart ^ b1;

          for (final pair in [(b1, b2), (b2, b1)]) {
            final startA = pair.$1;
            final startB = pair.$2;

            final queue = <(int, int, List<int>)>[(start, startB, [start])];
            while (queue.isNotEmpty) {
              final item = queue.removeAt(0);
              final curr = item.$1;
              final digitIn = item.$2;
              final path = item.$3;
              if (path.length > 8) continue;

              for (final next in bivalues) {
                if (path.contains(next) || !_sees[curr][next]) continue;
                final candNext = candidates[next];
                if ((candNext & digitIn) != 0) {
                  final nextDigitOut = candNext ^ digitIn;
                  if (nextDigitOut == startA && path.length >= 2) {
                    bool changed = false;
                    for (int x = 0; x < 81; x++) {
                      if (x != start && x != next && _sees[start][x] && _sees[next][x]) {
                        if (values[x] == 0 && (candidates[x] & startA) != 0) {
                          candidates[x] &= ~startA;
                          changed = true;
                        }
                      }
                    }
                    if (changed) {
                      recordTechnique('simple_aic');
                      return true;
                    }
                  }

                  queue.add((next, nextDigitOut, [...path, next]));
                }
              }
            }
          }
        }
      }

      return false;
    }

    // --- Main Solving Loop ---
    while (emptyCount > 0) {
      // Tier 1: Easy
      if (applyNakedSingle()) continue;
      if (applyHiddenSingle()) continue;

      if (maxAllowedDifficulty == Difficulty.easy) {
        // Ceiling check for early exit
        break;
      }

      // Tier 2: Medium
      if (applyPointingTuple()) continue;
      if (applyBoxLineReduction()) continue;
      if (applyNakedPair()) continue;
      if (applyHiddenPair()) continue;
      if (applyNakedTriple()) continue;
      if (applyHiddenTriple()) continue;

      if (maxAllowedDifficulty == Difficulty.medium) {
        break;
      }

      // Tier 3: Hard
      if (applyNakedQuad()) continue;
      if (applyHiddenQuad()) continue;
      if (applyXWing()) continue;
      if (applySwordfish()) continue;
      if (applySkyscraper()) continue;
      if (applyTwoStringKite()) continue;

      if (maxAllowedDifficulty == Difficulty.hard) {
        break;
      }

      // Tier 4: Expert
      if (applyUniqueRectangle()) continue;
      if (applyXYWing()) continue;
      if (applyXYZWing()) continue;
      if (applyWWing()) continue;
      if (applySimpleColors()) continue;

      // No deductive technique was able to make progress
      break;
    }

    final isSolved = emptyCount == 0;
    final diff = isSolved ? _determineDifficulty(techniquesUsed) : null;
    final hardest = isSolved ? _determineHardestTechnique(techniquesUsed) : null;
    final solutionSb = StringBuffer();
    for (int i = 0; i < 81; i++) {
      solutionSb.write(values[i].toString());
    }

    final Map<int, List<int>> remCands = {};
    if (!isSolved) {
      for (int i = 0; i < 81; i++) {
        if (values[i] == 0) {
          final list = <int>[];
          for (int d = 1; d <= 9; d++) {
            if ((candidates[i] & (1 << (d - 1))) != 0) list.add(d);
          }
          remCands[i] = list;
        }
      }
    }

    return GradeResult(
      isSolved: isSolved,
      isStalled: !isSolved,
      difficulty: diff,
      hardestTechnique: hardest,
      techniquesUsed: techniquesUsed,
      clueCount: clueCount,
      puzzle: puzzleStr,
      solution: isSolved ? solutionSb.toString() : '',
      remainingCandidates: remCands,
    );
  }

  static Difficulty? _determineDifficulty(Map<String, int> techniquesUsed) {
    int maxRank = 0;
    for (final t in techniquesUsed.keys) {
      final r = _techniqueRank[t] ?? 0;
      if (r > maxRank) maxRank = r;
    }
    if (maxRank >= 30) return Difficulty.expert;
    if (maxRank >= 20) return Difficulty.hard;
    if (maxRank >= 10) return Difficulty.medium;
    if (maxRank >= 1) return Difficulty.easy;
    return null;
  }

  static String? _determineHardestTechnique(Map<String, int> techniquesUsed) {
    String? hardest;
    int maxRank = 0;
    for (final entry in techniquesUsed.entries) {
      final r = _techniqueRank[entry.key] ?? 0;
      if (r > maxRank) {
        maxRank = r;
        hardest = entry.key;
      }
    }
    return hardest;
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

  static List<int> _bitsToDigits(int mask) {
    final list = <int>[];
    for (int d = 1; d <= 9; d++) {
      if ((mask & (1 << (d - 1))) != 0) {
        list.add(d);
      }
    }
    return list;
  }

  static int _lowestBit(int mask) => mask & -mask;

  /// Finds the next logical deduction for the given [board].
  ///
  /// If [preferredRow] and [preferredCol] are provided, it first checks if that
  /// specific cell has an available single deduction.
  /// Otherwise, it performs a search in ascending order of cognitive difficulty.
  static DeductiveHint? findNextHint(
    SudokuBoard board, {
    int? preferredRow,
    int? preferredCol,
  }) {
    // 1. Check for any active user mistakes on the board
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final cell = board.cellAt(r, c);
        if (!cell.isGiven && cell.value != 0 && cell.value != cell.solutionValue) {
          return DeductiveHint(
            techniqueId: 'error_conflict',
            techniqueName: 'Resolve Conflict',
            difficulty: Difficulty.easy,
            targetRow: r,
            targetCol: c,
            causeCellIndices: {r * 9 + c},
            clueMessage:
                'Row ${r + 1}, Column ${c + 1} has an incorrect digit (${cell.value}). Correct or erase it before seeking logical deductions.',
            explanationMessage:
                'The number ${cell.value} in Row ${r + 1}, Column ${c + 1} contradicts the puzzle solution. Once cleared, candidate deduction can resume.',
          );
        }
      }
    }

    // 2. Initialize values from correctly placed digits
    final values = List<int>.filled(81, 0);
    final candidates = List<int>.filled(81, 0x1FF);
    int emptyCount = 0;

    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final cell = board.cellAt(r, c);
        final i = r * 9 + c;
        if (cell.value > 0 && cell.value == cell.solutionValue) {
          values[i] = cell.value;
          candidates[i] = 1 << (cell.value - 1);
        } else {
          values[i] = 0;
          emptyCount++;
        }
      }
    }

    if (emptyCount == 0) return null; // Board already complete

    // 3. Propagate peer constraints
    for (int i = 0; i < 81; i++) {
      final d = values[i];
      if (d > 0) {
        final mask = ~(1 << (d - 1));
        for (final p in _peersOf[i]) {
          candidates[p] &= mask;
        }
      }
    }

    // 4. Check preferred cell first if requested
    if (preferredRow != null && preferredCol != null) {
      final pIdx = preferredRow * 9 + preferredCol;
      if (values[pIdx] == 0) {
        final hint = _checkCellForSingle(pIdx, values, candidates);
        if (hint != null) return hint;
      }
    }

    // 5. Global search in ascending order of difficulty

    // 5.1 Naked Singles
    for (int i = 0; i < 81; i++) {
      if (values[i] == 0) {
        final cand = candidates[i];
        if ((cand & (cand - 1)) == 0 && cand > 0) {
          final digit = _bitToDigit(cand);
          final r = _rowOf[i];
          final c = _colOf[i];
          final causeCells = _peersOf[i].where((p) => values[p] > 0).toSet();
          return DeductiveHint(
            techniqueId: 'naked_single',
            techniqueName: 'Naked Single',
            difficulty: Difficulty.easy,
            targetRow: r,
            targetCol: c,
            targetValue: digit,
            causeCellIndices: causeCells,
            clueMessage:
                'Look at Row ${r + 1}, Column ${c + 1}: all other digits 1-9 are ruled out by its row, column, and 3x3 box.',
            explanationMessage:
                'Every number from 1 to 9 except $digit appears in the row, column, or box of Row ${r + 1}, Column ${c + 1}. Therefore, this cell must be $digit.',
          );
        }
      }
    }

    // 5.2 Hidden Singles
    for (int u = 0; u < 27; u++) {
      final unit = _units[u];
      for (int d = 1; d <= 9; d++) {
        final bit = 1 << (d - 1);
        int count = 0;
        int targetCell = -1;
        for (final c in unit) {
          if (values[c] == d) {
            count = -1;
            break;
          }
          if (values[c] == 0 && (candidates[c] & bit) != 0) {
            count++;
            targetCell = c;
          }
        }
        if (count == 1) {
          final r = _rowOf[targetCell];
          final c = _colOf[targetCell];
          final unitType = u < 9 ? 'row' : (u < 18 ? 'column' : 'box');
          final unitIndex = u < 9 ? u : (u < 18 ? u - 9 : u - 18);
          final unitName = u < 9
              ? 'Row ${u + 1}'
              : (u < 18 ? 'Column ${u - 9 + 1}' : 'Box ${u - 18 + 1}');

          final causeCells = <int>{};
          for (final cell in unit) {
            if (values[cell] > 0) {
              causeCells.add(cell);
            } else if (cell != targetCell) {
              for (final p in _peersOf[cell]) {
                if (values[p] == d) {
                  causeCells.add(p);
                  break;
                }
              }
            }
          }

          return DeductiveHint(
            techniqueId: 'hidden_single',
            techniqueName: 'Hidden Single',
            difficulty: Difficulty.easy,
            targetRow: r,
            targetCol: c,
            targetValue: d,
            causeCellIndices: causeCells,
            unitType: unitType,
            unitIndex: unitIndex,
            clueMessage:
                'Look at $unitName: where can digit $d be placed in this unit?',
            explanationMessage:
                'In $unitName, every cell except Row ${r + 1}, Column ${c + 1} is blocked from containing $d by existing numbers. Therefore, this cell must be $d.',
          );
        }
      }
    }

    // 5.3 Pointing Pair / Triple (Box -> Line)
    final pointingHint = _findPointingTupleHint(values, candidates);
    if (pointingHint != null) return pointingHint;

    // 5.4 Box-Line Reduction (Line -> Box)
    final boxLineHint = _findBoxLineHint(values, candidates);
    if (boxLineHint != null) return boxLineHint;

    // 5.5 Naked Pair
    final nakedPairHint = _findNakedPairHint(values, candidates);
    if (nakedPairHint != null) return nakedPairHint;

    // 5.6 Hidden Pair
    final hiddenPairHint = _findHiddenPairHint(values, candidates);
    if (hiddenPairHint != null) return hiddenPairHint;

    // 5.7 X-Wing
    final xWingHint = _findXWingHint(values, candidates);
    if (xWingHint != null) return xWingHint;

    // 5.8 Skyscraper
    final skyscraperHint = _findSkyscraperHint(values, candidates);
    if (skyscraperHint != null) return skyscraperHint;

    // 5.9 Two-String Kite
    final kiteHint = _findTwoStringKiteHint(values, candidates);
    if (kiteHint != null) return kiteHint;

    // 5.10 XY-Wing
    final xyWingHint = _findXYWingHint(values, candidates);
    if (xyWingHint != null) return xyWingHint;

    // 5.11 Fallback: Find empty cell with fewest remaining candidates
    int bestCell = -1;
    int minCandidates = 10;
    for (int i = 0; i < 81; i++) {
      if (values[i] == 0) {
        final cCount = _popCount(candidates[i]);
        if (cCount < minCandidates) {
          minCandidates = cCount;
          bestCell = i;
        }
      }
    }

    if (bestCell != -1) {
      final r = _rowOf[bestCell];
      final c = _colOf[bestCell];
      final targetCell = board.cellAt(r, c);
      final causeCells = _peersOf[bestCell].where((p) => values[p] > 0).toSet();

      return DeductiveHint(
        techniqueId: 'solution_reveal',
        techniqueName: 'Next Logical Step',
        difficulty: board.puzzleId?.startsWith('expert') == true
            ? Difficulty.expert
            : Difficulty.hard,
        targetRow: r,
        targetCol: c,
        targetValue: targetCell.solutionValue,
        causeCellIndices: causeCells,
        clueMessage:
            'Focus on Row ${r + 1}, Column ${c + 1}: this cell has the fewest remaining candidate choices.',
        explanationMessage:
            'Row ${r + 1}, Column ${c + 1} solves to ${targetCell.solutionValue}.',
      );
    }

    return null;
  }

  static DeductiveHint? _checkCellForSingle(
    int i,
    List<int> values,
    List<int> candidates,
  ) {
    final cand = candidates[i];
    // Naked Single
    if ((cand & (cand - 1)) == 0 && cand > 0) {
      final digit = _bitToDigit(cand);
      final r = _rowOf[i];
      final c = _colOf[i];
      final causeCells = _peersOf[i].where((p) => values[p] > 0).toSet();
      return DeductiveHint(
        techniqueId: 'naked_single',
        techniqueName: 'Naked Single',
        difficulty: Difficulty.easy,
        targetRow: r,
        targetCol: c,
        targetValue: digit,
        causeCellIndices: causeCells,
        clueMessage:
            'Look at Row ${r + 1}, Column ${c + 1}: all other digits 1-9 are ruled out by its row, column, and 3x3 box.',
        explanationMessage:
            'Every number from 1 to 9 except $digit appears in the row, column, or box of Row ${r + 1}, Column ${c + 1}. Therefore, this cell must be $digit.',
      );
    }

    // Hidden Single in row, column, or box
    for (final u in _unitsOf[i]) {
      final unit = _units[u];
      for (int d = 1; d <= 9; d++) {
        final bit = 1 << (d - 1);
        if ((cand & bit) == 0) continue;
        int count = 0;
        for (final c in unit) {
          if (values[c] == d) {
            count = -1;
            break;
          }
          if (values[c] == 0 && (candidates[c] & bit) != 0) {
            count++;
          }
        }
        if (count == 1) {
          final r = _rowOf[i];
          final c = _colOf[i];
          final unitType = u < 9 ? 'row' : (u < 18 ? 'column' : 'box');
          final unitIndex = u < 9 ? u : (u < 18 ? u - 9 : u - 18);
          final unitName = u < 9
              ? 'Row ${u + 1}'
              : (u < 18 ? 'Column ${u - 9 + 1}' : 'Box ${u - 18 + 1}');

          final causeCells = <int>{};
          for (final cell in unit) {
            if (values[cell] > 0) {
              causeCells.add(cell);
            } else if (cell != i) {
              for (final p in _peersOf[cell]) {
                if (values[p] == d) {
                  causeCells.add(p);
                  break;
                }
              }
            }
          }

          return DeductiveHint(
            techniqueId: 'hidden_single',
            techniqueName: 'Hidden Single',
            difficulty: Difficulty.easy,
            targetRow: r,
            targetCol: c,
            targetValue: d,
            causeCellIndices: causeCells,
            unitType: unitType,
            unitIndex: unitIndex,
            clueMessage:
                'Look at $unitName: where can digit $d be placed in this unit?',
            explanationMessage:
                'In $unitName, every cell except Row ${r + 1}, Column ${c + 1} is blocked from containing $d. Therefore, this cell must be $d.',
          );
        }
      }
    }

    return null;
  }

  static DeductiveHint? _findPointingTupleHint(
    List<int> values,
    List<int> candidates,
  ) {
    for (int b = 0; b < 9; b++) {
      final boxCells = _units[18 + b];
      for (int d = 1; d <= 9; d++) {
        final bit = 1 << (d - 1);
        int count = 0;
        int sameRow = -1;
        int sameCol = -1;
        bool rowMatch = true;
        bool colMatch = true;
        final causeCells = <int>{};

        for (final c in boxCells) {
          if (values[c] == 0 && (candidates[c] & bit) != 0) {
            count++;
            causeCells.add(c);
            final r = _rowOf[c];
            final col = _colOf[c];
            if (sameRow == -1) {
              sameRow = r;
            } else if (sameRow != r) {
              rowMatch = false;
            }

            if (sameCol == -1) {
              sameCol = col;
            } else if (sameCol != col) {
              colMatch = false;
            }
          }
        }

        if (count >= 2 && count <= 3) {
          if (rowMatch && sameRow != -1) {
            final eliminations = <int, Set<int>>{};
            int targetCell = -1;
            for (final c in _units[sameRow]) {
              if (_boxOf[c] != b && values[c] == 0 && (candidates[c] & bit) != 0) {
                eliminations[c] = {d};
                if (targetCell == -1) targetCell = c;
              }
            }
            if (eliminations.isNotEmpty) {
              return DeductiveHint(
                techniqueId: 'pointing_pair',
                techniqueName: 'Pointing Pair / Triple',
                difficulty: Difficulty.medium,
                targetRow: _rowOf[targetCell],
                targetCol: _colOf[targetCell],
                candidateEliminations: eliminations,
                causeCellIndices: causeCells,
                unitType: 'box',
                unitIndex: b,
                clueMessage:
                    'Look at Box ${b + 1}: candidate $d is confined to Row ${sameRow + 1} inside this box.',
                explanationMessage:
                    'Because digit $d in Box ${b + 1} must be in Row ${sameRow + 1}, it points along the row and eliminates candidate $d from the rest of Row ${sameRow + 1}.',
              );
            }
          }
          if (colMatch && sameCol != -1) {
            final eliminations = <int, Set<int>>{};
            int targetCell = -1;
            for (final c in _units[9 + sameCol]) {
              if (_boxOf[c] != b && values[c] == 0 && (candidates[c] & bit) != 0) {
                eliminations[c] = {d};
                if (targetCell == -1) targetCell = c;
              }
            }
            if (eliminations.isNotEmpty) {
              return DeductiveHint(
                techniqueId: 'pointing_pair',
                techniqueName: 'Pointing Pair / Triple',
                difficulty: Difficulty.medium,
                targetRow: _rowOf[targetCell],
                targetCol: _colOf[targetCell],
                candidateEliminations: eliminations,
                causeCellIndices: causeCells,
                unitType: 'box',
                unitIndex: b,
                clueMessage:
                    'Look at Box ${b + 1}: candidate $d is confined to Column ${sameCol + 1} inside this box.',
                explanationMessage:
                    'Because digit $d in Box ${b + 1} must be in Column ${sameCol + 1}, it points down the column and eliminates candidate $d from the rest of Column ${sameCol + 1}.',
              );
            }
          }
        }
      }
    }
    return null;
  }

  static DeductiveHint? _findBoxLineHint(
    List<int> values,
    List<int> candidates,
  ) {
    for (int u = 0; u < 18; u++) {
      final lineCells = _units[u];
      final isRow = u < 9;
      final lineName = isRow ? 'Row ${u + 1}' : 'Column ${u - 9 + 1}';

      for (int d = 1; d <= 9; d++) {
        final bit = 1 << (d - 1);
        int count = 0;
        int sameBox = -1;
        bool boxMatch = true;
        final causeCells = <int>{};

        for (final c in lineCells) {
          if (values[c] == 0 && (candidates[c] & bit) != 0) {
            count++;
            causeCells.add(c);
            final b = _boxOf[c];
            if (sameBox == -1) {
              sameBox = b;
            } else if (sameBox != b) {
              boxMatch = false;
            }
          }
        }

        if (count >= 2 && count <= 3 && boxMatch && sameBox != -1) {
          final eliminations = <int, Set<int>>{};
          int targetCell = -1;
          for (final c in _units[18 + sameBox]) {
            final matchesLine = isRow ? _rowOf[c] == u : _colOf[c] == (u - 9);
            if (!matchesLine && values[c] == 0 && (candidates[c] & bit) != 0) {
              eliminations[c] = {d};
              if (targetCell == -1) targetCell = c;
            }
          }

          if (eliminations.isNotEmpty) {
            return DeductiveHint(
              techniqueId: 'box_line_reduction',
              techniqueName: 'Box-Line Reduction',
              difficulty: Difficulty.medium,
              targetRow: _rowOf[targetCell],
              targetCol: _colOf[targetCell],
              candidateEliminations: eliminations,
              causeCellIndices: causeCells,
              unitType: isRow ? 'row' : 'column',
              unitIndex: isRow ? u : u - 9,
              clueMessage:
                  'Look at $lineName: digit $d can only be placed within Box ${sameBox + 1}.',
              explanationMessage:
                  'Because digit $d in $lineName must be inside Box ${sameBox + 1}, it eliminates candidate $d from all other cells in Box ${sameBox + 1}.',
            );
          }
        }
      }
    }
    return null;
  }

  static DeductiveHint? _findNakedPairHint(
    List<int> values,
    List<int> candidates,
  ) {
    for (int u = 0; u < 27; u++) {
      final unit = _units[u];
      final unitName = u < 9
          ? 'Row ${u + 1}'
          : (u < 18 ? 'Column ${u - 9 + 1}' : 'Box ${u - 18 + 1}');

      for (int i = 0; i < unit.length; i++) {
        final c1 = unit[i];
        if (values[c1] == 0 && _popCount(candidates[c1]) == 2) {
          for (int j = i + 1; j < unit.length; j++) {
            final c2 = unit[j];
            if (values[c2] == 0 && candidates[c1] == candidates[c2]) {
              final pairMask = candidates[c1];
              final digits = _bitsToDigits(pairMask);
              final eliminations = <int, Set<int>>{};
              int targetCell = -1;

              for (final c in unit) {
                if (c != c1 &&
                    c != c2 &&
                    values[c] == 0 &&
                    (candidates[c] & pairMask) != 0) {
                  final elims = <int>{};
                  for (final d in digits) {
                    if ((candidates[c] & (1 << (d - 1))) != 0) elims.add(d);
                  }
                  if (elims.isNotEmpty) {
                    eliminations[c] = elims;
                    if (targetCell == -1) targetCell = c;
                  }
                }
              }

              if (eliminations.isNotEmpty) {
                return DeductiveHint(
                  techniqueId: 'naked_pair',
                  techniqueName: 'Naked Pair',
                  difficulty: Difficulty.medium,
                  targetRow: _rowOf[targetCell],
                  targetCol: _colOf[targetCell],
                  candidateEliminations: eliminations,
                  causeCellIndices: {c1, c2},
                  unitType: u < 9 ? 'row' : (u < 18 ? 'column' : 'box'),
                  unitIndex: u < 9 ? u : (u < 18 ? u - 9 : u - 18),
                  clueMessage:
                      'Look at $unitName: two cells share the exact pair (${digits.join(', ')}).',
                  explanationMessage:
                      'Digits ${digits.join(' and ')} are locked into Row ${_rowOf[c1] + 1}, Col ${_colOf[c1] + 1} and Row ${_rowOf[c2] + 1}, Col ${_colOf[c2] + 1}. They cannot appear in any other cell in $unitName.',
                );
              }
            }
          }
        }
      }
    }
    return null;
  }

  static DeductiveHint? _findHiddenPairHint(
    List<int> values,
    List<int> candidates,
  ) {
    for (int u = 0; u < 27; u++) {
      final unit = _units[u];
      final unitName = u < 9
          ? 'Row ${u + 1}'
          : (u < 18 ? 'Column ${u - 9 + 1}' : 'Box ${u - 18 + 1}');

      for (int d1 = 1; d1 <= 8; d1++) {
        final bit1 = 1 << (d1 - 1);
        final cells1 =
            unit.where((c) => values[c] == 0 && (candidates[c] & bit1) != 0).toList();
        if (cells1.length != 2) continue;

        for (int d2 = d1 + 1; d2 <= 9; d2++) {
          final bit2 = 1 << (d2 - 1);
          final cells2 =
              unit.where((c) => values[c] == 0 && (candidates[c] & bit2) != 0).toList();
          if (cells2.length == 2 &&
              cells1[0] == cells2[0] &&
              cells1[1] == cells2[1]) {
            final c1 = cells1[0];
            final c2 = cells1[1];
            final pairMask = bit1 | bit2;
            final eliminations = <int, Set<int>>{};

            for (final c in [c1, c2]) {
              final otherCand = candidates[c] & ~pairMask;
              if (otherCand != 0) {
                eliminations[c] = _bitsToDigits(otherCand).toSet();
              }
            }

            if (eliminations.isNotEmpty) {
              return DeductiveHint(
                techniqueId: 'hidden_pair',
                techniqueName: 'Hidden Pair',
                difficulty: Difficulty.medium,
                targetRow: _rowOf[c1],
                targetCol: _colOf[c1],
                candidateEliminations: eliminations,
                causeCellIndices: {c1, c2},
                unitType: u < 9 ? 'row' : (u < 18 ? 'column' : 'box'),
                unitIndex: u < 9 ? u : (u < 18 ? u - 9 : u - 18),
                clueMessage:
                    'Look at $unitName: digits $d1 and $d2 only appear in two specific cells.',
                explanationMessage:
                    'In $unitName, digits $d1 and $d2 must go in Row ${_rowOf[c1] + 1}, Col ${_colOf[c1] + 1} and Row ${_rowOf[c2] + 1}, Col ${_colOf[c2] + 1}. All other candidates can be eliminated from them.',
              );
            }
          }
        }
      }
    }
    return null;
  }

  static DeductiveHint? _findXWingHint(
    List<int> values,
    List<int> candidates,
  ) {
    for (int d = 1; d <= 9; d++) {
      final bit = 1 << (d - 1);
      final rowPairs = <int, List<int>>{};
      for (int r = 0; r < 9; r++) {
        final cols = <int>[];
        for (int c = 0; c < 9; c++) {
          final idx = r * 9 + c;
          if (values[idx] == 0 && (candidates[idx] & bit) != 0) {
            cols.add(c);
          }
        }
        if (cols.length == 2) {
          rowPairs[r] = cols;
        }
      }

      final rows = rowPairs.keys.toList();
      for (int i = 0; i < rows.length; i++) {
        for (int j = i + 1; j < rows.length; j++) {
          final r1 = rows[i];
          final r2 = rows[j];
          final c1 = rowPairs[r1]![0];
          final c2 = rowPairs[r1]![1];
          if (rowPairs[r2]![0] == c1 && rowPairs[r2]![1] == c2) {
            final eliminations = <int, Set<int>>{};
            int targetCell = -1;
            for (final col in [c1, c2]) {
              for (int r = 0; r < 9; r++) {
                if (r != r1 && r != r2) {
                  final idx = r * 9 + col;
                  if (values[idx] == 0 && (candidates[idx] & bit) != 0) {
                    eliminations[idx] = {d};
                    if (targetCell == -1) targetCell = idx;
                  }
                }
              }
            }
            if (eliminations.isNotEmpty) {
              return DeductiveHint(
                techniqueId: 'x_wing',
                techniqueName: 'X-Wing',
                difficulty: Difficulty.hard,
                targetRow: _rowOf[targetCell],
                targetCol: _colOf[targetCell],
                candidateEliminations: eliminations,
                causeCellIndices: {
                  r1 * 9 + c1,
                  r1 * 9 + c2,
                  r2 * 9 + c1,
                  r2 * 9 + c2,
                },
                clueMessage:
                    'An X-Wing pattern on digit $d is formed across Rows ${r1 + 1} and ${r2 + 1}.',
                explanationMessage:
                    'Digit $d must occupy opposite corners of the rectangle in Columns ${c1 + 1} and ${c2 + 1}. Therefore, candidate $d can be removed from all other cells in those columns.',
              );
            }
          }
        }
      }
    }
    return null;
  }

  static DeductiveHint? _findSkyscraperHint(
    List<int> values,
    List<int> candidates,
  ) {
    for (int d = 1; d <= 9; d++) {
      final bit = 1 << (d - 1);
      final colPairs = <int, List<int>>{};
      for (int c = 0; c < 9; c++) {
        final rows = <int>[];
        for (int r = 0; r < 9; r++) {
          final idx = r * 9 + c;
          if (values[idx] == 0 && (candidates[idx] & bit) != 0) {
            rows.add(r);
          }
        }
        if (rows.length == 2) {
          colPairs[c] = rows;
        }
      }

      final cols = colPairs.keys.toList();
      for (int i = 0; i < cols.length; i++) {
        for (int j = i + 1; j < cols.length; j++) {
          final c1 = cols[i];
          final c2 = cols[j];
          final r1 = colPairs[c1]!;
          final r2 = colPairs[c2]!;

          int? baseRow;
          int? roof1, roof2;
          if (r1[0] == r2[0]) {
            baseRow = r1[0];
            roof1 = r1[1];
            roof2 = r2[1];
          } else if (r1[0] == r2[1]) {
            baseRow = r1[0];
            roof1 = r1[1];
            roof2 = r2[0];
          } else if (r1[1] == r2[0]) {
            baseRow = r1[1];
            roof1 = r1[0];
            roof2 = r2[1];
          } else if (r1[1] == r2[1]) {
            baseRow = r1[1];
            roof1 = r1[0];
            roof2 = r2[0];
          }

          if (baseRow != null && roof1 != null && roof2 != null && roof1 != roof2) {
            final cellRoof1 = roof1 * 9 + c1;
            final cellRoof2 = roof2 * 9 + c2;
            final eliminations = <int, Set<int>>{};
            int targetCell = -1;

            for (int k = 0; k < 81; k++) {
              if (k != cellRoof1 &&
                  k != cellRoof2 &&
                  values[k] == 0 &&
                  (candidates[k] & bit) != 0) {
                if (_sees[cellRoof1][k] && _sees[cellRoof2][k]) {
                  eliminations[k] = {d};
                  if (targetCell == -1) targetCell = k;
                }
              }
            }

            if (eliminations.isNotEmpty) {
              return DeductiveHint(
                techniqueId: 'skyscraper',
                techniqueName: 'Skyscraper',
                difficulty: Difficulty.hard,
                targetRow: _rowOf[targetCell],
                targetCol: _colOf[targetCell],
                candidateEliminations: eliminations,
                causeCellIndices: {
                  baseRow * 9 + c1,
                  baseRow * 9 + c2,
                  cellRoof1,
                  cellRoof2,
                },
                clueMessage:
                    'A Skyscraper pattern on digit $d is formed between Columns ${c1 + 1} and ${c2 + 1}.',
                explanationMessage:
                    'At least one of the two roof cells must contain digit $d. Therefore, candidate $d can be eliminated from any cell that sees both roofs.',
              );
            }
          }
        }
      }
    }
    return null;
  }

  static DeductiveHint? _findTwoStringKiteHint(
    List<int> values,
    List<int> candidates,
  ) {
    for (int d = 1; d <= 9; d++) {
      final bit = 1 << (d - 1);
      final biRows = <int, List<int>>{};
      final biCols = <int, List<int>>{};

      for (int i = 0; i < 9; i++) {
        final rCells = <int>[];
        final cCells = <int>[];
        for (int j = 0; j < 9; j++) {
          final idxR = i * 9 + j;
          if (values[idxR] == 0 && (candidates[idxR] & bit) != 0) rCells.add(j);
          final idxC = j * 9 + i;
          if (values[idxC] == 0 && (candidates[idxC] & bit) != 0) cCells.add(j);
        }
        if (rCells.length == 2) biRows[i] = rCells;
        if (cCells.length == 2) biCols[i] = cCells;
      }

      for (final rEntry in biRows.entries) {
        final r = rEntry.key;
        final rCols = rEntry.value;
        for (final cEntry in biCols.entries) {
          final c = cEntry.key;
          final cRows = cEntry.value;
          if (rCols.contains(c) || cRows.contains(r)) continue;

          for (final cInRow in rCols) {
            for (final rInCol in cRows) {
              if (_boxOf[r * 9 + cInRow] == _boxOf[rInCol * 9 + c]) {
                final rOuter = r;
                final cOuter = c;
                final sharedBox = _boxOf[r * 9 + cInRow];

                if (_boxOf[rOuter * 9 + (rCols[0] == cInRow ? rCols[1] : rCols[0])] != sharedBox &&
                    _boxOf[(cRows[0] == rInCol ? cRows[1] : cRows[0]) * 9 + cOuter] != sharedBox) {
                  final targetIdx = rOuter * 9 + cOuter;
                  if (values[targetIdx] == 0 && (candidates[targetIdx] & bit) != 0) {
                    final causeCells = {
                      r * 9 + rCols[0],
                      r * 9 + rCols[1],
                      cRows[0] * 9 + c,
                      cRows[1] * 9 + c,
                    };
                    return DeductiveHint(
                      techniqueId: 'two_string_kite',
                      techniqueName: 'Two-String Kite',
                      difficulty: Difficulty.hard,
                      targetRow: rOuter,
                      targetCol: cOuter,
                      candidateEliminations: {targetIdx: {d}},
                      causeCellIndices: causeCells,
                      clueMessage:
                          'A Two-String Kite on digit $d connects Row ${r + 1} and Column ${c + 1}.',
                      explanationMessage:
                          'Either the row or column string must place digit $d at its outer tip. Row ${rOuter + 1}, Column ${cOuter + 1} sees both outer tips and cannot contain $d.',
                    );
                  }
                }
              }
            }
          }
        }
      }
    }
    return null;
  }

  static DeductiveHint? _findXYWingHint(
    List<int> values,
    List<int> candidates,
  ) {
    final biCells = <int>[];
    for (int i = 0; i < 81; i++) {
      if (values[i] == 0 && _popCount(candidates[i]) == 2) {
        biCells.add(i);
      }
    }

    for (int p = 0; p < biCells.length; p++) {
      final pivot = biCells[p];
      final pDigits = _bitsToDigits(candidates[pivot]);
      final x = pDigits[0];
      final y = pDigits[1];

      for (int a = 0; a < biCells.length; a++) {
        if (a == p) continue;
        final pincer1 = biCells[a];
        if (!_sees[pivot][pincer1]) continue;
        final p1Digits = _bitsToDigits(candidates[pincer1]);
        if (!p1Digits.contains(x) && !p1Digits.contains(y)) continue;
        if (p1Digits.contains(x) && p1Digits.contains(y)) continue;

        final shared1 = p1Digits.contains(x) ? x : y;
        final z = p1Digits[0] == shared1 ? p1Digits[1] : p1Digits[0];
        final otherShared = shared1 == x ? y : x;

        for (int b = a + 1; b < biCells.length; b++) {
          if (b == p) continue;
          final pincer2 = biCells[b];
          if (!_sees[pivot][pincer2]) continue;
          final p2Digits = _bitsToDigits(candidates[pincer2]);
          if (p2Digits.length == 2 &&
              p2Digits.contains(otherShared) &&
              p2Digits.contains(z)) {
            final zBit = 1 << (z - 1);
            final eliminations = <int, Set<int>>{};
            int targetCell = -1;

            for (int k = 0; k < 81; k++) {
              if (k != pivot &&
                  k != pincer1 &&
                  k != pincer2 &&
                  values[k] == 0 &&
                  (candidates[k] & zBit) != 0) {
                if (_sees[pincer1][k] && _sees[pincer2][k]) {
                  eliminations[k] = {z};
                  if (targetCell == -1) targetCell = k;
                }
              }
            }

            if (eliminations.isNotEmpty) {
              return DeductiveHint(
                techniqueId: 'xy_wing',
                techniqueName: 'XY-Wing',
                difficulty: Difficulty.expert,
                targetRow: _rowOf[targetCell],
                targetCol: _colOf[targetCell],
                candidateEliminations: eliminations,
                causeCellIndices: {pivot, pincer1, pincer2},
                clueMessage:
                    'An XY-Wing is formed with pivot at Row ${_rowOf[pivot] + 1}, Column ${_colOf[pivot] + 1}.',
                explanationMessage:
                    'Whether the pivot cell is $x or $y, one of the two pincer cells must be $z. Therefore, candidate $z can be eliminated from any cell seeing both pincers.',
              );
            }
          }
        }
      }
    }
    return null;
  }
}
