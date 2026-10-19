import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:jent_web/core/theme/app_dimens.dart';
import 'package:jent_web/core/widgets/window/window_resize_handles.dart';
import 'package:jent_web/domain/entities/email_message.dart';
import 'package:jent_web/domain/repositories/email_repository.dart';
import 'package:jent_web/domain/usecases/send_email_usecase.dart';
import 'package:jent_web/features/mail/bloc/mail_bloc.dart';
import 'package:jent_web/features/mail/bloc/mail_event.dart';
import 'package:jent_web/features/mail/bloc/mail_state.dart';
import 'package:jent_web/features/mail/view/mail_window.dart';
import 'package:jent_web/l10n/app_localizations.dart';

class MailOverlay extends StatefulWidget {
  final AnimationController controller;

  const MailOverlay({super.key, required this.controller});

  @override
  State<MailOverlay> createState() => _MailOverlayState();
}

class _MailOverlayState extends State<MailOverlay> {
  bool _mounted = false;

  /// Local window frame. Null means "use the preset size, centered".
  /// Cleared when the expand toggle changes so the window snaps back
  /// to its preset size.
  final ValueNotifier<Rect?> _frame = ValueNotifier(null);
  bool? _lastExpanded;
  bool _resizing = false;
  Size? _screenSize;

  /// macOS-like resize limits for the mail window.
  static const _minMailSize = Size(
    AppDimens.mailWidthMin,
    AppDimens.mailHeightMin,
  );
  static const _edgeGrip = 10.0;
  static const _cornerGrip = 18.0;

  @override
  void dispose() {
    _frame.dispose();
    super.dispose();
  }

  Size _baseSize(Size screenSize, bool isExpanded) =>
      AppDimens.mailWindowSize(screenSize, isExpanded);

  Rect _defaultFrame(Size screenSize, Size winSize) => Rect.fromLTWH(
        (screenSize.width - winSize.width) / 2,
        (screenSize.height - winSize.height) / 2,
        winSize.width,
        winSize.height,
      );

  /// Same drag limits as the photo window: the window always stays
  /// fully on screen with a small margin.
  Rect _clampFrame(Rect frame, Size screenSize) {
    final maxX = math.max(12.0, screenSize.width - frame.width - 12);
    final maxY = math.max(AppDimens.dragMinY, screenSize.height - 120);
    final left = frame.left.clamp(12.0, maxX);
    final top = frame.top.clamp(AppDimens.dragMinY, maxY);
    return Rect.fromLTWH(left, top, frame.width, frame.height);
  }

  void _onDragDelta(Offset delta) {
    final screenSize = _screenSize!;
    final expanded = context.read<MailBloc>().state.isExpandedWindow;
    final current =
        _frame.value ?? _defaultFrame(screenSize, _baseSize(screenSize, expanded));
    _frame.value = _clampFrame(
      Rect.fromLTWH(
        current.left + delta.dx,
        current.top + delta.dy,
        current.width,
        current.height,
      ),
      screenSize,
    );
  }

