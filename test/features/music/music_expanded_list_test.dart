import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jent_web/data/datasources/music_remote_datasource.dart';
import 'package:jent_web/features/music/bloc/music_bloc.dart';
import 'package:jent_web/features/music/bloc/music_event.dart';
import 'package:jent_web/features/music/view/music_window_overlay.dart';
import 'package:jent_web/l10n/app_localizations.dart';

import 'fake_music_audio_service.dart';

void main() {
  testWidgets('library lists every track and tapping selects one',
      (tester) async {
    final audio = FakeMusicAudioService();
    addTearDown(audio.dispose);
    final bloc = MusicBloc(audio, MusicRemoteDataSource());
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: BlocProvider.value(
          value: bloc,
          child: const Scaffold(
            body: Stack(children: [MusicWindowOverlay()]),
          ),
        ),
      ),
    );

    bloc.add(ToggleMusicPlayer());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Ghibli No Umi'), findsWidgets);
    expect(find.text('Midnight Reverie'), findsWidgets);
    expect(find.text('Paper Lanterns'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('music-row-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(bloc.state.musicTrackIndex, 1);

    bloc.add(CloseMusicPlayer());
    await tester.pump();
  });
}
