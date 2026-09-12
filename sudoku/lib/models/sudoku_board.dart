import 'sudoku_cell.dart';

class SudokuBoard {
  final List<List<SudokuCell>> cells;

  SudokuBoard(this.cells);

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

  /// Recalculates error states for all cells based on rule violations (duplicates).
  void validateDuplicates() {
    // Reset non-given errors
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (!cells[r][c].isGiven) {
          cells[r][c].isError = false;
        }
      }
    }

    // Check rows
    for (int r = 0; r < 9; r++) {
      _flagDuplicates(cells[r]);
    }

    // Check columns
    for (int c = 0; c < 9; c++) {
      _flagDuplicates(getCol(c));
    }

    // Check boxes
    for (int b = 0; b < 9; b++) {
      _flagDuplicates(getBox(b));
    }
  }

  void _flagDuplicates(List<SudokuCell> group) {
    final counts = <int, List<SudokuCell>>{};
    for (final cell in group) {
      if (cell.value > 0) {
        counts.putIfAbsent(cell.value, () => []).add(cell);
      }
    }
    for (final entry in counts.entries) {
      if (entry.value.length > 1) {
        for (final cell in entry.value) {
          if (!cell.isGiven) {
            cell.isError = true;
          }
        }
      }
    }
  }

  Map<String, dynamic> toJson() {
    return {
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
    return SudokuBoard(boardCells);
  }
}
