import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// One player and one video texture for the whole app lifetime.
///
/// Creating a `Player`/`VideoController` per player screen churns the external
/// OpenGL texture. That churn is what crashed the raster thread here:
///
///   GrDirectContext::flushAndSubmit  <- null context
///   EmbedderExternalTextureGL::ResolveTextureSkia
///   TextureLayer::Paint
///
/// Reusing a single texture means navigation only attaches/detaches the `Video`
/// widget; the texture itself is created once and released at shutdown.
class PlayerService {
  Player? _player;
  VideoController? _controller;
  bool _closed = false;

  Player get player {
    assert(!_closed, 'PlayerService used after dispose');
    return _player ??= Player(
      configuration: const PlayerConfiguration(
        title: 'Rogue',
        logLevel: MPVLogLevel.error,
      ),
    );
  }

  VideoController get controller {
    assert(!_closed, 'PlayerService used after dispose');
    _player ??= player;
    return _controller ??= VideoController(_player!);
  }

  bool get initialised => _player != null;

  /// Stops playback but keeps the texture alive between visits.
  Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (_) {
      // A failed stop must not break navigation.
    }
  }

  Future<void> dispose() async {
    _closed = true;
    try {
      await _player?.dispose();
    } catch (_) {
      // Best effort at shutdown.
    }
    _player = null;
    _controller = null;
  }
}
