import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/controllers/sudoku_controller.dart';
import 'package:sudoku/models/game_enums.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SudokuController', () {
    late SudokuController controller;

    setUp(() {
      controller = SudokuController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('initializes with an easy board', () {
      expect(controller.board.cells.length, equals(9));
      expect(controller.difficulty, equals(Difficulty.easy));
      expect(controller.status, equals(GameStatus.playing));
      expect(controller.elapsedSeconds, equals(0));
    });

    test('selection and entering digits', () {
      // Find an empty cell
      int emptyR = -1;
      int emptyC = -1;
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          if (controller.board.cellAt(r, c).isEmpty) {
            emptyR = r;
            emptyC = c;
            break;
          }
        }
        if (emptyR != -1) break;
      }

      controller.selectCell(emptyR, emptyC);
      expect(controller.selectedRow, equals(emptyR));
      expect(controller.selectedCol, equals(emptyC));

      // Enter digit 5
      controller.enterDigit(5);
      expect(controller.board.cellAt(emptyR, emptyC).value, equals(5));
      expect(controller.highlightedNumber, equals(5));

      // Cannot overwrite given clues
      int givenR = -1;
      int givenC = -1;
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          if (controller.board.cellAt(r, c).isGiven) {
            givenR = r;
            givenC = c;
            break;
          }
        }
        if (givenR != -1) break;
      }

      final originalVal = controller.board.cellAt(givenR, givenC).value;
      controller.selectCell(givenR, givenC);
      controller.enterDigit(1); // attempt to change
      expect(controller.board.cellAt(givenR, givenC).value, equals(originalVal));
    });

    test('erase clears entered value but not given clue', () {
      int emptyR = -1, emptyC = -1;
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          if (controller.board.cellAt(r, c).isEmpty) {
            emptyR = r;
            emptyC = c;
            break;
          }
        }
        if (emptyR != -1) break;
      }

      controller.selectCell(emptyR, emptyC);
      controller.enterDigit(7);
      expect(controller.board.cellAt(emptyR, emptyC).value, equals(7));

      controller.erase();
      expect(controller.board.cellAt(emptyR, emptyC).value, equals(0));
    });

    test('notes mode toggles candidate notes and auto-erases', () {
      int emptyR = -1, emptyC = -1;
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          if (controller.board.cellAt(r, c).isEmpty) {
            emptyR = r;
            emptyC = c;
            break;
          }
        }
        if (emptyR != -1) break;
      }

      controller.selectCell(emptyR, emptyC);
      controller.toggleNoteMode();
      expect(controller.isNoteMode, isTrue);

      // Add note 3 and note 9
      controller.enterDigit(3);
      controller.enterDigit(9);
      expect(controller.board.cellAt(emptyR, emptyC).notes, equals({3, 9}));

      // Toggle off note 3
      controller.enterDigit(3);
      expect(controller.board.cellAt(emptyR, emptyC).notes, equals({9}));

      // Switch back to normal mode and enter number
      controller.toggleNoteMode();
      expect(controller.isNoteMode, isFalse);
    });

    test('undo and redo revert actions', () {
      int emptyR = -1, emptyC = -1;
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          if (controller.board.cellAt(r, c).isEmpty) {
            emptyR = r;
            emptyC = c;
            break;
          }
        }
        if (emptyR != -1) break;
      }

      controller.selectCell(emptyR, emptyC);
      controller.enterDigit(4);
      expect(controller.board.cellAt(emptyR, emptyC).value, equals(4));
      expect(controller.canUndo, isTrue);

      controller.undo();
      expect(controller.board.cellAt(emptyR, emptyC).value, equals(0));
      expect(controller.canRedo, isTrue);

      controller.redo();
      expect(controller.board.cellAt(emptyR, emptyC).value, equals(4));
    });

    test('hint fills selected empty cell with solution value', () {
      int emptyR = -1, emptyC = -1;
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          if (controller.board.cellAt(r, c).isEmpty) {
            emptyR = r;
            emptyC = c;
            break;
          }
        }
        if (emptyR != -1) break;
      }

      controller.selectCell(emptyR, emptyC);
      final solution = controller.board.cellAt(emptyR, emptyC).solutionValue;

      controller.giveHint();
      expect(controller.board.cellAt(emptyR, emptyC).value, equals(solution));
      expect(controller.board.cellAt(emptyR, emptyC).hasHint, isTrue);
      expect(controller.hintsUsed, equals(1));
    });

    test('pause stops the game status and hides board interaction', () {
      expect(controller.status, equals(GameStatus.playing));
      controller.togglePause();
      expect(controller.status, equals(GameStatus.paused));

      // Attempting to select a cell while paused does nothing
      controller.selectCell(0, 0);
      expect(controller.selectedRow, isNull);

      controller.togglePause();
      expect(controller.status, equals(GameStatus.playing));
    });
  });
}
