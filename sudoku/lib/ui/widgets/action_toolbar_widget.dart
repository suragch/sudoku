import 'package:flutter/material.dart';
import '../../controllers/sudoku_controller.dart';
import '../../models/game_enums.dart';

class ActionToolbarWidget extends StatelessWidget {
  final SudokuController controller;

  const ActionToolbarWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final isPlaying = controller.status == GameStatus.playing;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Undo
          _ToolbarButton(
            icon: Icons.undo_rounded,
            label: 'Undo',
            isEnabled: isPlaying && controller.canUndo,
            onTap: controller.undo,
          ),

          // Erase
          _ToolbarButton(
            icon: Icons.backspace_outlined,
            label: 'Erase',
            isEnabled: isPlaying &&
                controller.selectedCell != null &&
                !controller.selectedCell!.isGiven &&
                (controller.selectedCell!.value > 0 ||
                    controller.selectedCell!.notes.isNotEmpty),
            onTap: controller.erase,
          ),

          // Notes Mode (Pencil)
          _ToolbarButton(
            icon: controller.isNoteMode ? Icons.edit_rounded : Icons.edit_outlined,
            label: 'Notes',
            isActive: controller.isNoteMode,
            isEnabled: isPlaying,
            onTap: controller.toggleNoteMode,
            badgeText: controller.isNoteMode ? 'ON' : 'OFF',
          ),

          // Hint
          _ToolbarButton(
            icon: Icons.lightbulb_outline_rounded,
            label: 'Hint',
            isEnabled: isPlaying,
            onTap: controller.giveHint,
            badgeText: controller.hintsUsed > 0 ? '${controller.hintsUsed}' : null,
          ),

          // Fast Mode (Digit-first)
          _ToolbarButton(
            icon: controller.inputMode == InputMode.digitFirst
                ? Icons.flash_on_rounded
                : Icons.flash_off_rounded,
            label: 'Fast Fill',
            isActive: controller.inputMode == InputMode.digitFirst,
            isEnabled: isPlaying,
            onTap: () {
              controller.setInputMode(
                controller.inputMode == InputMode.digitFirst
                    ? InputMode.cellFirst
                    : InputMode.digitFirst,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isEnabled;
  final bool isActive;
  final VoidCallback onTap;
  final String? badgeText;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    this.isEnabled = true,
    this.isActive = false,
    required this.onTap,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive
        ? theme.colorScheme.primary
        : (isEnabled
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurface.withValues(alpha: 0.35));

    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(12.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: isActive
                        ? theme.colorScheme.primaryContainer
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                if (badgeText != null)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isActive
                            ? theme.colorScheme.primary
                            : theme.colorScheme.secondary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeText!,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
