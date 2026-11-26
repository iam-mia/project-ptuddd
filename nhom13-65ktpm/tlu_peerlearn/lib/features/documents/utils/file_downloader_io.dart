import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

/// Downloads a file from [url] and lets the user save it via native save dialog.
Future<bool> downloadFileFromUrl({
  required String url,
  required String fileName,
}) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return false;

  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }

    final chunks = <int>[];
    await for (final chunk in response) {
      chunks.addAll(chunk);
    }
    final bytes = Uint8List.fromList(chunks);

    final savedUri = await FilePicker.saveFile(
      dialogTitle: 'Lưu tài liệu',
      fileName: fileName,
      bytes: bytes,
    );
    if (savedUri != null) {
      if (savedUri.scheme == 'file') {
        final file = File.fromUri(savedUri);
        if (!await file.exists()) {
          await file.writeAsBytes(bytes);
        }
      }
      return true;
    }
    return false;
  } finally {
    client.close();
  }
}
