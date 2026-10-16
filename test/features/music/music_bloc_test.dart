import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jent_web/data/datasources/music_remote_datasource.dart';
import 'package:jent_web/domain/entities/music_playlist_info.dart';
import 'package:jent_web/domain/entities/music_track.dart';
import 'package:jent_web/features/music/bloc/music_bloc.dart';
import 'package:jent_web/features/music/bloc/music_event.dart';
import 'package:jent_web/features/music/bloc/music_state.dart';
import 'package:mocktail/mocktail.dart';

import 'fake_music_audio_service.dart';

class _MockRemote extends Mock implements MusicRemoteDataSource {}

const _remoteTracks = [
  MusicTrack(
    id: 'r1',
    title: 'Remote One',
    artist: 'Artist A',
    album: 'Album A',
    duration: Duration(minutes: 2),
    audioUrl: 'https://example.com/r1.mp3',
  ),
  MusicTrack(
    id: 'r2',
    title: 'Remote Two',
    artist: 'Artist B',
    album: 'Album B',
    duration: Duration(minutes: 3),
    audioUrl: 'https://example.com/r2.mp3',
  ),
  MusicTrack(
    id: 'r3',
    title: 'Remote Three',
    artist: 'Artist A',
    album: 'Album A',
    duration: Duration(minutes: 4),
    audioUrl: 'https://example.com/r3.mp3',
  ),
];

const _remotePlaylists = [
  (
    MusicPlaylistInfo(id: 'p1', name: 'Faves'),
    <String>['r1', 'r3'],
  ),
];

