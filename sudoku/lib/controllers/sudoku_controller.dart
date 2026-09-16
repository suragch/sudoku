import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/game_action.dart';
import '../models/game_enums.dart';
import '../models/game_stats.dart';
import '../models/sudoku_board.dart';
import '../models/sudoku_cell.dart';
import '../services/puzzle_database_service.dart';
import '../services/storage_service.dart';

class SudokuController extends ChangeNotifier {
  final StorageService? _storageService;
  final PuzzleDatabaseService? _databaseService;

  late SudokuBoard _board;
  Difficulty _difficulty = Difficulty.easy;
  GameStatus _status = GameStatus.playing;
  InputMode _inputMode = InputMode.cellFirst;

  int? _selectedRow;
  int? _selectedCol;
  int? _selectedDigit; // Used in digitFirst mode or for highlighting

  bool _isNoteMode = false;
  int _elapsedSeconds = 0;
  int _mistakes = 0;
  int _hintsUsed = 0;
  Timer? _timer;

  final List<GameAction> _undoStack = [];
  final List<GameAction> _redoStack = [];

  // Completion animation tracking
  final Set<int> _animatingRows = {};
  final Set<int> _animatingCols = {};
  final Set<int> _animatingBoxes = {};

  GameStats _stats = GameStats();
  bool _isNewBestTime = false;

  SudokuController({
    StorageService? storageService,
    PuzzleDatabaseService? databaseService,
    SudokuBoard? initialBoard,
  })  : _storageService = storageService,
        _databaseService = databaseService ?? PuzzleDatabaseService.instanceOrNull {
    if (storageService != null) {
      _stats = storageService.loadStats();
    }
    _initGame(initialBoard: initialBoard);
  }

  // Getters
  SudokuBoard get board => _board;
  Difficulty get difficulty => _difficulty;
  GameStatus get status => _status;
  InputMode get inputMode => _inputMode;
  int? get selectedRow => _selectedRow;
  int? get selectedCol => _selectedCol;
  int? get selectedDigit => _selectedDigit;
  bool get isNoteMode => _isNoteMode;
  int get elapsedSeconds => _elapsedSeconds;
  int get mistakes => _mistakes;
  int get hintsUsed => _hintsUsed;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  GameStats get stats => _stats;
  bool get isNewBestTime => _isNewBestTime;

  Set<int> get animatingRows => _animatingRows;
  Set<int> get animatingCols => _animatingCols;
  Set<int> get animatingBoxes => _animatingBoxes;

  SudokuCell? get selectedCell {
    if (_selectedRow != null && _selectedCol != null) {
      return _board.cellAt(_selectedRow!, _selectedCol!);
    }
    return null;
  }

  int get highlightedNumber {
    if (_inputMode == InputMode.digitFirst && _selectedDigit != null) {
      return _selectedDigit!;
    }
    final cell = selectedCell;
    if (cell != null && cell.value > 0) {
      return cell.value;
    }
    return _selectedDigit ?? 0;
  }

  bool isDigitComplete(int digit) => _board.isDigitComplete(digit);
  int getRemainingCount(int digit) => _board.getRemainingCount(digit);

  void _initGame({SudokuBoard? initialBoard}) {
    final saved = _storageService?.loadActiveGame();
    if (saved != null && saved.status != GameStatus.completed) {
      _board = saved.board;
      _difficulty = saved.difficulty;
      _elapsedSeconds = saved.elapsedSeconds;
      _mistakes = saved.mistakes;
      _hintsUsed = saved.hintsUsed;
      _status = saved.status;
      _board.validateDuplicates();
    } else if (initialBoard != null) {
      _startFreshBoardWithBoard(_difficulty, initialBoard);
    } else {
      final db = _databaseService ?? PuzzleDatabaseService.instanceOrNull;
      if (db != null) {
        final preloaded = db.getPreloadedBoard(_difficulty);
        _startFreshBoardWithBoard(_difficulty, preloaded);
      } else {
        throw StateError(
          'SudokuController requires an initialBoard or an initialized PuzzleDatabaseService.',
        );
      }
    }
    _startTimer();
  }

