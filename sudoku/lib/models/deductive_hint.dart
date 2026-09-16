import 'game_enums.dart';

/// Represents a logical deduction hint computed by the [DeductiveGrader].
class DeductiveHint {
  /// Unique identifier of the technique (e.g. 'naked_single', 'hidden_single', 'pointing_pair', 'x_wing').
  final String techniqueId;

  /// Human-friendly display name (e.g. 'Naked Single', 'Hidden Single', 'Pointing Pair').
  final String techniqueName;

  /// Difficulty tier associated with this deduction technique.
  final Difficulty difficulty;

  /// Row coordinate of the primary cell (0-8).
  final int targetRow;

  /// Column coordinate of the primary cell (0-8).
  final int targetCol;

  /// The digit to place (1-9) if this deduction directly determines a cell value.
  final int? targetValue;

  /// Specific candidate eliminations: Map of cell index (row * 9 + col) -> Set of eliminated digits.
  final Map<int, Set<int>> candidateEliminations;

  /// Indices (row * 9 + col) of the cells that cause or constrain this deduction.
  final Set<int> causeCellIndices;

  /// Type of unit involved ('row', 'column', 'box', or null).
  final String? unitType;

  /// Index of the unit involved (0-8).
  final int? unitIndex;

  /// Stage 1 message: Guiding clue pointing the player where to look without spoiling the answer.
  final String clueMessage;

  /// Stage 2 message: Detailed explanation showing why this digit/elimination is logically forced.
  final String explanationMessage;

  const DeductiveHint({
    required this.techniqueId,
    required this.techniqueName,
    required this.difficulty,
    required this.targetRow,
    required this.targetCol,
    this.targetValue,
    this.candidateEliminations = const {},
    this.causeCellIndices = const {},
    this.unitType,
    this.unitIndex,
    required this.clueMessage,
    required this.explanationMessage,
  });

  /// Index of the target cell in row-major order (0-80).
  int get targetIndex => targetRow * 9 + targetCol;

  /// Whether this hint directly places a digit into a cell.
  bool get isValuePlacement => targetValue != null;

  /// Label for the unit involved (e.g. "Box 4", "Row 2", "Column 7").
  String? get unitLabel {
    if (unitType == null || unitIndex == null) return null;
    final num = unitIndex! + 1;
    switch (unitType) {
      case 'row':
        return 'Row $num';
      case 'column':
        return 'Column $num';
      case 'box':
        return 'Box $num';
      default:
        return null;
    }
  }
}
