// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../core/app_log.dart';
import '../core/fullscreen.dart';
import '../data/models.dart';
import '../state/app_model.dart';
import '../state/player_service.dart';
import '../theme.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.playlist,
    required this.initialIndex,
  });

  final List<PlayableMedia> playlist;
  final int initialIndex;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
  late final PlayerService _service = AppScope.read(context).player;
  late final AppModel _app = AppScope.read(context);
  final FullscreenController _fullscreenController = FullscreenController();
  Player get _player => _service.player;
  VideoController get _controller => _service.controller;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  late int _index = widget.initialIndex.clamp(0, widget.playlist.length - 1);
  bool _playing = false;
  bool _buffering = true;
  bool _controlsVisible = true;
  bool _fullscreen = false;
  bool _disposed = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 100;
  String? _error;
  Timer? _hideTimer;
  Timer? _scrubTimer;
  Timer? _feedbackTimer;
  int? _feedbackSeconds;
  bool _scrubbing = false;
  List<SubtitleTrack> _subtitleTracks = const [];
  String? _activeSubtitleId;
  DateTime _lastProgressWrite = DateTime.fromMillisecondsSinceEpoch(0);

  PlayableMedia get _current => widget.playlist[_index];
  bool get _isLive => _current.isLive;
  bool get _hasNext => _index + 1 < widget.playlist.length;
  bool get _hasPrevious => _index > 0;
  bool get _isDesktop => !Platform.isAndroid && !Platform.isIOS;
  bool get _subtitlesOn =>
      _activeSubtitleId != null && _activeSubtitleId != 'no';

  /// mpv reports `auto` when it picked the first track itself; treat that as
  /// "track 0 is showing" so the menu matches the picture.
  bool _subtitleSelected(SubtitleTrack track, int index) =>
      _activeSubtitleId == track.id ||
      (_activeSubtitleId == 'auto' && index == 0);
  bool get _hasSubtitleTracks => _subtitleTracks.isNotEmpty;

  Duration get _remaining {
    final left = _duration - _position;
    return left < Duration.zero ? Duration.zero : left;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bindStreams();
    _open();
    _scheduleHide();
  }

  void _bindStreams() {
    _subscriptions.add(
      _player.stream.playing.listen((value) {
        if (_disposed) return;
        setState(() => _playing = value);
      }),
    );
    _subscriptions.add(
      _player.stream.buffering.listen((value) {
        if (_disposed) return;
        setState(() => _buffering = value);
      }),
    );
    _subscriptions.add(
      _player.stream.position.listen((value) {
        if (_disposed || _scrubbing) return;
        setState(() => _position = value);
        _recordProgress();
      }),
    );
    _subscriptions.add(
      _player.stream.duration.listen((value) {
        if (_disposed) return;
        setState(() => _duration = value);
      }),
    );
    _subscriptions.add(
      _player.stream.volume.listen((value) {
        if (_disposed) return;
        setState(() => _volume = value.clamp(0, 100));
      }),
    );
    _subscriptions.add(
      _player.stream.error.listen((value) {
        if (_disposed) return;
        setState(() => _error = value);
      }),
    );
    // Netflix-style auto-advance: finished episode -> next in the playlist.
    _subscriptions.add(
      _player.stream.completed.listen((done) {
        if (_disposed || !done) return;
        _recordProgress(force: true);
        if (_isLive || !_hasNext) return;
        AppLog.write('playback finished, advancing to ${_index + 1}');
        _playIndex(_index + 1);
      }),
    );
    _subscriptions.add(
      _player.stream.tracks.listen((tracks) {
        if (_disposed) return;
        final subtitles = tracks.subtitle
            .where((track) => track.id != 'no' && track.id != 'auto')
            .toList(growable: false);
        setState(() => _subtitleTracks = subtitles);
        AppLog.write('subtitle tracks: ${subtitles.length}');
      }),
    );
    _subscriptions.add(
      _player.stream.track.listen((track) {
        if (_disposed) return;
        setState(() => _activeSubtitleId = track.subtitle.id);
      }),
    );
  }

  Future<void> _open() async {
    final media = _current;
    setState(() {
      _error = null;
      _buffering = true;
      _position = Duration.zero;
      _duration = Duration.zero;
      _feedbackSeconds = null;
      _subtitleTracks = const [];
      _activeSubtitleId = null;
    });
    // mpv applies `start` while loading; a seek() immediately after open() races
    // the stream and is often ignored (resume would restart at 0).
    final startAt = media.startAt;
    final resumeAt = (startAt != null && startAt > const Duration(seconds: 2))
        ? startAt
        : null;
    try {
      await _player.open(Media(media.url, start: resumeAt), play: true);
      await _player.setVolume(_volume);
      if (resumeAt != null) {
        AppLog.write('resumed at ${resumeAt.inSeconds}s "${media.title}"');
      }
      AppLog.write('player opened "${media.title}" live=$_isLive');
    } on Exception catch (e) {
      AppLog.write('player open failed "${media.title}": $e');
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  void _playIndex(int index) {
    if (index < 0 || index >= widget.playlist.length) return;
    _recordProgress(force: true);
    setState(() => _index = index);
    _open();
  }

  /// Persists how far through the current movie/episode we are. Throttled to
  /// one write every five seconds while playing; forced on switching, finishing
  /// and leaving the screen.
  void _recordProgress({bool force = false}) {
    final id = _current.progressId;
    if (id == null || _duration.inSeconds <= 0) return;
    if (!force && DateTime.now().difference(_lastProgressWrite).inSeconds < 5) {
      return;
    }
    _lastProgressWrite = DateTime.now();
    // Episodes roll credits quickly; films need a longer tail.
    final slack = id.startsWith('ep:')
        ? const Duration(minutes: 1)
        : const Duration(minutes: 5);
    _app.progress.record(id, _position, _duration, completionSlack: slack);
  }

  /// Skip ±[seconds] for VOD, clamped to the media. No-op for live streams.
  void _seekRelative(int seconds) {
    if (_isLive || _duration == Duration.zero) return;
    final target = _position + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _duration ? _duration : target);
    _player.seek(clamped);
    if (mounted) setState(() => _position = clamped);
    _showSeekFeedback(seconds);
    _showControls();
  }

  void _showSeekFeedback(int seconds) {
    _feedbackTimer?.cancel();
    if (mounted) setState(() => _feedbackSeconds = seconds);
    _feedbackTimer = Timer(const Duration(milliseconds: 750), () {
      if (mounted) setState(() => _feedbackSeconds = null);
    });
  }

  Future<void> _toggleSubtitles() async {
    if (!_hasSubtitleTracks) return;
    if (_subtitlesOn) {
      await _player.setSubtitleTrack(SubtitleTrack.no());
    } else {
      await _player.setSubtitleTrack(_subtitleTracks.first);
    }
    _showControls();
  }

  Future<void> _selectSubtitle(String id) async {
    if (id == 'off') {
      await _player.setSubtitleTrack(SubtitleTrack.no());
    } else {
      final track = _subtitleTracks.firstWhere(
        (candidate) => candidate.id == id,
        orElse: () => _subtitleTracks.first,
      );
      await _player.setSubtitleTrack(track);
    }
    _showControls();
  }

  String _trackLabel(SubtitleTrack track, int index) {
    final title = (track.title ?? '').trim();
    final language = (track.language ?? '').trim();
    if (title.isNotEmpty &&
        language.isNotEmpty &&
        title.toLowerCase() != language.toLowerCase()) {
      return '$title ($language)';
    }
    if (title.isNotEmpty) return title;
    if (language.isNotEmpty) return language;
    return 'Track ${index + 1}';
  }

  Widget _subtitleButton() {
    final active = _subtitlesOn;
    final enabled = _hasSubtitleTracks;
    return PopupMenuButton<String>(
      enabled: enabled,
      tooltip: enabled ? 'Subtitles (C)' : 'No subtitles in this stream',
      color: AppColors.surfaceHigh,
      offset: const Offset(0, -8),
      onSelected: _selectSubtitle,
      itemBuilder: (context) => [
        PopupMenuItem(value: 'off', child: _subtitleRow('Off', !active)),
        for (var i = 0; i < _subtitleTracks.length; i++)
          PopupMenuItem(
            value: _subtitleTracks[i].id,
            child: _subtitleRow(
              _trackLabel(_subtitleTracks[i], i),
              _subtitleSelected(_subtitleTracks[i], i),
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Icon(
          Icons.closed_caption_rounded,
          size: 22,
          color: !enabled
              ? Colors.white24
              : (active ? AppColors.accent : Colors.white),
        ),
      ),
    );
  }

  Widget _subtitleRow(String label, bool selected) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          child: selected
              ? Icon(Icons.check_rounded, size: 16, color: AppColors.accent)
              : null,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: selected ? AppColors.accent : AppColors.text,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _player.pause();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _hideTimer?.cancel();
    _scrubTimer?.cancel();
    _feedbackTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    AppLog.write('player dispose');
    // Record the final position before the route goes away.
    _recordProgress(force: true);
    // Sync Win32 restore; safe here. No window_manager, no awaits.
    _restoreWindow();
    // The player and its external texture are owned by AppModel and survive
    // navigation; only playback is stopped. Destroying the texture per visit is
    // what crashed the raster thread (EmbedderExternalTextureGL + null GrContext).
    _service.stop();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _controlsVisible = false);
    });
  }

  void _showControls() {
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _scheduleHide();
  }

  Future<void> _setFullscreen(bool value) async {
    if (_fullscreen == value) return;
    if (_isDesktop) {
      AppLog.write('fullscreen -> $value');
      final ok = value
          ? _fullscreenController.enter()
          : _fullscreenController.exit();
      if (ok && mounted) setState(() => _fullscreen = value);
      return;
    }
    await SystemChrome.setEnabledSystemUIMode(
      value ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    if (mounted) setState(() => _fullscreen = value);
  }

  Future<void> _toggleFullscreen() => _setFullscreen(!_fullscreen);

  void _handleBack() {
    if (_fullscreen) {
      _setFullscreen(false);
    } else {
      _close();
    }
  }

  /// Restores the window synchronously. Never pops or awaits: calling
  /// `maybePop()` from `onPopInvoked` while `canPop` is still stale caused an
  /// infinite microtask loop (UI thread at 100%, app unresponsive).
  void _restoreWindow() {
    if (!_fullscreen) return;
    _fullscreen = false;
    if (_isDesktop) {
      AppLog.write('fullscreen -> false');
      _fullscreenController.exit();
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _handleVideoTap(Offset position, double width) {
    if (width <= 0) return;
    final fraction = position.dx / width;
    if (!_isLive && fraction < 0.3) {
      _seekRelative(-10);
    } else if (!_isLive && fraction > 0.7) {
      _seekRelative(10);
    } else {
      _player.playOrPause();
      _showControls();
    }
  }

  Widget _seekFeedback() {
    final seconds = _feedbackSeconds;
    if (seconds == null) return const SizedBox.shrink();
    final forward = seconds > 0;
    return IgnorePointer(
      child: Align(
        alignment: Alignment(forward ? 0.42 : -0.42, 0),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.82, end: 1),
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  forward ? Icons.forward_10_rounded : Icons.replay_10_rounded,
                  size: 30,
                  color: Colors.white,
                ),
                const SizedBox(height: 4),
                Text(
                  forward ? '+10s' : '−10s',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scrubPreview() {
    if (!_scrubbing) return const SizedBox.shrink();
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _stamp(_position),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '  /  ${_stamp(_duration)}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white60,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _close() async {
    AppLog.write('player close');
    _player.pause();
    if (mounted) Navigator.of(context).maybePop();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    _showControls();
    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
        _player.playOrPause();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        // Esc leaves fullscreen first; a second Esc closes the player.
        _handleBack();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyF:
        _toggleFullscreen();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        if (_isLive && _hasPrevious) _playIndex(_index - 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        if (_isLive && _hasNext) _playIndex(_index + 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.keyJ:
        _seekRelative(-10);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.keyL:
        _seekRelative(10);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyK:
        _player.playOrPause();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyC:
        _toggleSubtitles();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        // canPop stays true: blocking the pop and re-popping from this callback
        // spins forever because the rebuilt canPop is not visible yet.
        if (didPop) _restoreWindow();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          autofocus: true,
          onKeyEvent: _onKey,
          child: MouseRegion(
            onHover: (_) => _showControls(),
            onExit: (_) => _hideTimer?.cancel(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    // Netflix-style tap zones: left third rewinds, right third
                    // forwards, the middle toggles playback.
                    onTapUp: (details) => _handleVideoTap(
                      details.localPosition,
                      constraints.maxWidth,
                    ),
                    child: Video(
                      controller: _controller,
                      controls: NoVideoControls,
                      fit: BoxFit.contain,
                      fill: Colors.black,
                      subtitleViewConfiguration:
                          const SubtitleViewConfiguration(
                            padding: EdgeInsets.fromLTRB(28, 0, 28, 96),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              shadows: [
                                Shadow(blurRadius: 10, color: Colors.black87),
                                Shadow(blurRadius: 2, color: Colors.black),
                              ],
                            ),
                          ),
                    ),
                  ),
                ),
                if (_buffering && _error == null)
                  Center(
                    child: SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                if (_error != null) _errorPane(),
                _seekFeedback(),
                _scrubPreview(),
                _topBar(),
                _bottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorPane() {
    return Container(
      color: Colors.black.withValues(alpha: 0.82),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 34, color: AppColors.accent),
          const SizedBox(height: 14),
          const Text(
            'Playback failed',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.tonal(onPressed: _open, child: const Text('Retry')),
              const SizedBox(width: 10),
              TextButton(onPressed: _close, child: const Text('Close')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: IgnorePointer(
        ignoring: !_controlsVisible,
        child: AnimatedOpacity(
          opacity: _controlsVisible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 20, 40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.78),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _handleBack,
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                  tooltip: 'Back (Esc)',
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _current.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      if (_current.subtitle != null)
                        Text(
                          _current.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_isLive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !_controlsVisible,
        child: AnimatedOpacity(
          opacity: _controlsVisible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 44, 20, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.85),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isLive && _duration.inMilliseconds > 0) _seekBar(),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (_isLive)
                      _iconButton(
                        icon: const Icon(Icons.skip_previous_rounded),
                        onTap: _hasPrevious
                            ? () => _playIndex(_index - 1)
                            : null,
                        tooltip: 'Previous channel',
                      ),
                    if (!_isLive)
                      _iconButton(
                        icon: const Icon(Icons.replay_10_rounded),
                        onTap: () => _seekRelative(-10),
                        tooltip: 'Back 10 seconds (Left arrow or J)',
                      ),
                    _iconButton(
                      icon: Icon(
                        _playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      size: 30,
                      onTap: _player.playOrPause,
                      tooltip: 'Play / pause (Space or K)',
                    ),
                    if (!_isLive)
                      _iconButton(
                        icon: const Icon(Icons.forward_10_rounded),
                        onTap: () => _seekRelative(10),
                        tooltip: 'Forward 10 seconds (Right arrow or L)',
                      ),
                    if (_isLive)
                      _iconButton(
                        icon: const Icon(Icons.skip_next_rounded),
                        onTap: _hasNext ? () => _playIndex(_index + 1) : null,
                        tooltip: 'Next channel',
                      ),
                    const SizedBox(width: 14),
                    Text(
                      _isLive
                          ? 'LIVE'
                          : '${_stamp(_position)} / -${_stamp(_remaining)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const Spacer(),
                    _subtitleButton(),
                    const SizedBox(width: 6),
                    Icon(
                      _volume == 0
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      size: 19,
                      color: Colors.white70,
                    ),
                    SizedBox(
                      width: 120,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: Colors.white,
                        ),
                        child: Slider(
                          value: _volume,
                          max: 100,
                          onChanged: (value) {
                            setState(() => _volume = value);
                            _player.setVolume(value);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _iconButton(
                      icon: Icon(
                        _fullscreen
                            ? Icons.fullscreen_exit_rounded
                            : Icons.fullscreen_rounded,
                      ),
                      onTap: _toggleFullscreen,
                      tooltip: 'Fullscreen (F)',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _seekBar() {
    final total = _duration.inMilliseconds.toDouble();
    final value = _position.inMilliseconds.toDouble().clamp(
      0.0,
      total == 0 ? 0.0 : total,
    );
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: Colors.white24,
        thumbColor: AppColors.accent,
        overlayColor: AppColors.accent.withValues(alpha: 0.18),
      ),
      child: Slider(
        value: value,
        max: total == 0 ? 1 : total,
        onChangeStart: (_) {
          _hideTimer?.cancel();
          _scrubTimer?.cancel();
          setState(() => _scrubbing = true);
        },
        onChanged: (next) {
          // Preview while dragging; the player's position stream is ignored
          // until the seek is committed, otherwise it snaps the thumb back.
          if (total > 0) {
            setState(() => _position = Duration(milliseconds: next.round()));
          }
        },
        onChangeEnd: (next) {
          final target = Duration(milliseconds: next.round());
          setState(() {
            _position = target;
            _scrubbing = true;
          });
          _player.seek(target);
          _showControls();
          // Hold the lock briefly so the first post-seek positions don't jump.
          _scrubTimer?.cancel();
          _scrubTimer = Timer(const Duration(milliseconds: 450), () {
            if (!mounted) return;
            setState(() => _scrubbing = false);
            _scheduleHide();
          });
        },
      ),
    );
  }

  /// Takes a widget rather than [IconData] on purpose: the release icon-font
  /// tree shaker only sees `const Icon(...)` usages, so passing dynamic IconData
  /// silently removes the glyph and leaves an invisible button.
  Widget _iconButton({
    required Widget icon,
    VoidCallback? onTap,
    double size = 22,
    String? tooltip,
  }) {
    final button = InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: IconTheme.merge(
          data: IconThemeData(
            color: onTap == null ? Colors.white24 : Colors.white,
            size: size,
          ),
          child: icon,
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }

  String _stamp(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
