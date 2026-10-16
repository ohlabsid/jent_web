import 'package:jent_web/domain/entities/music_playlist_info.dart';
import 'package:jent_web/domain/entities/music_track.dart';

abstract class MusicEvent {}

class ToggleMusicPlayer extends MusicEvent {}

class CloseMusicPlayer extends MusicEvent {}

class MinimizeMusicPlayer extends MusicEvent {}

class ExpandMusicPlayer extends MusicEvent {}

class SelectMusicTrack extends MusicEvent {
  final int index;

  SelectMusicTrack(this.index);
}

class ToggleMusicPlayback extends MusicEvent {}

class NextMusicTrack extends MusicEvent {}

class PreviousMusicTrack extends MusicEvent {}

class SeekMusicPosition extends MusicEvent {
  final Duration position;

  SeekMusicPosition(this.position);
}

class MusicLibrarySearchChanged extends MusicEvent {
  final String query;

  MusicLibrarySearchChanged(this.query);
}

class MusicSidebarSelectionChanged extends MusicEvent {
  final MusicSidebarSelection selection;

  MusicSidebarSelectionChanged(this.selection);
}

class SelectMusicPlaylist extends MusicEvent {
  final String? playlistId;

  /// Null clears the playlist filter (shows the whole library).
  SelectMusicPlaylist(this.playlistId);
}

class MusicLibraryRequested extends MusicEvent {
  final bool force;

  MusicLibraryRequested({this.force = false});
}

/// Internal: remote library fetch finished.
class MusicLibraryLoaded extends MusicEvent {
  final List<MusicTrack> tracks;
  final List<(MusicPlaylistInfo, List<String>)> playlists;

  MusicLibraryLoaded(this.tracks, this.playlists);
}

enum MusicSidebarSelection { songs, albums, artists }

/// Internal: audio backend reported a new position.
class MusicPositionUpdated extends MusicEvent {
  final Duration position;

  MusicPositionUpdated(this.position);
}

/// Internal: audio backend reported the track duration.
class MusicDurationUpdated extends MusicEvent {
  final Duration? duration;

  MusicDurationUpdated(this.duration);
}

/// Internal: audio backend reported playing state.
class MusicPlayingUpdated extends MusicEvent {
  final bool isPlaying;

  MusicPlayingUpdated(this.isPlaying);
}
