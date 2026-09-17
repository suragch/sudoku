import 'package:flutter/material.dart';
import '../../models/game_enums.dart';
import '../../models/game_stats.dart';

class StatsDialog extends StatelessWidget {
  final GameStats stats;

  const StatsDialog({super.key, required this.stats});

  static Future<void> show(BuildContext context, GameStats stats) {
    return showDialog(
      context: context,
      builder: (context) => StatsDialog(stats: stats),
    );
  }

  String _formatTime(int? seconds) {
    if (seconds == null || seconds <= 0) return '--:--';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.leaderboard_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Statistics'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: Difficulty.values.map((difficulty) {
            final stat = stats.forDifficulty(difficulty);

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          difficulty.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            difficulty.logicalTier,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatItem(label: 'Played', value: '${stat.gamesStarted}'),
                        _StatItem(label: 'Won', value: '${stat.gamesWon}'),
                        _StatItem(
                          label: 'Win Rate',
                          value: '${stat.winRate.toStringAsFixed(0)}%',
                        ),
                        _StatItem(
                          label: 'Best Time',
                          value: _formatTime(stat.bestTimeSeconds),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
