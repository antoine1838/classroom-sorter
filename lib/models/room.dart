/// La salle : une grille de places, certaines pouvant être désactivées
/// (allées, estrade, espace vide…). Le rang 0 est le rang de devant
/// (proche du tableau / de l'enseignant).
library;

class Room {
  int rows;
  int cols;

  /// Clés "r,c" des cases qui ne sont PAS des places (allées, vides).
  Set<String> disabled;

  Room({this.rows = 5, this.cols = 6, Set<String>? disabled})
      : disabled = disabled ?? <String>{};

  static String keyOf(int r, int c) => '$r,$c';

  static (int, int) parse(String key) {
    final parts = key.split(',');
    return (int.parse(parts[0]), int.parse(parts[1]));
  }

  bool inBounds(int r, int c) => r >= 0 && r < rows && c >= 0 && c < cols;

  /// Vrai si (r,c) est une vraie place utilisable.
  bool isSeat(int r, int c) => inBounds(r, c) && !disabled.contains(keyOf(r, c));

  /// Toutes les places utilisables, dans l'ordre de lecture.
  List<String> get seatKeys {
    final list = <String>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (isSeat(r, c)) list.add(keyOf(r, c));
      }
    }
    return list;
  }

  int get capacity => seatKeys.length;

  /// Active/désactive une case.
  void toggle(int r, int c) {
    final k = keyOf(r, c);
    if (disabled.contains(k)) {
      disabled.remove(k);
    } else {
      disabled.add(k);
    }
  }

  Map<String, dynamic> toJson() => {
        'rows': rows,
        'cols': cols,
        'disabled': disabled.toList(),
      };

  factory Room.fromJson(Map<String, dynamic> j) => Room(
        rows: (j['rows'] ?? 5) as int,
        cols: (j['cols'] ?? 6) as int,
        disabled: ((j['disabled'] ?? const []) as List)
            .map((e) => e as String)
            .toSet(),
      );
}
