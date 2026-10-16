import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jent_web/data/datasources/music_remote_datasource.dart';
import 'package:jent_web/core/widgets/window/window_title_bar.dart';
import 'package:jent_web/features/music/bloc/music_bloc.dart';
import 'package:jent_web/features/music/bloc/music_event.dart';
import 'package:jent_web/features/music/view/music_window_overlay.dart';
import 'package:jent_web/l10n/app_localizations.dart';

import 'fake_music_audio_service.dart';

void main() {
  testWidgets('dragging the title bar moves the music window', (
    tester,
  ) async {
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
    await tester.pump(const Duration(milliseconds: 400));

    Offset windowPos() {
      final positioned = tester.widget<Positioned>(
        find
            .ancestor(
              of: find.byType(WindowTitleBar),
              matching: find.byType(Positioned),
            )
            .first,
      );
      return Offset(positioned.left!, positioned.top!);
    }

    final before = windowPos();
    // Drag the shared title-bar area: deltas accumulate, then pump
    // twice to measure (one rebuild + one settle). The title bar
    // (not the list body, which would scroll) moves the window.
    await tester.timedDrag(
      find.byType(WindowTitleBar),
      const Offset(-100, 60),
      const Duration(milliseconds: 300),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final after = windowPos();
    expect(after.dx, lessThan(before.dx));
    expect(after.dy, greaterThan(before.dy));

    bloc.add(CloseMusicPlayer());
    await tester.pump();
  });
}
