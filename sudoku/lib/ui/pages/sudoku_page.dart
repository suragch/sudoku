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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
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
                icon: const Icon(Icons.add_rounded),
                tooltip: 'New Game',
                onPressed: _openDifficultySelector,
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

                    // Number Pad (1-9 with disappearing completed digits)
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
