/// Uploads `music_upload/*.mp3` + `tracks.json` to Supabase.
///
/// Reads the manifest, pushes each MP3 to the public `music` storage
/// bucket, then upserts `music_playlists`, `music_tracks`, and
/// `music_playlist_tracks` so the in-app player picks them up.
///
/// Needs the service_role key (bypasses RLS — dashboard uploads use
/// your login instead, but this script is unattended):
///
/// ```sh
/// SUPABASE_URL=https://xyz.supabase.co \
/// SUPABASE_SERVICE_ROLE_KEY=eyJ... \
/// dart run tool/upload_music.dart
/// ```
///
/// `--dry-run` validates the manifest and files without any network.
/// `--manifest <path>` points at a different manifest (MP3s resolve
/// relative to the manifest's folder).
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _bucket = 'music';

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  var manifestPath = 'music_upload/tracks.json';
  final manifestFlag = args.indexOf('--manifest');
  if (manifestFlag >= 0 && manifestFlag + 1 < args.length) {
    manifestPath = args[manifestFlag + 1];
  }

  final manifestFile = File(manifestPath);
  if (!manifestFile.existsSync()) {
    _fail('manifest not found: $manifestPath');
  }
  final baseDir = manifestFile.parent;

  late Map<String, dynamic> manifest;
  try {
    manifest = jsonDecode(manifestFile.readAsStringSync())
        as Map<String, dynamic>;
  } catch (e) {
    _fail('manifest is not valid JSON: $e');
  }

  final plan = _parseManifest(manifest, baseDir);
  _printPlan(plan, manifestPath);

  if (dryRun) {
    stdout.writeln('dry-run OK: ${plan.tracks.length} track(s), '
        '${plan.playlists.length} playlist(s) — nothing uploaded.');
    return;
  }

  final url =
      Platform.environment['SUPABASE_URL']?.trim().replaceAll(RegExp(r'/$'), '');
  final serviceKey = Platform.environment['SUPABASE_SERVICE_ROLE_KEY']?.trim();
  if (url == null || url.isEmpty) {
    _fail('SUPABASE_URL is not set in the environment.');
  }
  if (serviceKey == null || serviceKey.isEmpty) {
    _fail('SUPABASE_SERVICE_ROLE_KEY is not set in the environment.');
  }

  final api = _SupabaseAdmin(url: url, serviceKey: serviceKey);
  var failures = 0;

  for (final track in plan.tracks) {
    final error = await _uploadTrack(api, baseDir, track);
    if (error == null) {
      stdout.writeln('  ✓ ${track.file} -> ${track.id}');
    } else {
      failures++;
      stdout.writeln('  ✗ ${track.file}: $error');
    }
  }

  if (failures > 0) {
    _fail('$failures track(s) failed (audio may be partially uploaded).');
  }

  await api.upsertPlaylists(plan.playlists);
  stdout.writeln('playlists upserted: ${plan.playlists.length}');
  await api.upsertTracks(plan.tracks);
  stdout.writeln('tracks upserted: ${plan.tracks.length}');
  await api.replaceJunction(plan);
  stdout.writeln('playlist memberships written.');

  stdout.writeln(
      'done: ${plan.tracks.length} track(s), ${plan.playlists.length} '
      'playlist(s). Open the music window and hit refresh.');
}

Future<String?> _uploadTrack(
  _SupabaseAdmin api,
  Directory baseDir,
  _TrackSpec track,
) async {
  final bytes = File('${baseDir.path}/${track.file}').readAsBytesSync();
  final storageError = await api.uploadAudio(track.file, bytes);
  if (storageError != null) return 'storage: $storageError';
  return null;
}

class _PlaylistSpec {
  final String id;
  final String name;
  final int sortOrder;

  _PlaylistSpec({required this.id, required this.name, required this.sortOrder});
}

class _TrackSpec {
  final String file;
  final String id;
  final String title;
  final String artist;
  final String album;
  final int durationSeconds;
  final int sortOrder;
  final String artworkUrl;
  final List<String> playlists;

