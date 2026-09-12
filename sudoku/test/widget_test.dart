import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/controllers/sudoku_controller.dart';
import 'package:sudoku/main.dart';
import 'package:sudoku/ui/widgets/number_pad_widget.dart';
import 'package:sudoku/ui/widgets/sudoku_cell_widget.dart';
import 'package:sudoku/ui/widgets/sudoku_grid_widget.dart';

void main() {
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
}
