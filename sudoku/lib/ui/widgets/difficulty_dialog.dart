import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/game_enums.dart';

/// A modern, logically graded difficulty chooser dialog using the app's standard theme.
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
    final primaryColor = theme.colorScheme.primary;

    return AlertDialog(
      scrollable: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      actionsPadding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
      title: Row(
        children: [
          Icon(
            Icons.tune_rounded,
            color: primaryColor,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Difficulty',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Graded by deductive solving techniques',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.normal,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...Difficulty.values.map((difficulty) {
              final isSelected = difficulty == currentDifficulty;
              final isLast = difficulty == Difficulty.values.last;

              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 8.0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: ValueKey('difficulty_option_${difficulty.name}'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop();
                      onDifficultySelected(difficulty);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isSelected
                            ? primaryColor.withValues(alpha: isDark ? 0.18 : 0.08)
                            : (isDark
                                ? const Color(0xFF0F172A).withValues(alpha: 0.6)
                                : const Color(0xFFF1F5F9).withValues(alpha: 0.8)),
                        border: Border.all(
                          color: isSelected
                              ? primaryColor
                              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                          width: isSelected ? 1.8 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                            color: isSelected ? primaryColor : theme.colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      difficulty.displayName,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? primaryColor : null,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (isSelected)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: primaryColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'ACTIVE',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: primaryColor,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  difficulty.techniquesSummary,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? const Color(0xFFCBD5E1)
                                        : const Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  difficulty.description,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    height: 1.2,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
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
