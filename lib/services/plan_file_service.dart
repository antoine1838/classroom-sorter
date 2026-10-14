/// Import/export local d'un plan modifiable, sans dépendance réseau.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../models/classroom.dart';

typedef PlanFileSaver = Future<bool> Function(String filename, Uint8List bytes);
typedef PlanFilePicker = Future<Uint8List?> Function();

class PlanFileService {
  static const format = 'plandeclasse.plan';
  static const schemaVersion = 1;
  static const extension = 'planclasse';

  PlanFileService({PlanFileSaver? saveFile, PlanFilePicker? pickFile})
    : _saveFile = saveFile ?? _saveWithPlatform,
      _pickFile = pickFile ?? _pickWithPlatform;

  final PlanFileSaver _saveFile;
  final PlanFilePicker _pickFile;

  String encode(ClassGroup classGroup) =>
      const JsonEncoder.withIndent('  ').convert({
        'format': format,
        'schemaVersion': schemaVersion,
        'class': classGroup.toJson(),
      });

  ClassGroup decode(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map ||
          decoded['format'] != format ||
          decoded['schemaVersion'] != schemaVersion ||
          decoded['class'] is! Map) {
        throw const FormatException('Format de fichier de plan invalide.');
      }
      return ClassGroup.fromJson(
        (decoded['class'] as Map).cast<String, dynamic>(),
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Format de fichier de plan invalide.');
    }
  }

  Future<bool> exportClass(ClassGroup classGroup) async {
    final filename = '${_safeFilename(classGroup.name)}.$extension';
    return _saveFile(
      filename,
      Uint8List.fromList(utf8.encode(encode(classGroup))),
    );
  }

  static Future<bool> _saveWithPlatform(
    String filename,
    Uint8List bytes,
  ) async {
    final destination = await FilePicker.saveFile(
      dialogTitle: 'Enregistrer le plan',
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: [extension],
      bytes: bytes,
    );
    return destination != null;
  }

  Future<ClassGroup?> importClass() async {
    final bytes = await _pickFile();
    return bytes == null ? null : decode(utf8.decode(bytes));
  }

  static Future<Uint8List?> _pickWithPlatform() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: [extension, 'json'],
    );
    if (file == null) return null;
    return file.readAsBytes();
  }

  String _safeFilename(String value) {
    final collapsed = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-');
    return collapsed.isEmpty ? 'plan-de-classe' : collapsed;
  }
}
