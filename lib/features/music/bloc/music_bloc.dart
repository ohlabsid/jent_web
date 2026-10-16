import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:jent_web/data/datasources/music_remote_datasource.dart';
import 'package:jent_web/domain/entities/music_track.dart';
import 'package:jent_web/domain/repositories/music_audio_service.dart';
import 'package:jent_web/features/music/bloc/music_event.dart';
import 'package:jent_web/features/music/bloc/music_state.dart';

/// Music library player: streams tracks through [MusicAudioService]
/// (just_audio in production, fake in tests). The catalog comes from
/// Supabase when configured ([MusicRemoteDataSource]); otherwise the
/// bundled [MusicPlaylist.tracks] demo fallback plays.
@injectable
class MusicBloc extends Bloc<MusicEvent, MusicState> {
  final MusicAudioService _audio;
  final MusicRemoteDataSource _remote;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<bool>? _playingSub;

  MusicBloc(this._audio, this._remote) : super(const MusicState()) {
    on<ToggleMusicPlayer>(_onToggle);
    on<CloseMusicPlayer>(_onClose);
    on<MinimizeMusicPlayer>(_onMinimize);
    on<ExpandMusicPlayer>(_onExpand);
    on<SelectMusicTrack>(_onSelect);
    on<ToggleMusicPlayback>(_onTogglePlayback);
    on<NextMusicTrack>(_onNext);
    on<PreviousMusicTrack>(_onPrevious);
    on<SeekMusicPosition>(_onSeek);
    on<MusicLibrarySearchChanged>(_onSearchChanged);
    on<MusicSidebarSelectionChanged>(_onSidebarChanged);
    on<SelectMusicPlaylist>(_onSelectPlaylist);
    on<MusicLibraryRequested>(_onLibraryRequested);
    on<MusicLibraryLoaded>(_onLibraryLoaded);
    on<MusicPositionUpdated>(_onPositionUpdated);
    on<MusicDurationUpdated>(_onDurationUpdated);
    on<MusicPlayingUpdated>(_onPlayingUpdated);

    _positionSub = _audio.positionStream.listen(
      (p) => add(MusicPositionUpdated(p)),
    );
    _durationSub = _audio.durationStream.listen(
      (d) => add(MusicDurationUpdated(d)),
    );
    _playingSub = _audio.playingStream.listen(
      (playing) => add(MusicPlayingUpdated(playing)),
    );
  }

  void _onToggle(ToggleMusicPlayer event, Emitter<MusicState> emit) {
    if (state.isShowMusicPlayer) {
      emit(state.copyWith(isShowMusicPlayer: false));
      return;
    }
    emit(
      state.copyWith(
        isShowMusicPlayer: true,
        isMusicMinimized: false,
        isMusicExpanded: false,
        clearError: true,
      ),
    );
    if (!state.libraryLoaded && !state.libraryLoading) {
      add(MusicLibraryRequested());
    }
    // No autoplay: playback starts only from an explicit user action
    // (transport button or track row) so the play/pause button always
    // matches the real backend state.
  }

  Future<void> _onClose(CloseMusicPlayer event, Emitter<MusicState> emit) async {
    await _audio.stop();
    emit(
      state.copyWith(
        isShowMusicPlayer: false,
        isMusicMinimized: false,
        isMusicExpanded: false,
        isMusicPlaying: false,
        isMusicLoading: false,
        musicPosition: Duration.zero,
        clearDuration: true,
        clearError: true,
      ),
    );
  }

  void _onMinimize(MinimizeMusicPlayer event, Emitter<MusicState> emit) {
    emit(
      state.copyWith(
        isShowMusicPlayer: false,
        isMusicMinimized: true,
        isMusicExpanded: false,
      ),
    );
  }

  void _onExpand(ExpandMusicPlayer event, Emitter<MusicState> emit) {
    emit(state.copyWith(isMusicExpanded: !state.isMusicExpanded));
  }

  Future<void> _onSelect(SelectMusicTrack event, Emitter<MusicState> emit) async {
    if (event.index < 0 || event.index >= state.tracks.length) return;
    final track = state.tracks[event.index];
    emit(
      state.copyWith(
        musicTrackIndex: event.index,
        musicPosition: Duration.zero,
        clearDuration: true,
        isMusicLoading: true,
        isMusicPlaying: false,
        isShowMusicPlayer: true,
        isMusicMinimized: false,
        clearError: true,
      ),
    );
    try {
      await _audio.playUrl(track.audioUrl);
      // Commit the button state here instead of waiting for the
      // backend's playing echo: if that event is ever delayed or
      // dropped, the button would stick on the spinner. The stream
      // handler below just re-confirms this.
      emit(state.copyWith(isMusicPlaying: true, isMusicLoading: false));
    } catch (e) {
      emit(
        state.copyWith(
          isMusicLoading: false,
          isMusicPlaying: false,
          musicError: 'Could not play this track ($e)',
        ),
      );
    }
  }

  Future<void> _onTogglePlayback(
    ToggleMusicPlayback event,
    Emitter<MusicState> emit,
  ) async {
    if (state.isMusicPlaying) {
      try {
        await _audio.pause();
        emit(state.copyWith(isMusicPlaying: false));
      } catch (e) {
        emit(state.copyWith(musicError: 'Could not pause ($e)'));
      }
      return;
    }
    // Resume when a track was loaded and paused mid-way; otherwise
    // (re)start the current track.
    if (state.musicPosition > Duration.zero &&
        (state.musicDuration == null ||
            state.musicPosition < state.musicDuration!)) {
      try {
        await _audio.play();
        emit(state.copyWith(isMusicPlaying: true));
      } catch (e) {
        emit(state.copyWith(musicError: 'Could not resume ($e)'));
      }
      return;
    }
    add(SelectMusicTrack(state.musicTrackIndex));
  }

