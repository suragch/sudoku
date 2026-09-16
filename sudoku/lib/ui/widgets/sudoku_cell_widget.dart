import 'package:flutter/material.dart';
import '../../models/sudoku_cell.dart';
import '../theme/sudoku_theme.dart';

class SudokuCellWidget extends StatelessWidget {
  final SudokuCell cell;
  final bool isSelected;
  final bool isSameNumber;
  final bool isCrosshair;
  final bool isAnimatingCompletion;
  final bool isHintTarget;
  final bool isHintCause;
  final int highlightedNumber;
  final VoidCallback onTap;
  final double? cellSize;

  const SudokuCellWidget({
    super.key,
    required this.cell,
    required this.isSelected,
    required this.isSameNumber,
    required this.isCrosshair,
    required this.isAnimatingCompletion,
    this.isHintTarget = false,
    this.isHintCause = false,
    required this.highlightedNumber,
    required this.onTap,
    this.cellSize,
  });

  @override
  Widget build(BuildContext context) {
    Color? backgroundColor;
    Border? border;

    if (isAnimatingCompletion) {
      backgroundColor = SudokuTheme.getCompletionGlow(context);
    } else if (cell.isError) {
      backgroundColor = SudokuTheme.getErrorBg(context);
    } else if (isHintTarget) {
      backgroundColor = SudokuTheme.getHintTargetBg(context);
    } else if (isHintCause) {
      backgroundColor = SudokuTheme.getHintCauseBg(context);
    } else if (isSelected) {
      backgroundColor = SudokuTheme.getSelectedCellBg(context);
    } else if (isSameNumber) {
      backgroundColor = SudokuTheme.getSameNumberBg(context);
    } else if (isCrosshair) {
      backgroundColor = SudokuTheme.getCrosshairBg(context);
    }

    if (isHintTarget) {
      border = Border.all(
        color: SudokuTheme.getHintTargetBorder(context),
        width: 2.5,
      );
    } else if (isHintCause) {
      border = Border.all(
        color: SudokuTheme.getHintCauseBorder(context),
        width: 2.0,
      );
    } else if (isSelected) {
      border = Border.all(
        color: cell.isError
            ? SudokuTheme.getErrorColor(context)
            : Theme.of(context).colorScheme.primary,
        width: 2.0,
      );
    }

    Widget buildContent(double effectiveSize) {
      return Center(
        child: cell.value > 0
            ? _buildCellValue(context, effectiveSize)
            : _buildCellNotes(context, effectiveSize),
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: border,
        ),
        child: cellSize != null
            ? buildContent(cellSize!)
            : LayoutBuilder(
                builder: (context, constraints) => buildContent(constraints.maxHeight),
              ),
      ),
    );
  }

  Widget _buildCellValue(BuildContext context, double size) {
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

    // Dynamically scale font size with cell size (default ~24px for 40px cell)
    final fontSize = (size * 0.58).clamp(10.0, 36.0);

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        '${cell.value}',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildCellNotes(BuildContext context, double size) {
    if (cell.notes.isEmpty) {
      return const SizedBox.shrink();
    }

    final fontSize = (size / 3.8).clamp(6.0, 13.0);

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
          child: FittedBox(
            fit: BoxFit.scaleDown,
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
          ),
        );
      },
    );
  }
}
