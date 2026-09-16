import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../controllers/sudoku_controller.dart';
import '../../models/game_enums.dart';
import '../theme/sudoku_theme.dart';
import 'sudoku_cell_widget.dart';

class SudokuGridWidget extends StatelessWidget {
  final SudokuController controller;

  const SudokuGridWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final thickBorderColor = SudokuTheme.getThickBorder(context);
    final thinBorderColor = SudokuTheme.getThinBorder(context);

    return AspectRatio(
      aspectRatio: 1.0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gridSize = math.min(constraints.maxWidth, constraints.maxHeight);
          final cellSize = gridSize / 9.0;

          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: thickBorderColor, width: 2.5),
                  borderRadius: BorderRadius.circular(4.0),
                  color: Theme.of(context).colorScheme.surface,
                ),
                child: Column(
                  children: List.generate(9, (r) {
                    final isThickBottom = (r % 3 == 2) && (r < 8);
                    return Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isThickBottom ? thickBorderColor : thinBorderColor,
                              width: isThickBottom ? 2.5 : 0.75,
                            ),
                          ),
                        ),
                        child: Row(
                          children: List.generate(9, (c) {
                            final isThickRight = (c % 3 == 2) && (c < 8);
                            final cell = controller.board.cellAt(r, c);

                            final isSelected =
                                controller.selectedRow == r && controller.selectedCol == c;
                            final isSameNumber = cell.value > 0 &&
                                controller.highlightedNumber == cell.value;
                            final isCrosshair = (controller.selectedRow == r ||
                                    controller.selectedCol == c ||
                                    controller.selectedCell?.boxIndex == cell.boxIndex) &&
                                !isSelected;

                            final isHintTarget = controller.isHintActive &&
                                controller.activeHint?.targetRow == r &&
                                controller.activeHint?.targetCol == c;
                            final isHintCause = controller.isHintActive &&
                                (controller.activeHint?.causeCellIndices.contains(r * 9 + c) ?? false);

                            final isAnimatingCompletion =
                                controller.animatingRows.contains(r) ||
                                controller.animatingCols.contains(c) ||
                                controller.animatingBoxes.contains(cell.boxIndex);

                            return Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(
                                      color: isThickRight ? thickBorderColor : thinBorderColor,
                                      width: isThickRight ? 2.5 : 0.75,
                                    ),
                                  ),
                                ),
                                child: SudokuCellWidget(
                                  cell: cell,
                                  cellSize: cellSize,
                                  isSelected: isSelected,
                                  isSameNumber: isSameNumber,
                                  isCrosshair: isCrosshair,
                                  isAnimatingCompletion: isAnimatingCompletion,
                                  isHintTarget: isHintTarget,
                                  isHintCause: isHintCause,
                                  highlightedNumber: controller.highlightedNumber,
                                  onTap: () => controller.selectCell(r, c),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    );
                  }),
                ),
              ),

          // Paused Overlay (Hides board content to prevent cheating while paused)
          if (controller.status == GameStatus.paused)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.pause_circle_filled_rounded,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Game Paused',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: controller.togglePause,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Resume'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  ),
);
  }
}
