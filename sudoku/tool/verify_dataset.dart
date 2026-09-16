// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:sudoku/engine/deductive_grader.dart';
import 'package:sudoku/engine/puzzle_record.dart';
import 'package:sudoku/engine/sudoku_solver.dart';
import 'package:sudoku/models/game_enums.dart';

void main() {
  print('===============================================================');
  print('        AUTOMATED AUDIT & VERIFICATION TEST SUITE              ');
  print('===============================================================\n');

  final pFile = File('assets/puzzles/puzzles.json');
  if (!pFile.existsSync()) {
    print('Error: assets/puzzles/puzzles.json not found! Run tool/generate_dataset.dart first.');
    exit(1);
  }

  final rawJson = jsonDecode(pFile.readAsStringSync()) as List;
  print('Loaded ${rawJson.length} puzzle records from ${pFile.path}.\n');

  int totalPuzzles = rawJson.length;
  int uniquePass = 0;
  int gradePass = 0;
  int symmetryPass = 0;
  int schemaPass = 0;
  int floorPass = 0;
  int ceilingPass = 0;

  final categoryCounts = <String, int>{};
  final sw = Stopwatch()..start();

  for (int i = 0; i < totalPuzzles; i++) {
    final map = rawJson[i] as Map<String, dynamic>;
    final record = SudokuPuzzleRecord.fromJson(map);
    categoryCounts[record.difficulty] = (categoryCounts[record.difficulty] ?? 0) + 1;

    // 1. Schema Check
    if (record.id.isNotEmpty &&
        record.difficulty.isNotEmpty &&
        record.clueCount >= 17 &&
        record.puzzle.length == 81 &&
        record.solution.length == 81 &&
        record.hardestTechnique.isNotEmpty &&
        record.techniquesUsed.isNotEmpty) {
      schemaPass++;
    } else {
      print('FAILED Schema check on puzzle ${record.id}');
    }

    // 2. Symmetry Check (180° rotational symmetry)
    bool isSymmetric = true;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final idx1 = r * 9 + c;
        final idx2 = (8 - r) * 9 + (8 - c);
        final ch1 = record.puzzle[idx1];
        final ch2 = record.puzzle[idx2];
        final isClue1 = ch1 != '.' && ch1 != '0';
        final isClue2 = ch2 != '.' && ch2 != '0';
        if (isClue1 != isClue2) {
          isSymmetric = false;
          break;
        }
      }
      if (!isSymmetric) break;
    }
    if (isSymmetric) {
      symmetryPass++;
    } else {
      print('FAILED 180° Symmetry check on puzzle ${record.id}');
    }

    // 3. Uniqueness Audit
    final solCount = SudokuSolver.countSolutionsString(record.puzzle, maxCount: 2);
    if (solCount == 1) {
      uniquePass++;
    } else {
      print('FAILED Uniqueness check on puzzle ${record.id}: solutions count = $solCount');
    }

    // 4. Grade Consistency Audit (Independent re-solve)
    final grade = DeductiveGrader.gradePuzzle(record.puzzle);
    if (grade.isSolved && grade.difficulty?.name == record.difficulty) {
      gradePass++;
    } else {
      print('FAILED Grade consistency on puzzle ${record.id}: expected ${record.difficulty}, got ${grade.difficulty?.name}, solved=${grade.isSolved}');
    }

    // Check Floor and Ceiling Invariants
    final diff = Difficulty.values.firstWhere((d) => d.name == record.difficulty);
    final techNames = record.techniquesUsed.keys.toSet();

    const mediumTechniques = {
      'pointing_pair',
      'box_line_reduction',
      'naked_pair',
      'hidden_pair',
      'naked_triple',
      'hidden_triple'
    };
    const hardTechniques = {
      'naked_quad',
      'hidden_quad',
      'x_wing',
      'swordfish',
      'skyscraper',
      'two_string_kite'
    };
    const expertTechniques = {
      'unique_rectangle',
      'xy_wing',
      'xyz_wing',
      'w_wing',
      'simple_aic'
    };

    bool floorMet = false;
    bool ceilingMet = false;

    switch (diff) {
      case Difficulty.easy:
        floorMet = techNames.contains('naked_single') || techNames.contains('hidden_single');
        ceilingMet = !techNames.any((t) => mediumTechniques.contains(t) || hardTechniques.contains(t) || expertTechniques.contains(t));
      case Difficulty.medium:
        floorMet = techNames.any((t) => mediumTechniques.contains(t));
        ceilingMet = !techNames.any((t) => hardTechniques.contains(t) || expertTechniques.contains(t));
      case Difficulty.hard:
        floorMet = techNames.any((t) => hardTechniques.contains(t));
        ceilingMet = !techNames.any((t) => expertTechniques.contains(t));
      case Difficulty.expert:
        floorMet = techNames.any((t) => expertTechniques.contains(t));
        ceilingMet = grade.isSolved; // Solvable without guessing
    }

    if (floorMet) {
      floorPass++;
    } else {
      print('FAILED Floor invariant on ${record.id} ($diff): no required tier technique found');
    }

    if (ceilingMet) {
      ceilingPass++;
    } else {
      print('FAILED Ceiling invariant on ${record.id} ($diff): exceeded difficulty boundary');
    }

    if ((i + 1) % 500 == 0 || i == totalPuzzles - 1) {
      stdout.write('\rAudited ${i + 1}/$totalPuzzles puzzles (${((i + 1) / totalPuzzles * 100).toStringAsFixed(1)}%)...');
    }
  }

  final elapsed = sw.elapsedMilliseconds;
  print('\n\n===============================================================');
  print('                    AUDIT RESULTS SUMMARY                      ');
  print('===============================================================');
  print('Total Puzzles Audited: $totalPuzzles across categories: $categoryCounts');
  print('Verification Duration: ${(elapsed / 1000).toStringAsFixed(2)}s (${(totalPuzzles / (elapsed / 1000)).toStringAsFixed(1)} puzzles/sec)\n');

  print('1. Schema Validation:      $schemaPass / $totalPuzzles (${(schemaPass / totalPuzzles * 100).toStringAsFixed(1)}%)');
  print('2. 180° Symmetry Audit:    $symmetryPass / $totalPuzzles (${(symmetryPass / totalPuzzles * 100).toStringAsFixed(1)}%)');
  print('3. Strict Uniqueness:      $uniquePass / $totalPuzzles (${(uniquePass / totalPuzzles * 100).toStringAsFixed(1)}%)');
  print('4. Grade Match Audit:      $gradePass / $totalPuzzles (${(gradePass / totalPuzzles * 100).toStringAsFixed(1)}%)');
  print('5. Floor Boundary Check:   $floorPass / $totalPuzzles (${(floorPass / totalPuzzles * 100).toStringAsFixed(1)}%)');
  print('6. Ceiling Boundary Check: $ceilingPass / $totalPuzzles (${(ceilingPass / totalPuzzles * 100).toStringAsFixed(1)}%)\n');

  if (schemaPass == totalPuzzles &&
      symmetryPass == totalPuzzles &&
      uniquePass == totalPuzzles &&
      gradePass == totalPuzzles &&
      floorPass == totalPuzzles &&
      ceilingPass == totalPuzzles) {
    print('>>> ALL 6 AUDIT INVARIANTS PASSED WITH 100% SUCCESS RATE! <<<');
  } else {
    print('>>> AUDIT FAILED! Review errors above. <<<');
    exit(1);
  }
}