  _TrackSpec({
    required this.file,
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationSeconds,
    required this.sortOrder,
    required this.artworkUrl,
    required this.playlists,
  });

  Map<String, dynamic> toRow() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'duration_seconds': durationSeconds,
        'audio_path': file,
        'artwork_url': artworkUrl,
        'sort_order': sortOrder,
      };
}

class _UploadPlan {
  final List<_PlaylistSpec> playlists;
  final List<_TrackSpec> tracks;

  _UploadPlan({required this.playlists, required this.tracks});
}

_UploadPlan _parseManifest(Map<String, dynamic> manifest, Directory baseDir) {
  String reqStr(Map<String, dynamic> m, String key, String what) {
    final v = m[key];
    if (v is! String || v.trim().isEmpty) {
      _fail('$what is missing required "$key".');
    }
    return v.trim();
  }

  int optInt(Map<String, dynamic> m, String key, int fallback, String what) {
    final v = m[key];
    if (v == null) return fallback;
    if (v is int && v >= 0) return v;
    _fail('$what has invalid "$key": must be a non-negative integer.');
  }

  final playlists = <_PlaylistSpec>[];
  final playlistIds = <String>{};
  final rawPlaylists = manifest['playlists'];
  if (rawPlaylists != null) {
    if (rawPlaylists is! List) _fail('top-level "playlists" must be a list.');
    var order = 1;
    for (final entry in rawPlaylists) {
      if (entry is! Map) _fail('each playlist must be an object.');
      final m = Map<String, dynamic>.from(entry);
      final id = reqStr(m, 'id', 'playlist');
      if (!playlistIds.add(id)) _fail('duplicate playlist id "$id".');
      playlists.add(_PlaylistSpec(
        id: id,
        name: reqStr(m, 'name', 'playlist "$id"'),
        sortOrder: optInt(m, 'sort_order', order, 'playlist "$id"'),
      ));
      order++;
    }
  }

  final rawTracks = manifest['tracks'];
  if (rawTracks is! List || rawTracks.isEmpty) {
    _fail('manifest needs a non-empty "tracks" list.');
  }
  final tracks = <_TrackSpec>[];
  final trackIds = <String>{};
  var order = 1;
  for (final entry in rawTracks) {
    if (entry is! Map) _fail('each track must be an object.');
    final m = Map<String, dynamic>.from(entry);
    final file = reqStr(m, 'file', 'track');
    if (!file.toLowerCase().endsWith('.mp3')) {
      _fail('track "$file": only .mp3 files are supported.');
    }
    final mp3 = File('${baseDir.path}/$file');
    if (!mp3.existsSync()) {
      _fail('track "$file": file not found in ${baseDir.path}/.');
    }
    final id = (m['id'] as String?)?.trim().isEmpty ?? true
        ? file.replaceAll(RegExp(r'\.mp3$', caseSensitive: false), '')
        : (m['id'] as String).trim();
    if (!trackIds.add(id)) _fail('duplicate track id "$id".');

    final rawPl = m['playlists'];
    final trackPlaylists = <String>[];
    if (rawPl != null) {
      if (rawPl is! List) _fail('track "$id": "playlists" must be a list.');
      for (final pid in rawPl) {
        final idStr = pid.toString();
        if (!playlistIds.contains(idStr)) {
          _fail('track "$id": unknown playlist "$idStr".');
        }
        trackPlaylists.add(idStr);
      }
    }

    final duration = m['duration_seconds'];
    if (duration is! int || duration < 0) {
      _fail('track "$id": "duration_seconds" is required '
          '(non-negative integer).');
    }

    tracks.add(_TrackSpec(
      file: file,
      id: id,
      title: reqStr(m, 'title', 'track "$id"'),
      artist: (m['artist'] as String? ?? '').trim(),
      album: (m['album'] as String? ?? '').trim(),
      durationSeconds: duration,
      sortOrder: optInt(m, 'sort_order', order, 'track "$id"'),
      artworkUrl: (m['artwork_url'] as String? ?? '').trim(),
      playlists: trackPlaylists,
    ));
    order++;
  }
  return _UploadPlan(playlists: playlists, tracks: tracks);
}

