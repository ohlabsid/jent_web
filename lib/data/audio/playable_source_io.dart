import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Native builds: spills bytes to a stable temp-file path (doubling
/// as a disk cache across restarts). Deleted on cache eviction.
Future<String> createPlayableSource(String key, Uint8List bytes) async {
  final raw = base64Url.encode(utf8.encode(key)).replaceAll('=', '');
  final slug = raw.length > 32 ? raw.substring(0, 32) : raw;
  final file = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}jent_music_$slug.mp3',
  );
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<void> releasePlayableSource(String source) async {
  try {
    await File(source).delete();
  } catch (_) {
    // Already gone (e.g. OS-cleaned temp) — nothing to do.
  }
}
