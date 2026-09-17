import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/game_enums.dart';

/// A clean difficulty chooser dialog that lets the user select a difficulty level.
class DifficultyDialog extends StatelessWidget {
  final Difficulty currentDifficulty;
  final ValueChanged<Difficulty> onDifficultySelected;

  const DifficultyDialog({
    super.key,
    required this.currentDifficulty,
    required this.onDifficultySelected,
  });

  static Future<void> show({
    required BuildContext context,
    required Difficulty currentDifficulty,
    required ValueChanged<Difficulty> onDifficultySelected,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => DifficultyDialog(
        currentDifficulty: currentDifficulty,
        onDifficultySelected: onDifficultySelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.tune_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          const Text('Select Difficulty'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: Difficulty.values.map((difficulty) {
          final isSelected = difficulty == currentDifficulty;
          return ListTile(
            key: ValueKey('difficulty_option_${difficulty.name}'),
            title: Text(
              difficulty.displayName,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? theme.colorScheme.primary : null,
              ),
            ),
            leading: Icon(
              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            selected: isSelected,
            selectedTileColor: theme.colorScheme.primary.withValues(
              alpha: isDark ? 0.18 : 0.08,
            ),
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).pop();
              onDifficultySelected(difficulty);
            },
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