  void _startFreshBoardWithBoard(Difficulty difficulty, SudokuBoard board) {
    _difficulty = difficulty;
    _board = board;
    _board.validateDuplicates();
    _elapsedSeconds = 0;
    _mistakes = 0;
    _hintsUsed = 0;
    _status = GameStatus.playing;
    _selectedRow = null;
    _selectedCol = null;
    _selectedDigit = null;
    _undoStack.clear();
    _redoStack.clear();
    _animatingRows.clear();
    _animatingCols.clear();
    _animatingBoxes.clear();
    _isNewBestTime = false;

    _stats = _stats.recordGameStarted(difficulty);
    _storageService?.saveStats(_stats);
    _saveState();
  }

  Future<void> startNewGame(Difficulty difficulty, [SudokuBoard? board]) async {
    _timer?.cancel();
    final SudokuBoard newBoard;
    if (board != null) {
      newBoard = board;
    } else {
      final db = _databaseService ?? PuzzleDatabaseService.instanceOrNull;
      if (db == null) {
        throw StateError(
          'Cannot start new game: PuzzleDatabaseService is not initialized.',
        );
      }
      newBoard = await db.getRandomPuzzle(difficulty);
    }
    _startFreshBoardWithBoard(difficulty, newBoard);
    _startTimer();
    notifyListeners();
  }

