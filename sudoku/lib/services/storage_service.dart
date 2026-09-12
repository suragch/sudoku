import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_enums.dart';
import '../models/game_stats.dart';
import '../models/sudoku_board.dart';

class SavedGameState {
  final SudokuBoard board;
  final Difficulty difficulty;
  final int elapsedSeconds;
  final int mistakes;
  final int hintsUsed;
  final GameStatus status;

  SavedGameState({
    required this.board,
    required this.difficulty,
    required this.elapsedSeconds,
    required this.mistakes,
    required this.hintsUsed,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
        'board': board.toJson(),
        'difficulty': difficulty.name,
        'elapsedSeconds': elapsedSeconds,
        'mistakes': mistakes,
        'hintsUsed': hintsUsed,
        'status': status.name,
      };

  factory SavedGameState.fromJson(Map<String, dynamic> json) => SavedGameState(
        board: SudokuBoard.fromJson(json['board'] as Map<String, dynamic>),
        difficulty: Difficulty.values.byName(json['difficulty'] as String),
        elapsedSeconds: json['elapsedSeconds'] as int? ?? 0,
        mistakes: json['mistakes'] as int? ?? 0,
        hintsUsed: json['hintsUsed'] as int? ?? 0,
        status: GameStatus.values.byName(json['status'] as String? ?? 'playing'),
      );
}

class StorageService {
  static const String _keyActiveGame = 'sudoku_active_game';
  static const String _keyStats = 'sudoku_game_stats';
  static const String _keyHaptics = 'sudoku_haptics_enabled';
  static const String _keyHighlightSame = 'sudoku_highlight_same_enabled';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // Active Game State
  Future<void> saveActiveGame(SavedGameState state) async {
    final raw = jsonEncode(state.toJson());
    await _prefs.setString(_keyActiveGame, raw);
  }

  SavedGameState? loadActiveGame() {
    final raw = _prefs.getString(_keyActiveGame);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return SavedGameState.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearActiveGame() async {
    await _prefs.remove(_keyActiveGame);
  }

  // Statistics
  Future<void> saveStats(GameStats stats) async {
    final raw = jsonEncode(stats.toJson());
    await _prefs.setString(_keyStats, raw);
  }

  GameStats loadStats() {
    final raw = _prefs.getString(_keyStats);
    if (raw == null || raw.isEmpty) return GameStats();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return GameStats.fromJson(map);
    } catch (_) {
      return GameStats();
    }
  }

  // Settings
  bool get hapticsEnabled => _prefs.getBool(_keyHaptics) ?? true;
  Future<void> setHapticsEnabled(bool enabled) async =>
      _prefs.setBool(_keyHaptics, enabled);

  bool get highlightSameEnabled => _prefs.getBool(_keyHighlightSame) ?? true;
  Future<void> setHighlightSameEnabled(bool enabled) async =>
      _prefs.setBool(_keyHighlightSame, enabled);
}
