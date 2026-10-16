import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jent_web/core/theme/app_dimens.dart';
import 'package:jent_web/core/widgets/window/window_resize_handles.dart';
import 'package:jent_web/core/widgets/window/window_title_bar.dart';
import 'package:jent_web/features/music/bloc/music_bloc.dart';
import 'package:jent_web/features/music/bloc/music_event.dart';
import 'package:jent_web/features/music/bloc/music_state.dart';
import 'package:jent_web/features/music/view/music_library_body.dart';

/// Standard macOS-style library window for music: shared
/// [WindowTitleBar] chrome, drag-to-move, invisible resize zones,
/// expand toggle snaps back to the preset size.
class MusicWindowOverlay extends StatefulWidget {
  const MusicWindowOverlay({super.key});

  @override
  State<MusicWindowOverlay> createState() => _MusicWindowOverlayState();
}

class _MusicWindowOverlayState extends State<MusicWindowOverlay> {
  final ValueNotifier<Rect?> _frame = ValueNotifier(null);
  bool? _lastExpanded;
  bool _resizing = false;

  static const _minWinSize = Size(
    AppDimens.musicMinWidth,
    AppDimens.musicMinHeight,
  );
  static const _edgeGrip = 10.0;
  static const _cornerGrip = 18.0;

  @override
  void dispose() {
    _frame.dispose();
    super.dispose();
  }

  Size _baseSize(bool expanded) => expanded
      ? const Size(AppDimens.musicExpandedWidth, AppDimens.musicExpandedHeight)
      : const Size(AppDimens.musicWindowWidth, AppDimens.musicWindowHeight);

  Rect _defaultFrame(Size screen, Size base) => Rect.fromLTWH(
        (screen.width - base.width) / 2,
        (screen.height - base.height) / 2 - 40,
        base.width,
        base.height,
      );

  Rect _clampFrame(Rect frame, Size screen) {
    final maxX = math.max(12.0, screen.width - frame.width - 12);
    final maxY = math.max(AppDimens.dragMinY, screen.height - 120);
    final left = frame.left.clamp(12.0, maxX);
    final top = frame.top.clamp(AppDimens.dragMinY, maxY);
    return Rect.fromLTWH(left, top, frame.width, frame.height);
  }

  void _onDrag(Offset delta, Size screen) {
    final base = _baseSize(context.read<MusicBloc>().state.isMusicExpanded);
    final current = _frame.value ?? _defaultFrame(screen, base);
    final next = current.topLeft + delta;
    final maxX = math.max(12.0, screen.width - current.width - 12);
    final maxY = math.max(AppDimens.dragMinY, screen.height - 120);
    _frame.value = Rect.fromLTWH(
      next.dx.clamp(12.0, maxX),
      next.dy.clamp(AppDimens.dragMinY, maxY),
      current.width,
      current.height,
    );
  }

  void _onResize(WindowResizeEdges edges, Offset delta, Size screen) {
    final base = _baseSize(context.read<MusicBloc>().state.isMusicExpanded);
    final current = _frame.value ?? _defaultFrame(screen, base);
    var left = current.left;
    var top = current.top;
    var right = current.right;
    var bottom = current.bottom;
    if (edges.left) left += delta.dx;
    if (edges.right) right += delta.dx;
    if (edges.top) top += delta.dy;
    if (edges.bottom) bottom += delta.dy;
    if (right - left < _minWinSize.width) {
      if (edges.left) {
        left = right - _minWinSize.width;
      } else {
        right = left + _minWinSize.width;
      }
    }
    if (bottom - top < _minWinSize.height) {
      if (edges.top) {
        top = bottom - _minWinSize.height;
      } else {
        bottom = top + _minWinSize.height;
      }
    }
    left = left.clamp(0.0, math.max(0.0, screen.width - _minWinSize.width));
    right = right.clamp(
      _minWinSize.width,
      math.max(_minWinSize.width, screen.width),
    );
    top = top.clamp(0.0, math.max(0.0, screen.height - _minWinSize.height));
    bottom = bottom.clamp(
      _minWinSize.height,
      math.max(_minWinSize.height, screen.height - 24),
    );
    _frame.value = Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);

