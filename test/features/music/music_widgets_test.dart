import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jent_web/core/widgets/window/window_title_bar.dart';
import 'package:jent_web/domain/entities/music_playlist_info.dart';
import 'package:jent_web/domain/entities/music_track.dart';
import 'package:jent_web/features/music/bloc/music_bloc.dart';
import 'package:jent_web/features/music/bloc/music_event.dart';
import 'package:jent_web/features/music/view/music_artwork.dart';
import 'package:jent_web/features/music/view/music_controls.dart';
import 'package:jent_web/features/music/view/music_library_body.dart';
import 'package:jent_web/features/music/view/music_window_overlay.dart';
import 'package:jent_web/data/datasources/music_remote_datasource.dart';
import 'package:jent_web/l10n/app_localizations.dart';

import 'fake_music_audio_service.dart';

Widget l10nWrap(Widget child, MusicBloc bloc) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: BlocProvider.value(
      value: bloc,
      child: Scaffold(body: child),
    ),
  );
}

MusicBloc openBloc(FakeMusicAudioService audio) {
  final bloc = MusicBloc(audio, MusicRemoteDataSource());
  bloc.add(ToggleMusicPlayer());
  return bloc;
}

void main() {
  group('formatTrackTime', () {
    test('formats durations as m:ss', () {
      expect(formatTrackTime(Duration.zero), '0:00');
      expect(formatTrackTime(const Duration(seconds: 7)), '0:07');
      expect(
        formatTrackTime(const Duration(minutes: 5, seconds: 26)),
        '5:26',
      );
    });
  });

  group('MusicWindowOverlay library', () {
    testWidgets('shows sidebar, tracks, and the now-playing bar',
        (tester) async {
      final audio = FakeMusicAudioService();
      addTearDown(audio.dispose);
      final bloc = openBloc(audio);
      addTearDown(bloc.close);

      await tester.pumpWidget(
        l10nWrap(
          const Stack(children: [MusicWindowOverlay()]),
          bloc,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Songs'), findsOneWidget);
      expect(find.text('Albums'), findsOneWidget);
      expect(find.text('Artists'), findsOneWidget);
      expect(find.text('Ghibli No Umi'), findsWidgets);
      expect(find.byType(MusicLibraryBody), findsOneWidget);
      // Bottom bar transport: idle play button before any playback.
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('tapping a row plays that track', (tester) async {
      final audio = FakeMusicAudioService();
      addTearDown(audio.dispose);
      final bloc = openBloc(audio);
      addTearDown(bloc.close);

      await tester.pumpWidget(
        l10nWrap(
          const Stack(children: [MusicWindowOverlay()]),
          bloc,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const ValueKey('music-row-2')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(bloc.state.musicTrackIndex, 2);
      expect(audio.playUrlCalls, 1);
    });

    testWidgets('search filters the list', (tester) async {
      final audio = FakeMusicAudioService();
      addTearDown(audio.dispose);
      final bloc = openBloc(audio);
      addTearDown(bloc.close);

      await tester.pumpWidget(
        l10nWrap(
          const Stack(children: [MusicWindowOverlay()]),
          bloc,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(
        find.byKey(const ValueKey('music-library-search')),
        'reverie',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Midnight Reverie'), findsWidgets);
      expect(find.byKey(const ValueKey('music-row-0')), findsNothing);
      expect(find.byKey(const ValueKey('music-row-1')), findsOneWidget);
    });

    testWidgets('albums view groups tracks under album headers',
        (tester) async {
      final audio = FakeMusicAudioService();
      addTearDown(audio.dispose);
      final bloc = openBloc(audio);
      addTearDown(bloc.close);

      await tester.pumpWidget(
        l10nWrap(
          const Stack(children: [MusicWindowOverlay()]),
          bloc,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const ValueKey('music-nav-albums')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Demo Singles'), findsWidgets);
      expect(find.text('Ghibli No Umi'), findsWidgets);
    });

    testWidgets('playlist tile filters the list to its tracks',
        (tester) async {
      final audio = FakeMusicAudioService();
      addTearDown(audio.dispose);
      final bloc = openBloc(audio);
      addTearDown(bloc.close);

      await tester.pumpWidget(
        l10nWrap(
          const Stack(children: [MusicWindowOverlay()]),
          bloc,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      bloc.add(
        MusicLibraryLoaded(
          const [
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
          ],
          const [
            (
              MusicPlaylistInfo(id: 'p1', name: 'Faves'),
              <String>['r1'],
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Faves'), findsOneWidget);
      await tester.tap(find.text('Faves'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Remote One'), findsWidgets);
      expect(find.text('Remote Two'), findsNothing);
      expect(bloc.state.selectedPlaylistId, 'p1');

      bloc.add(CloseMusicPlayer());
      await tester.pump();
    });

    testWidgets('artwork url renders images with placeholder fallback',
        (tester) async {
      final audio = FakeMusicAudioService();
      addTearDown(audio.dispose);
      final bloc = openBloc(audio);
      addTearDown(bloc.close);

      await tester.pumpWidget(
        l10nWrap(
          const Stack(children: [MusicWindowOverlay()]),
          bloc,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Demo tracks have no artwork: placeholders only, no Image.
      expect(find.byType(Image), findsNothing);

      bloc.add(
        MusicLibraryLoaded(
          const [
            MusicTrack(
              id: 'r1',
              title: 'Remote One',
              artist: 'Artist A',
              album: 'Album A',
              duration: Duration(minutes: 2),
              audioUrl: 'https://example.com/r1.mp3',
              artworkUrl: 'https://example.com/r1.jpg',
            ),
          ],
          const [],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Row thumb + now-playing art. flutter_test blocks real HTTP,
      // so the errorBuilder placeholder shows — without crashing.
      expect(find.byType(Image), findsWidgets);
      expect(find.byType(TrackArtwork), findsWidgets);

      bloc.add(CloseMusicPlayer());
      await tester.pump();
    });

    testWidgets('play then pause follows the backend state', (tester) async {
      final audio = FakeMusicAudioService();
      addTearDown(audio.dispose);
      final bloc = openBloc(audio);
      addTearDown(bloc.close);

      await tester.pumpWidget(
        l10nWrap(
          const Stack(children: [MusicWindowOverlay()]),
          bloc,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Idle: play icon. Tap it to start the first track.
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(audio.playUrlCalls, 1);

      // Playing: pause icon, in sync with the backend.
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(bloc.state.isMusicPlaying, isTrue);
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      expect(audio.pauseCalls, 1);

      bloc.add(CloseMusicPlayer());
      await tester.pump();
    });

    testWidgets('window has the shared title bar chrome', (tester) async {
      final audio = FakeMusicAudioService();
      addTearDown(audio.dispose);
      final bloc = openBloc(audio);
      addTearDown(bloc.close);

      await tester.pumpWidget(
        l10nWrap(
          const Stack(children: [MusicWindowOverlay()]),
          bloc,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(WindowTitleBar), findsOneWidget);

      bloc.add(CloseMusicPlayer());
      await tester.pump();
    });
  });
}
