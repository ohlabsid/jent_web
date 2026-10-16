import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jent_web/di/injection.dart';
import 'package:jent_web/features/desktop/widgets/home_dock.dart';
import 'package:jent_web/features/desktop/widgets/home_menu_bar.dart';
import 'package:jent_web/features/desktop/window_z_order.dart';
import 'package:jent_web/features/mail/bloc/mail_bloc.dart';
import 'package:jent_web/features/mail/bloc/mail_state.dart';
import 'package:jent_web/features/mail/view/mail_overlay.dart';
import 'package:jent_web/features/music/bloc/music_bloc.dart';
import 'package:jent_web/features/music/bloc/music_state.dart';
import 'package:jent_web/features/music/view/music_window_overlay.dart';
import 'package:jent_web/features/notes/bloc/notes_bloc.dart';
import 'package:jent_web/features/notes/bloc/notes_state.dart';
import 'package:jent_web/features/notes/view/notes_overlay.dart';
import 'package:jent_web/features/notes/view/notes_pin_overlay.dart';
import 'package:jent_web/features/photos/bloc/photos_bloc.dart';
import 'package:jent_web/features/photos/bloc/photos_state.dart';
import 'package:jent_web/features/photos/view/photos_pin_overlay.dart';
import 'package:jent_web/features/photos/view/photos_window_overlay.dart';
import 'package:jent_web/features/wallpaper/bloc/wallpaper_bloc.dart';
import 'package:jent_web/features/wallpaper/bloc/wallpaper_event.dart';
import 'package:jent_web/features/wallpaper/widgets/home_background.dart';
import 'package:jent_web/core/base_page.dart';

/// Desktop shell: provides one bloc per feature and composes their
/// overlays. Features never talk to each other directly; the dock is
/// the only cross-feature reader.

class HomePage extends BasePage {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _windowController;

  /// Window ids, oldest-visible first. The latest opened window sorts
  /// last so it paints on top of the older ones.
  final WindowZOrder _zOrder = WindowZOrder();

  @override
  void initState() {
    super.initState();
    _windowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
  }

  @override
  void dispose() {
    _windowController.dispose();
    super.dispose();
  }

  /// Records a visibility transition; rebuilds only when the
  /// stacking order actually changes.
  void _trackWindow(String id, bool visible) {
    if (_zOrder.setVisible(id, visible)) {
      setState(() {});
    }
  }

  /// Brings a visible window to the front when the user clicks or
  /// drags anywhere inside it. No-op for hidden or already-front
  /// windows, so background rebuilds stay quiet.
  void _focusWindow(String id) {
    if (_zOrder.moveToFront(id)) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<WallpaperBloc>()..add(StartWallpaperRotation()),
        ),
        BlocProvider(create: (_) => getIt<MailBloc>()),
        BlocProvider(create: (_) => getIt<MusicBloc>()),
        BlocProvider(create: (_) => getIt<PhotosBloc>()),
        BlocProvider(create: (_) => getIt<NotesBloc>()),
      ],
      child: Scaffold(
        body: MultiBlocListener(
          listeners: [
            BlocListener<MailBloc, MailState>(
              listenWhen: (prev, curr) =>
                  prev.isShowWindow != curr.isShowWindow ||
                  prev.isMinimizedWindow != curr.isMinimizedWindow,
              listener: (context, state) {
                if (state.isShowWindow) {
                  _windowController.forward();
                } else {
                  _windowController.reverse();
                }
                _trackWindow(
                  'mail',
                  state.isShowWindow || state.isMinimizedWindow,
                );
              },
            ),
            BlocListener<MusicBloc, MusicState>(
              listenWhen: (prev, curr) =>
                  prev.isShowMusicPlayer != curr.isShowMusicPlayer ||
                  prev.isMusicMinimized != curr.isMusicMinimized,
              listener: (context, state) {
                _trackWindow(
                  'music',
                  state.isShowMusicPlayer || state.isMusicMinimized,
                );
              },
            ),
            BlocListener<PhotosBloc, PhotosState>(
              listenWhen: (prev, curr) =>
                  prev.isShowPhotosWindow != curr.isShowPhotosWindow ||
                  prev.isPhotosMinimized != curr.isPhotosMinimized,
              listener: (context, state) {
                _trackWindow(
                  'photos',
                  state.isShowPhotosWindow || state.isPhotosMinimized,
                );
              },
            ),
            BlocListener<NotesBloc, NotesState>(
              listenWhen: (prev, curr) =>
                  prev.isShowNotesWindow != curr.isShowNotesWindow ||
                  prev.isNotesMinimized != curr.isNotesMinimized,
              listener: (context, state) {
                _trackWindow(
                  'notes',
                  state.isShowNotesWindow || state.isNotesMinimized,
                );
              },
            ),
          ],
          child: Stack(
            children: [
              const HomeBackground(),
              Stack(
                fit: StackFit.expand,
                children: [
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: HomeMenuBar(),
                  ),
                  // Windows paint in open order: the latest opened
                  // sorts last so it lands in front of older ones.
                  ..._orderedWindows(),
                  const PhotosPinOverlay(),
                  const NotesPinOverlay(),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: HomeDock(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Window overlays sorted oldest-visible first. Hidden windows render
  /// nothing anyway; unranked entries keep declaration order.
  ///
  /// Each entry carries a stable key on its focus wrapper: re-sorting
  /// `Stack` children without keys would remount every overlay on each
  /// reorder and wipe their local state (mount flags, drag frames,
  /// text fields). Taps and drags anywhere inside a window report
  /// focus through the wrapper so a behind window comes forward,
  /// macOS-style.
  List<Widget> _orderedWindows() {
    final windows = <MapEntry<String, Widget>>[
      // Full-screen like the photo overlay so the window can
      // use the whole desktop (including the dock area) and
      // is never cropped by a wrapper.
      MapEntry(
        'mail',
        Listener(
          key: const ValueKey('window-mail'),
          onPointerDown: (_) => _focusWindow('mail'),
          child: MailOverlay(controller: _windowController),
        ),
      ),
      MapEntry(
        'music',
        Listener(
          key: const ValueKey('window-music'),
          onPointerDown: (_) => _focusWindow('music'),
          child: const MusicWindowOverlay(),
        ),
      ),
      MapEntry(
        'photos',
        Listener(
          key: const ValueKey('window-photos'),
          onPointerDown: (_) => _focusWindow('photos'),
          child: const PhotosWindowOverlay(),
        ),
      ),
      MapEntry(
        'notes',
        Listener(
          key: const ValueKey('window-notes'),
          onPointerDown: (_) => _focusWindow('notes'),
          child: const NotesOverlay(),
        ),
      ),
    ]..sort(
        (a, b) => _zOrder.rank(a.key).compareTo(_zOrder.rank(b.key)),
      );
    return [for (final entry in windows) entry.value];
  }
}
