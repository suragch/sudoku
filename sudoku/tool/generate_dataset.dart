// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:sudoku/engine/puzzle_record.dart';
import 'package:sudoku/engine/sudoku_generator.dart';
import 'package:sudoku/models/game_enums.dart';

class WorkerConfig {
  final SendPort sendPort;
  final int workerId;
  final int seed;

  WorkerConfig({
    required this.sendPort,
    required this.workerId,
    required this.seed,
  });
}

class GeneratedMessage {
  final SudokuPuzzleRecord record;
  GeneratedMessage(this.record);
}

void workerEntryPoint(WorkerConfig config) {
  final random = Random(config.seed);
  final generator = SudokuGenerator(random);

  while (true) {
    // Pick random difficulty with weighted chance to balance generation
    for (final diff in [Difficulty.expert, Difficulty.hard, Difficulty.medium, Difficulty.easy]) {
      final record = generator.generatePuzzleRecord(
        targetDifficulty: diff,
        maxAttempts: 15,
      );
      if (record != null) {
        config.sendPort.send(GeneratedMessage(record));
      }
    }
  }
}

Future<void> main() async {
  print('===============================================================');
  print(' Logic-Based Sudoku Generator & Grading Pipeline: Dataset Export');
  print(' Target: 1,000 Easy, 1,000 Medium, 1,000 Hard, 1,000 Expert');
  print(' Hard Invariants: 100% Unique, 0 Mistakes, Pure Deduction, 180° Symmetry');
  print('===============================================================\n');

  final outputDir = Directory('assets/puzzles');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  final stopwatch = Stopwatch()..start();
  final workerCount = Platform.numberOfProcessors;
  print('Spawning $workerCount parallel worker isolates across CPU cores...');

  final receivePort = ReceivePort();
  final isolates = <Isolate>[];

  final targetPerCategory = 1000;
  final collected = <Difficulty, List<SudokuPuzzleRecord>>{
    Difficulty.easy: [],
    Difficulty.medium: [],
    Difficulty.hard: [],
    Difficulty.expert: [],
  };

  final timeToReach1000 = <Difficulty, int>{};

  final baseSeed = DateTime.now().millisecondsSinceEpoch;
  for (int i = 0; i < workerCount; i++) {
    final isolate = await Isolate.spawn(
      workerEntryPoint,
      WorkerConfig(
        sendPort: receivePort.sendPort,
        workerId: i,
        seed: baseSeed + i * 10007,
      ),
    );
    isolates.add(isolate);
  }

  print('Workers active. Collecting validated puzzles...\n');

  int totalCollected = 0;
  DateTime lastPrint = DateTime.now();

  await for (final msg in receivePort) {
    if (msg is GeneratedMessage) {
      final rec = msg.record;
      final diff = Difficulty.values.firstWhere((d) => d.name == rec.difficulty);
      final list = collected[diff]!;

      if (list.length < targetPerCategory) {
        final id = '${diff.name}_${(list.length + 1).toString().padLeft(4, '0')}';
        final indexedRecord = SudokuPuzzleRecord(
          id: id,
          difficulty: rec.difficulty,
          clueCount: rec.clueCount,
          puzzle: rec.puzzle,
          solution: rec.solution,
          hardestTechnique: rec.hardestTechnique,
          techniquesUsed: rec.techniquesUsed,
        );
        list.add(indexedRecord);
        totalCollected++;

        if (list.length == targetPerCategory) {
          timeToReach1000[diff] = stopwatch.elapsedMilliseconds;
          print('>>> [DONE] ${diff.displayName.toUpperCase()}: 1,000 puzzles generated in ${(timeToReach1000[diff]! / 1000).toStringAsFixed(2)}s');
        }

        final now = DateTime.now();
        if (now.difference(lastPrint).inMilliseconds >= 500 || totalCollected == targetPerCategory * 4) {
          lastPrint = now;
          stdout.write('\rProgress: Easy: ${collected[Difficulty.easy]!.length}/$targetPerCategory | '
              'Medium: ${collected[Difficulty.medium]!.length}/$targetPerCategory | '
              'Hard: ${collected[Difficulty.hard]!.length}/$targetPerCategory | '
              'Expert: ${collected[Difficulty.expert]!.length}/$targetPerCategory | '
              'Total: $totalCollected/4000 (${(totalCollected / 40).toStringAsFixed(1)}%) in ${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s');
        }

        if (totalCollected == targetPerCategory * 4) {
          break;
        }
      }
    }
  }

  print('\n\nGeneration complete! Shutting down worker isolates...');
  for (final iso in isolates) {
    iso.kill(priority: Isolate.immediate);
  }
  receivePort.close();

  final totalElapsed = stopwatch.elapsedMilliseconds;
  print('All 4,000 puzzles generated in ${(totalElapsed / 1000).toStringAsFixed(2)}s!\n');

  // --- Export Deliverables ---
  print('Exporting dataset files to ${outputDir.path}...');

  // 1. Export category JSONs
  for (final diff in Difficulty.values) {
    final file = File('${outputDir.path}/${diff.name}.json');
    final jsonList = collected[diff]!.map((r) => r.toJson()).toList();
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(jsonList));
    print('  - Saved ${file.path} (${collected[diff]!.length} puzzles)');
  }

  // 2. Export combined JSON
  final allPuzzles = <SudokuPuzzleRecord>[
    ...collected[Difficulty.easy]!,
    ...collected[Difficulty.medium]!,
    ...collected[Difficulty.hard]!,
    ...collected[Difficulty.expert]!,
  ];
  final combinedFile = File('${outputDir.path}/puzzles.json');
  final allJsonList = allPuzzles.map((r) => r.toJson()).toList();
  combinedFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(allJsonList));
  print('  - Saved ${combinedFile.path} (4,000 puzzles combined)');

  // 3. Export SQLite SQL Script and Database
  final sqlFile = File('${outputDir.path}/puzzles.sql');
  final sqlBuffer = StringBuffer();
  sqlBuffer.writeln('-- Sudoku Puzzles SQLite Export');
  sqlBuffer.writeln('PRAGMA synchronous = OFF;');
  sqlBuffer.writeln('PRAGMA journal_mode = MEMORY;');
  sqlBuffer.writeln('BEGIN TRANSACTION;');
  sqlBuffer.writeln('DROP TABLE IF EXISTS puzzles;');
  sqlBuffer.writeln('''
CREATE TABLE puzzles (
  id TEXT PRIMARY KEY,
  difficulty TEXT NOT NULL,
  clue_count INTEGER NOT NULL,
  puzzle TEXT NOT NULL,
  solution TEXT NOT NULL,
  hardest_technique TEXT NOT NULL,
  techniques_used TEXT NOT NULL
);
''');

  for (final p in allPuzzles) {
    sqlBuffer.writeln(p.toSqlInsert());
  }

  sqlBuffer.writeln('CREATE INDEX idx_puzzles_difficulty ON puzzles(difficulty);');
  sqlBuffer.writeln('CREATE INDEX idx_puzzles_clue_count ON puzzles(clue_count);');
  sqlBuffer.writeln('CREATE INDEX idx_puzzles_hardest_technique ON puzzles(hardest_technique);');
  sqlBuffer.writeln('COMMIT;');

  sqlFile.writeAsStringSync(sqlBuffer.toString());
  print('  - Saved ${sqlFile.path} (SQL schema & inserts)');

  // Build SQLite database via sqlite3 CLI
  final dbFile = File('${outputDir.path}/puzzles.db');
  if (dbFile.existsSync()) dbFile.deleteSync();
  final sqliteResult = Process.runSync('/bin/sh', ['-c', 'sqlite3 ${dbFile.path} < ${sqlFile.path}']);
  if (sqliteResult.exitCode == 0) {
    print('  - Built SQLite database: ${dbFile.path}');
  } else {
    print('  - Warning: Failed to run sqlite3 CLI: ${sqliteResult.stderr}');
  }

  // --- Statistical Summary Report ---
  print('\n===============================================================');
  print('                   STATISTICAL SUMMARY REPORT                  ');
  print('===============================================================');
  print('Total Generation Time: ${(totalElapsed / 1000).toStringAsFixed(2)}s');
  print('Overall Throughput: ${(4000 / (totalElapsed / 1000)).toStringAsFixed(1)} puzzles/sec\n');

  for (final diff in Difficulty.values) {
    final list = collected[diff]!;
    final clueCounts = list.map((p) => p.clueCount).toList();
    final minClues = clueCounts.reduce(min);
    final maxClues = clueCounts.reduce(max);
    final avgClues = clueCounts.reduce((a, b) => a + b) / clueCounts.length;
    final timeMs = timeToReach1000[diff] ?? totalElapsed;

    final techDist = <String, int>{};
    final hardestDist = <String, int>{};
    for (final p in list) {
      hardestDist[p.hardestTechnique] = (hardestDist[p.hardestTechnique] ?? 0) + 1;
      for (final t in p.techniquesUsed.keys) {
        techDist[t] = (techDist[t] ?? 0) + p.techniquesUsed[t]!;
      }
    }

    print('Category: ${diff.displayName.toUpperCase()} (1,000 puzzles)');
    print('  - Time to Generate: ${(timeMs / 1000).toStringAsFixed(2)}s');
    print('  - Clue Count: min=$minClues, max=$maxClues, avg=${avgClues.toStringAsFixed(2)}');
    print('  - Hardest Technique Distribution:');
    hardestDist.forEach((k, v) => print('      * $k: $v (${(v / 10).toStringAsFixed(1)}%)'));
    print('  - Total Invocations Across Puzzles:');
    techDist.forEach((k, v) => print('      * $k: $v (avg ${(v / 1000).toStringAsFixed(1)}/puzzle)'));
    print('');
  }
}
