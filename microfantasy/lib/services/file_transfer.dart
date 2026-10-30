import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

class FileTransfer {
  Future<String?> readJson() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null) return null;
    final bytes = result.files.single.bytes;
    if (bytes == null) {
      throw const FormatException('No se pudo leer el archivo.');
    }
    if (bytes.length > 2097152) {
      throw const FormatException('El archivo supera 2 MB.');
    }
    return utf8.decode(bytes);
  }

  Future<bool> saveJson(String name, String text) async {
    final result = await FilePicker.platform.saveFile(
      fileName: name,
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: Uint8List.fromList(utf8.encode(text)),
    );
    return result != null;
  }
}
