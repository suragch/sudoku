import '../engine/puzzle_record.dart';
import 'sudoku_cell.dart';

class SudokuBoard {
  final List<List<SudokuCell>> cells;
  final String? puzzleId;

  SudokuBoard(this.cells, {this.puzzleId});

  SudokuCell cellAt(int row, int col) => cells[row][col];

  List<SudokuCell> getRow(int row) => cells[row];

  List<SudokuCell> getCol(int col) {
    return List.generate(9, (r) => cells[r][col]);
  }

  List<SudokuCell> getBox(int boxIndex) {
    final startRow = (boxIndex ~/ 3) * 3;
    final startCol = (boxIndex % 3) * 3;
    final boxCells = <SudokuCell>[];
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        boxCells.add(cells[startRow + r][startCol + c]);
      }
    }
    return boxCells;
  }

  bool isRowComplete(int row) {
    final values = cells[row].map((c) => c.value).where((v) => v > 0).toSet();
    return values.length == 9;
  }

  bool isColComplete(int col) {
    final values = getCol(col).map((c) => c.value).where((v) => v > 0).toSet();
    return values.length == 9;
  }

  bool isBoxComplete(int boxIndex) {
    final values = getBox(boxIndex).map((c) => c.value).where((v) => v > 0).toSet();
    return values.length == 9;
  }

  bool get isComplete {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final cell = cells[r][c];
        if (cell.value == 0 || cell.value != cell.solutionValue) {
          return false;
        }
      }
    }
    return true;
  }

  /// Counts how many instances of [digit] (1-9) remain to be placed correctly.
  int getRemainingCount(int digit) {
    int placed = 0;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (cells[r][c].value == digit && cells[r][c].value == cells[r][c].solutionValue) {
          placed++;
        }
      }
    }
    return (9 - placed).clamp(0, 9);
  }

  /// Returns true if all 9 instances of [digit] are placed correctly.
  bool isDigitComplete(int digit) => getRemainingCount(digit) == 0;

  /// Recalculates error states for all cells based on mistakes (non-matching solution value).
  void validateErrors() {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final cell = cells[r][c];
        if (!cell.isGiven) {
          cell.isError = cell.value != 0 && cell.value != cell.solutionValue;
        }
      }
    }
  }

  /// Alias for [validateErrors] to maintain backwards compatibility.
  void validateDuplicates() => validateErrors();

  /// Creates a deep copy of this board.
  SudokuBoard copy() {
    return SudokuBoard(
      cells.map((row) => row.map((cell) => cell.copyWith()).toList()).toList(),
      puzzleId: puzzleId,
    );
  }

  /// Constructs a [SudokuBoard] from 81-character puzzle and solution strings.
  factory SudokuBoard.fromPuzzleAndSolution({
    required String puzzle,
    required String solution,
    String? puzzleId,
  }) {
    assert(puzzle.length == 81, 'Puzzle string must be exactly 81 characters');
    assert(solution.length == 81, 'Solution string must be exactly 81 characters');

    final cells = List.generate(9, (r) {
      return List.generate(9, (c) {
        final idx = r * 9 + c;
        final pChar = puzzle[idx];
        final sChar = solution[idx];
        final isGiven = pChar != '.' && pChar != '0';
        final val = isGiven ? int.parse(pChar) : 0;
        final sol = int.parse(sChar);
        return SudokuCell(
          row: r,
          col: c,
          solutionValue: sol,
          isGiven: isGiven,
          value: val,
        );
      });
    });
    return SudokuBoard(cells, puzzleId: puzzleId);
  }

  /// Constructs a [SudokuBoard] from a [SudokuPuzzleRecord].
  factory SudokuBoard.fromRecord(SudokuPuzzleRecord record) {
    return SudokuBoard.fromPuzzleAndSolution(
      puzzle: record.puzzle,
      solution: record.solution,
      puzzleId: record.id,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (puzzleId != null) 'puzzleId': puzzleId,
      'cells': cells.map((row) => row.map((cell) => cell.toJson()).toList()).toList(),
    };
  }

  factory SudokuBoard.fromJson(Map<String, dynamic> json) {
    final rawCells = json['cells'] as List<dynamic>;
    final boardCells = rawCells.map((row) {
      return (row as List<dynamic>).map((cellJson) {
        return SudokuCell.fromJson(cellJson as Map<String, dynamic>);
      }).toList();
    }).toList();
    return SudokuBoard(
      boardCells,
      puzzleId: json['puzzleId'] as String?,
    );
  }
}
