import 'package:flutter/material.dart';
import '../../controllers/sudoku_controller.dart';
import '../../models/game_enums.dart';

class NumberPadWidget extends StatelessWidget {
  final SudokuController controller;

  const NumberPadWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(9, (index) {
          final digit = index + 1;
          final isCompleted = controller.isDigitComplete(digit);
          final remaining = controller.getRemainingCount(digit);
          final isSelectedDigit = controller.highlightedNumber == digit;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: isCompleted ? 0.0 : 1.0,
                child: IgnorePointer(
                  ignoring: isCompleted || controller.status != GameStatus.playing,
                  child: _NumberButton(
                    key: ValueKey('number_btn_$digit'),
                    digit: digit,
                    remaining: remaining,
                    isSelected: isSelectedDigit,
                    onTap: () {
                      if (controller.inputMode == InputMode.digitFirst) {
                        controller.selectDigitForFastPlacement(digit);
                      } else {
                        controller.enterDigit(digit);
                      }
                    },
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NumberButton extends StatelessWidget {
  final int digit;
  final int remaining;
  final bool isSelected;
  final VoidCallback onTap;

  const _NumberButton({
    super.key,
    required this.digit,
    required this.remaining,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Material(
      color: isSelected
          ? primaryColor
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(10.0),
      elevation: isSelected ? 3 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$digit',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$remaining',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? theme.colorScheme.onPrimary.withValues(alpha: 0.8)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
