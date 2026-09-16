import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/controllers/sudoku_controller.dart';
import 'package:sudoku/models/game_enums.dart';
import 'package:sudoku/services/puzzle_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await PuzzleDatabaseService.init();
  });

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

    test('two-stage hint provides clue first then reveals answer on second stage', () {
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
      // Stage 1: Give Hint provides clue and highlighting, does not spoil value yet
      controller.giveHint();
      expect(controller.isHintActive, isTrue);
      expect(controller.hintStage, equals(1));
      expect(controller.activeHint, isNotNull);
      final hint = controller.activeHint!;
      expect(hint.clueMessage.isNotEmpty, isTrue);
      // Value not yet placed, hintsUsed not incremented in stage 1
      expect(controller.board.cellAt(hint.targetRow, hint.targetCol).value, equals(0));
      expect(controller.hintsUsed, equals(0));

      final targetSol = controller.board.cellAt(hint.targetRow, hint.targetCol).solutionValue;

      // Stage 2: Reveal hint places the value and increments hintsUsed
      controller.revealHint();
      expect(controller.hintStage, equals(2));
      expect(controller.board.cellAt(hint.targetRow, hint.targetCol).value, equals(targetSol));
      expect(controller.board.cellAt(hint.targetRow, hint.targetCol).hasHint, isTrue);
      expect(controller.hintsUsed, equals(1));

      // Dismiss hint clears the active hint state
      controller.dismissHint();
      expect(controller.isHintActive, isFalse);
      expect(controller.activeHint, isNull);
      expect(controller.hintStage, equals(0));
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

    test('entering a mistake marks cell as isError and increments mistakes count', () {
      // Find an empty cell
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

      final cell = controller.board.cellAt(emptyR, emptyC);
      final solution = cell.solutionValue;
      final wrongDigit = (solution % 9) + 1;

      controller.selectCell(emptyR, emptyC);
      controller.enterDigit(wrongDigit);

      expect(controller.mistakes, equals(1));
      expect(cell.value, equals(wrongDigit));
      expect(cell.isError, isTrue);

      // Undoing the mistake reverts cell to 0 and clears isError
      controller.undo();
      expect(cell.value, equals(0));
      expect(cell.isError, isFalse);

      // Redoing the mistake restores value and isError
      controller.redo();
      expect(cell.value, equals(wrongDigit));
      expect(cell.isError, isTrue);

      // Erasing clears the mistake and clears isError
      controller.erase();
      expect(cell.value, equals(0));
      expect(cell.isError, isFalse);

      // Entering the correct number does not mark isError and does not increment mistakes
      controller.enterDigit(solution);
      expect(cell.value, equals(solution));
      expect(cell.isError, isFalse);
      expect(controller.mistakes, equals(1)); // Still 1 from earlier mistake
    });

    test('startNewGame loads fresh puzzle from database', () async {
      final initialBoard = controller.board;
      expect(controller.difficulty, equals(Difficulty.easy));

      await controller.startNewGame(Difficulty.medium);
      expect(controller.difficulty, equals(Difficulty.medium));
      expect(controller.board, isNot(same(initialBoard)));
      expect(controller.status, equals(GameStatus.playing));
      expect(controller.elapsedSeconds, equals(0));
    });
  });
}
