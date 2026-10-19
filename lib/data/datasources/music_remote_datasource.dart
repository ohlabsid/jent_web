import 'package:injectable/injectable.dart';
import 'package:jent_web/core/supabase/supabase_config.dart';
import 'package:jent_web/domain/entities/music_playlist_info.dart';
import 'package:jent_web/domain/entities/music_track.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Remote music library on Supabase: track metadata in the
/// `music_tracks` table, playlists in `music_playlists` +
/// `music_playlist_tracks`, audio files in the public `music`
/// storage bucket. Registered as a lazy singleton via injectable.
///
/// Read-only from the app: you upload MP3s and edit rows in the
/// Supabase dashboard (owner login), the app only fetches. RLS
/// grants anon SELECT only — see the SQL in `docs/backend-and-secrets.md`
/// and the doc comment below.
///
/// All methods are offline-safe: when Supabase isn't configured or
/// the network fails they return `null` instead of throwing, so the
/// player keeps working with the bundled demo catalog.
///
/// Table + bucket SQL (run once in the Supabase SQL editor; create
/// the bucket in Storage > New bucket, name `music`, public on):
///
/// ```sql
/// create table music_tracks (
///   id text primary key,
///   title text not null,
///   artist text not null default '',
///   album text not null default '',
///   duration_seconds int not null default 0,
///   audio_path text not null default '',
///   artwork_url text not null default '',
///   sort_order int not null default 0,
///   created_at timestamptz not null default now()
/// );
/// create table music_playlists (
///   id text primary key,
///   name text not null,
///   sort_order int not null default 0,
///   created_at timestamptz not null default now()
/// );
/// create table music_playlist_tracks (
///   playlist_id text not null references music_playlists(id)
///     on delete cascade,
///   track_id text not null references music_tracks(id)
///     on delete cascade,
///   position int not null default 0,
///   primary key (playlist_id, track_id)
/// );
/// alter table music_tracks enable row level security;
/// alter table music_playlists enable row level security;
/// alter table music_playlist_tracks enable row level security;
/// -- Demo policy: anyone with the anon key can read. Writes stay
/// -- dashboard-side (owner login), so no anon insert/update/delete.
/// create policy "anon read tracks" on music_tracks
///   for select to anon using (true);
/// create policy "anon read playlists" on music_playlists
///   for select to anon using (true);
/// create policy "anon read playlist tracks" on music_playlist_tracks
///   for select to anon using (true);
/// -- Storage: bucket `music` public, with a read-only anon policy
/// -- (Storage > Policies > New policy > For full customization):
/// -- target `storage.objects`, for select to anon
/// -- using (bucket_id = 'music').
/// ```
@lazySingleton
class MusicRemoteDataSource {
  static const tracksTable = 'music_tracks';
  static const playlistsTable = 'music_playlists';
  static const junctionTable = 'music_playlist_tracks';
  static const bucket = 'music';

  SupabaseClient? get _client {
    try {
      if (!SupabaseConfig.isConfigured) return null;
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Returns remote tracks ascending by `sort_order` (then
  /// `created_at`), with `audio_path` resolved to a public storage
  /// URL, or `null` when unavailable.
  Future<List<MusicTrack>?> fetchTracks() async {
    final client = _client;
    if (client == null) return null;
    try {
      final rows = await client
          .from(tracksTable)
          .select()
          .order('sort_order', ascending: true)
          .order('created_at', ascending: true);
      return (rows as List).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        final path = (map['audio_path'] ?? '').toString();
        map['audio_url'] =
            path.isEmpty ? '' : client.storage.from(bucket).getPublicUrl(path);
        return MusicTrack.fromMap(map);
      }).toList();
    } catch (_) {
      return null;
    }
  }

  /// Returns playlists ascending by `sort_order` (each with its
  /// track ids ascending by `position`), or `null` when unavailable.
  Future<List<(MusicPlaylistInfo, List<String>)>?> fetchPlaylists() async {
    final client = _client;
    if (client == null) return null;
    try {
      final playlistRows = await client
          .from(playlistsTable)
          .select()
          .order('sort_order', ascending: true)
          .order('created_at', ascending: true);
      final junctionRows = await client
          .from(junctionTable)
          .select()
          // Ascending on purpose: postgrest-dart's `order()` defaults to
          // DESCENDING, which would play every playlist backwards.
          .order('position', ascending: true);
      final byPlaylist = <String, List<String>>{};
      for (final row in junctionRows as List) {
        final map = Map<String, dynamic>.from(row as Map);
        final pid = (map['playlist_id'] ?? '').toString();
        final tid = (map['track_id'] ?? '').toString();
        if (pid.isEmpty || tid.isEmpty) continue;
        byPlaylist.putIfAbsent(pid, () => []).add(tid);
      }
      return (playlistRows as List).map((row) {
        final map = Map<String, dynamic>.from(row as Map);
        final info = MusicPlaylistInfo.fromMap(map);
        return (info, byPlaylist[info.id] ?? const <String>[]);
      }).toList();
    } catch (_) {
      return null;
    }
  }
}
