/// La salle : une grille de places, certaines pouvant être désactivées
/// (allées, estrade, espace vide…). Le rang 0 est le rang de devant
/// (proche du tableau / de l'enseignant).
library;

class Room {
  int rows;
  int cols;

  /// Clés "r,c" des cases qui ne sont PAS des places (allées, vides).
  Set<String> disabled;

  /// Couloirs verticaux : un index `c` signifie qu'un couloir sépare la
  /// colonne `c` de la colonne `c+1` (donc `0 <= c <= cols - 2`). Deux places
  /// de part et d'autre d'un couloir ne sont pas voisines.
  ///
  /// Note : les rangs sont, eux, TOUJOURS séparés par un couloir. On ne
  /// considère « à côté » que deux places du même rang, sur des colonnes
  /// adjacentes, sans couloir entre elles (voir [SeatingEngine]).
  Set<int> colAisles;

  Room({
    this.rows = 5,
    this.cols = 7,
    Set<String>? disabled,
    Set<int>? colAisles,
  })  : disabled = disabled ?? <String>{},
        colAisles = colAisles ?? <int>{};

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

  /// Vrai s'il y a un couloir entre la colonne `c` et la colonne `c+1`.
  bool hasColAisleAfter(int c) => colAisles.contains(c);

  /// Ajoute/retire un couloir entre la colonne `c` et la colonne `c+1`.
  void toggleColAisle(int c) {
    if (c < 0 || c >= cols - 1) return; // hors des frontières internes
    if (colAisles.contains(c)) {
      colAisles.remove(c);
    } else {
      colAisles.add(c);
    }
  }

  /// Vrai si un couloir sépare deux colonnes adjacentes (ordre indifférent).
  bool colAisleBetween(int c1, int c2) {
    final lo = c1 < c2 ? c1 : c2;
    final hi = c1 < c2 ? c2 : c1;
    for (var b = lo; b < hi; b++) {
      if (colAisles.contains(b)) return true;
    }
    return false;
  }

  /// Supprime les couloirs devenus hors grille (après réduction des colonnes).
  void pruneColAisles() => colAisles.removeWhere((c) => c < 0 || c >= cols - 1);

  Map<String, dynamic> toJson() => {
        'rows': rows,
        'cols': cols,
        'disabled': disabled.toList(),
        'colAisles': colAisles.toList(),
      };

  factory Room.fromJson(Map<String, dynamic> j) => Room(
        rows: (j['rows'] ?? 5) as int,
        cols: (j['cols'] ?? 7) as int,
        disabled: ((j['disabled'] ?? const []) as List)
            .map((e) => e as String)
            .toSet(),
        colAisles: ((j['colAisles'] ?? const []) as List)
            .map((e) => e as int)
            .toSet(),
      );
}
