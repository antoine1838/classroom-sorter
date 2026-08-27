/// Une salle enregistrée par l'utilisateur pour être réutilisée d'une
/// classe à l'autre (voir issue #28) : un nom et une géométrie de [Room],
/// indépendante de toute classe — elle survit à la suppression de celles
/// qui l'ont utilisée.
library;

import 'room.dart';

class SavedRoom {
  final String id;
  String name;
  Room room;

  SavedRoom({required this.id, required this.name, required this.room});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'room': room.toJson(),
      };

  factory SavedRoom.fromJson(Map<String, dynamic> j) => SavedRoom(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        room: Room.fromJson((j['room'] ?? const {}) as Map<String, dynamic>),
      );
}