  void _onResize(WindowResizeEdges edges, Offset delta) {
    final screenSize = _screenSize!;
    final expanded = context.read<MailBloc>().state.isExpandedWindow;
    final current =
        _frame.value ?? _defaultFrame(screenSize, _baseSize(screenSize, expanded));
    var left = current.left;
    var top = current.top;
    var right = current.right;
    var bottom = current.bottom;
    if (edges.left) left += delta.dx;
    if (edges.right) right += delta.dx;
    if (edges.top) top += delta.dy;
    if (edges.bottom) bottom += delta.dy;
    // Enforce the minimum size, pushing the dragged edge back.
    if (right - left < _minMailSize.width) {
      if (edges.left) {
        left = right - _minMailSize.width;
      } else {
        right = left + _minMailSize.width;
      }
    }
    if (bottom - top < _minMailSize.height) {
      if (edges.top) {
        top = bottom - _minMailSize.height;
      } else {
        bottom = top + _minMailSize.height;
      }
    }
    _frame.value = _clampFrame(
      Rect.fromLTRB(left, top, right, bottom),
      screenSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    _screenSize = MediaQuery.sizeOf(context);
    final isExpanded = context.select<MailBloc, bool>(
      (bloc) => bloc.state.isExpandedWindow,
    );
    // The expand toggle snaps back to the preset size.
    if (_lastExpanded != isExpanded) {
      _lastExpanded = isExpanded;
      _frame.value = null;
    }
    final winSize = _baseSize(_screenSize!, isExpanded);

    return BlocListener<MailBloc, MailState>(
      listenWhen: (prev, curr) =>
          prev.isShowWindow != curr.isShowWindow ||
          prev.isExpandedWindow != curr.isExpandedWindow ||
          prev.emailStatus != curr.emailStatus,
      listener: (context, state) {
        if (state.isShowWindow) {
          setState(() => _mounted = true);
          widget.controller.forward(from: 0);
        } else if (!state.isShowWindow) {
          widget.controller.reverse().whenComplete(() {
            if (mounted) setState(() => _mounted = false);
          });
        }
        if (_frame.value != null) {
          _frame.value = _clampFrame(_frame.value!, _screenSize!);
        }
      },
      // Positioned is a direct child of this explicit Stack so it
      // never competes with the page's Positioned.fill wrapper for
      // StackParentData. The open/close animation lives inside.
      child: SizedBox.expand(
        child: ValueListenableBuilder<Rect?>(
          valueListenable: _frame,
          builder: (context, custom, _) {
            final frame = _clampFrame(
              custom ?? _defaultFrame(_screenSize!, winSize),
              _screenSize!,
            );
            return Stack(
              children: [
                if (_mounted)
                  Positioned(
                    left: frame.left,
                    top: frame.top,
                    child: _MailEntrance(
                      controller: widget.controller,
                      child: SizedBox(
                        width: frame.width,
                        height: frame.height,
                        child: Stack(
                          children: [
                            AnimatedContainer(
                              duration: _resizing
                                  ? Duration.zero
                                  : const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              width: frame.width,
                              height: frame.height,
                              child: MailWindow(
                                size: Size(frame.width, frame.height),
                                onClose: () => context
                                    .read<MailBloc>()
                                    .add(ToggleCloseEmailMenu()),
                                onExpand: () => context
                                    .read<MailBloc>()
                                    .add(ToggleExpandEmailMenu()),
                                onMinimize: () => context
                                    .read<MailBloc>()
                                    .add(ToggleMinimizeEmailMenu()),
                                onDragDelta: _onDragDelta,
                                onSend: (draft) =>
                                    context.read<MailBloc>().add(
                                          SendEmail(
                                            name: draft.name,
                                            from: draft.from,
                                            subject: draft.subject,
                                            body: draft.body,
                                            captchaToken: draft.captchaToken,
                                          ),
                                        ),
                              ),
                            ),
                            // macOS-style resize zones above the content.
                            WindowResizeHandle(
                              key: const ValueKey('mail-resize-left'),
                              cursor: SystemMouseCursors.resizeLeftRight,
                              left: 0,
                              top: _cornerGrip,
                              bottom: _cornerGrip,
                              width: _edgeGrip,
                              onResize: (delta) => _onResize(
                                WindowResizeEdges.onLeft,
                                delta,
                              ),
                              onResizeStart: () =>
                                  setState(() => _resizing = true),
                              onResizeEnd: () =>
                                  setState(() => _resizing = false),
                            ),
                            WindowResizeHandle(
                              key: const ValueKey('mail-resize-right'),
                              cursor: SystemMouseCursors.resizeLeftRight,
                              right: 0,
                              top: _cornerGrip,
                              bottom: _cornerGrip,
                              width: _edgeGrip,
                              onResize: (delta) => _onResize(
                                WindowResizeEdges.onRight,
                                delta,
                              ),
                              onResizeStart: () =>
                                  setState(() => _resizing = true),
                              onResizeEnd: () =>
                                  setState(() => _resizing = false),
                            ),
                            WindowResizeHandle(
                              key: const ValueKey('mail-resize-top'),
                              cursor: SystemMouseCursors.resizeUpDown,
                              left: _cornerGrip,
                              right: _cornerGrip,
                              top: 0,
                              height: 8,
                              onResize: (delta) => _onResize(
                                WindowResizeEdges.onTop,
                                delta,
                              ),
                              onResizeStart: () =>
                                  setState(() => _resizing = true),
                              onResizeEnd: () =>
                                  setState(() => _resizing = false),
                            ),
                            WindowResizeHandle(
                              key: const ValueKey('mail-resize-bottom'),
                              cursor: SystemMouseCursors.resizeUpDown,
                              left: _cornerGrip,
                              right: _cornerGrip,
                              bottom: 0,
                              height: _edgeGrip,
                              onResize: (delta) => _onResize(
                                WindowResizeEdges.onBottom,
                                delta,
                              ),
                              onResizeStart: () =>
                                  setState(() => _resizing = true),
                              onResizeEnd: () =>
                                  setState(() => _resizing = false),
                            ),
                            WindowResizeHandle(
                              key: const ValueKey('mail-resize-topLeft'),
                              cursor: SystemMouseCursors
                                  .resizeUpLeftDownRight,
                              left: 0,
                              top: 0,
                              width: _cornerGrip,
                              height: _cornerGrip,
                              onResize: (delta) => _onResize(
                                WindowResizeEdges.onTopLeft,
                                delta,
                              ),
                              onResizeStart: () =>
                                  setState(() => _resizing = true),
                              onResizeEnd: () =>
                                  setState(() => _resizing = false),
                            ),
                            WindowResizeHandle(
                              key: const ValueKey('mail-resize-topRight'),
                              cursor: SystemMouseCursors
                                  .resizeUpRightDownLeft,
                              right: 0,
                              top: 0,
                              width: _cornerGrip,
                              height: _cornerGrip,
                              onResize: (delta) => _onResize(
                                WindowResizeEdges.onTopRight,
                                delta,
                              ),
                              onResizeStart: () =>
                                  setState(() => _resizing = true),
                              onResizeEnd: () =>
                                  setState(() => _resizing = false),
                            ),
                            WindowResizeHandle(
                              key: const ValueKey('mail-resize-bottomLeft'),
                              cursor: SystemMouseCursors
                                  .resizeUpRightDownLeft,
                              left: 0,
                              bottom: 0,
                              width: _cornerGrip,
                              height: _cornerGrip,
                              onResize: (delta) => _onResize(
                                WindowResizeEdges.onBottomLeft,
                                delta,
                              ),
                              onResizeStart: () =>
                                  setState(() => _resizing = true),
                              onResizeEnd: () =>
                                  setState(() => _resizing = false),
                            ),
                            WindowResizeHandle(
                              key: const ValueKey(
                                'mail-resize-bottomRight',
                              ),
                              cursor: SystemMouseCursors
                                  .resizeUpLeftDownRight,
                              right: 0,
                              bottom: 0,
                              width: _cornerGrip,
                              height: _cornerGrip,
                              onResize: (delta) => _onResize(
                                WindowResizeEdges.onBottomRight,
                                delta,
                              ),
                              onResizeStart: () =>
                                  setState(() => _resizing = true),
                              onResizeEnd: () =>
                                  setState(() => _resizing = false),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Open/close animation for the mail window, applied inside the
/// Positioned so it never interferes with StackParentData.
class _MailEntrance extends StatelessWidget {
  final AnimationController controller;
  final Widget child;

  const _MailEntrance({required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value;
        final scale = Curves.easeOutBack.transform(t).clamp(0.0, 1.2);
        final opacity = Curves.easeOut.transform(t).clamp(0.0, 1.0);
        final liftY = (1 - Curves.easeOutCubic.transform(t)) * 140;
        return Transform.translate(
          offset: Offset(0, liftY),
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale == 0 ? 0.001 : scale,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// No-op email repository so the preview never touches the network.
class _PreviewEmailRepository implements EmailRepository {
  @override
  Future<void> send(EmailMessage message) async {}
}

/// Preview shell: owns the entrance [AnimationController] (a top-level
/// preview function cannot provide `vsync`) and mirrors the home_page
/// nesting of `MailOverlay` inside `Positioned.fill` inside a `Stack`.
/// [initialEvents] are dispatched post-frame so the [BlocListener] inside
/// [MailOverlay] observes the transitions and mounts the window — events
/// added before first build would be missed.
class _MailOverlayPreviewShell extends StatefulWidget {
  final MailBloc bloc;
  final List<MailEvent> initialEvents;

  const _MailOverlayPreviewShell({
    required this.bloc,
    this.initialEvents = const [],
  });

  @override
  State<_MailOverlayPreviewShell> createState() =>
      _MailOverlayPreviewShellState();
}

class _MailOverlayPreviewShellState extends State<_MailOverlayPreviewShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    if (widget.initialEvents.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final event in widget.initialEvents) {
          widget.bloc.add(event);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: BlocProvider.value(
        value: widget.bloc,
        child: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: MailOverlay(controller: _controller),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

@Preview(name: 'MailOverlay - open', group: 'Mail', size: Size(1200, 800))
Widget mailOverlayPreview() {
  return _MailOverlayPreviewShell(
    bloc: MailBloc(SendEmailUseCase(_PreviewEmailRepository())),
    initialEvents: [ToggleOpenEmailMenu()],
  );
}

@Preview(name: 'MailOverlay - expanded', group: 'Mail', size: Size(1200, 800))
Widget mailOverlayExpandedPreview() {
  return _MailOverlayPreviewShell(
    bloc: MailBloc(SendEmailUseCase(_PreviewEmailRepository())),
    initialEvents: [ToggleOpenEmailMenu(), ToggleExpandEmailMenu()],
  );
}
