import 'dart:async';

import 'package:flutter/material.dart';

import 'controllers/sudoku_controller.dart';
import 'models/game_enums.dart';
import 'services/puzzle_database_service.dart';
import 'ui/pages/sudoku_page.dart';
import 'ui/widgets/victory_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PuzzleDatabaseService.init();
  runApp(const ScreenshotApp());
}

class ScreenshotApp extends StatefulWidget {
  const ScreenshotApp({super.key});

  @override
  State<ScreenshotApp> createState() => _ScreenshotAppState();
}

class _ScreenshotAppState extends State<ScreenshotApp> {
  int _currentStep = 1;
  Timer? _stepTimer;
  late final List<SudokuController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = [
      _buildStep1Controller(),
      _buildStep2Controller(),
      _buildStep3Controller(),
      _buildStep4Controller(),
      _buildStep5Controller(),
    ];
    _startAutoAdvance();
  }

  void _startAutoAdvance() {
    // Advance screen every 4.0 seconds
    _stepTimer = Timer.periodic(const Duration(milliseconds: 4000), (timer) {
      if (_currentStep < 5) {
        setState(() {
          _currentStep++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  // Step 1: Active Game with '5' selected and highlighted across board
  SudokuController _buildStep1Controller() {
    final controller = SudokuController();
    // Find a cell with value 5 and select it
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (controller.board.cellAt(r, c).value == 5) {
          controller.selectCell(r, c);
          return controller;
        }
      }
    }
    return controller;
  }

  // Step 2: Pencil Notes mode with candidate notes
  SudokuController _buildStep2Controller() {
    final controller = SudokuController();
    controller.toggleNoteMode();

    // Populate several cells with candidate notes
    int count = 0;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final cell = controller.board.cellAt(r, c);
        if (cell.isEmpty) {
          if (count == 0) {
            cell.notes.addAll({2, 4, 8});
            controller.selectCell(r, c);
          } else if (count == 1) {
            cell.notes.addAll({1, 7});
          } else if (count == 2) {
            cell.notes.addAll({3, 6, 9});
          } else if (count == 3) {
            cell.notes.addAll({4, 8});
          }
          count++;
          if (count >= 4) break;
        }
      }
      if (count >= 4) break;
    }
    return controller;
  }

  // Step 3: Row completion celebration & completed numbers disappeared
  SudokuController _buildStep3Controller() {
    final controller = SudokuController();
    // Complete row 0 with solution values
    for (int c = 0; c < 9; c++) {
      final cell = controller.board.cellAt(0, c);
      cell.value = cell.solutionValue;
    }
    controller.animatingRows.add(0);
    controller.selectCell(0, 2);

    // Complete all 9 instances of digit 1 so digit 1 disappears from number pad
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final cell = controller.board.cellAt(r, c);
        if (cell.solutionValue == 1) {
          cell.value = 1;
        }
      }
    }
    return controller;
  }

  // Step 4: Solved board with Victory Celebration Dialog
  SudokuController _buildStep4Controller() {
    final controller = SudokuController();
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final cell = controller.board.cellAt(r, c);
        cell.value = cell.solutionValue;
      }
    }
    return controller;
  }

  // Step 5: Dark mode active game
  SudokuController _buildStep5Controller() {
    final controller = SudokuController();
    // Select cell with value 3
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (controller.board.cellAt(r, c).value == 3) {
          controller.selectCell(r, c);
          return controller;
        }
      }
    }
    return controller;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _currentStep == 5;
    final controller = _controllers[_currentStep - 1];

    return MaterialApp(
      title: 'Sudoku App Store Capture',
      debugShowCheckedModeBanner: false,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8FAFC),
          scrolledUnderElevation: 0,
          elevation: 0,
          centerTitle: false,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          scrolledUnderElevation: 0,
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: _currentStep == 4
          ? Scaffold(
              body: Stack(
                children: [
                  SudokuPage(controller: controller),
                  Positioned.fill(
                    child: Container(
                      color: Colors.black54,
                      child: VictoryDialog(
                        difficulty: Difficulty.easy,
                        elapsedSeconds: 274, // 04:34
                        mistakes: 0,
                        hintsUsed: 0,
                        isNewBest: true,
                        onPlayAgain: () {},
                        onViewStats: () {},
                      ),
                    ),
                  ),
                ],
              ),
            )
          : SudokuPage(controller: controller),
    );
  }
}
