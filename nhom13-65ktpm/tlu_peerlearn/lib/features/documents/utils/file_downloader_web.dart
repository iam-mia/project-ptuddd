import 'dart:js_interop';

@JS('document.createElement')
external _AnchorElement _createElement(String tagName);

@JS('document.body.appendChild')
external void _appendChild(_AnchorElement element);

extension type _AnchorElement(JSObject _) implements JSObject {
  external set href(String value);
  external set download(String value);
  external set target(String value);
  external set rel(String value);
  external void click();
  external void remove();
}

/// Triggers a real browser file download using a temporary anchor element.
/// Appends `?download=<fileName>` for Supabase Storage URLs so the browser
/// receives `Content-Disposition: attachment` and saves the file directly.
Future<bool> downloadFileFromUrl({
  required String url,
  required String fileName,
}) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return false;

  final downloadUri = uri.path.contains('/storage/v1/object/')
      ? uri.replace(
          queryParameters: {
            ...uri.queryParameters,
            'download': fileName,
          },
        )
      : uri;

  final anchor = _createElement('a')
    ..href = downloadUri.toString()
    ..download = fileName
    ..target = '_blank'
    ..rel = 'noopener noreferrer';

  _appendChild(anchor);
  anchor.click();
  anchor.remove();
  return true;
}