    return BlocSelector<MusicBloc, MusicState, _MusicVisibility>(
      selector: (state) => _MusicVisibility(
        show: state.isShowMusicPlayer,
        minimized: state.isMusicMinimized,
        expanded: state.isMusicExpanded,
      ),
      builder: (context, vis) {
        if (!vis.show) {
          _frame.value = null;
          _lastExpanded = null;
          return const SizedBox.shrink();
        }
        if (_lastExpanded != vis.expanded) {
          _lastExpanded = vis.expanded;
          _frame.value = null;
        }
        return SizedBox.expand(
          child: ValueListenableBuilder<Rect?>(
            valueListenable: _frame,
            builder: (context, custom, _) {
              final frame = _clampFrame(
                custom ?? _defaultFrame(screen, _baseSize(vis.expanded)),
                screen,
              );
              return Stack(
                children: [
                  Positioned(
                    left: frame.left,
                    top: frame.top,
                    child: SizedBox(
                      width: frame.width,
                      height: frame.height,
                      child: Stack(
                        children: [
                          Material(
                            elevation: 22,
                            borderRadius: BorderRadius.circular(
                              AppDimens.windowRadius,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanUpdate: (details) =>
                                  _onDrag(details.delta, screen),
                              child: AnimatedContainer(
                                duration: _resizing
                                    ? Duration.zero
                                    : const Duration(milliseconds: 250),
                                curve: Curves.easeOutCubic,
                                width: frame.width,
                                height: frame.height,
                                color: Colors.white,
                                child: Column(
                                  children: [
                                    WindowTitleBar(
                                      onClose: () => context
                                          .read<MusicBloc>()
                                          .add(CloseMusicPlayer()),
                                      onMinimize: () => context
                                          .read<MusicBloc>()
                                          .add(MinimizeMusicPlayer()),
                                      onExpand: () => context
                                          .read<MusicBloc>()
                                          .add(ExpandMusicPlayer()),
                                      onPanUpdate: (offset) =>
                                          _onDrag(offset, screen),
                                    ),
                                    const Expanded(
                                      child: MusicLibraryBody(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          WindowResizeHandle(
                            key: const ValueKey('music-resize-left'),
                            cursor: SystemMouseCursors.resizeLeftRight,
                            left: 0,
                            top: _cornerGrip,
                            bottom: _cornerGrip,
                            width: _edgeGrip,
                            onResize: (delta) => _onResize(
                              WindowResizeEdges.onLeft,
                              delta,
                              screen,
                            ),
                            onResizeStart: () =>
                                setState(() => _resizing = true),
                            onResizeEnd: () =>
                                setState(() => _resizing = false),
                          ),
                          WindowResizeHandle(
                            key: const ValueKey('music-resize-right'),
                            cursor: SystemMouseCursors.resizeLeftRight,
                            right: 0,
                            top: _cornerGrip,
                            bottom: _cornerGrip,
                            width: _edgeGrip,
                            onResize: (delta) => _onResize(
                              WindowResizeEdges.onRight,
                              delta,
                              screen,
                            ),
                            onResizeStart: () =>
                                setState(() => _resizing = true),
                            onResizeEnd: () =>
                                setState(() => _resizing = false),
                          ),
                          WindowResizeHandle(
                            key: const ValueKey('music-resize-top'),
                            cursor: SystemMouseCursors.resizeUpDown,
                            left: _cornerGrip,
                            right: _cornerGrip,
                            top: 0,
                            height: 8,
                            onResize: (delta) => _onResize(
                              WindowResizeEdges.onTop,
                              delta,
                              screen,
                            ),
                            onResizeStart: () =>
                                setState(() => _resizing = true),
                            onResizeEnd: () =>
                                setState(() => _resizing = false),
                          ),
                          WindowResizeHandle(
                            key: const ValueKey('music-resize-bottom'),
                            cursor: SystemMouseCursors.resizeUpDown,
                            left: _cornerGrip,
                            right: _cornerGrip,
                            bottom: 0,
                            height: _edgeGrip,
                            onResize: (delta) => _onResize(
                              WindowResizeEdges.onBottom,
                              delta,
                              screen,
                            ),
                            onResizeStart: () =>
                                setState(() => _resizing = true),
                            onResizeEnd: () =>
                                setState(() => _resizing = false),
                          ),
                          WindowResizeHandle(
                            key: const ValueKey('music-resize-topLeft'),
                            cursor:
                                SystemMouseCursors.resizeUpLeftDownRight,
                            left: 0,
                            top: 0,
                            width: _cornerGrip,
                            height: _cornerGrip,
                            onResize: (delta) => _onResize(
                              WindowResizeEdges.onTopLeft,
                              delta,
                              screen,
                            ),
                            onResizeStart: () =>
                                setState(() => _resizing = true),
                            onResizeEnd: () =>
                                setState(() => _resizing = false),
                          ),
                          WindowResizeHandle(
                            key: const ValueKey('music-resize-topRight'),
                            cursor:
                                SystemMouseCursors.resizeUpRightDownLeft,
                            right: 0,
                            top: 0,
                            width: _cornerGrip,
                            height: _cornerGrip,
                            onResize: (delta) => _onResize(
                              WindowResizeEdges.onTopRight,
                              delta,
                              screen,
                            ),
                            onResizeStart: () =>
                                setState(() => _resizing = true),
                            onResizeEnd: () =>
                                setState(() => _resizing = false),
                          ),
                          WindowResizeHandle(
                            key: const ValueKey('music-resize-bottomLeft'),
                            cursor:
                                SystemMouseCursors.resizeUpRightDownLeft,
                            left: 0,
                            bottom: 0,
                            width: _cornerGrip,
                            height: _cornerGrip,
                            onResize: (delta) => _onResize(
                              WindowResizeEdges.onBottomLeft,
                              delta,
                              screen,
                            ),
                            onResizeStart: () =>
                                setState(() => _resizing = true),
                            onResizeEnd: () =>
                                setState(() => _resizing = false),
                          ),
                          WindowResizeHandle(
                            key: const ValueKey('music-resize-bottomRight'),
                            cursor:
                                SystemMouseCursors.resizeUpLeftDownRight,
                            right: 0,
                            bottom: 0,
                            width: _cornerGrip,
                            height: _cornerGrip,
                            onResize: (delta) => _onResize(
                              WindowResizeEdges.onBottomRight,
                              delta,
                              screen,
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
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _MusicVisibility {
  final bool show;
  final bool minimized;
  final bool expanded;

  const _MusicVisibility({
    required this.show,
    required this.minimized,
    required this.expanded,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MusicVisibility &&
          show == other.show &&
          minimized == other.minimized &&
          expanded == other.expanded;

  @override
  int get hashCode => Object.hash(show, minimized, expanded);
}
