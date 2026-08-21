/// La salle : une grille de places, certaines pouvant être désactivées
/// (allées, estrade, espace vide…). Le rang 0 est le rang de devant
/// (proche du tableau / de l'enseignant).
library;

/// Orientation d'une place : le sens vers lequel l'élève fait face.
/// [nord] (par défaut) fait face au tableau, comme toutes les places
/// aujourd'hui. Purement visuelle : elle ne modifie pas le voisinage, qui ne
/// dépend que de l'adjacence sur la grille (voir [SeatingEngine]).
enum Facing { nord, est, sud, ouest }

extension FacingRotation on Facing {
  /// Prochaine orientation dans le cycle nord → est → sud → ouest → nord.
  Facing get next => Facing.values[(index + 1) % Facing.values.length];
}

class Room {
  int rows;
  int cols;

  /// Clés "r,c" des cases qui ne sont PAS des places (allées, vides).
  Set<String> disabled;

  /// Couloirs verticaux : un index `c` signifie qu'un couloir sépare la
  /// colonne `c` de la colonne `c+1` (donc `0 <= c <= cols - 2`). Deux places
  /// de part et d'autre d'un couloir ne sont pas voisines.
  Set<int> colAisles;

  /// Couloirs horizontaux : un index `r` signifie qu'un couloir sépare le
  /// rang `r` du rang `r+1` (donc `0 <= r <= rows - 2`). Miroir de
  /// [colAisles] pour l'autre axe. Comme un couloir de colonne, il ne coupe
  /// que le voisinage : il n'empêche pas un grand élève de gêner la vue de
  /// celui situé un rang plus près du tableau (voir [SeatingEngine]).
  Set<int> rowAisles;

  /// Orientation des places qui ne font PAS face au tableau (clé "r,c").
  /// Creuse : une place absente de cette map est orientée [Facing.nord],
  /// ce qui permet de relire sans migration les salles enregistrées avant
  /// l'introduction de l'orientation. Purement visuelle (voir [Facing]).
  Map<String, Facing> facing;

  Room({
    this.rows = 5,
    this.cols = 7,
    Set<String>? disabled,
    Set<int>? colAisles,
    Set<int>? rowAisles,
    Map<String, Facing>? facing,
  })  : disabled = disabled ?? <String>{},
        colAisles = colAisles ?? <int>{},
        rowAisles = rowAisles ?? <int>{},
        facing = facing ?? <String, Facing>{};

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
      facing.remove(k);
    }
  }

  /// Orientation de la place (r,c) : [Facing.nord] si non renseignée.
  Facing facingOf(int r, int c) => facing[keyOf(r, c)] ?? Facing.nord;

  /// Fait tourner la place (r,c) au cran suivant (nord → est → sud → ouest).
  void rotateFacing(int r, int c) {
    if (!isSeat(r, c)) return;
    final k = keyOf(r, c);
    final next = facingOf(r, c).next;
    if (next == Facing.nord) {
      facing.remove(k);
    } else {
      facing[k] = next;
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

  /// Vrai s'il y a un couloir entre le rang `r` et le rang `r+1`.
  bool hasRowAisleAfter(int r) => rowAisles.contains(r);

  /// Ajoute/retire un couloir entre le rang `r` et le rang `r+1`.
  void toggleRowAisle(int r) {
    if (r < 0 || r >= rows - 1) return; // hors des frontières internes
    if (rowAisles.contains(r)) {
      rowAisles.remove(r);
    } else {
      rowAisles.add(r);
    }
  }

  /// Vrai si un couloir sépare deux rangs adjacents (ordre indifférent).
  bool rowAisleBetween(int r1, int r2) {
    final lo = r1 < r2 ? r1 : r2;
    final hi = r1 < r2 ? r2 : r1;
    for (var b = lo; b < hi; b++) {
      if (rowAisles.contains(b)) return true;
    }
    return false;
  }

  /// Supprime les couloirs devenus hors grille (après réduction des colonnes).
  void pruneColAisles() => colAisles.removeWhere((c) => c < 0 || c >= cols - 1);

  /// Supprime les couloirs devenus hors grille (après réduction des rangs).
  void pruneRowAisles() => rowAisles.removeWhere((r) => r < 0 || r >= rows - 1);

  /// Supprime les orientations des cases devenues hors grille ou désactivées.
  void pruneFacing() => facing.removeWhere((k, _) {
        final (r, c) = parse(k);
        return !isSeat(r, c);
      });

  Map<String, dynamic> toJson() => {
        'rows': rows,
        'cols': cols,
        'disabled': disabled.toList(),
        'colAisles': colAisles.toList(),
        'rowAisles': rowAisles.toList(),
        'facing': facing.map((k, f) => MapEntry(k, f.name)),
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
        rowAisles: ((j['rowAisles'] ?? const []) as List)
            .map((e) => e as int)
            .toSet(),
        facing: ((j['facing'] ?? const {}) as Map).map(
          (k, v) => MapEntry(
            k as String,
            Facing.values.firstWhere((f) => f.name == v,
                orElse: () => Facing.nord),
          ),
        ),
      );
}
