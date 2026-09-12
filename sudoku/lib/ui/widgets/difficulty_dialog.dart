import 'package:flutter/material.dart';
import '../../models/game_enums.dart';

class DifficultyDialog extends StatelessWidget {
  final Difficulty currentDifficulty;
  final ValueChanged<Difficulty> onDifficultySelected;
  final VoidCallback onRestartCurrent;

  const DifficultyDialog({
    super.key,
    required this.currentDifficulty,
    required this.onDifficultySelected,
    required this.onRestartCurrent,
  });

  static Future<void> show({
    required BuildContext context,
    required Difficulty currentDifficulty,
    required ValueChanged<Difficulty> onDifficultySelected,
    required VoidCallback onRestartCurrent,
  }) {
    return showDialog(
      context: context,
      builder: (context) => DifficultyDialog(
        currentDifficulty: currentDifficulty,
        onDifficultySelected: onDifficultySelected,
        onRestartCurrent: onRestartCurrent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.tune_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Select Difficulty'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...Difficulty.values.map((difficulty) {
            final isSelected = difficulty == currentDifficulty;
            return ListTile(
              title: Text(
                difficulty.displayName,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text('${difficulty.clueTarget} starting clues'),
              leading: Icon(
                isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              selected: isSelected,
              onTap: () {
                Navigator.of(context).pop();
                onDifficultySelected(difficulty);
              },
            );
          }),
          const Divider(height: 24),
          ListTile(
            leading: Icon(Icons.refresh_rounded, color: theme.colorScheme.secondary),
            title: const Text('Restart Current Puzzle'),
            subtitle: const Text('Clear all entered numbers'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onTap: () {
              Navigator.of(context).pop();
              onRestartCurrent();
            },
          ),
        ],
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
