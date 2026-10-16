import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:jent_web/core/widgets/dock/dock_widget.dart';
import 'package:jent_web/data/datasources/music_remote_datasource.dart';
import 'package:jent_web/data/datasources/notes_remote_datasource.dart';
import 'package:jent_web/domain/entities/email_message.dart';
import 'package:jent_web/domain/repositories/email_repository.dart';
import 'package:jent_web/domain/repositories/music_audio_service.dart';
import 'package:jent_web/domain/usecases/send_email_usecase.dart';
import 'package:jent_web/features/mail/bloc/mail_bloc.dart';
import 'package:jent_web/features/mail/bloc/mail_event.dart';
import 'package:jent_web/features/music/bloc/music_bloc.dart';
import 'package:jent_web/features/music/bloc/music_event.dart';
import 'package:jent_web/features/notes/bloc/notes_bloc.dart';
import 'package:jent_web/features/notes/bloc/notes_event.dart';
import 'package:jent_web/features/photos/bloc/photos_bloc.dart';
import 'package:jent_web/features/photos/bloc/photos_event.dart';
import 'package:jent_web/gen/assets.gen.dart';
import 'package:jent_web/l10n/app_localizations.dart';

/// Desktop dock. Each entry reads its own feature bloc, so the dot
/// reflects that window's open/minimized state.
class HomeDock extends StatelessWidget {
  const HomeDock({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final mailActive = context.select<MailBloc, bool>(
      (b) => b.state.isShowWindow || b.state.isMinimizedWindow,
    );
    final notesActive = context.select<NotesBloc, bool>(
      (b) => b.state.isShowNotesWindow || b.state.isNotesMinimized,
    );
    final musicActive = context.select<MusicBloc, bool>(
      (b) => b.state.isShowMusicPlayer || b.state.isMusicMinimized,
    );
    final photosActive = context.select<PhotosBloc, bool>(
      (b) => b.state.isShowPhotosWindow || b.state.isPhotosMinimized,
    );
    final mailOpen = context.select<MailBloc, bool>(
      (b) => b.state.isShowWindow,
    );

    return DockWidget(
      icons: [
        Assets.icFinder.image(
          key: const ValueKey('dock-icon-finder'),
          width: 28,
          height: 28,
        ),
        Assets.icEmail.image(
          key: const ValueKey('dock-icon-email'),
          width: 28,
          height: 28,
        ),
        Assets.icNotes.image(
          key: const ValueKey('dock-icon-notes'),
          width: 28,
          height: 28,
        ),
        Assets.icMusic.image(
          key: const ValueKey('dock-icon-music'),
          width: 28,
          height: 28,
        ),
        Assets.icPhotos.image(
          key: const ValueKey('dock-icon-photos'),
          width: 28,
          height: 28,
        ),
        Assets.icSpotLight.image(
          key: const ValueKey('dock-icon-spotlight'),
          width: 28,
          height: 28,
        ),
      ],
      tooltips: [
        localizations.textFinder,
        localizations.textEmail,
        localizations.textNotes,
        localizations.textMusic,
        localizations.textPhotos,
        localizations.textSpotlight,
      ],
      listDockMinimized: [
        false,
        mailActive,
        notesActive,
        musicActive,
        photosActive,
        false,
      ],
      onIconTapped: (int p1) {
        if (p1 == 1) {
          if (mailOpen) {
            context.read<MailBloc>().add(ToggleCloseEmailMenu());
          } else {
            context.read<MailBloc>().add(ToggleOpenEmailMenu());
          }
        } else if (p1 == 2) {
          context.read<NotesBloc>().add(ToggleNotesWindow());
        } else if (p1 == 3) {
          context.read<MusicBloc>().add(ToggleMusicPlayer());
        } else if (p1 == 4) {
          context.read<PhotosBloc>().add(TogglePhotosWindow());
        }
      },
    );
  }
}

/// No-op email repository so the dock preview never touches the network.
class _PreviewEmailRepository implements EmailRepository {
  @override
  Future<void> send(EmailMessage message) async {}
}

/// Silent audio stub with empty streams so the preview stays
/// hermetic (no native plugins, no network, no timers at startup).
class _PreviewAudioService implements MusicAudioService {
  @override
  Stream<Duration> get positionStream => const Stream.empty();

  @override
  Stream<Duration?> get durationStream => const Stream.empty();

  @override
  Stream<bool> get playingStream => const Stream.empty();

  @override
  Future<void> playUrl(String url) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

Widget _homeDockPreviewRoot({
  required MailBloc mailBloc,
  required NotesBloc notesBloc,
  required MusicBloc musicBloc,
  required PhotosBloc photosBloc,
}) {
  return MaterialApp(
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
        body: Align(alignment: Alignment.bottomCenter, child: HomeDock()),
      ),
    ),
  );
}

MusicBloc _previewMusicBloc(_PreviewAudioService audio) =>
    MusicBloc(audio, MusicRemoteDataSource());

@Preview(name: 'HomeDock - idle', group: 'Dock', size: Size(700, 200))
Widget homeDockIdlePreview() {
  final audio = _PreviewAudioService();
  return _homeDockPreviewRoot(
    mailBloc: MailBloc(SendEmailUseCase(_PreviewEmailRepository())),
    notesBloc: NotesBloc(NotesRemoteDataSource()),
    musicBloc: _previewMusicBloc(audio),
    photosBloc: PhotosBloc(),
  );
}

@Preview(name: 'HomeDock - mail running', group: 'Dock', size: Size(700, 200))
Widget homeDockRunningPreview() {
  final audio = _PreviewAudioService();
  return _homeDockPreviewRoot(
    mailBloc: MailBloc(SendEmailUseCase(_PreviewEmailRepository()))
      ..add(ToggleOpenEmailMenu()),
    notesBloc: NotesBloc(NotesRemoteDataSource()),
    musicBloc: _previewMusicBloc(audio),
    photosBloc: PhotosBloc(),
  );
}
