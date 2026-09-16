import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/engine/deductive_grader.dart';
import 'package:sudoku/engine/sudoku_solver.dart';
import 'package:sudoku/models/game_enums.dart';
import 'package:sudoku/models/sudoku_board.dart';
import 'package:sudoku/services/puzzle_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeductiveGrader Unit Tests', () {
    late PuzzleDatabaseService dbService;

    setUpAll(() async {
      dbService = await PuzzleDatabaseService.init();
    });

    test('Easy tier puzzle solves using only Naked and Hidden singles', () async {
      final record = await dbService.getRandomPuzzleRecord(Difficulty.easy);

      final result = DeductiveGrader.gradePuzzle(record.puzzle);
      expect(result.isSolved, isTrue);
      expect(result.difficulty, equals(Difficulty.easy));
      expect(result.hardestTechnique, anyOf(equals('naked_single'), equals('hidden_single')));

      // Assert ceiling: no medium or higher techniques
      for (final t in result.techniquesUsed.keys) {
        expect(['naked_single', 'hidden_single'].contains(t), isTrue,
            reason: 'Easy puzzle should only use singles, but found $t');
      }
    });

    test('Medium tier puzzle satisfies floor (Medium technique) and ceiling (no Hard+)', () async {
      final record = await dbService.getRandomPuzzleRecord(Difficulty.medium);

      final result = DeductiveGrader.gradePuzzle(record.puzzle);
      expect(result.isSolved, isTrue);
      expect(result.difficulty, equals(Difficulty.medium));

      const mediumTechniques = [
        'pointing_pair',
        'box_line_reduction',
        'naked_pair',
        'hidden_pair',
        'naked_triple',
        'hidden_triple',
      ];
      expect(result.techniquesUsed.keys.any((t) => mediumTechniques.contains(t)), isTrue);
      expect(result.hardestTechnique, isIn(mediumTechniques));
    });

    test('Hard tier puzzle satisfies floor (Hard technique) and ceiling (no Expert+)', () async {
      final record = await dbService.getRandomPuzzleRecord(Difficulty.hard);

      final result = DeductiveGrader.gradePuzzle(record.puzzle);
      expect(result.isSolved, isTrue);
      expect(result.difficulty, equals(Difficulty.hard));

      const hardTechniques = [
        'naked_quad',
        'hidden_quad',
        'x_wing',
        'swordfish',
        'skyscraper',
        'two_string_kite',
      ];
      expect(result.techniquesUsed.keys.any((t) => hardTechniques.contains(t)), isTrue);
      expect(result.hardestTechnique, isIn(hardTechniques));
    });

    test('Expert tier puzzle satisfies floor (Expert technique) and is fully solved without guessing', () async {
      final record = await dbService.getRandomPuzzleRecord(Difficulty.expert);

      final result = DeductiveGrader.gradePuzzle(record.puzzle);
      expect(result.isSolved, isTrue);
      expect(result.difficulty, equals(Difficulty.expert));

      const expertTechniques = [
        'unique_rectangle',
        'xy_wing',
        'xyz_wing',
        'w_wing',
        'simple_aic',
      ];
      expect(result.techniquesUsed.keys.any((t) => expertTechniques.contains(t)), isTrue);
      expect(result.hardestTechnique, isIn(expertTechniques));
    });

    test('Evaluates XY-Wing specifically in Expert dataset', () async {
      final xyRecord = await dbService.getPuzzleByTechnique('xy_wing');
      expect(xyRecord, isNotNull);

      final result = DeductiveGrader.gradePuzzle(xyRecord!.puzzle);
      expect(result.isSolved, isTrue);
      expect(result.difficulty, equals(Difficulty.expert));
      expect(result.hardestTechnique, equals('xy_wing'));
      expect(result.techniquesUsed.containsKey('xy_wing'), isTrue);
    });

    test('Evaluates Skyscraper specifically in Hard dataset', () async {
      final skyRecord = await dbService.getPuzzleByTechnique('skyscraper');
      expect(skyRecord, isNotNull);

      final result = DeductiveGrader.gradePuzzle(skyRecord!.puzzle);
      expect(result.isSolved, isTrue);
      expect(result.difficulty, equals(Difficulty.hard));
      expect(result.hardestTechnique, equals('skyscraper'));
      expect(result.techniquesUsed.containsKey('skyscraper'), isTrue);
    });

    test('Evaluates Pointing Pair specifically in Medium dataset', () async {
      final ppRecord = await dbService.getPuzzleByTechnique('pointing_pair');
      expect(ppRecord, isNotNull);

      final result = DeductiveGrader.gradePuzzle(ppRecord!.puzzle);
      expect(result.isSolved, isTrue);
      expect(result.difficulty, equals(Difficulty.medium));
      expect(result.hardestTechnique, equals('pointing_pair'));
      expect(result.techniquesUsed.containsKey('pointing_pair'), isTrue);
    });

    test('Evaluates Two-String Kite specifically in Hard dataset', () async {
      final kiteRecord = await dbService.getPuzzleByTechnique('two_string_kite');
      expect(kiteRecord, isNotNull);

      final result = DeductiveGrader.gradePuzzle(kiteRecord!.puzzle);
      expect(result.isSolved, isTrue);
      expect(result.difficulty, equals(Difficulty.hard));
      expect(result.hardestTechnique, equals('two_string_kite'));
      expect(result.techniquesUsed.containsKey('two_string_kite'), isTrue);
    });

    test('Detects stalled state when puzzle requires guessing / bifurcation', () {
      // Minimal 17-clue puzzle requiring trial-and-error / bifurcation
      const ultraHard = '000000010000002000000030000000000400001000000000500000000060000000007000000800000';
      final result = DeductiveGrader.gradePuzzle(ultraHard);
      expect(result.isSolved, isFalse);
      expect(result.isStalled, isTrue);
      expect(result.difficulty, isNull);
    });

    test('Fast Uniqueness Checker validates single unique solution correctly', () {
      const uniquePuzzle = '530070000600195000098000060800060003400803001700020006060000280000419005000080079';
      expect(SudokuSolver.countSolutionsString(uniquePuzzle, maxCount: 2), equals(1));
      expect(SudokuSolver.solveString(uniquePuzzle), isNotNull);

      // Multiple solutions test (clearing cells from a valid board)
      final multiSolution = '.' * 81;
      expect(SudokuSolver.countSolutionsString(multiSolution, maxCount: 2), equals(2));
    });

    group('DeductiveGrader.findNextHint Tests', () {
      test('finds error_conflict hint when an invalid digit is placed', () async {
        final record = await dbService.getRandomPuzzleRecord(Difficulty.easy);
        final board = SudokuBoard.fromRecord(record);

        // Find an empty cell and enter a wrong digit
        int emptyR = -1, emptyC = -1;
        for (int r = 0; r < 9; r++) {
          for (int c = 0; c < 9; c++) {
            if (board.cellAt(r, c).isEmpty) {
              emptyR = r;
              emptyC = c;
              break;
            }
          }
          if (emptyR != -1) break;
        }

        final wrongValue = (board.cellAt(emptyR, emptyC).solutionValue % 9) + 1;
        board.cellAt(emptyR, emptyC).value = wrongValue;
        board.cellAt(emptyR, emptyC).isError = true;

        final hint = DeductiveGrader.findNextHint(board);
        expect(hint, isNotNull);
        expect(hint!.techniqueId, equals('error_conflict'));
        expect(hint.targetRow, equals(emptyR));
        expect(hint.targetCol, equals(emptyC));
        expect(hint.clueMessage, contains('incorrect digit'));
      });

      test('finds deductive hint for naked or hidden single on easy board', () async {
        final record = await dbService.getRandomPuzzleRecord(Difficulty.easy);
        final board = SudokuBoard.fromRecord(record);

        final hint = DeductiveGrader.findNextHint(board);
        expect(hint, isNotNull);
        expect(hint!.targetRow, inInclusiveRange(0, 8));
        expect(hint.targetCol, inInclusiveRange(0, 8));
        expect(hint.targetValue, inInclusiveRange(1, 9));
        expect(hint.causeCellIndices, isNotEmpty);
        expect(hint.clueMessage, isNotEmpty);
        expect(hint.explanationMessage, isNotEmpty);
        expect(['naked_single', 'hidden_single'].contains(hint.techniqueId), isTrue);

        // Verify the hinted value matches the known solution value
        final sol = board.cellAt(hint.targetRow, hint.targetCol).solutionValue;
        expect(hint.targetValue, equals(sol));
      });

      test('prioritizes preferred cell when a deduction is available for it', () async {
        final record = await dbService.getRandomPuzzleRecord(Difficulty.easy);
        final board = SudokuBoard.fromRecord(record);

        // Find a cell that has a naked or hidden single
        final firstHint = DeductiveGrader.findNextHint(board);
        expect(firstHint, isNotNull);

        // When we pass the firstHint target cell as preferredRow/preferredCol, it should return that cell
        final preferredHint = DeductiveGrader.findNextHint(
          board,
          preferredRow: firstHint!.targetRow,
          preferredCol: firstHint.targetCol,
        );
        expect(preferredHint, isNotNull);
        expect(preferredHint!.targetRow, equals(firstHint.targetRow));
        expect(preferredHint.targetCol, equals(firstHint.targetCol));
      });
    });
  });
}

