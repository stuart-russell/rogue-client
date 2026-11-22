import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../data/models.dart';
import '../core/search_text.dart';
import '../state/app_model.dart';
import '../state/catalog_controller.dart';
import '../state/preview_player.dart';
import '../theme.dart';
import 'catalog_widgets.dart';
import 'focusable_tap.dart';
import 'compact_channel_tile.dart';
import 'responsive.dart';
import 'favourites_actions.dart';
import '../state/recents.dart';
import 'recents_actions.dart';
import 'player_screen.dart';
import 'widgets.dart';

/// Sky-style TV guide: vertical categories -> banner (now playing + mini player)
/// -> channel rows with a timeline.
class LiveGuideScreen extends StatefulWidget {
  const LiveGuideScreen({super.key, required this.active});

  /// False while another tab is selected; the preview releases the panel
  /// connection so it does not compete with playback elsewhere.
  final bool active;

  @override
  State<LiveGuideScreen> createState() => LiveGuideScreenState();
}

class LiveGuideScreenState extends State<LiveGuideScreen>
    with WidgetsBindingObserver {
  static const double _rowHeight = 62;
  static const double _channelWidth = 200;
  static const double _rulerHeight = 34;
  static const double _pxPerMinute = 4;

  final _search = TextEditingController();
  final _horizontal = ScrollController();
  final _gridScroll = ScrollController();
  final _channelScroll = ScrollController();
  final _preview = PreviewPlayer();
  final _categoryKey = GlobalKey();
  final _categoryFocus = FocusNode(debugLabel: 'guide-category');

  int? _categoryId;
  int? _selectedId;
  String _query = '';
  bool _syncing = false;
  bool _initialJumpDone = false;
  bool _resumed = true;
  Timer? _clock;

  late final DateTime _windowStart;
  late final DateTime _windowEnd;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _windowStart = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute - now.minute % 30,
    );
    _windowEnd = _windowStart.add(const Duration(hours: 12));

    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _resumed = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _startClock();

    _gridScroll.addListener(() => _sync(_gridScroll, _channelScroll));
    _channelScroll.addListener(() => _sync(_channelScroll, _gridScroll));
  }

  void _startClock() {
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted || !_resumed) return;
      setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (_resumed == resumed) return;
    _resumed = resumed;
    if (resumed) {
      _startClock();
      final model = AppScope.read(context);
      if (model.epg.isStale && (ModalRoute.of(context)?.isCurrent ?? true)) {
        // With the cached engine the app can stay alive for days; pick up a
        // fresh guide instead of showing yesterday's programmes. Skip it while
        // a player route owns the panel connection.
        unawaited(model.epg.load(force: true));
      }
      if (widget.active) _resumePreview(force: true);
      return;
    }
    // The Flutter engine now survives leaving the app, so stop the minute
    // clock and the preview stream until the viewer comes back.
    _clock?.cancel();
    _clock = null;
    _preview.halt();
  }

  @override
  void didUpdateWidget(covariant LiveGuideScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) return;
    if (widget.active) {
      _resumePreview(force: true);
    } else {
      _preview.halt();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _categoryFocus.dispose();
    _clock?.cancel();
    _search.dispose();
    _horizontal.dispose();
    _gridScroll.dispose();
    _channelScroll.dispose();
    _preview.dispose();
    super.dispose();
  }

  void _sync(ScrollController from, ScrollController to) {
    if (_syncing || !to.hasClients || !from.hasClients) return;
    _syncing = true;
    to.jumpTo(from.offset.clamp(0.0, to.position.maxScrollExtent));
    _syncing = false;
  }

  double get _totalWidth =>
      _windowEnd.difference(_windowStart).inMinutes * _pxPerMinute;

  double _nowX(DateTime now) =>
      now.difference(_windowStart).inMinutes * _pxPerMinute;

  void _jumpToNow({bool animate = true}) {
    if (!_horizontal.hasClients) return;
    final target =
        (_nowX(DateTime.now()) - _horizontal.position.viewportDimension * 0.2)
            .clamp(0.0, _horizontal.position.maxScrollExtent);
    if (animate) {
      _horizontal.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _horizontal.jumpTo(target);
    }
  }

  void _shiftTime(double hours) {
    if (!_horizontal.hasClients) return;
    final target = (_horizontal.offset + hours * 60 * _pxPerMinute).clamp(
      0.0,
      _horizontal.position.maxScrollExtent,
    );
    _horizontal.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  LiveStream? _selected(List<LiveStream> channels) {
    if (channels.isEmpty) return null;
    return channels.firstWhere(
      (channel) => channel.streamId == _selectedId,
      orElse: () => channels.first,
    );
  }

  /// TV Back within the guide: grid/content -> category rail.
  ///
  /// Returns false when the category rail already has focus, so the shell can
  /// continue to the sidebar and then the exit prompt.
  bool handleBack() {
    if (!isTv(context) || !_resumed) return false;
    final focus = FocusManager.instance.primaryFocus?.context;
    if (focus != null && _isWithin(_categoryKey, focus)) return false;
    if (_categoryFocus.context == null) return false;
    _categoryFocus.requestFocus();
    return true;
  }

  bool _isWithin(GlobalKey key, BuildContext focus) {
    final target = key.currentContext;
    if (target == null) return false;
    if (identical(focus, target)) return true;
    var inside = false;
    focus.visitAncestorElements((element) {
      if (identical(element, target)) {
        inside = true;
        return false;
      }
      return true;
    });
    return inside;
  }

  void _resumePreview({bool force = false}) {
    if (!_resumed) return;
    // A pushed player route owns the panel connection.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final model = AppScope.read(context);
    if (model.preferences.performanceMode) {
      _preview.release();
      return;
    }
    final catalog = model.catalog;
    var channels = catalog.channelsIn(_categoryId);
    if (_query.isNotEmpty) {
      channels = channels
          .where((c) => matchesSearch(c.name, _query))
          .toList(growable: false);
    }
    final channel = _selected(channels);
    final api = model.session.api;
    if (channel == null || api == null) return;
    final url = api.liveUrl(
      channel.streamId,
      extension: model.preferences.liveExtension,
    );
    _preview.show(url, force: force);
  }

  Future<void> _openMedia(
    List<PlayableMedia> playlist,
    int index, {
    RecentItem? recent,
  }) async {
    if (recent != null) AppScope.read(context).recents.add(recent);
    await _preview.halt();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'player'),
        builder: (_) => PlayerScreen(playlist: playlist, initialIndex: index),
      ),
    );
    if (!mounted) return;
    if (widget.active) _resumePreview(force: true);
  }

  void _onChannelTap(AppModel model, List<LiveStream> channels, int index) {
    final channel = channels[index];
    if (_selectedId == channel.streamId) {
      _openMedia(
        [for (final c in channels) liveToMedia(model, c)],
        index,
        recent: recentForChannel(model, channel),
      );
      return;
    }
    setState(() => _selectedId = channel.streamId);
  }

  void _openProgramme(
    AppModel model,
    List<LiveStream> channels,
    int index,
    Programme programme,
  ) {
    final channel = channels[index];
    final now = DateTime.now();
    final live = !now.isBefore(programme.start) && now.isBefore(programme.stop);

    if (live) {
      _openMedia(
        [for (final c in channels) liveToMedia(model, c)],
        index,
        recent: recentForChannel(model, channel),
      );
      return;
    }

    final archived =
        programme.stop.isBefore(now) &&
        channel.hasArchive &&
        channel.archiveDays > 0 &&
        programme.start.isAfter(
          now.subtract(Duration(days: channel.archiveDays)),
        );

    if (archived) {
      final api = model.session.api;
      if (api == null) return;
      final minutes = programme.stop
          .difference(programme.start)
          .inMinutes
          .clamp(1, 24 * 60);
      _openMedia(
        [
          PlayableMedia(
            url: api.timeshiftUrl(
              channel.streamId,
              programme.start,
              minutes: minutes,
            ),
            title: channel.name,
            subtitle: '${programme.title} - replay',
            poster: api.absolute(channel.icon),
          ),
        ],
        0,
        recent: recentForChannel(model, channel),
      );
      return;
    }

    if (programme.start.isAfter(now)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            width: 380,
            content: Text(
              '${programme.title} starts at ${clock(programme.start)}',
            ),
          ),
        );
      return;
    }

    _openMedia(
      [for (final c in channels) liveToMedia(model, c)],
      index,
      recent: recentForChannel(model, channel),
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final catalog = model.catalog;
    final guide = model.epg;

    var channels = catalog.channelsIn(_categoryId);
    if (_query.isNotEmpty) {
      channels = channels
          .where((c) => matchesSearch(c.name, _query))
          .toList(growable: false);
    }

    final selected = _selected(channels);
    final categories = catalog.categoriesFor(CatalogSegment.live);
    final performance = model.preferences.performanceMode;
    final now = DateTime.now();

    // Phones get a now/next list instead of the 12-hour grid, and no silent
    // data use from the preview player.
    final compact = isCompact(context);

    if (!compact && selected != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        if (_selectedId != selected.streamId) {
          setState(() => _selectedId = selected.streamId);
          return;
        }
        if (!widget.active) return;
        if (!_resumed) return;
        if (performance) {
          await _preview.release();
          return;
        }
        final api = model.session.api;
        if (api == null) return;
        final url = api.liveUrl(
          selected.streamId,
          extension: model.preferences.liveExtension,
        );
        final hadVideo = _preview.hasVideo;
        await _preview.show(url);
        // Rebuild once when the texture is first created; later channel
        // switches reuse the existing Video widget and must not setState here
        // or this post-frame would loop every build.
        if (!hadVideo && mounted) setState(() {});
      });
    }

    if (compact) {
      return _buildCompact(model, channels, categories);
    }

    return CatalogScaffold(
      title: 'TV Guide',
      subtitle: '${channels.length} channels · now ${clock(now)}',
      actions: [
        if (guide.loading)
          Padding(
            padding: EdgeInsets.only(right: 10),
            child: MetaChip(
              label: 'Loading guide…',
              icon: Icons.downloading_rounded,
              color: AppColors.blue,
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _TimeButton(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Back 2 hours',
              onTap: () => _shiftTime(-2),
            ),
          ),
        _TimeButton(
          icon: Icons.my_location_rounded,
          tooltip: 'Jump to now',
          onTap: _jumpToNow,
        ),
        _TimeButton(
          icon: Icons.chevron_right_rounded,
          tooltip: 'Forward 2 hours',
          onTap: () => _shiftTime(2),
        ),
        const SizedBox(width: 10),
        refreshButton(
          busy: catalog.loading[CatalogSegment.live] ?? false,
          onPressed: () => catalog.load(CatalogSegment.live, force: true),
        ),
      ],
      child: catalog.countFor(CatalogSegment.live, null) == 0
          ? segmentStatus(
              catalog: catalog,
              segment: CatalogSegment.live,
              onRetry: () => catalog.load(CatalogSegment.live, force: true),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Keep search in the content column so D-pad Up from the
                // category rail or grid can reach it.
                SearchField(
                  controller: _search,
                  hint: 'Find a channel…',
                  onChanged: (value) => setState(() => _query = value.trim()),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CategoryRail(
                        key: _categoryKey,
                        selectedFocusNode: _categoryFocus,
                        items: categoriesToRail(
                          categories,
                          catalog.countFor(CatalogSegment.live, null),
                          (id) => catalog.countFor(CatalogSegment.live, id),
                        ),
                        selected: _categoryId,
                        onSelected: (id) => setState(() {
                          _categoryId = id;
                          _selectedId = null;
                        }),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (selected != null)
                              _Banner(
                                model: model,
                                channel: selected,
                                preview: _preview,
                                performance: performance,
                              ),
                            if (!guide.hasData)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_month_outlined,
                                      size: 16,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        guide.error ?? 'Guide data not loaded yet — channels are listed without programmes.',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: guide.loading
                                          ? null
                                          : () => guide.load(force: true),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.accent,
                                      ),
                                      child: const Text('Load guide'),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: channels.isEmpty
                                  ? const StatusPane(
                                      icon: Icons.search_off_rounded,
                                      title: 'No channels match',
                                    )
                                  : _buildGrid(model, channels, selected, now),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCompact(
    AppModel model,
    List<LiveStream> channels,
    List<Category> categories,
  ) {
    final catalog = model.catalog;
    final guide = model.epg;
    final busy = catalog.loading[CatalogSegment.live] ?? false;
    final pad = pagePadding(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(pad, pageTopPadding(context), pad, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionHeader(
                  title: 'TV Guide',
                  subtitle: '${channels.length} channels',
                ),
              ),
              refreshButton(
                busy: busy,
                onPressed: () => catalog.load(CatalogSegment.live, force: true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SearchField(
            controller: _search,
            hint: 'Find a channel…',
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
          const SizedBox(height: 10),
          if (categories.isNotEmpty) ...[
            CategoryChips(
              categories: categories,
              total: catalog.countFor(CatalogSegment.live, null),
              selected: _categoryId,
              countFor: (id) => catalog.countFor(CatalogSegment.live, id),
              onSelected: (id) => setState(() {
                _categoryId = id;
                _selectedId = null;
              }),
            ),
            const SizedBox(height: 10),
          ],
          if (!guide.hasData)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Guide data not loaded — channels only.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: guide.loading
                        ? null
                        : () => guide.load(force: true),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                    ),
                    child: const Text('Load'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: channels.isEmpty
                ? const StatusPane(
                    icon: Icons.search_off_rounded,
                    title: 'No channels match',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 18),
                    itemCount: channels.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: AppColors.border.withValues(alpha: 0.55),
                    ),
                    itemBuilder: (context, index) {
                      final channel = channels[index];
                      return CompactChannelTile(
                        channel: channel,
                        programme: guide.now(channel.epgChannelId),
                        next: guide.next(channel.epgChannelId),
                        onTap: () => _openMedia(
                          [for (final c in channels) liveToMedia(model, c)],
                          index,
                          recent: recentForChannel(model, channel),
                        ),
                        onLongPress: (position) => showFavouriteMenu(
                          context,
                          position,
                          favouriteForChannel(model, channel),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(
    AppModel model,
    List<LiveStream> channels,
    LiveStream? selected,
    DateTime now,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialJumpDone && mounted && _horizontal.hasClients) {
        _initialJumpDone = true;
        _jumpToNow(animate: false);
      }
    });

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.35),
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _channelWidth,
              child: Column(
                children: [
                  Container(
                    height: _rulerHeight,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 14),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: Text(
                      'CHANNEL',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _channelScroll,
                      itemExtent: _rowHeight,
                      itemCount: channels.length,
                      itemBuilder: (context, index) => _ChannelRow(
                        channel: channels[index],
                        selected:
                            selected != null &&
                            channels[index].streamId == selected.streamId,
                        onTap: () => _onChannelTap(model, channels, index),
                        onContextMenu: (position) => showFavouriteMenu(
                          context,
                          position,
                          favouriteForChannel(model, channels[index]),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                    PointerDeviceKind.stylus,
                  },
                  scrollbars: false,
                ),
                child: Scrollbar(
                  controller: _horizontal,
                  thumbVisibility: true,
                  scrollbarOrientation: ScrollbarOrientation.bottom,
                  child: SingleChildScrollView(
                    controller: _horizontal,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: _totalWidth,
                      child: Stack(
                        children: [
                          Column(
                            children: [
                              SizedBox(
                                height: _rulerHeight,
                                child: _Ruler(
                                  windowStart: _windowStart,
                                  windowEnd: _windowEnd,
                                  pxPerMinute: _pxPerMinute,
                                ),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  controller: _gridScroll,
                                  itemExtent: _rowHeight,
                                  itemCount: channels.length,
                                  itemBuilder: (context, index) {
                                    final channel = channels[index];
                                    return _TimelineRow(
                                      programmes: model.epg.forChannel(
                                        channel.epgChannelId,
                                      ),
                                      windowStart: _windowStart,
                                      windowEnd: _windowEnd,
                                      pxPerMinute: _pxPerMinute,
                                      now: now,
                                      selected:
                                          selected != null &&
                                          channel.streamId == selected.streamId,
                                      onSelected: (programme) => _openProgramme(
                                        model,
                                        channels,
                                        index,
                                        programme,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            left: _nowX(now),
                            top: _rulerHeight,
                            bottom: 0,
                            child: IgnorePointer(
                              child: Container(
                                width: 2,
                                color: AppColors.accent.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.model,
    required this.channel,
    required this.preview,
    required this.performance,
  });

  final AppModel model;
  final LiveStream channel;
  final PreviewPlayer preview;
  final bool performance;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final current = model.epg.now(channel.epgChannelId);
    final next = model.epg.next(channel.epgChannelId);
    final progress = current == null
        ? null
        : (now.difference(current.start).inSeconds /
                  current.stop.difference(current.start).inSeconds)
              .clamp(0.0, 1.0);

    return Container(
      height: 172,
      decoration: glassPanel(radius: 14),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
              child: Row(
                children: [
                  ChannelAvatar(
                    name: channel.name,
                    image: channel.icon,
                    size: 64,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                channel.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            MetaChip(label: 'LIVE', color: AppColors.accent),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          current?.title ?? 'No guide data for this channel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          current == null
                              ? 'Select the channel again to watch it full screen'
                              : '${timeRange(current.start, current.stop)}  ·  ${_progressLabel(now, current.stop)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                        if (progress != null) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 3,
                              backgroundColor: AppColors.surfaceHigh,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                        if (next != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Next: ${next.title} at ${clock(next.start)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  color: Colors.black,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (performance)
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ChannelAvatar(
                                name: channel.name,
                                image: channel.icon,
                                size: 84,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Preview off · performance mode',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (preview.hasVideo)
                        Video(
                          controller: preview.controller,
                          controls: NoVideoControls,
                          fit: BoxFit.cover,
                        )
                      else
                        Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _progressLabel(DateTime now, DateTime stop) {
    final left = stop.difference(now);
    if (left.isNegative) return 'ending';
    if (left.inMinutes < 1) return 'less than a minute left';
    return '${left.inMinutes} min left';
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 19),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textMuted,
          side: BorderSide(color: AppColors.border),
          minimumSize: const Size(34, 34),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.channel,
    required this.selected,
    required this.onTap,
    required this.onContextMenu,
  });

  final LiveStream channel;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<Offset> onContextMenu;

  @override
  Widget build(BuildContext context) {
    return FocusableTap(
      onTap: onTap,
      onLongPressStart: (details) => onContextMenu(details.globalPosition),
      onSecondaryTapUp: (details) => onContextMenu(details.globalPosition),
      builder: (context, focused) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        foregroundDecoration: focused
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accent, width: 2),
              )
            : null,
        decoration: BoxDecoration(
          color: focused
              ? AppColors.accent.withValues(alpha: 0.2)
              : selected
              ? AppColors.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          boxShadow: focused
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.28),
                    blurRadius: 12,
                  ),
                ]
              : const [],
          border: Border(
            bottom: BorderSide(color: AppColors.border, width: 0.6),
            left: BorderSide(
              color: selected || focused
                  ? AppColors.accent
                  : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            ChannelAvatar(name: channel.name, image: channel.icon, size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                channel.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
            if (selected)
              Icon(
                Icons.play_circle_outline_rounded,
                size: 16,
                color: AppColors.accent,
              ),
          ],
        ),
      ),
    );
  }
}

class _Ruler extends StatelessWidget {
  const _Ruler({
    required this.windowStart,
    required this.windowEnd,
    required this.pxPerMinute,
  });

  final DateTime windowStart;
  final DateTime windowEnd;
  final double pxPerMinute;

  @override
  Widget build(BuildContext context) {
    final totalMinutes = windowEnd.difference(windowStart).inMinutes;
    final ticks = <Widget>[];
    for (var minute = 0; minute <= totalMinutes; minute += 30) {
      final time = windowStart.add(Duration(minutes: minute));
      final onHour = time.minute == 0;
      ticks.add(
        Positioned(
          left: minute * pxPerMinute,
          top: 0,
          bottom: 0,
          child: Container(
            width: 1,
            color: AppColors.border.withValues(alpha: onHour ? 0.9 : 0.45),
          ),
        ),
      );
      if (onHour) {
        ticks.add(
          Positioned(
            left: minute * pxPerMinute + 6,
            top: 8,
            child: Text(
              clock(time),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
        );
      }
    }
    return Stack(children: ticks);
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.programmes,
    required this.windowStart,
    required this.windowEnd,
    required this.pxPerMinute,
    required this.now,
    required this.selected,
    required this.onSelected,
  });

  final List<Programme> programmes;
  final DateTime windowStart;
  final DateTime windowEnd;
  final double pxPerMinute;
  final DateTime now;
  final bool selected;
  final ValueChanged<Programme> onSelected;

  @override
  Widget build(BuildContext context) {
    final blocks = <Widget>[];
    for (final programme in programmes) {
      if (!programme.stop.isAfter(windowStart) ||
          !programme.start.isBefore(windowEnd)) {
        continue;
      }
      final start = programme.start.isBefore(windowStart)
          ? windowStart
          : programme.start;
      final stop = programme.stop.isAfter(windowEnd)
          ? windowEnd
          : programme.stop;
      final left = start.difference(windowStart).inMinutes * pxPerMinute;
      final width = stop.difference(start).inMinutes * pxPerMinute - 3;
      if (width <= 2) continue;
      final live =
          !now.isBefore(programme.start) && now.isBefore(programme.stop);
      blocks.add(
        Positioned(
          left: left,
          top: 4,
          width: width,
          bottom: 4,
          child: _ProgrammeBlock(
            programme: programme,
            live: live,
            selected: selected,
            progress: live
                ? now.difference(programme.start).inSeconds /
                      programme.stop.difference(programme.start).inSeconds
                : null,
            onTap: () => onSelected(programme),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.6)),
      ),
      child: Stack(children: blocks),
    );
  }
}

class _ProgrammeBlock extends StatefulWidget {
  const _ProgrammeBlock({
    required this.programme,
    required this.live,
    required this.selected,
    required this.progress,
    required this.onTap,
  });

  final Programme programme;
  final bool live;
  final bool selected;
  final double? progress;
  final VoidCallback onTap;

  @override
  State<_ProgrammeBlock> createState() => _ProgrammeBlockState();
}

class _ProgrammeBlockState extends State<_ProgrammeBlock> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final live = widget.live;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(9, 3, 9, 3),
          decoration: BoxDecoration(
            color: live
                ? AppColors.accent.withValues(alpha: 0.16)
                : widget.selected
                ? AppColors.surfaceHigh.withValues(alpha: 0.9)
                : _hovered
                ? AppColors.surfaceHigh
                : AppColors.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: live
                  ? AppColors.accent.withValues(alpha: 0.55)
                  : AppColors.border.withValues(alpha: 0.7),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  if (live) ...[
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],
                  Expanded(
                    child: Text(
                      widget.programme.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: live ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                '${clock(widget.programme.start)} – ${clock(widget.programme.stop)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  color: live ? AppColors.accent : AppColors.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (live && widget.progress != null) ...[
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: widget.progress!.clamp(0.0, 1.0),
                    minHeight: 2.5,
                    backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                    color: AppColors.accent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
