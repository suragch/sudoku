import 'package:flutter/material.dart';
import '../../controllers/sudoku_controller.dart';
import '../../models/game_enums.dart';

class HeaderBarWidget extends StatelessWidget {
  final SudokuController controller;
  final VoidCallback onSelectDifficulty;
  final VoidCallback onShowStats;

  const HeaderBarWidget({
    super.key,
    required this.controller,
    required this.onSelectDifficulty,
    required this.onShowStats,
  });

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPaused = controller.status == GameStatus.paused;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Difficulty Selector Button
          ActionChip(
            avatar: const Icon(Icons.tune_rounded, size: 16),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  controller.difficulty.displayName.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_drop_down_rounded, size: 18),
              ],
            ),
            tooltip: 'Change Difficulty / New Game',
            onPressed: onSelectDifficulty,
          ),

          // Mistakes Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: controller.mistakes > 0
                  ? theme.colorScheme.errorContainer.withValues(alpha: 0.4)
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: controller.mistakes > 0
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'Mistakes: ${controller.mistakes}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: controller.mistakes > 0
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Timer & Pause/Resume
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(controller.elapsedSeconds),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: theme.colorScheme.primary,
                ),
                tooltip: isPaused ? 'Resume' : 'Pause',
                onPressed: controller.togglePause,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
