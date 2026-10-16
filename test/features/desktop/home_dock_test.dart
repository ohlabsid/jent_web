import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jent_web/data/datasources/notes_remote_datasource.dart';
import 'package:jent_web/data/datasources/music_remote_datasource.dart';
import 'package:jent_web/features/desktop/widgets/home_dock.dart';
import 'package:jent_web/features/mail/bloc/mail_bloc.dart';
import 'package:jent_web/features/mail/bloc/mail_event.dart';
import 'package:jent_web/features/music/bloc/music_bloc.dart';
import 'package:jent_web/features/music/bloc/music_event.dart';
import 'package:jent_web/features/notes/bloc/notes_bloc.dart';
import 'package:jent_web/features/notes/bloc/notes_event.dart';
import 'package:jent_web/features/photos/bloc/photos_bloc.dart';
import 'package:jent_web/features/photos/bloc/photos_event.dart';
import 'package:jent_web/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jent_web/domain/repositories/music_audio_service.dart';
import 'package:jent_web/domain/usecases/send_email_usecase.dart';

class _MockSendEmail extends Mock implements SendEmailUseCase {}
class _MockAudio extends Mock implements MusicAudioService {}

void main() {
  setUpAll(() => registerFallbackValue(const Duration(seconds: 1)));
  /// The running-app indicator dot under a dock icon: an 8x8 grey
  /// circle. Icon tiles use rounded rectangles, so the circle shape
  /// identifies dots uniquely.
  Finder dockDots() => find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final decoration = w.decoration;
        return decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle;
      });

  late MailBloc mailBloc;
  late NotesBloc notesBloc;
  late MusicBloc musicBloc;
  late PhotosBloc photosBloc;

  Future<void> pumpDock(WidgetTester tester) {
    final audio = _MockAudio();
    when(
      () => audio.positionStream,
    ).thenAnswer((_) => const Stream<Duration>.empty());
    when(
      () => audio.durationStream,
    ).thenAnswer((_) => const Stream<Duration?>.empty());
    when(
      () => audio.playingStream,
    ).thenAnswer((_) => const Stream<bool>.empty());
    when(() => audio.playUrl(any())).thenAnswer((_) async {});
    when(() => audio.play()).thenAnswer((_) async {});
    when(() => audio.pause()).thenAnswer((_) async {});
    when(() => audio.seek(any())).thenAnswer((_) async {});
    when(() => audio.stop()).thenAnswer((_) async {});
    mailBloc = MailBloc(_MockSendEmail());
    notesBloc = NotesBloc(NotesRemoteDataSource());
    musicBloc = MusicBloc(audio, MusicRemoteDataSource());
    photosBloc = PhotosBloc();
    addTearDown(() async {
      await mailBloc.close();
      await notesBloc.close();
      await musicBloc.close();
      await photosBloc.close();
    });
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: mailBloc),
            BlocProvider.value(value: notesBloc),
            BlocProvider.value(value: musicBloc),
            BlocProvider.value(value: photosBloc),
          ],
          child: const Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: HomeDock(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('email dot tracks open, minimize, and close', (tester) async {
    await pumpDock(tester);

    // Launch: nothing running, no dots.
    expect(dockDots(), findsNothing);

    // Open: running app shows the dot.
    mailBloc.add(ToggleOpenEmailMenu());
    await settle(tester);
    expect(mailBloc.state.isShowWindow, isTrue);
    expect(dockDots(), findsOneWidget);

    // Minimize: window hidden but the dot stays (regression test).
    mailBloc.add(ToggleMinimizeEmailMenu());
    await settle(tester);
    expect(mailBloc.state.isMinimizedWindow, isTrue);
    expect(dockDots(), findsOneWidget);

    // Dock tap restores; closing clears the dot.
    mailBloc.add(ToggleOpenEmailMenu());
    await settle(tester);
    expect(mailBloc.state.isShowWindow, isTrue);
    expect(dockDots(), findsOneWidget);
    mailBloc.add(ToggleCloseEmailMenu());
    await settle(tester);
    expect(mailBloc.state.isShowWindow, isFalse);
    expect(dockDots(), findsNothing);
  });

  testWidgets('dock icons toggle their own feature windows', (tester) async {
    await pumpDock(tester);

    // Music toggles open with a dot.
    musicBloc.add(ToggleMusicPlayer());
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(dockDots(), findsOneWidget);

    // Notes asks for the PIN first: still no window, no dot.
    notesBloc.add(ToggleNotesWindow());
    await settle(tester);
    expect(notesBloc.state.isNotesPinVisible, isTrue);
    expect(dockDots(), findsNWidgets(1));

    // Photos PIN gate shows nothing yet either.
    photosBloc.add(TogglePhotosWindow());
    await settle(tester);
    expect(photosBloc.state.isPhotosPinVisible, isTrue);
    expect(dockDots(), findsNWidgets(1));

    // Quiesce the music simulation timer before teardown.
    musicBloc.add(CloseMusicPlayer());
    await settle(tester);
  });
}
