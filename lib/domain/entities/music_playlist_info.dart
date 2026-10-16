/// A named playlist from the Supabase `music_playlists` table.
/// Track membership lives in `music_playlist_tracks` and is resolved
/// to track ids by [MusicRemoteDataSource].
class MusicPlaylistInfo {
  final String id;
  final String name;

  const MusicPlaylistInfo({required this.id, required this.name});

  factory MusicPlaylistInfo.fromMap(Map<String, dynamic> map) {
    return MusicPlaylistInfo(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {'id': id, 'name': name};
}
