import 'package:flutter/material.dart';
import 'controllers/sudoku_controller.dart';
import 'services/puzzle_database_service.dart';
import 'services/storage_service.dart';
import 'ui/pages/sudoku_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storageService = await StorageService.init();
  final databaseService = await PuzzleDatabaseService.init();
  final controller = SudokuController(
    storageService: storageService,
    databaseService: databaseService,
  );

  runApp(SudokuApp(controller: controller));
}

class SudokuApp extends StatelessWidget {
  final SudokuController controller;

  const SudokuApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sudoku',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
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
      home: SudokuPage(controller: controller),
    );
  }
}
