import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jent_web/core/theme/app_dimens.dart';
import 'package:jent_web/domain/entities/music_playlist_info.dart';
import 'package:jent_web/domain/entities/music_track.dart';
import 'package:jent_web/features/music/bloc/music_bloc.dart';
import 'package:jent_web/features/music/bloc/music_event.dart';
import 'package:jent_web/features/music/view/music_artwork.dart';
import 'package:jent_web/features/music/view/music_controls.dart'
    show formatTrackTime;

const _sidebarBackground = Color(0xFFF2F3F5);
const _accent = Color(0xFFFA2D48);

/// macOS Music-style library: sidebar, toolbar with search, track list
/// grouped by the sidebar selection, and a bottom now-playing bar.
class MusicLibraryBody extends StatelessWidget {
  const MusicLibraryBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _MusicToolbar(),
        const Divider(height: 1, color: Color(0xFFE3E5E8)),
        const Expanded(child: _LibrarySplit()),
        const Divider(height: 1, color: Color(0xFFE3E5E8)),
        const _NowPlayingBar(),
      ],
    );
  }
}

class _MusicToolbar extends StatelessWidget {
  const _MusicToolbar();

  @override
  Widget build(BuildContext context) {
    final snapshot = context.select<MusicBloc, ({String query, bool loading})>(
      (b) => (
        query: b.state.libraryQuery,
        loading: b.state.libraryLoading,
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          const Icon(Icons.chevron_left_rounded, color: Color(0xFF9AA0A6)),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF9AA0A6)),
          const SizedBox(width: 12),
          const Text(
            'Music',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 4),
          IconButton(
            key: const ValueKey('music-library-refresh'),
            onPressed: snapshot.loading
                ? null
                : () => context.read<MusicBloc>().add(
                      MusicLibraryRequested(force: true),
                    ),
            iconSize: 18,
            color: const Color(0xFF5F6368),
            tooltip: 'Refresh library',
            icon: snapshot.loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          const Spacer(),
          SizedBox(
            width: 220,
            height: 34,
            child: TextField(
              key: const ValueKey('music-library-search'),
              onChanged: (v) => context.read<MusicBloc>().add(
                    MusicLibrarySearchChanged(v),
                  ),
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: snapshot.query.isNotEmpty
                    ? IconButton(
                        onPressed: () => context.read<MusicBloc>().add(
                              MusicLibrarySearchChanged(''),
                            ),
                        icon: const Icon(Icons.close_rounded, size: 16),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF0F1F3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibrarySplit extends StatelessWidget {
  const _LibrarySplit();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MusicSidebar(),
        VerticalDivider(width: 1, color: Color(0xFFE3E5E8)),
        Expanded(child: _TrackList()),
      ],
    );
  }
}

class _MusicSidebar extends StatelessWidget {
  const _MusicSidebar();

  @override
  Widget build(BuildContext context) {
    final snapshot = context.select<MusicBloc, _SidebarSnapshot>(
      (b) => _SidebarSnapshot(
        selection: b.state.sidebarSelection,
        playlists: b.state.playlists,
        selectedPlaylistId: b.state.selectedPlaylistId,
      ),
    );
    final bloc = context.read<MusicBloc>();
    return Container(
      width: AppDimens.musicSidebarWidth,
      color: _sidebarBackground,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          const _SidebarHeader(label: 'Library'),
          _SidebarTile(
            key: const ValueKey('music-nav-songs'),
            icon: Icons.music_note_rounded,
            label: 'Songs',
            selected: snapshot.selection == MusicSidebarSelection.songs &&
                snapshot.selectedPlaylistId == null,
            onTap: () => bloc.add(
              MusicSidebarSelectionChanged(
                MusicSidebarSelection.songs,
              ),
            ),
          ),
          _SidebarTile(
            key: const ValueKey('music-nav-albums'),
            icon: Icons.album_rounded,
            label: 'Albums',
            selected: snapshot.selection == MusicSidebarSelection.albums &&
                snapshot.selectedPlaylistId == null,
            onTap: () => bloc.add(
              MusicSidebarSelectionChanged(
                MusicSidebarSelection.albums,
              ),
            ),
          ),
          _SidebarTile(
            key: const ValueKey('music-nav-artists'),
            icon: Icons.person_rounded,
            label: 'Artists',
            selected: snapshot.selection == MusicSidebarSelection.artists &&
                snapshot.selectedPlaylistId == null,
            onTap: () => bloc.add(
              MusicSidebarSelectionChanged(
                MusicSidebarSelection.artists,
              ),
            ),
          ),
          const _SidebarHeader(label: 'Playlists'),
          for (final entry in snapshot.playlists)
            _SidebarTile(
              key: ValueKey('music-playlist-${entry.$1.id}'),
              icon: Icons.queue_music_rounded,
              label: entry.$1.name,
              selected: snapshot.selectedPlaylistId == entry.$1.id,
              onTap: () => bloc.add(SelectMusicPlaylist(entry.$1.id)),
            ),
        ],
      ),
    );
  }
}

class _SidebarSnapshot {
  final MusicSidebarSelection selection;
  final List<(MusicPlaylistInfo, List<String>)> playlists;
  final String? selectedPlaylistId;

