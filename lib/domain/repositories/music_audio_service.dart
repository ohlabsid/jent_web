/// Playback backend for the music feature. The bloc talks only to
/// this interface so tests stay hermetic (use [FakeMusicAudioService])
/// while production uses just_audio (web = HTML audio element).
abstract class MusicAudioService {
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<bool> get playingStream;

  Future<void> playUrl(String url);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> stop();
  Future<void> dispose();
}
