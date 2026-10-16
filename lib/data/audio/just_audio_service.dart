import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:jent_web/data/audio/playable_source.dart';
import 'package:jent_web/domain/repositories/music_audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Production playback backed by just_audio (HTML audio on web).
///
/// Download-then-play with a local cache: the first tap on a song
/// downloads it (spinner is truthful), replays and switches reuse
/// the cached copy instantly. Downloads run concurrently — a tap
/// never waits on a stale fetch — while the final set+play step
/// stays serialized so the backend can't end up playing a different
/// track than the state shows.
@LazySingleton(as: MusicAudioService)
class JustAudioService implements MusicAudioService {
  final AudioPlayer _player = AudioPlayer();
  final http.Client _http = http.Client();

  /// Bounds each load phase: a stalled read must surface as an error
  /// instead of hanging a handler forever.
  static const loadTimeout = Duration(seconds: 15);

  /// Downloads get longer: a slow network just means a longer
  /// spinner, and switching songs cancels nothing — stale results
  /// are discarded while the newest tap proceeds on its own.
  static const downloadTimeout = Duration(seconds: 60);

  /// Memory/disk cap for cached songs (LRU, never evicts the track
  /// that is currently active).
  static const maxCachedSongs = 5;

  /// Remote URL -> playable source (blob URL on web, temp file on
  /// native). Insertion-ordered for LRU eviction.
  final Map<String, String> _sources = {};

  /// Monotonic tap counter: only the newest request may touch the
  /// player or populate the cache.
  int _generation = 0;

  /// URL currently loaded (or loading) in the player; exempt from
  /// cache eviction.
  String? _activeUrl;

  /// Serializes only the fast set+play step.
  Future<void> _tail = Future<void>.value();

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Future<void> playUrl(String url) async {
    final gen = ++_generation;
    // Fast path: cached copy plays with no network at all.
    var source = _sources[url];
    source ??= await _fetchSource(url, gen);
    // A newer tap owns the outcome from here.
    if (gen != _generation) return;
    if (source == null) return;
    _touch(url);
    final clip = source;
    final next = _tail.then((_) => _playSource(url, clip, gen));
    // Keep the chain alive for the next request even if this one
    // fails; the caller still gets the original error.
    _tail = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  /// Downloads + converts to a playable source concurrently with any
  /// other in-flight tap. Returns null when superseded mid-flight
  /// (the newer tap proceeds on its own); throws on real failures
  /// so the bloc can show an error.
  Future<String?> _fetchSource(String url, int gen) async {
    Uint8List bytes;
    try {
      final res = await _http.get(Uri.parse(url)).timeout(downloadTimeout);
      if (res.statusCode != 200) {
        throw Exception('download failed: HTTP ${res.statusCode}');
      }
      bytes = res.bodyBytes;
    } on TimeoutException {
      throw TimeoutException('taking too long to download audio');
    }
    if (gen != _generation) return null;
    final source = await createPlayableSource(url, bytes);
    if (gen != _generation) {
      await releasePlayableSource(source);
      return null;
    }
    _sources[url] = source;
    await _evict();
    return source;
  }

  /// Refreshes LRU order (most-recently-used last).
  void _touch(String url) {
    final source = _sources.remove(url);
    if (source != null) _sources[url] = source;
  }

  Future<void> _evict() async {
    while (_sources.length > maxCachedSongs) {
      String? oldest;
      for (final key in _sources.keys) {
        if (key != _activeUrl) {
          oldest = key;
          break;
        }
      }
      if (oldest == null) break;
      final source = _sources.remove(oldest)!;
      await releasePlayableSource(source);
    }
  }

  Future<void> _playSource(String url, String source, int gen) async {
    _activeUrl = url;
    try {
      await _player.setUrl(source).timeout(loadTimeout);
    } on TimeoutException {
      throw TimeoutException('taking too long to load audio');
    }
    if (gen != _generation) return;
    try {
      await _player.play().timeout(loadTimeout);
    } on TimeoutException {
      throw TimeoutException('taking too long to start playback');
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() {
    _activeUrl = null;
    return _player.stop();
  }

  @override
  Future<void> dispose() {
    _http.close();
    return _player.dispose();
  }
}