void main() {
  late FakeMusicAudioService audio;
  late _MockRemote remote;

  setUp(() {
    audio = FakeMusicAudioService();
    addTearDown(audio.dispose);
    remote = _MockRemote();
    // Offline by default: the demo fallback plays.
    when(() => remote.fetchTracks()).thenAnswer((_) async => null);
    when(() => remote.fetchPlaylists()).thenAnswer((_) async => null);
  });

  MusicBloc buildBloc() => MusicBloc(audio, remote);

  group('music player', () {
    blocTest<MusicBloc, MusicState>(
      'toggling shows the window without autoplaying',
      build: buildBloc,
      act: (bloc) => bloc.add(ToggleMusicPlayer()),
      expect: () => [
        isA<MusicState>()
            .having((s) => s.isShowMusicPlayer, 'shown', true)
            .having((s) => s.isMusicMinimized, 'minimized', false)
            .having((s) => s.isMusicLoading, 'loading', false)
            .having((s) => s.isMusicPlaying, 'playing', false),
        // Library fetch starts (offline: falls back to the demo list).
        isA<MusicState>()
            .having((s) => s.libraryLoading, 'libLoading', true),
        isA<MusicState>()
            .having((s) => s.libraryLoaded, 'libLoaded', true)
            .having((s) => s.libraryLoading, 'libLoading', false)
            .having((s) => s.isMusicPlaying, 'playing', false),
      ],
      verify: (_) => expect(audio.playUrlCalls, 0),
    );

    blocTest<MusicBloc, MusicState>(
      'pressing play from idle starts the current track',
      build: buildBloc,
      seed: () => const MusicState(
        isShowMusicPlayer: true,
        libraryLoaded: true,
      ),
      act: (bloc) => bloc.add(ToggleMusicPlayback()),
      expect: () => [
        isA<MusicState>()
            .having((s) => s.musicTrackIndex, 'track', 0)
            .having((s) => s.isMusicLoading, 'loading', true),
        // Button commits as soon as the backend call succeeds,
        // without waiting for its stream echoes.
        isA<MusicState>()
            .having((s) => s.isMusicPlaying, 'playing', true)
            .having((s) => s.isMusicLoading, 'loading', false),
        isA<MusicState>()
            .having((s) => s.musicDuration, 'duration', audio.autoDuration),
        isA<MusicState>().having((s) => s.isMusicPlaying, 'playing', true),
      ],
      verify: (_) =>
          expect(audio.lastUrl, MusicPlaylist.tracks.first.audioUrl),
    );

    blocTest<MusicBloc, MusicState>(
      'toggling a visible window hides it but keeps playback',
      build: buildBloc,
      seed: () => const MusicState(
        isShowMusicPlayer: true,
        isMusicPlaying: true,
        musicDuration: Duration(minutes: 3),
        libraryLoaded: true,
      ),
      act: (bloc) => bloc.add(ToggleMusicPlayer()),
      expect: () => [
        isA<MusicState>()
            .having((s) => s.isShowMusicPlayer, 'shown', false)
            .having((s) => s.isMusicPlaying, 'playing', true),
      ],
    );

    blocTest<MusicBloc, MusicState>(
      'minimize hides the window, toggle restores without replaying',
      build: buildBloc,
      seed: () => const MusicState(
        isShowMusicPlayer: true,
        isMusicPlaying: true,
        musicDuration: Duration(minutes: 3),
        libraryLoaded: true,
      ),
      act: (bloc) async {
        bloc.add(MinimizeMusicPlayer());
        await Future<void>.delayed(Duration.zero);
        bloc.add(ToggleMusicPlayer());
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [
        isA<MusicState>()
            .having((s) => s.isShowMusicPlayer, 'shown', false)
            .having((s) => s.isMusicMinimized, 'minimized', true),
        isA<MusicState>()
            .having((s) => s.isShowMusicPlayer, 'shown', true)
            .having((s) => s.isMusicMinimized, 'minimized', false),
      ],
      verify: (_) => expect(audio.playUrlCalls, 0),
    );

    blocTest<MusicBloc, MusicState>(
      'expand toggles the wide library view',
      build: buildBloc,
      seed: () => const MusicState(isShowMusicPlayer: true),
      act: (bloc) async {
        bloc
          ..add(ExpandMusicPlayer())
          ..add(ExpandMusicPlayer());
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [
        isA<MusicState>()
            .having((s) => s.isMusicExpanded, 'expanded', true),
        isA<MusicState>()
            .having((s) => s.isMusicExpanded, 'expanded', false),
      ],
    );

    blocTest<MusicBloc, MusicState>(
      'close stops the backend and resets position',
      build: buildBloc,
      seed: () => const MusicState(
        isShowMusicPlayer: true,
        isMusicPlaying: true,
        musicPosition: Duration(seconds: 42),
        musicDuration: Duration(minutes: 3),
      ),
      act: (bloc) => bloc.add(CloseMusicPlayer()),
      expect: () => [
        isA<MusicState>()
            .having((s) => s.isShowMusicPlayer, 'shown', false)
            .having((s) => s.isMusicPlaying, 'playing', false)
            .having((s) => s.musicPosition, 'pos', Duration.zero),
        // Backend echoes playing=false after stop; values unchanged.
        isA<MusicState>()
            .having((s) => s.isMusicPlaying, 'playing', false),
      ],
      verify: (_) => expect(audio.stopCalls, 1),
    );

    blocTest<MusicBloc, MusicState>(
      'selecting a track plays its stream url',
      build: buildBloc,
      act: (bloc) => bloc.add(SelectMusicTrack(2)),
      expect: () => [
        isA<MusicState>()
            .having((s) => s.musicTrackIndex, 'track', 2)
            .having((s) => s.musicPosition, 'pos', Duration.zero)
            .having((s) => s.isShowMusicPlayer, 'shown', true),
        // Button commits as soon as the backend call succeeds,
        // without waiting for its stream echoes.
        isA<MusicState>()
            .having((s) => s.isMusicPlaying, 'playing', true)
            .having((s) => s.isMusicLoading, 'loading', false),
        isA<MusicState>()
            .having((s) => s.musicDuration, 'duration', audio.autoDuration),
        isA<MusicState>().having((s) => s.isMusicPlaying, 'playing', true),
      ],
      verify: (_) =>
          expect(audio.lastUrl, MusicPlaylist.tracks[2].audioUrl),
    );

    blocTest<MusicBloc, MusicState>(
      'switching tracks mid-load ends on the latest track',
      build: buildBloc,
      seed: () => const MusicState(
        isShowMusicPlayer: true,
        libraryLoaded: true,
      ),
      act: (bloc) {
        bloc
          ..add(SelectMusicTrack(0))
          ..add(SelectMusicTrack(2));
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [
        // First selection starts loading track 0...
        isA<MusicState>()
            .having((s) => s.musicTrackIndex, 'track', 0)
            .having((s) => s.isMusicLoading, 'loading', true),
        // ...backend echoes interleave, then selection 2 wins...
        isA<MusicState>(),
        isA<MusicState>(),
        isA<MusicState>(),
        isA<MusicState>(),
        isA<MusicState>(),
        isA<MusicState>(),
        // ...and playback confirms on track 2.
        isA<MusicState>()
            .having((s) => s.musicTrackIndex, 'track', 2)
            .having((s) => s.isMusicPlaying, 'playing', true)
            .having((s) => s.isMusicLoading, 'loading', false),
      ],
      verify: (_) {
        expect(audio.lastUrl, MusicPlaylist.tracks[2].audioUrl);
        expect(audio.playUrlCalls, 2);
      },
    );

    blocTest<MusicBloc, MusicState>(
      'a failed load shows an error and later selections still play',
      build: () {
        audio = _FlakyAudio();
        addTearDown(audio.dispose);
        return buildBloc();
      },
      seed: () => const MusicState(
        isShowMusicPlayer: true,
        libraryLoaded: true,
      ),
      act: (bloc) async {
        bloc.add(SelectMusicTrack(0));
        await Future<void>.delayed(Duration.zero);
        bloc.add(SelectMusicTrack(1));
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [
        isA<MusicState>()
            .having((s) => s.musicTrackIndex, 'track', 0)
            .having((s) => s.isMusicLoading, 'loading', true),
        // Timeout surfaces as an error instead of a stuck spinner.
        isA<MusicState>()
            .having((s) => s.isMusicLoading, 'loading', false)
            .having((s) => s.musicError, 'error', contains('too long')),
        // The queue is unblocked: the next tap plays normally.
        isA<MusicState>()
            .having((s) => s.musicTrackIndex, 'track', 1)
            .having((s) => s.isMusicLoading, 'loading', true),
        isA<MusicState>()
            .having((s) => s.isMusicPlaying, 'playing', true)
            .having((s) => s.isMusicLoading, 'loading', false),
        isA<MusicState>(),
        isA<MusicState>(),
      ],
      verify: (_) => expect(audio.lastUrl, MusicPlaylist.tracks[1].audioUrl),
    );

    blocTest<MusicBloc, MusicState>(
      'ignores out-of-range track selection',
      build: buildBloc,
      act: (bloc) => bloc.add(SelectMusicTrack(99)),
      expect: () => [],
      verify: (_) => expect(audio.playUrlCalls, 0),
    );

    blocTest<MusicBloc, MusicState>(
      'play failure surfaces an error instead of hanging on loading',
      build: () {
        audio = _FailingAudio();
        addTearDown(audio.dispose);
        return buildBloc();
      },
      act: (bloc) => bloc.add(SelectMusicTrack(0)),
      expect: () => [
        isA<MusicState>()
            .having((s) => s.isMusicLoading, 'loading', true),
        isA<MusicState>()
            .having((s) => s.isMusicLoading, 'loading', false)
            .having((s) => s.musicError, 'error', isNotNull),
      ],
    );

    blocTest<MusicBloc, MusicState>(
      'pause then resume reuses the loaded stream',
      build: buildBloc,
      seed: () => const MusicState(
        isShowMusicPlayer: true,
        isMusicPlaying: true,
        musicPosition: Duration(seconds: 10),
        musicDuration: Duration(minutes: 3),
      ),
      act: (bloc) async {
        bloc.add(ToggleMusicPlayback());
        await Future<void>.delayed(Duration.zero);
        bloc.add(ToggleMusicPlayback());
      },
      wait: const Duration(milliseconds: 50),
      verify: (_) {
        expect(audio.pauseCalls, 1);
        expect(audio.playCalls, 1);
        expect(audio.playUrlCalls, 0);
      },
    );

    blocTest<MusicBloc, MusicState>(
      'seek forwards to the backend',
      build: buildBloc,
      act: (bloc) =>
          bloc.add(SeekMusicPosition(const Duration(seconds: 30))),
      expect: () => [
        isA<MusicState>()
            .having((s) => s.musicPosition, 'pos', const Duration(seconds: 30)),
        isA<MusicState>()
            .having((s) => s.musicPosition, 'pos', const Duration(seconds: 30)),
      ],
      verify: (_) =>
          expect(audio.seeks, [const Duration(seconds: 30)]),
    );

    blocTest<MusicBloc, MusicState>(
      'previous restarts the track when played past 3 seconds',
      build: buildBloc,
      seed: () => const MusicState(
        isShowMusicPlayer: true,
        musicTrackIndex: 1,
        musicPosition: Duration(seconds: 10),
        musicDuration: Duration(minutes: 3),
      ),
      act: (bloc) => bloc.add(PreviousMusicTrack()),
      expect: () => [
        isA<MusicState>().having((s) => s.musicPosition, 'pos', Duration.zero),
        isA<MusicState>().having((s) => s.musicPosition, 'pos', Duration.zero),
      ],
      verify: (_) => expect(audio.playUrlCalls, 0),
    );

    blocTest<MusicBloc, MusicState>(
      'reaching the end auto-advances to the next track',
      build: buildBloc,
      seed: () => const MusicState(
        isShowMusicPlayer: true,
        isMusicPlaying: true,
        musicTrackIndex: 0,
        musicDuration: Duration(minutes: 3),
      ),
      act: (bloc) => bloc.add(
        MusicPositionUpdated(
          const Duration(minutes: 3, seconds: 1),
        ),
      ),
      expect: () => [
        isA<MusicState>()
            .having((s) => s.musicTrackIndex, 'track', 1)
            .having((s) => s.musicPosition, 'pos', Duration.zero),
        isA<MusicState>(),
        isA<MusicState>(),
        isA<MusicState>(),
      ],
      verify: (_) =>
          expect(audio.lastUrl, MusicPlaylist.tracks[1].audioUrl),
    );

    blocTest<MusicBloc, MusicState>(
      'library search and sidebar selection are stored',
      build: buildBloc,
      act: (bloc) {
        bloc
          ..add(MusicLibrarySearchChanged('ghibli'))
          ..add(
            MusicSidebarSelectionChanged(MusicSidebarSelection.albums),
          );
      },
      expect: () => [
        isA<MusicState>()
            .having((s) => s.libraryQuery, 'query', 'ghibli'),
        isA<MusicState>().having(
          (s) => s.sidebarSelection,
          'sidebar',
          MusicSidebarSelection.albums,
        ),
      ],
    );

    blocTest<MusicBloc, MusicState>(
      'remote tracks and playlists replace the fallback on first open',
      build: () {
        when(() => remote.fetchTracks())
            .thenAnswer((_) async => _remoteTracks);
        when(() => remote.fetchPlaylists())
            .thenAnswer((_) async => _remotePlaylists);
        return buildBloc();
      },
      act: (bloc) => bloc.add(ToggleMusicPlayer()),
      expect: () => [
        isA<MusicState>()
            .having((s) => s.isShowMusicPlayer, 'shown', true),
        isA<MusicState>()
            .having((s) => s.libraryLoading, 'libLoading', true),
        // Remote wins without starting playback: the user presses
        // play explicitly.
        isA<MusicState>()
            .having(
              (s) => s.tracks.map((t) => t.id).toList(),
              'trackIds',
              ['r1', 'r2', 'r3'],
            )
            .having(
              (s) => s.playlists.map((p) => p.$1.name).toList(),
              'playlists',
              ['Faves'],
            )
            .having((s) => s.libraryLoaded, 'libLoaded', true)
            .having((s) => s.isMusicPlaying, 'playing', false),
      ],
      verify: (_) => expect(audio.playUrlCalls, 0),
    );

    blocTest<MusicBloc, MusicState>(
      'empty remote keeps the demo fallback',
      build: () {
        when(() => remote.fetchTracks())
            .thenAnswer((_) async => const <MusicTrack>[]);
        return buildBloc();
      },
      act: (bloc) => bloc.add(MusicLibraryRequested(force: true)),
      expect: () => [
        isA<MusicState>()
            .having((s) => s.libraryLoading, 'libLoading', true),
        isA<MusicState>()
            .having((s) => s.libraryLoaded, 'libLoaded', true)
            .having((s) => s.tracks, 'tracks', MusicPlaylist.tracks),
      ],
      verify: (_) => expect(audio.playUrlCalls, 0),
    );

    blocTest<MusicBloc, MusicState>(
      'selecting a playlist filters next/previous to its tracks',
      build: buildBloc,
      seed: () => const MusicState(
        isShowMusicPlayer: true,
        tracks: _remoteTracks,
        playlists: _remotePlaylists,
        libraryLoaded: true,
      ),
      act: (bloc) async {
        bloc.add(SelectMusicPlaylist('p1'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(NextMusicTrack());
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [
        isA<MusicState>()
            .having((s) => s.selectedPlaylistId, 'playlist', 'p1'),
        // From index 0 (r1, in playlist) next steps to index 2 (r3),
        // skipping r2 which is not in the playlist.
        isA<MusicState>()
            .having((s) => s.musicTrackIndex, 'track', 2),
        isA<MusicState>(),
        isA<MusicState>(),
        isA<MusicState>(),
      ],
      verify: (_) => expect(audio.lastUrl, _remoteTracks[2].audioUrl),
    );

    blocTest<MusicBloc, MusicState>(
      'sidebar selection clears the playlist filter',
      build: buildBloc,
      seed: () => const MusicState(
        tracks: _remoteTracks,
        playlists: _remotePlaylists,
        selectedPlaylistId: 'p1',
        libraryLoaded: true,
      ),
      act: (bloc) => bloc.add(
        MusicSidebarSelectionChanged(MusicSidebarSelection.albums),
      ),
      expect: () => [
        isA<MusicState>()
            .having((s) => s.selectedPlaylistId, 'playlist', isNull)
            .having(
              (s) => s.sidebarSelection,
              'sidebar',
              MusicSidebarSelection.albums,
            ),
      ],
    );
  });
}

class _FailingAudio extends FakeMusicAudioService {
  @override
  Future<void> playUrl(String url) async {
    throw Exception('no network');
  }
}

/// Backend that stalls once (like a hung load) and works after.
class _FlakyAudio extends FakeMusicAudioService {
  var failNext = true;

  @override
  Future<void> playUrl(String url) async {
    if (failNext) {
      failNext = false;
      throw TimeoutException('taking too long to load audio');
    }
    return super.playUrl(url);
  }
}