  const _SidebarSnapshot({
    required this.selection,
    required this.playlists,
    required this.selectedPlaylistId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SidebarSnapshot &&
          selection == other.selection &&
          playlists == other.playlists &&
          selectedPlaylistId == other.selectedPlaylistId;

  @override
  int get hashCode =>
      Object.hash(selection, playlists, selectedPlaylistId);
}

class _SidebarHeader extends StatelessWidget {
  final String label;

  const _SidebarHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF9AA0A6),
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarTile({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: selected ? const Color(0xFFE2E4E8) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: [
                Icon(icon, size: 17, color: const Color(0xFF5F6368)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackList extends StatelessWidget {
  const _TrackList();

  List<MusicTrack> _visibleTracks(
    List<MusicTrack> all,
    List<(MusicPlaylistInfo, List<String>)> playlists,
    String? selectedPlaylistId,
    String query,
  ) {
    var tracks = all;
    if (selectedPlaylistId != null) {
      final ids = <String>{};
      for (final entry in playlists) {
        if (entry.$1.id == selectedPlaylistId) ids.addAll(entry.$2);
      }
      tracks = tracks.where((t) => ids.contains(t.id)).toList();
    }
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return tracks;
    return tracks
        .where(
          (t) =>
              t.title.toLowerCase().contains(q) ||
              t.artist.toLowerCase().contains(q) ||
              t.album.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = context.select<MusicBloc, _ListSnapshot>(
      (b) => _ListSnapshot(
        trackIndex: b.state.musicTrackIndex,
        isPlaying: b.state.isMusicPlaying,
        query: b.state.libraryQuery,
        selection: b.state.sidebarSelection,
        tracks: b.state.tracks,
        playlists: b.state.playlists,
        selectedPlaylistId: b.state.selectedPlaylistId,
      ),
    );
    final all = snapshot.tracks;
    final tracks = _visibleTracks(
      all,
      snapshot.playlists,
      snapshot.selectedPlaylistId,
      snapshot.query,
    );
    if (tracks.isEmpty) {
      return const Center(
        child: Text(
          'No songs found, try another search',
          style: TextStyle(color: Colors.black54, fontSize: 13),
        ),
      );
    }
    String groupKey(MusicTrack t) => switch (snapshot.selection) {
          MusicSidebarSelection.albums => t.album,
          MusicSidebarSelection.artists => t.artist,
          MusicSidebarSelection.songs => '',
        };
    final items = <Widget>[];
    var lastGroup = '';
    for (final track in tracks) {
      final group = groupKey(track);
      if (group.isNotEmpty && group != lastGroup) {
        lastGroup = group;
        items.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              group,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
          ),
        );
      }
      final globalIndex = all.indexOf(track);
      final active = globalIndex == snapshot.trackIndex;
      items.add(
        _SongRow(
          key: ValueKey('music-row-$globalIndex'),
          track: track,
          number: tracks.indexOf(track) + 1,
          active: active,
          isPlaying: active && snapshot.isPlaying,
          onTap: () =>
              context.read<MusicBloc>().add(SelectMusicTrack(globalIndex)),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        const _ColumnHeader(),
        ...items,
      ],
    );
  }
}

class _ListSnapshot {
  final int trackIndex;
  final bool isPlaying;
  final String query;
  final MusicSidebarSelection selection;
  final List<MusicTrack> tracks;
  final List<(MusicPlaylistInfo, List<String>)> playlists;
  final String? selectedPlaylistId;

  const _ListSnapshot({
    required this.trackIndex,
    required this.isPlaying,
    required this.query,
    required this.selection,
    required this.tracks,
    required this.playlists,
    required this.selectedPlaylistId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ListSnapshot &&
          trackIndex == other.trackIndex &&
          isPlaying == other.isPlaying &&
          query == other.query &&
          selection == other.selection &&
          tracks == other.tracks &&
          playlists == other.playlists &&
          selectedPlaylistId == other.selectedPlaylistId;

  @override
  int get hashCode => Object.hash(
        trackIndex,
        isPlaying,
        query,
        selection,
        tracks,
        playlists,
        selectedPlaylistId,
      );
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 11, color: Color(0xFF9AA0A6));
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          SizedBox(width: 44),
          SizedBox(width: 36),
          SizedBox(width: 10),
          Expanded(child: Text('Title', style: style)),
          SizedBox(width: 120, child: Text('Artist', style: style)),
          SizedBox(
            width: 48,
            child: Text('Time', style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _SongRow extends StatelessWidget {
  final MusicTrack track;
  final int number;
  final bool active;
  final bool isPlaying;
  final VoidCallback onTap;

  const _SongRow({
    super.key,
    required this.track,
    required this.number,
    required this.active,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? const Color(0xFFFCE8EB) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: active && isPlaying
                    ? const Icon(
                        Icons.graphic_eq_rounded,
                        size: 18,
                        color: _accent,
                      )
                    : Text(
                        '$number',
                        style: const TextStyle(
                          color: Colors.black38,
                          fontSize: 13,
                        ),
                      ),
              ),
              TrackArtwork(artworkUrl: track.artworkUrl, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(
                width: 120,
                child: Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  formatTrackTime(track.duration),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NowPlayingBar extends StatelessWidget {
  const _NowPlayingBar();

  @override
  Widget build(BuildContext context) {
    final snapshot = context.select<MusicBloc, _NowPlayingSnapshot>(
      (b) {
        final tracks = b.state.tracks;
        final index = tracks.isEmpty
            ? 0
            : b.state.musicTrackIndex.clamp(0, tracks.length - 1);
        final track = tracks.isEmpty ? null : tracks[index];
        return _NowPlayingSnapshot(
          trackIndex: index,
          isPlaying: b.state.isMusicPlaying,
          isLoading: b.state.isMusicLoading,
          position: b.state.musicPosition,
          duration: b.state.musicDuration ?? track?.duration ?? Duration.zero,
          error: b.state.musicError,
          title: track?.title ?? 'No tracks',
          subtitle: track == null
              ? 'Add songs in Supabase'
              : '${track.artist} — ${track.album}',
          artworkUrl: track?.artworkUrl ?? '',
        );
      },
    );
    final bloc = context.read<MusicBloc>();
    final total = snapshot.duration.inMilliseconds;
    final value = total == 0
        ? 0.0
        : snapshot.position.inMilliseconds.clamp(0, total) / total;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (snapshot.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                snapshot.error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          Row(
            children: [
              TrackArtwork(artworkUrl: snapshot.artworkUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      snapshot.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      snapshot.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => bloc.add(PreviousMusicTrack()),
                icon: const Icon(Icons.skip_previous_rounded),
              ),
              snapshot.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton.filled(
                      onPressed: () => bloc.add(ToggleMusicPlayback()),
                      style: IconButton.styleFrom(backgroundColor: _accent),
                      icon: Icon(
                        snapshot.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                    ),
              IconButton(
                onPressed: () => bloc.add(NextMusicTrack()),
                icon: const Icon(Icons.skip_next_rounded),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                formatTrackTime(snapshot.position),
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Expanded(
                child: Slider(
                  value: value,
                  activeColor: _accent,
                  onChanged: (v) => bloc.add(
                    SeekMusicPosition(
                      Duration(
                        milliseconds: (v * total).round(),
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                formatTrackTime(snapshot.duration),
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NowPlayingSnapshot {
  final int trackIndex;
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration duration;
  final String? error;
  final String title;
  final String subtitle;
  final String artworkUrl;

  const _NowPlayingSnapshot({
    required this.trackIndex,
    required this.isPlaying,
    required this.isLoading,
    required this.position,
    required this.duration,
    required this.error,
    required this.title,
    required this.subtitle,
    required this.artworkUrl,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _NowPlayingSnapshot &&
          trackIndex == other.trackIndex &&
          isPlaying == other.isPlaying &&
          isLoading == other.isLoading &&
          position == other.position &&
          duration == other.duration &&
          error == other.error &&
          title == other.title &&
          subtitle == other.subtitle &&
          artworkUrl == other.artworkUrl;

  @override
  int get hashCode => Object.hash(
        trackIndex,
        isPlaying,
        isLoading,
        position,
        duration,
        error,
        title,
        subtitle,
        artworkUrl,
      );
}
