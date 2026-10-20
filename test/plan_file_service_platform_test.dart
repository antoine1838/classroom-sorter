// Les deux adaptateurs qui relient PlanFileService à la boîte de dialogue du
// système (enregistrer, ouvrir). Les autres tests injectent leur propre
// `saveFile` / `pickFile` et ne les traversent donc jamais : on remplace ici le
// plugin `file_picker` lui-même.
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:plandeclasse/models/classroom.dart';
import 'package:plandeclasse/models/room.dart';
import 'package:plandeclasse/models/student.dart';
import 'package:plandeclasse/services/plan_file_service.dart';

/// Fichier « choisi » par l'utilisateur : seul son contenu importe.
base class _PickedFile extends PlatformFile {
  _PickedFile(this._bytes);

  final Uint8List _bytes;

  @override
  String get name => 'plan.planclasse';

  @override
  Uri get uri => Uri.file('/plan.planclasse');

  @override
  Never get xFile => throw UnimplementedError();

  @override
  int? lengthSync() => _bytes.length;

  @override
  Future<int?> length() async => _bytes.length;

  @override
  Future<Uint8List> readAsBytes() async => _bytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(_bytes);
}

class _FakeFilePicker extends FilePickerPlatform
    with MockPlatformInterfaceMixin {
  _FakeFilePicker({this.picked, this.destination});

  /// Ce que renvoie « ouvrir » ; nul quand l'utilisateur annule.
  final PlatformFile? picked;

  /// Ce que renvoie « enregistrer » ; nul quand l'utilisateur annule.
  final Uri? destination;

  String? savedFileName;
  Uint8List? savedBytes;
  String? savedDialogTitle;
  List<String>? pickedExtensions;
  FileType? pickedType;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    void Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    savedFileName = fileName;
    savedBytes = bytes;
    savedDialogTitle = dialogTitle;
    return destination;
  }

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    pickedType = type;
    pickedExtensions = allowedExtensions;
    return picked;
  }
}

ClassGroup _class() => ClassGroup(
  id: 'source',
  name: '6ème/B',
  room: Room(rows: 1, cols: 2),
  students: [Student(id: 'lea', firstName: 'Léa')],
  assignment: {'0,0': 'lea'},
);

void main() {
  final original = FilePickerPlatform.instance;
  tearDown(() => FilePickerPlatform.instance = original);

  group('enregistrer', () {
    test('envoie le plan, sous un nom sûr, à la boîte de dialogue', () async {
      final picker = _FakeFilePicker(destination: Uri.file('/tmp/plan'));
      FilePickerPlatform.instance = picker;

      final saved = await PlanFileService().exportClass(_class());

      expect(saved, isTrue);
      expect(picker.savedFileName, '6ème-B.planclasse');
      expect(picker.savedDialogTitle, isNotEmpty);
      final restored = PlanFileService().decode(
        utf8.decode(picker.savedBytes!),
      );
      expect(restored.name, '6ème/B');
      expect(restored.assignment, {'0,0': 'lea'});
    });

    test('rend faux quand l\'utilisateur annule', () async {
      FilePickerPlatform.instance = _FakeFilePicker();

      expect(await PlanFileService().exportClass(_class()), isFalse);
    });
  });

  group('ouvrir', () {
    test('lit le fichier choisi et recrée la classe', () async {
      final service = PlanFileService();
      final picker = _FakeFilePicker(
        picked: _PickedFile(
          Uint8List.fromList(utf8.encode(service.encode(_class()))),
        ),
      );
      FilePickerPlatform.instance = picker;

      final imported = await service.importClass();

      expect(imported?.name, '6ème/B');
      expect(imported?.students.single.fullName, 'Léa');
      expect(picker.pickedType, FileType.custom);
      expect(picker.pickedExtensions, ['planclasse', 'json']);
    });

    test('rend nul quand l\'utilisateur annule', () async {
      FilePickerPlatform.instance = _FakeFilePicker();

      expect(await PlanFileService().importClass(), isNull);
    });

    test('refuse un fichier choisi qui n\'est pas un plan', () async {
      FilePickerPlatform.instance = _FakeFilePicker(
        picked: _PickedFile(Uint8List.fromList(utf8.encode('{"autre":1}'))),
      );

      await expectLater(PlanFileService().importClass(), throwsFormatException);
    });

    test(
      'accepte un fichier enregistré avec une marque d\'ordre des octets',
      () async {
        final service = PlanFileService();
        // Certains éditeurs ajoutent un BOM UTF-8 en tête de fichier.
        final withBom = Uint8List.fromList([
          0xEF,
          0xBB,
          0xBF,
          ...utf8.encode(service.encode(_class())),
        ]);
        FilePickerPlatform.instance = _FakeFilePicker(
          picked: _PickedFile(withBom),
        );

        final imported = await service.importClass();

        expect(imported?.name, '6ème/B');
      },
    );
  });
}