  void _onNext(NextMusicTrack event, Emitter<MusicState> emit) {
    final visible = _visibleIndices;
    if (visible.isEmpty) return;
    final pos = visible.indexOf(state.musicTrackIndex);
    final next = visible[(pos + 1) % visible.length];
    add(SelectMusicTrack(next));
  }

  void _onPrevious(PreviousMusicTrack event, Emitter<MusicState> emit) {
    if (state.musicPosition > const Duration(seconds: 3)) {
      add(SeekMusicPosition(Duration.zero));
      return;
    }
    final visible = _visibleIndices;
    if (visible.isEmpty) return;
    final pos = visible.indexOf(state.musicTrackIndex);
    final previous = visible[(pos - 1 + visible.length) % visible.length];
    add(SelectMusicTrack(previous));
  }

  /// Track indices in the current playlist filter (whole library
  /// when no playlist is selected). Transport steps within this.
  List<int> get _visibleIndices {
    final selected = state.selectedPlaylistId;
    if (selected == null) {
      return List.generate(state.tracks.length, (i) => i);
    }
    final ids = <String>{};
    for (final entry in state.playlists) {
      if (entry.$1.id == selected) ids.addAll(entry.$2);
    }
    final indices = <int>[];
    for (var i = 0; i < state.tracks.length; i++) {
      if (ids.contains(state.tracks[i].id)) indices.add(i);
    }
    return indices.isEmpty
        ? List.generate(state.tracks.length, (i) => i)
        : indices;
  }

  Future<void> _onSeek(SeekMusicPosition event, Emitter<MusicState> emit) async {
    emit(state.copyWith(musicPosition: event.position));
    try {
      await _audio.seek(event.position);
    } catch (e) {
      emit(state.copyWith(musicError: 'Seek failed ($e)'));
    }
  }

  void _onSearchChanged(
    MusicLibrarySearchChanged event,
    Emitter<MusicState> emit,
  ) {
    emit(state.copyWith(libraryQuery: event.query));
  }

  void _onSidebarChanged(
    MusicSidebarSelectionChanged event,
    Emitter<MusicState> emit,
  ) {
    emit(
      state.copyWith(
        sidebarSelection: event.selection,
        clearPlaylist: true,
      ),
    );
  }

  void _onSelectPlaylist(SelectMusicPlaylist event, Emitter<MusicState> emit) {
    emit(
      state.copyWith(
        selectedPlaylistId: event.playlistId,
        clearPlaylist: event.playlistId == null,
      ),
    );
  }

  Future<void> _onLibraryRequested(
    MusicLibraryRequested event,
    Emitter<MusicState> emit,
  ) async {
    if (state.libraryLoading) return;
    if (state.libraryLoaded && !event.force) return;
    emit(state.copyWith(libraryLoading: true, clearError: true));
    final tracks = await _remote.fetchTracks();
    if (tracks == null || tracks.isEmpty) {
      // Offline/unconfigured/empty: keep the demo fallback.
      emit(state.copyWith(libraryLoading: false, libraryLoaded: true));
      return;
    }
    final playlists = await _remote.fetchPlaylists();
    add(MusicLibraryLoaded(tracks, playlists ?? const []));
  }

  void _onLibraryLoaded(MusicLibraryLoaded event, Emitter<MusicState> emit) {
    final selectedStillThere = event.playlists.any(
      (entry) => entry.$1.id == state.selectedPlaylistId,
    );
    // A refresh while a track is active swaps the catalog underneath
    // the playing audio; replay index 0 so the backend matches the
    // newly loaded list.
    final wasActive = state.isMusicPlaying || state.isMusicLoading;
    emit(
      state.copyWith(
        tracks: event.tracks,
        playlists: event.playlists,
        clearPlaylist: !selectedStillThere,
        musicTrackIndex: 0,
        musicPosition: Duration.zero,
        clearDuration: true,
        libraryLoaded: true,
        libraryLoading: false,
      ),
    );
    if (wasActive) add(SelectMusicTrack(0));
  }

  void _onPositionUpdated(MusicPositionUpdated event, Emitter<MusicState> emit) {
    if (state.tracks.isEmpty) return;
    final current = state.tracks[state.musicTrackIndex.clamp(
      0,
      state.tracks.length - 1,
    )];
    final duration = state.musicDuration ?? current.duration;
    if (event.position >= duration) {
      add(NextMusicTrack());
      return;
    }
    emit(state.copyWith(musicPosition: event.position));
  }

  void _onDurationUpdated(MusicDurationUpdated event, Emitter<MusicState> emit) {
    // Duration alone doesn't clear the loading spinner: the button
    // must keep showing progress until the backend confirms playback
    // (or reports an error), otherwise it flashes a play icon for a
    // track that hasn't started yet.
    emit(state.copyWith(musicDuration: event.duration));
  }

  void _onPlayingUpdated(MusicPlayingUpdated event, Emitter<MusicState> emit) {
    emit(
      state.copyWith(
        isMusicPlaying: event.isPlaying,
        isMusicLoading: false,
      ),
    );
  }

  @override
  Future<void> close() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    return super.close();
  }
}
