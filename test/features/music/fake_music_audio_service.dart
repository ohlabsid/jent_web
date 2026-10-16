import 'dart:async';

import 'package:jent_web/domain/repositories/music_audio_service.dart';

/// Hermetic playback stub: records calls and lets tests drive the
/// bloc by pushing position/duration/playing events. `playUrl`
/// auto-reports a duration and playing state like a real backend.
class FakeMusicAudioService implements MusicAudioService {
  final positionController = StreamController<Duration>.broadcast();
  final durationController = StreamController<Duration?>.broadcast();
  final playingController = StreamController<bool>.broadcast();

  String? lastUrl;
  int playUrlCalls = 0;
  int playCalls = 0;
  int pauseCalls = 0;
  int stopCalls = 0;
  final List<Duration> seeks = [];

  Duration autoDuration = const Duration(minutes: 3);

  @override
  Stream<Duration> get positionStream => positionController.stream;

  @override
  Stream<Duration?> get durationStream => durationController.stream;

  @override
  Stream<bool> get playingStream => playingController.stream;

  @override
  Future<void> playUrl(String url) async {
    lastUrl = url;
    playUrlCalls++;
    durationController.add(autoDuration);
    playingController.add(true);
  }

  @override
  Future<void> play() async {
    playCalls++;
    playingController.add(true);
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    playingController.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    positionController.add(position);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    playingController.add(false);
  }

  @override
  Future<void> dispose() async {
    await positionController.close();
    await durationController.close();
    await playingController.close();
  }
}
