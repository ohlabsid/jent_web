import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Browser build: wraps bytes in a blob URL for the audio element.
/// Revoked via [releasePlayableSource] once replaced.
Future<String> createPlayableSource(String key, Uint8List bytes) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'audio/mpeg'),
  );
  return web.URL.createObjectURL(blob);
}

Future<void> releasePlayableSource(String source) async {
  web.URL.revokeObjectURL(source);
}
