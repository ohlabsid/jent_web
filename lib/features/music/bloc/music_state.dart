import 'package:jent_web/domain/entities/music_playlist_info.dart';
import 'package:jent_web/domain/entities/music_track.dart';
import 'package:jent_web/features/music/bloc/music_event.dart';

class MusicState {
  final bool isShowMusicPlayer;
  final bool isMusicMinimized;
  final bool isMusicExpanded;
  final bool isMusicPlaying;
  final bool isMusicLoading;
  final int musicTrackIndex;
  final Duration musicPosition;
  final Duration? musicDuration;
  final String libraryQuery;
  final MusicSidebarSelection sidebarSelection;

  /// Library tracks: remote rows when Supabase has them, otherwise
  /// the bundled [MusicPlaylist.tracks] demo fallback.
  final List<MusicTrack> tracks;

  /// Remote playlists (id + ordered track ids). Defaults to the
  /// offline "Demo Singles" entry covering the whole library.
  final List<(MusicPlaylistInfo, List<String>)> playlists;

  /// Null = whole library; otherwise only this playlist's tracks.
  final String? selectedPlaylistId;
  final bool libraryLoaded;
  final bool libraryLoading;
  final String? musicError;

  const MusicState({
    this.isShowMusicPlayer = false,
    this.isMusicMinimized = false,
    this.isMusicExpanded = false,
    this.isMusicPlaying = false,
    this.isMusicLoading = false,
    this.musicTrackIndex = 0,
    this.musicPosition = Duration.zero,
    this.musicDuration,
    this.libraryQuery = '',
    this.sidebarSelection = MusicSidebarSelection.songs,
    this.tracks = MusicPlaylist.tracks,
    this.playlists = const [
      (MusicPlaylistInfo(id: 'demo', name: 'Demo Singles'), <String>[]),
    ],
    this.selectedPlaylistId,
    this.libraryLoaded = false,
    this.libraryLoading = false,
    this.musicError,
  });

  MusicState copyWith({
    bool? isShowMusicPlayer,
    bool? isMusicMinimized,
    bool? isMusicExpanded,
    bool? isMusicPlaying,
    bool? isMusicLoading,
    int? musicTrackIndex,
    Duration? musicPosition,
    Duration? musicDuration,
    bool clearDuration = false,
    String? libraryQuery,
    MusicSidebarSelection? sidebarSelection,
    List<MusicTrack>? tracks,
    List<(MusicPlaylistInfo, List<String>)>? playlists,
    String? selectedPlaylistId,
    bool clearPlaylist = false,
    bool? libraryLoaded,
    bool? libraryLoading,
    String? musicError,
    bool clearError = false,
  }) {
    return MusicState(
      isShowMusicPlayer: isShowMusicPlayer ?? this.isShowMusicPlayer,
      isMusicMinimized: isMusicMinimized ?? this.isMusicMinimized,
      isMusicExpanded: isMusicExpanded ?? this.isMusicExpanded,
      isMusicPlaying: isMusicPlaying ?? this.isMusicPlaying,
      isMusicLoading: isMusicLoading ?? this.isMusicLoading,
      musicTrackIndex: musicTrackIndex ?? this.musicTrackIndex,
      musicPosition: musicPosition ?? this.musicPosition,
      musicDuration: clearDuration ? null : (musicDuration ?? this.musicDuration),
      libraryQuery: libraryQuery ?? this.libraryQuery,
      sidebarSelection: sidebarSelection ?? this.sidebarSelection,
      tracks: tracks ?? this.tracks,
      playlists: playlists ?? this.playlists,
      selectedPlaylistId:
          clearPlaylist ? null : (selectedPlaylistId ?? this.selectedPlaylistId),
      libraryLoaded: libraryLoaded ?? this.libraryLoaded,
      libraryLoading: libraryLoading ?? this.libraryLoading,
      musicError: clearError ? null : (musicError ?? this.musicError),
    );
  }
}