void _printPlan(_UploadPlan plan, String manifestPath) {
  stdout.writeln('manifest: $manifestPath');
  for (final p in plan.playlists) {
    final members =
        plan.tracks.where((t) => t.playlists.contains(p.id)).length;
    stdout.writeln('  playlist "${p.name}" (${p.id}): $members track(s)');
  }
  for (final t in plan.tracks) {
    stdout.writeln('  track "${t.title}" (${t.id}): ${t.file}, '
        '${t.durationSeconds}s, order ${t.sortOrder}');
  }
}

/// Minimal admin client over the Supabase REST + Storage HTTP APIs.
/// Uses the service_role key, so it bypasses RLS by design — keep
/// that key out of the app and out of git.
class _SupabaseAdmin {
  final String url;
  final String serviceKey;

  _SupabaseAdmin({required this.url, required this.serviceKey});

  Map<String, String> get _auth => {
        'apikey': serviceKey,
        'Authorization': 'Bearer $serviceKey',
      };

  /// Uploads (or overwrites via `x-upsert`) one MP3. Returns an
  /// error string, or null on success.
  Future<String?> uploadAudio(String fileName, List<int> bytes) async {
    final uri =
        Uri.parse('$url/storage/v1/object/$_bucket/${Uri.encodeComponent(fileName)}');
    http.Response res;
    try {
      res = await http.post(
        uri,
        headers: {..._auth, 'Content-Type': 'audio/mpeg', 'x-upsert': 'true'},
        body: bytes,
      );
    } catch (e) {
      return 'network error: $e';
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return null;
    return 'HTTP ${res.statusCode}: ${res.body}';
  }

  Future<void> upsertPlaylists(List<_PlaylistSpec> playlists) async {
    if (playlists.isEmpty) return;
    await _postRest(
      'music_playlists',
      playlists
          .map((p) => {'id': p.id, 'name': p.name, 'sort_order': p.sortOrder})
          .toList(),
    );
  }

  Future<void> upsertTracks(List<_TrackSpec> tracks) async {
    await _postRest(
      'music_tracks',
      tracks.map((t) => t.toRow()).toList(),
    );
  }

  /// Replaces each manifest playlist's membership rows so removals
  /// in `tracks.json` take effect remotely too.
  Future<void> replaceJunction(_UploadPlan plan) async {
    for (final playlist in plan.playlists) {
      final deleteUri = Uri.parse(
        '$url/rest/v1/music_playlist_tracks'
        '?playlist_id=eq.${Uri.encodeComponent(playlist.id)}',
      );
      final del = await http.delete(deleteUri, headers: _auth);
      if (del.statusCode < 200 || del.statusCode >= 300) {
        _fail('clearing playlist "${playlist.id}" failed: '
            'HTTP ${del.statusCode}: ${del.body}');
      }
      final rows = <Map<String, dynamic>>[];
      var position = 1;
      for (final track in plan.tracks) {
        if (!track.playlists.contains(playlist.id)) continue;
        rows.add({
          'playlist_id': playlist.id,
          'track_id': track.id,
          'position': position++,
        });
      }
      if (rows.isEmpty) continue;
      await _postRest('music_playlist_tracks', rows);
    }
  }

  Future<void> _postRest(String table, List<Map<String, dynamic>> rows) async {
    final uri = Uri.parse('$url/rest/v1/$table');
    http.Response res;
    try {
      res = await http.post(
        uri,
        headers: {
          ..._auth,
          'Content-Type': 'application/json',
          'Prefer': 'resolution=merge-duplicates',
        },
        body: jsonEncode(rows),
      );
    } catch (e) {
      _fail('network error writing $table: $e');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _fail('upserting $table failed: HTTP ${res.statusCode}: ${res.body}');
    }
  }
}

Never _fail(String message) {
  stderr.writeln('error: $message');
  exit(1);
}
