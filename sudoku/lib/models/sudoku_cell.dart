class SudokuCell {
  final int row;
  final int col;
  final int solutionValue;
  final bool isGiven;

  int value;
  Set<int> notes;
  bool isError;
  bool hasHint;

  SudokuCell({
    required this.row,
    required this.col,
    required this.solutionValue,
    required this.isGiven,
    this.value = 0,
    Set<int>? notes,
    this.isError = false,
    this.hasHint = false,
  }) : notes = notes ?? <int>{};

  int get boxIndex => (row ~/ 3) * 3 + (col ~/ 3);

  bool get isEmpty => value == 0;
  bool get isFilled => value != 0;
  bool get isCorrect => value == solutionValue;

  SudokuCell copyWith({
    int? value,
    Set<int>? notes,
    bool? isError,
    bool? hasHint,
  }) {
    return SudokuCell(
      row: row,
      col: col,
      solutionValue: solutionValue,
      isGiven: isGiven,
      value: value ?? this.value,
      notes: notes != null ? Set<int>.from(notes) : Set<int>.from(this.notes),
      isError: isError ?? this.isError,
      hasHint: hasHint ?? this.hasHint,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'row': row,
      'col': col,
      'solutionValue': solutionValue,
      'isGiven': isGiven,
      'value': value,
      'notes': notes.toList(),
      'isError': isError,
      'hasHint': hasHint,
    };
  }

  factory SudokuCell.fromJson(Map<String, dynamic> json) {
    return SudokuCell(
      row: json['row'] as int,
      col: json['col'] as int,
      solutionValue: json['solutionValue'] as int,
      isGiven: json['isGiven'] as bool,
      value: json['value'] as int? ?? 0,
      notes: (json['notes'] as List<dynamic>?)?.map((e) => e as int).toSet() ?? <int>{},
      isError: json['isError'] as bool? ?? false,
      hasHint: json['hasHint'] as bool? ?? false,
    );
  }
}
