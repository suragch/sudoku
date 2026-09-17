import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/controllers/sudoku_controller.dart';
import 'package:sudoku/main.dart';
import 'package:sudoku/models/deductive_hint.dart';
import 'package:sudoku/models/game_enums.dart';
import 'package:sudoku/services/puzzle_database_service.dart';
import 'package:sudoku/ui/theme/sudoku_theme.dart';
import 'package:sudoku/ui/widgets/number_pad_widget.dart';
import 'package:sudoku/ui/widgets/sudoku_cell_widget.dart';
import 'package:sudoku/ui/widgets/sudoku_grid_widget.dart';

void main() {
  setUpAll(() async {
    await PuzzleDatabaseService.init();
  });

  testWidgets('SudokuApp smoke test and gameplay interactions', (WidgetTester tester) async {
    final controller = SudokuController();

    await tester.pumpWidget(SudokuApp(controller: controller));
    await tester.pumpAndSettle();

    // Verify AppBar
    expect(find.text('Sudoku'), findsOneWidget);

    // Verify 9x9 grid is rendered with 81 cells
    expect(find.byType(SudokuGridWidget), findsOneWidget);
    expect(find.byType(SudokuCellWidget), findsNWidgets(81));

    // Verify NumberPadWidget is rendered
    expect(find.byType(NumberPadWidget), findsOneWidget);

    // Verify action buttons
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Erase'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Hint'), findsOneWidget);
    expect(find.text('Fast Fill'), findsOneWidget);

    // Verify Timer and Difficulty chip
    expect(find.text('EASY'), findsOneWidget);
    expect(find.textContaining('Mistakes:'), findsOneWidget);

    // Find an empty cell widget and tap it
    final emptyCellFinder = find.byWidgetPredicate(
      (widget) => widget is SudokuCellWidget && widget.cell.isEmpty,
    );
    expect(emptyCellFinder, findsWidgets);

    await tester.tap(emptyCellFinder.first);
    await tester.pumpAndSettle();

    // Tap number 7 on the number pad using ValueKey
    final num7Finder = find.byKey(const ValueKey('number_btn_7'));
    expect(num7Finder, findsOneWidget);

    await tester.tap(num7Finder);
    await tester.pumpAndSettle();

    // The selected cell should now contain 7
    expect(controller.selectedCell?.value, equals(7));

    // Tap erase
    await tester.tap(find.text('Erase'));
    await tester.pumpAndSettle();

    // The cell value should now be 0 (cleared)
    expect(controller.selectedCell?.value, equals(0));

    // Tap notes mode
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(controller.isNoteMode, isTrue);

    // Add note 3 on the number pad
    final num3Finder = find.byKey(const ValueKey('number_btn_3'));
    await tester.tap(num3Finder);
    await tester.pumpAndSettle();
    expect(controller.selectedCell?.notes.contains(3), isTrue);

    controller.dispose();
  });

  testWidgets('Mistake is marked in red and undo reverts it', (WidgetTester tester) async {
    final controller = SudokuController();

    await tester.pumpWidget(SudokuApp(controller: controller));
    await tester.pumpAndSettle();

    // Find an empty cell
    final emptyCellFinder = find.byWidgetPredicate(
      (widget) => widget is SudokuCellWidget && widget.cell.isEmpty,
    );
    expect(emptyCellFinder, findsWidgets);

    // Tap first empty cell
    await tester.tap(emptyCellFinder.first);
    await tester.pumpAndSettle();

    final selectedCell = controller.selectedCell!;
    final solution = selectedCell.solutionValue;
    final wrongDigit = (solution % 9) + 1;

    // Enter wrong digit
    final wrongBtnFinder = find.byKey(ValueKey('number_btn_$wrongDigit'));
    await tester.tap(wrongBtnFinder);
    await tester.pumpAndSettle();

    // Mistakes label in header bar should reflect 1 mistake
    expect(find.text('Mistakes: 1'), findsOneWidget);

    // The text on the grid for this wrong digit should have error color (red)
    final textFinder = find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is SudokuCellWidget && widget.cell.row == selectedCell.row && widget.cell.col == selectedCell.col,
      ),
      matching: find.text('$wrongDigit'),
    );
    expect(textFinder, findsOneWidget);

    final textWidget = tester.widget<Text>(textFinder);
    expect(textWidget.style?.color, equals(SudokuTheme.lightErrorText));

    // Tap Undo
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    // Cell should now be cleared
    expect(selectedCell.value, equals(0));
    expect(selectedCell.isError, isFalse);
    expect(textFinder, findsNothing);

    controller.dispose();
  });

  testWidgets('Two-stage hint banner flow: clue -> reveal answer -> dismiss', (WidgetTester tester) async {
    final controller = SudokuController();

    await tester.pumpWidget(SudokuApp(controller: controller));
    await tester.pumpAndSettle();

    // Tap Hint button in toolbar
    await tester.tap(find.text('Hint'));
    await tester.pumpAndSettle();

    // Verify Hint Banner appears in Stage 1 and hint counter is updated immediately
    expect(controller.isHintActive, isTrue);
    expect(controller.hintStage, equals(1));
    expect(controller.hintsUsed, equals(1));
    expect(find.text('Where to Look'), findsOneWidget);
    expect(find.text('Reveal Answer'), findsOneWidget);
    expect(find.text("I'll solve it"), findsOneWidget);

    // Tap Reveal Answer
    await tester.tap(find.text('Reveal Answer'));
    await tester.pumpAndSettle();

    // Verify Hint Banner transitions to Stage 2
    expect(controller.hintStage, equals(2));
    expect(find.text('Explanation'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);
    expect(controller.hintsUsed, equals(1));

    // Tap Got it to dismiss
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    // Verify Hint Banner is dismissed
    expect(controller.isHintActive, isFalse);
    expect(find.text('Explanation'), findsNothing);

    controller.dispose();
  });

  testWidgets('Pointing Pair / elimination hint reveals answer on the board when Reveal Answer is clicked', (WidgetTester tester) async {
    final controller = SudokuController();

    // Find an empty cell to target
    int targetR = -1, targetC = -1;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (controller.board.cellAt(r, c).isEmpty) {
          targetR = r;
          targetC = c;
          break;
        }
      }
      if (targetR != -1) break;
    }

    final targetCell = controller.board.cellAt(targetR, targetC);
    final expectedVal = targetCell.solutionValue;

    // Simulate Pointing Pair hint (targetValue is null)
    final pointingPairHint = DeductiveHint(
      techniqueId: 'pointing_pair',
      techniqueName: 'Pointing Pair / Triple',
      difficulty: Difficulty.medium,
      targetRow: targetR,
      targetCol: targetC,
      targetValue: null,
      candidateEliminations: {},
      causeCellIndices: {},
      clueMessage: 'Look at Box 2: candidate 9 is confined to Row 1.',
      explanationMessage: 'Because candidate 9 is confined to Row 1, it eliminates candidate 9 from other cells.',
    );

    controller.setActiveHintForTesting(pointingPairHint, stage: 1);

    await tester.pumpWidget(SudokuApp(controller: controller));
    await tester.pumpAndSettle();

    // Verify Pointing Pair chip and clue are shown
    expect(find.text('Pointing Pair / Triple'), findsOneWidget);
    expect(find.text('Where to Look'), findsOneWidget);
    expect(find.text('Reveal Answer'), findsOneWidget);
    expect(targetCell.value, equals(0));

    // Tap Reveal Answer
    await tester.tap(find.text('Reveal Answer'));
    await tester.pumpAndSettle();

    // Verify cell answer is revealed on the board!
    expect(targetCell.value, equals(expectedVal));
    expect(targetCell.hasHint, isTrue);

    // Verify Stage 2 explanation includes the revealed cell answer
    expect(find.text('Explanation'), findsOneWidget);
    expect(find.textContaining('revealed as $expectedVal'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('Grid numbers shrink proportionally when the grid shrinks in size', (WidgetTester tester) async {
    final controller = SudokuController();

    // 1. Render in a large 450x450 box (typical cell size ~50px)
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 450,
              height: 450,
              child: SudokuGridWidget(controller: controller),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Find a given clue number Text widget
    final clueCellFinder = find.byWidgetPredicate(
      (w) => w is SudokuCellWidget && w.cell.isGiven && w.cell.value > 0,
    );
    expect(clueCellFinder, findsWidgets);

    final firstClueTextFinder = find.descendant(
      of: clueCellFinder.first,
      matching: find.byType(Text),
    );
    final textWidgetLarge = tester.widget<Text>(firstClueTextFinder);
    final largeFontSize = textWidgetLarge.style?.fontSize;
    expect(largeFontSize, isNotNull);

    // 2. Render in a small 270x270 box (typical shrunk cell size ~30px, e.g. during hint banner)
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 270,
              height: 270,
              child: SudokuGridWidget(controller: controller),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final textWidgetSmall = tester.widget<Text>(firstClueTextFinder);
    final smallFontSize = textWidgetSmall.style?.fontSize;
    expect(smallFontSize, isNotNull);

    // Verify the numbers shrunk
    expect(smallFontSize!, lessThan(largeFontSize!));
    expect(smallFontSize, closeTo(270 / 9 * 0.58, 0.5));
    expect(largeFontSize, closeTo(450 / 9 * 0.58, 0.5));

    controller.dispose();
  });

  testWidgets('DifficultyDialog displays deductive tiers and allows changing difficulty', (WidgetTester tester) async {
    final controller = SudokuController();

    await tester.pumpWidget(SudokuApp(controller: controller));
    await tester.pumpAndSettle();

    // Tap difficulty chip in header bar
    await tester.tap(find.text('EASY'));
    await tester.pumpAndSettle();

    // Verify dialog header
    expect(find.text('Select Difficulty'), findsOneWidget);

    // Verify all 4 difficulty levels are displayed without explanations
    expect(find.text('Easy'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Hard'), findsOneWidget);
    expect(find.text('Expert'), findsOneWidget);

    // Verify explanations/subtitles are not present
    expect(find.text('Graded by deductive solving techniques'), findsNothing);
    expect(find.text('Naked & Hidden Singles'), findsNothing);
    expect(find.text('Restart Current Puzzle'), findsNothing);

    // Select Medium tier
    await tester.tap(find.byKey(const ValueKey('difficulty_option_medium')));
    await tester.pumpAndSettle();

    // Check if dialog closed
    expect(find.text('Select Difficulty'), findsNothing);

    // Allow background sqflite query to complete
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // Verify difficulty changed to Medium
    expect(controller.difficulty, equals(Difficulty.medium));
    expect(find.text('MEDIUM'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('Stats dialog does not indicate game was played until at least one cell is marked', (WidgetTester tester) async {
    final controller = SudokuController();

    await tester.pumpWidget(SudokuApp(controller: controller));
    await tester.pumpAndSettle();

    // 1. Open Stats before marking any cell
    await tester.tap(find.byIcon(Icons.leaderboard_outlined));
    await tester.pumpAndSettle();

    // In the stats dialog, games played should be 0 for all difficulties
    expect(find.text('Statistics'), findsOneWidget);
    expect(controller.stats.forDifficulty(Difficulty.easy).gamesStarted, equals(0));

    // Close stats dialog
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // 2. Select an empty cell and enter a digit
    final emptyCellFinder = find.byWidgetPredicate(
      (widget) => widget is SudokuCellWidget && widget.cell.isEmpty,
    );
    expect(emptyCellFinder, findsWidgets);

    await tester.tap(emptyCellFinder.first);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('number_btn_1')));
    await tester.pumpAndSettle();

    // 3. Open Stats again - now games played should be 1 for Easy
    await tester.tap(find.byIcon(Icons.leaderboard_outlined));
    await tester.pumpAndSettle();

    expect(controller.stats.forDifficulty(Difficulty.easy).gamesStarted, equals(1));
    expect(find.text('1'), findsAtLeast(1));

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    controller.dispose();
  });

  testWidgets('Paused overlay displays only Resume button without non-tappable pause button', (WidgetTester tester) async {
    final controller = SudokuController();

    await tester.pumpWidget(SudokuApp(controller: controller));
    await tester.pumpAndSettle();

    // Pause the game via the timer pause icon
    await tester.tap(find.byTooltip('Pause'));
    await tester.pumpAndSettle();

    expect(controller.status, equals(GameStatus.paused));

    // Verify non-tappable big pause icon is removed
    expect(find.byIcon(Icons.pause_circle_filled_rounded), findsNothing);

    // Verify Resume button is displayed on the paused overlay
    final resumeBtn = find.widgetWithText(FilledButton, 'Resume');
    expect(resumeBtn, findsOneWidget);

    // Tap Resume button to unpause
    await tester.tap(resumeBtn);
    await tester.pumpAndSettle();

    expect(controller.status, equals(GameStatus.playing));
    expect(resumeBtn, findsNothing);

    controller.dispose();
  });

  testWidgets('If hint is showing when pause button is pressed, hint text is dismissed', (WidgetTester tester) async {
    final controller = SudokuController();

    await tester.pumpWidget(SudokuApp(controller: controller));
    await tester.pumpAndSettle();

    // Trigger hint
    await tester.tap(find.text('Hint'));
    await tester.pumpAndSettle();

    expect(controller.isHintActive, isTrue);
    expect(find.text('Where to Look'), findsOneWidget);

    // Tap pause button in header bar
    await tester.tap(find.byTooltip('Pause'));
    await tester.pumpAndSettle();

    expect(controller.status, equals(GameStatus.paused));
    expect(controller.isHintActive, isFalse);
    expect(find.text('Where to Look'), findsNothing);

    // Tap Resume button to unpause
    await tester.tap(find.widgetWithText(FilledButton, 'Resume'));
    await tester.pumpAndSettle();

    expect(controller.status, equals(GameStatus.playing));
    // Hint remains dismissed after unpausing
    expect(controller.isHintActive, isFalse);
    expect(find.text('Where to Look'), findsNothing);

    controller.dispose();
  });
}



