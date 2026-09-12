class CellNoteChange {
  final int row;
  final int col;
  final Set<int> previousNotes;
  final Set<int> newNotes;

  CellNoteChange({
    required this.row,
    required this.col,
    required this.previousNotes,
    required this.newNotes,
  });

  Map<String, dynamic> toJson() => {
        'row': row,
        'col': col,
        'previousNotes': previousNotes.toList(),
        'newNotes': newNotes.toList(),
      };

  factory CellNoteChange.fromJson(Map<String, dynamic> json) => CellNoteChange(
        row: json['row'] as int,
        col: json['col'] as int,
        previousNotes: (json['previousNotes'] as List<dynamic>).cast<int>().toSet(),
        newNotes: (json['newNotes'] as List<dynamic>).cast<int>().toSet(),
      );
}

class GameAction {
  final int row;
  final int col;
  final int previousValue;
  final int newValue;
  final Set<int> previousNotes;
  final Set<int> newNotes;
  final List<CellNoteChange> secondaryNoteChanges;

  GameAction({
    required this.row,
    required this.col,
    required this.previousValue,
    required this.newValue,
    required this.previousNotes,
    required this.newNotes,
    this.secondaryNoteChanges = const [],
  });

  Map<String, dynamic> toJson() => {
        'row': row,
        'col': col,
        'previousValue': previousValue,
        'newValue': newValue,
        'previousNotes': previousNotes.toList(),
        'newNotes': newNotes.toList(),
        'secondaryNoteChanges': secondaryNoteChanges.map((e) => e.toJson()).toList(),
      };

  factory GameAction.fromJson(Map<String, dynamic> json) => GameAction(
        row: json['row'] as int,
        col: json['col'] as int,
        previousValue: json['previousValue'] as int,
        newValue: json['newValue'] as int,
        previousNotes: (json['previousNotes'] as List<dynamic>).cast<int>().toSet(),
        newNotes: (json['newNotes'] as List<dynamic>).cast<int>().toSet(),
        secondaryNoteChanges: (json['secondaryNoteChanges'] as List<dynamic>?)
                ?.map((e) => CellNoteChange.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}