  void restartCurrentGame() {
    // Reset all non-given cells
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final cell = _board.cellAt(r, c);
        if (!cell.isGiven) {
          cell.value = 0;
          cell.notes.clear();
          cell.isError = false;
          cell.hasHint = false;
        }
      }
    }
    _elapsedSeconds = 0;
    _mistakes = 0;
    _status = GameStatus.playing;
    _undoStack.clear();
    _redoStack.clear();
    _animatingRows.clear();
    _animatingCols.clear();
    _animatingBoxes.clear();
    _startTimer();
    _saveState();
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_status == GameStatus.playing) {
        _elapsedSeconds++;
        notifyListeners();
        if (_elapsedSeconds % 5 == 0) {
          _saveState();
        }
      }
    });
  }

  void togglePause() {
    if (_status == GameStatus.completed) return;
    if (_status == GameStatus.playing) {
      _status = GameStatus.paused;
    } else {
      _status = GameStatus.playing;
    }
    _saveState();
    notifyListeners();
  }

  void setInputMode(InputMode mode) {
    _inputMode = mode;
    notifyListeners();
  }

  void toggleNoteMode() {
    _isNoteMode = !_isNoteMode;
    HapticFeedback.selectionClick();
    notifyListeners();
  }

  // Selection
  void selectCell(int r, int c) {
    if (_status == GameStatus.paused) return;

    if (_inputMode == InputMode.digitFirst && _selectedDigit != null) {
      // In digit-first mode, tapping a cell applies the selected digit
      _selectedRow = r;
      _selectedCol = c;
      enterDigit(_selectedDigit!);
    } else {
      _selectedRow = r;
      _selectedCol = c;
      final cell = _board.cellAt(r, c);
      if (cell.value > 0) {
        _selectedDigit = cell.value;
      }
      HapticFeedback.selectionClick();
      notifyListeners();
    }
  }

  void selectDigitForFastPlacement(int digit) {
    _selectedDigit = (_selectedDigit == digit) ? null : digit;
    HapticFeedback.selectionClick();
    notifyListeners();
  }

  // Digit Entry
  void enterDigit(int digit) {
    if (_status != GameStatus.playing) return;
    if (_selectedRow == null || _selectedCol == null) {
      // If no cell selected, select the digit for highlighting
      _selectedDigit = digit;
      notifyListeners();
      return;
    }

    final r = _selectedRow!;
    final c = _selectedCol!;
    final cell = _board.cellAt(r, c);

    if (cell.isGiven) return;

    if (_isNoteMode) {
      // Toggle note
      final prevNotes = Set<int>.from(cell.notes);
      final newNotes = Set<int>.from(cell.notes);
      if (newNotes.contains(digit)) {
        newNotes.remove(digit);
      } else {
        newNotes.add(digit);
      }

      cell.notes = newNotes;
      _undoStack.add(GameAction(
        row: r,
        col: c,
        previousValue: cell.value,
        newValue: cell.value,
        previousNotes: prevNotes,
        newNotes: newNotes,
      ));
      _redoStack.clear();
      HapticFeedback.lightImpact();
      notifyListeners();
      return;
    }

    // Normal digit placement
    final prevVal = cell.value;
    final prevNotes = Set<int>.from(cell.notes);
    final secondaryNotes = <CellNoteChange>[];

    // If cell already has this digit, clear it (toggle off)
    final newVal = (prevVal == digit) ? 0 : digit;
    cell.value = newVal;
    cell.notes.clear();

    if (newVal != 0) {
      if (newVal != cell.solutionValue) {
        _mistakes++;
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }

      // Auto-erase matching notes in row, column, and box
      final b = cell.boxIndex;
      // In row
      for (int i = 0; i < 9; i++) {
        if (i != c && _board.cellAt(r, i).notes.contains(digit)) {
          final target = _board.cellAt(r, i);
          final old = Set<int>.from(target.notes);
          target.notes.remove(digit);
          secondaryNotes.add(CellNoteChange(
            row: r,
            col: i,
            previousNotes: old,
            newNotes: Set<int>.from(target.notes),
          ));
        }
      }
      // In col
      for (int i = 0; i < 9; i++) {
        if (i != r && _board.cellAt(i, c).notes.contains(digit)) {
          final target = _board.cellAt(i, c);
          final old = Set<int>.from(target.notes);
          target.notes.remove(digit);
          secondaryNotes.add(CellNoteChange(
            row: i,
            col: c,
            previousNotes: old,
            newNotes: Set<int>.from(target.notes),
          ));
        }
      }
      // In box
      for (final target in _board.getBox(b)) {
        if ((target.row != r || target.col != c) && target.notes.contains(digit)) {
          final old = Set<int>.from(target.notes);
          target.notes.remove(digit);
          secondaryNotes.add(CellNoteChange(
            row: target.row,
            col: target.col,
            previousNotes: old,
            newNotes: Set<int>.from(target.notes),
          ));
        }
      }
    }

    _board.validateDuplicates();

    _undoStack.add(GameAction(
      row: r,
      col: c,
      previousValue: prevVal,
      newValue: newVal,
      previousNotes: prevNotes,
      newNotes: Set<int>.from(cell.notes),
      secondaryNoteChanges: secondaryNotes,
    ));
    _redoStack.clear();

    // Check row, col, box completion
    _checkCompletions(r, c);

    // Check full puzzle victory
    if (_board.isComplete) {
      _handleVictory();
    }

    _saveState();
    notifyListeners();
  }

  void erase() {
    if (_status != GameStatus.playing) return;
    if (_selectedRow == null || _selectedCol == null) return;

    final r = _selectedRow!;
    final c = _selectedCol!;
    final cell = _board.cellAt(r, c);

    if (cell.isGiven) return;
    if (cell.value == 0 && cell.notes.isEmpty) return;

    final prevVal = cell.value;
    final prevNotes = Set<int>.from(cell.notes);

    cell.value = 0;
    cell.notes.clear();
    cell.isError = false;

    _board.validateDuplicates();

    _undoStack.add(GameAction(
      row: r,
      col: c,
      previousValue: prevVal,
      newValue: 0,
      previousNotes: prevNotes,
      newNotes: const {},
    ));
    _redoStack.clear();

    HapticFeedback.lightImpact();
    _saveState();
    notifyListeners();
  }

  void undo() {
    if (!canUndo || _status != GameStatus.playing) return;

    final action = _undoStack.removeLast();
    final cell = _board.cellAt(action.row, action.col);

    cell.value = action.previousValue;
    cell.notes = Set<int>.from(action.previousNotes);

    // Revert secondary note removals
    for (final change in action.secondaryNoteChanges) {
      _board.cellAt(change.row, change.col).notes = Set<int>.from(change.previousNotes);
    }

    _redoStack.add(action);
    _board.validateDuplicates();
    HapticFeedback.selectionClick();
    _saveState();
    notifyListeners();
  }

  void redo() {
    if (!canRedo || _status != GameStatus.playing) return;

    final action = _redoStack.removeLast();
    final cell = _board.cellAt(action.row, action.col);

    cell.value = action.newValue;
    cell.notes = Set<int>.from(action.newNotes);

    for (final change in action.secondaryNoteChanges) {
      _board.cellAt(change.row, change.col).notes = Set<int>.from(change.newNotes);
    }

    _undoStack.add(action);
    _board.validateDuplicates();
    HapticFeedback.selectionClick();
    _saveState();
    notifyListeners();
  }

  void giveHint() {
    if (_status != GameStatus.playing) return;

    SudokuCell? target;
    // Prefer current selected cell if empty
    if (_selectedRow != null && _selectedCol != null) {
      final cell = _board.cellAt(_selectedRow!, _selectedCol!);
      if (cell.isEmpty) {
        target = cell;
      }
    }

    // Otherwise find the first empty cell
    if (target == null) {
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          final cell = _board.cellAt(r, c);
          if (cell.isEmpty) {
            target = cell;
            _selectedRow = r;
            _selectedCol = c;
            break;
          }
        }
        if (target != null) break;
      }
    }

    if (target == null) return; // Board full

    _hintsUsed++;
    final prevVal = target.value;
    final prevNotes = Set<int>.from(target.notes);

    target.value = target.solutionValue;
    target.notes.clear();
    target.hasHint = true;
    target.isError = false;

    _board.validateDuplicates();

    _undoStack.add(GameAction(
      row: target.row,
      col: target.col,
      previousValue: prevVal,
      newValue: target.solutionValue,
      previousNotes: prevNotes,
      newNotes: const {},
    ));
    _redoStack.clear();

    _checkCompletions(target.row, target.col);

    if (_board.isComplete) {
      _handleVictory();
    }

    HapticFeedback.mediumImpact();
    _saveState();
    notifyListeners();
  }

  void _checkCompletions(int r, int c) {
    final b = (r ~/ 3) * 3 + (c ~/ 3);
    bool anyNew = false;

    if (_board.isRowComplete(r) && !_animatingRows.contains(r)) {
      _animatingRows.add(r);
      anyNew = true;
    }
    if (_board.isColComplete(c) && !_animatingCols.contains(c)) {
      _animatingCols.add(c);
      anyNew = true;
    }
    if (_board.isBoxComplete(b) && !_animatingBoxes.contains(b)) {
      _animatingBoxes.add(b);
      anyNew = true;
    }

    if (anyNew) {
      HapticFeedback.heavyImpact();
      // Remove animation highlight after 1.5 seconds
      Timer(const Duration(milliseconds: 1500), () {
        _animatingRows.remove(r);
        _animatingCols.remove(c);
        _animatingBoxes.remove(b);
        notifyListeners();
      });
    }
  }

  void _handleVictory() {
    _status = GameStatus.completed;
    _timer?.cancel();

    final prevBest = _stats.forDifficulty(_difficulty).bestTimeSeconds;
    _stats = _stats.recordWin(_difficulty, _elapsedSeconds);
    _isNewBestTime = prevBest == null || _elapsedSeconds < prevBest;

    _storageService?.saveStats(_stats);
    _storageService?.clearActiveGame();
    HapticFeedback.heavyImpact();
  }

  void _saveState() {
    if (_status == GameStatus.completed) {
      _storageService?.clearActiveGame();
      return;
    }
    _storageService?.saveActiveGame(SavedGameState(
      board: _board,
      difficulty: _difficulty,
      elapsedSeconds: _elapsedSeconds,
      mistakes: _mistakes,
      hintsUsed: _hintsUsed,
      status: _status,
    ));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
