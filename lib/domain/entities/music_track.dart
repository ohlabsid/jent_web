class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String audioUrl;
  final String artworkUrl;

  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.audioUrl,
    this.artworkUrl = '',
  });

  /// Row from the Supabase `music_tracks` table. `audioUrl` must
  /// already be resolved to a playable (public) URL by the caller.
  factory MusicTrack.fromMap(Map<String, dynamic> map) {
    return MusicTrack(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      artist: (map['artist'] ?? '').toString(),
      album: (map['album'] ?? '').toString(),
      duration: Duration(seconds: (map['duration_seconds'] as num? ?? 0).toInt()),
      audioUrl: (map['audio_url'] ?? '').toString(),
      artworkUrl: (map['artwork_url'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'duration_seconds': duration.inSeconds,
      'audio_url': audioUrl,
      'artwork_url': artworkUrl,
    };
  }
}

/// Local demo catalog. Audio streams from freely-downloadable sample
/// MP3s (SoundHelix demo songs, CORS-enabled) so the player really
/// plays without any account or API key.
abstract class MusicPlaylist {
  static const tracks = [
    MusicTrack(
      id: 'song-1',
      title: 'Ghibli No Umi',
      artist: 'Nanbaka',
      album: 'Demo Singles',
      duration: Duration(minutes: 6, seconds: 12),
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    ),
    MusicTrack(
      id: 'song-2',
      title: 'Midnight Reverie',
      artist: 'Pritjent Ensemble',
      album: 'Demo Singles',
      duration: Duration(minutes: 7, seconds: 4),
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
    ),
    MusicTrack(
      id: 'song-3',
      title: 'Paper Lanterns',
      artist: 'Nanbaka',
      album: 'Demo Singles',
      duration: Duration(minutes: 5, seconds: 44),
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
    ),
  ];
}
