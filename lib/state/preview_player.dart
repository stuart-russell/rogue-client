import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Small, muted preview player used by the TV guide banner.
///
/// Deliberately separate from [PlayerService]: the panel allows a single
/// connection, so the guide stops this preview before opening the full player
/// and restarts it when the player is closed.
class PreviewPlayer {
  Player? _player;
  VideoController? _controller;
  String? _url;
  bool _started = false;
  bool _muted = true;
  bool _closed = false;

  bool get hasVideo => _player != null;
  bool get isMuted => _muted;

  Player get player => _player ??= Player(
    configuration: const PlayerConfiguration(
      title: 'Rogue preview',
      logLevel: MPVLogLevel.error,
    ),
  );

  VideoController get controller => _controller ??= VideoController(player);

  Future<void> show(String url, {bool force = false}) async {
    if (_closed) return;
    if (!force && _url == url && _started) return;
    _url = url;
    _started = true;
    try {
      await player.open(Media(url), play: true);
      await player.setVolume(_muted ? 0 : 60);
    } catch (_) {
      _started = false;
    }
  }

  Future<void> halt() async {
    _started = false;
    try {
      await _player?.stop();
    } catch (_) {
      // Releasing the preview is best-effort.
    }
  }

  Future<void> toggleMute() async {
    _muted = !_muted;
    try {
      await _player?.setVolume(_muted ? 0 : 60);
    } catch (_) {}
  }

  Future<void> dispose() async {
    _closed = true;
    try {
      await _player?.dispose();
    } catch (_) {}
    _player = null;
    _controller = null;
  }
}
