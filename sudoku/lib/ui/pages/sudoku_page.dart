import 'package:flutter/material.dart';
import '../../controllers/sudoku_controller.dart';
import '../../models/game_enums.dart';
import '../widgets/action_toolbar_widget.dart';
import '../widgets/difficulty_dialog.dart';
import '../widgets/header_bar_widget.dart';
import '../widgets/number_pad_widget.dart';
import '../widgets/stats_dialog.dart';
import '../widgets/sudoku_grid_widget.dart';
import '../widgets/victory_dialog.dart';

class SudokuPage extends StatefulWidget {
  final SudokuController controller;

  const SudokuPage({super.key, required this.controller});

  @override
  State<SudokuPage> createState() => _SudokuPageState();
}

class _SudokuPageState extends State<SudokuPage> {
  bool _hasShownVictoryDialog = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerUpdate);
    super.dispose();
  }

  void _handleControllerUpdate() {
    if (widget.controller.status == GameStatus.completed &&
        !_hasShownVictoryDialog) {
      _hasShownVictoryDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showVictory();
      });
    } else if (widget.controller.status != GameStatus.completed) {
      _hasShownVictoryDialog = false;
    }
  }

  void _showVictory() {
    VictoryDialog.show(
      context: context,
      difficulty: widget.controller.difficulty,
      elapsedSeconds: widget.controller.elapsedSeconds,
      mistakes: widget.controller.mistakes,
      hintsUsed: widget.controller.hintsUsed,
      isNewBest: widget.controller.isNewBestTime,
      onPlayAgain: () {
        _hasShownVictoryDialog = false;
        widget.controller.startNewGame(widget.controller.difficulty);
      },
      onViewStats: _openStats,
    );
  }

  void _openDifficultySelector() {
    DifficultyDialog.show(
      context: context,
      currentDifficulty: widget.controller.difficulty,
      onDifficultySelected: (difficulty) {
        widget.controller.startNewGame(difficulty);
      },
      onRestartCurrent: () {
        widget.controller.restartCurrentGame();
      },
    );
  }

  void _openStats() {
    StatsDialog.show(context, widget.controller.stats);
  }

  void _confirmRestartCurrent() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart Puzzle?'),
        content: const Text(
          'This will clear all entered numbers and restart the timer for this puzzle.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.controller.restartCurrentGame();
            },
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final isCompleted = widget.controller.status == GameStatus.completed;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Sudoku',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.leaderboard_outlined),
                tooltip: 'Statistics',
                onPressed: _openStats,
              ),
              IconButton(
                icon: const Icon(Icons.restart_alt_rounded),
                tooltip: 'Restart Puzzle',
                onPressed: _confirmRestartCurrent,
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  children: [
                    // Header Bar (Difficulty, Mistakes, Timer)
                    HeaderBarWidget(
                      controller: widget.controller,
                      onSelectDifficulty: _openDifficultySelector,
                      onShowStats: _openStats,
                    ),

                    // Sudoku Grid (9x9) fitted dynamically to remaining height
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        child: Center(
                          child: SudokuGridWidget(controller: widget.controller),
                        ),
                      ),
                    ),

                    // Action Toolbar (Undo, Erase, Notes, Hint, Fast Fill)
                    ActionToolbarWidget(controller: widget.controller),

                    const SizedBox(height: 4),

                    // Number Pad or Solved Summary Card
                    if (isCompleted)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                        child: Card(
                          elevation: 0,
                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                            child: Row(
                              children: [
                                const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 30),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Puzzle Solved!',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      Text(
                                        'Time: ${_formatTime(widget.controller.elapsedSeconds)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                OutlinedButton(
                                  onPressed: _openStats,
                                  child: const Text('Stats'),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: _openDifficultySelector,
                                  child: const Text('New Game'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      NumberPadWidget(controller: widget.controller),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
