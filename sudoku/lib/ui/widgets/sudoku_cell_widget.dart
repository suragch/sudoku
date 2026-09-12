import 'package:flutter/material.dart';
import '../../models/sudoku_cell.dart';
import '../theme/sudoku_theme.dart';

class SudokuCellWidget extends StatelessWidget {
  final SudokuCell cell;
  final bool isSelected;
  final bool isSameNumber;
  final bool isCrosshair;
  final bool isAnimatingCompletion;
  final int highlightedNumber;
  final VoidCallback onTap;

  const SudokuCellWidget({
    super.key,
    required this.cell,
    required this.isSelected,
    required this.isSameNumber,
    required this.isCrosshair,
    required this.isAnimatingCompletion,
    required this.highlightedNumber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color? backgroundColor;

    if (isAnimatingCompletion) {
      backgroundColor = SudokuTheme.getCompletionGlow(context);
    } else if (cell.isError) {
      backgroundColor = SudokuTheme.getErrorBg(context);
    } else if (isSelected) {
      backgroundColor = SudokuTheme.getSelectedCellBg(context);
    } else if (isSameNumber) {
      backgroundColor = SudokuTheme.getSameNumberBg(context);
    } else if (isCrosshair) {
      backgroundColor = SudokuTheme.getCrosshairBg(context);
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: isSelected
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2.0,
                )
              : null,
        ),
        child: Center(
          child: cell.value > 0
              ? _buildCellValue(context)
              : _buildCellNotes(context),
        ),
      ),
    );
  }

  Widget _buildCellValue(BuildContext context) {
    Color textColor;
    FontWeight fontWeight;

    if (cell.isError) {
      textColor = SudokuTheme.getErrorColor(context);
      fontWeight = FontWeight.bold;
    } else if (cell.isGiven) {
      textColor = SudokuTheme.getClueColor(context);
      fontWeight = FontWeight.w700;
    } else if (cell.hasHint) {
      textColor = SudokuTheme.getHintColor(context);
      fontWeight = FontWeight.w600;
    } else {
      textColor = SudokuTheme.getUserColor(context);
      fontWeight = FontWeight.w600;
    }

    return Text(
      '${cell.value}',
      style: TextStyle(
        fontSize: 24,
        fontWeight: fontWeight,
        color: textColor,
      ),
    );
  }

  Widget _buildCellNotes(BuildContext context) {
    if (cell.notes.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final fontSize = (constraints.maxHeight / 3.6).clamp(8.0, 13.0);

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(1.0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.0,
          ),
          itemCount: 9,
          itemBuilder: (context, index) {
            final noteDigit = index + 1;
            final hasNote = cell.notes.contains(noteDigit);
            if (!hasNote) return const SizedBox.shrink();

            final isMatchingHighlight = highlightedNumber == noteDigit;

            return Center(
              child: Text(
                '$noteDigit',
                style: TextStyle(
                  fontSize: fontSize,
                  height: 1.0,
                  fontWeight: isMatchingHighlight ? FontWeight.bold : FontWeight.w500,
                  color: isMatchingHighlight
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
