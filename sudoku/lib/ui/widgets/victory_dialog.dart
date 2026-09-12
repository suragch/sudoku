import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/game_enums.dart';

class VictoryDialog extends StatefulWidget {
  final Difficulty difficulty;
  final int elapsedSeconds;
  final int mistakes;
  final int hintsUsed;
  final bool isNewBest;
  final VoidCallback onPlayAgain;
  final VoidCallback? onViewStats;

  const VictoryDialog({
    super.key,
    required this.difficulty,
    required this.elapsedSeconds,
    required this.mistakes,
    required this.hintsUsed,
    required this.isNewBest,
    required this.onPlayAgain,
    this.onViewStats,
  });

  static Future<void> show({
    required BuildContext context,
    required Difficulty difficulty,
    required int elapsedSeconds,
    required int mistakes,
    required int hintsUsed,
    required bool isNewBest,
    required VoidCallback onPlayAgain,
    VoidCallback? onViewStats,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => VictoryDialog(
        difficulty: difficulty,
        elapsedSeconds: elapsedSeconds,
        mistakes: mistakes,
        hintsUsed: hintsUsed,
        isNewBest: isNewBest,
        onPlayAgain: onPlayAgain,
        onViewStats: onViewStats,
      ),
    );
  }

  @override
  State<VictoryDialog> createState() => _VictoryDialogState();
}

class _VictoryDialogState extends State<VictoryDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Confetti background
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AnimatedBuilder(
                animation: _confettiController,
                builder: (context, _) => CustomPaint(
                  painter: _ConfettiPainter(_confettiController.value),
                ),
              ),
            ),
          ),

          // Close button at top-right
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Close and view board',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    size: 52,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Puzzle Solved!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.difficulty.displayName,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),

                if (widget.isNewBest)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade400,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'NEW BEST TIME!',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Stat Cards
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatColumn(
                        label: 'Time',
                        value: _formatTime(widget.elapsedSeconds),
                      ),
                      _StatColumn(
                        label: 'Mistakes',
                        value: '${widget.mistakes}',
                      ),
                      _StatColumn(
                        label: 'Hints',
                        value: '${widget.hintsUsed}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Primary Play Again Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onPlayAgain();
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Play Again'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Secondary Action Row: View Stats & Close (View Board)
                Row(
                  children: [
                    if (widget.onViewStats != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onViewStats!();
                          },
                          icon: const Icon(Icons.leaderboard_outlined, size: 18),
                          label: const Text('View Stats'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    if (widget.onViewStats != null) const SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;

  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  static final List<Point<double>> _points = List.generate(40, (i) {
    final r = Random(i);
    return Point(r.nextDouble(), r.nextDouble());
  });
  static final List<Color> _colors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.amber,
    Colors.purple,
    Colors.orange,
    Colors.teal,
  ];

  _ConfettiPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < _points.length; i++) {
      final initialPt = _points[i];
      final color = _colors[i % _colors.length];
      paint.color = color.withValues(alpha: 0.6);

      final y = ((initialPt.y + progress) % 1.0) * size.height;
      final x = (initialPt.x + sin(progress * 2 * pi + i) * 0.05) * size.width;

      canvas.drawCircle(Offset(x, y), 3.5, paint);
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => true;
}
