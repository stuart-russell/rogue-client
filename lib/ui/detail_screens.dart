import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_model.dart';
import '../state/favourites.dart';
import '../state/watch_progress.dart';
import '../theme.dart';
import 'ambient.dart';
import 'catalog_widgets.dart';
import 'responsive.dart';
import 'recents_actions.dart';
import 'favourites_actions.dart';
import 'resume_dialog.dart';
import 'widgets.dart';

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movie});

  final VodStream movie;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  VodInfo? _info;
  bool _loading = true;
  String? _error;
  bool _started = false;
  Color _accent = AppColors.accent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _loadAccent(String? url) async {
    final color = await accentFromArtwork(url);
    if (color != null && mounted) setState(() => _accent = color);
  }

  Future<void> _load() async {
    final api = AppScope.read(context).session.api;
    if (api == null) return;
    _loadAccent(api.absolute(widget.movie.icon));
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final info = await api.vodInfo(widget.movie.streamId);
      if (!mounted) return;
      setState(() {
        _info = info;
        _loading = false;
      });
      _loadAccent(
        api.absolute(info?.backdrop ?? info?.poster ?? widget.movie.icon),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final model = AppScope.of(context);
    final api = model.session.api;
    final poster = api?.absolute(info?.poster ?? widget.movie.icon);
    final backdrop = api?.absolute(
      info?.backdrop ?? info?.poster ?? widget.movie.icon,
    );
    final watch = model.progress.entryFor('vod:${widget.movie.streamId}');
    final resumable =
        watch != null &&
        !watch.completed &&
        watch.position > const Duration(seconds: 20);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: AmbientBackdrop(image: backdrop, accent: _accent),
          ),
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 400,
                pinned: true,
                backgroundColor: Colors.transparent,
                forceMaterialTransparency: true,
                surfaceTintColor: Colors.transparent,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _RoundButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (backdrop != null)
                        ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (rect) => const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white,
                              Colors.white,
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.6, 1.0],
                          ).createShader(rect),
                          child: CachedNetworkImage(
                            imageUrl: backdrop,
                            fit: BoxFit.cover,
                            memCacheWidth: 1400,
                          ),
                        )
                      else
                        ColoredBox(color: AppColors.surfaceHigh),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.background.withValues(alpha: 0.35),
                              AppColors.background.withValues(alpha: 0.55),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.6, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isCompact(context) ? 16 : 30,
                    6,
                    isCompact(context) ? 16 : 30,
                    isCompact(context) ? 24 : 40,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: isCompact(context) ? 140 : 190,
                        child: Column(
                          children: [
                            GestureDetector(
                              onLongPressStart: (details) =>
                                  _showPosterMenu(details.globalPosition),
                              onSecondaryTapUp: (details) =>
                                  _showPosterMenu(details.globalPosition),
                              child: Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.08,
                                        ),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _accent.withValues(
                                            alpha: 0.28,
                                          ),
                                          blurRadius: 28,
                                          offset: const Offset(0, 12),
                                        ),
                                      ],
                                    ),
                                    child: AspectRatio(
                                      aspectRatio: 0.68,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(13),
                                        child: (poster != null)
                                            ? CachedNetworkImage(
                                                imageUrl: poster,
                                                fit: BoxFit.cover,
                                                memCacheWidth: 400,
                                              )
                                            : ColoredBox(
                                                color: AppColors.surfaceHigh,
                                              ),
                                      ),
                                    ),
                                  ),
                                  if (watch?.completed == true)
                                    const Positioned(
                                      top: 10,
                                      right: 10,
                                      child: WatchedBadge(size: 26),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: FilledButton.icon(
                                onPressed: () => _play(
                                  poster,
                                  startAt: resumable ? watch.position : null,
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _accent,
                                  foregroundColor: Colors.white,
                                  elevation: 6,
                                  shadowColor: _accent.withValues(alpha: 0.45),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 22,
                                ),
                                label: Text(
                                  resumable
                                      ? 'Resume ${stampDuration(watch.position)}'
                                      : 'Play film',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            if (resumable) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                height: 40,
                                child: OutlinedButton(
                                  onPressed: () =>
                                      _play(poster, startAt: Duration.zero),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.text,
                                    side: BorderSide(color: AppColors.border),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('From start'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(width: isCompact(context) ? 16 : 30),
                      Expanded(child: _details(info, backdrop)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPosterMenu(Offset position) {
    showItemMenu(
      context,
      position,
      favourite: favouriteForMovie(AppScope.read(context), widget.movie),
      watchId: 'vod:${widget.movie.streamId}',
    );
  }

  void _play(String? poster, {Duration? startAt}) {
    final model = AppScope.read(context);
    model.recents.add(recentForMovie(model, widget.movie));
    final movie = _info == null
        ? widget.movie
        : VodStream(
            streamId: widget.movie.streamId,
            name: widget.movie.name,
            icon: widget.movie.icon,
            categoryId: widget.movie.categoryId,
            containerExtension: _info!.containerExtension,
          );
    final media = vodToMedia(
      model,
      movie,
      poster: poster,
    ).copyWith(startAt: startAt);
    openPlayer(context, [media], 0);
  }

  Widget _details(VodInfo? info, String? backdrop) {
    final title = info?.name ?? widget.movie.name;
    final model = AppScope.of(context);
    final watch = model.progress.entryFor('vod:${widget.movie.streamId}');
    final isFavourite = model.favourites.contains(
      FavouriteType.vod,
      widget.movie.streamId,
    );
    final chips = <Widget>[
      if (info?.rating != null)
        MetaChip(
          label: '★ ${info!.rating!.toStringAsFixed(1)}',
          color: AppColors.warning,
        ),
      if (info?.releaseDate != null && info!.releaseDate!.isNotEmpty)
        MetaChip(label: info.releaseDate!),
      if (info?.duration != null)
        MetaChip(label: info!.duration!, icon: Icons.schedule_rounded),
      if (info?.genre != null) MetaChip(label: info!.genre!),
      MetaChip(
        label: (info?.containerExtension ?? widget.movie.containerExtension)
            .toUpperCase(),
      ),
      if (watch != null)
        MetaChip(
          label: watch.completed
              ? 'Watched'
              : '${watch.remaining.inMinutes} min left',
          icon: watch.completed ? Icons.check_rounded : Icons.timelapse_rounded,
          color: watch.completed ? AppColors.success : _accent,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  height: 1.1,
                ),
              ),
            ),
            IconButton(
              onPressed: () => toggleFavourite(
                context,
                favouriteForMovie(model, widget.movie),
              ),
              tooltip: isFavourite
                  ? 'Remove from favourites'
                  : 'Add to favourites',
              icon: Icon(
                isFavourite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: isFavourite ? AppColors.accent : AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
        const SizedBox(height: 22),
        if (_loading)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text(
                  'Loading details…',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                ),
              ],
            ),
          )
        else if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
        if (info?.plot != null && info!.plot!.isNotEmpty) ...[
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Text(
              info.plot!,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.65,
                color: AppColors.text,
              ),
            ),
          ),
          const SizedBox(height: 22),
        ],
        if (info?.director != null && info!.director!.isNotEmpty)
          _labelled('Director', info.director!),
        if (info?.cast != null && info!.cast!.isNotEmpty)
          _labelled('Cast', info.cast!),
      ],
    );
  }

  Widget _labelled(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.text,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SeriesDetailScreen extends StatefulWidget {
  const SeriesDetailScreen({super.key, required this.series});

  final SeriesItem series;

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  SeriesInfo? _info;
  bool _loading = true;
  String? _error;
  bool _started = false;
  int? _season;
  Color _accent = AppColors.accent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _loadAccent(String? url) async {
    final color = await accentFromArtwork(url);
    if (color != null && mounted) setState(() => _accent = color);
  }

  Future<void> _load() async {
    final api = AppScope.read(context).session.api;
    if (api == null) return;
    _loadAccent(api.absolute(widget.series.cover));
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final info = await api.seriesInfo(widget.series.seriesId);
      if (!mounted) return;
      setState(() {
        _info = info;
        _season = info?.seasons.keys.isEmpty ?? true
            ? null
            : info!.seasons.keys.first;
        _loading = false;
      });
      _loadAccent(
        api.absolute(info?.backdrop ?? info?.cover ?? widget.series.cover),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final model = AppScope.of(context);
    final api = model.session.api;
    final cover = api?.absolute(info?.cover ?? widget.series.cover);
    final backdrop = api?.absolute(
      info?.backdrop ?? info?.cover ?? widget.series.cover,
    );
    final episodes = (_season != null && info != null)
        ? (info.seasons[_season] ?? const <Episode>[])
        : const <Episode>[];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: AmbientBackdrop(image: backdrop, accent: _accent),
          ),
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 380,
                pinned: true,
                backgroundColor: Colors.transparent,
                forceMaterialTransparency: true,
                surfaceTintColor: Colors.transparent,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _RoundButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (backdrop != null)
                        ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (rect) => const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white,
                              Colors.white,
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.6, 1.0],
                          ).createShader(rect),
                          child: CachedNetworkImage(
                            imageUrl: backdrop,
                            fit: BoxFit.cover,
                            memCacheWidth: 1400,
                          ),
                        )
                      else
                        ColoredBox(color: AppColors.surfaceHigh),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.background.withValues(alpha: 0.35),
                              AppColors.background.withValues(alpha: 0.55),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.6, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isCompact(context) ? 16 : 30,
                    6,
                    isCompact(context) ? 16 : 30,
                    isCompact(context) ? 20 : 30,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: isCompact(context) ? 130 : 170,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _accent.withValues(alpha: 0.28),
                                blurRadius: 26,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: AspectRatio(
                            aspectRatio: 0.68,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: (cover != null)
                                  ? CachedNetworkImage(
                                      imageUrl: cover,
                                      fit: BoxFit.cover,
                                      memCacheWidth: 400,
                                    )
                                  : ColoredBox(color: AppColors.surfaceHigh),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 28),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.series.name,
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => toggleFavourite(
                                    context,
                                    favouriteForSeries(model, widget.series),
                                  ),
                                  tooltip:
                                      model.favourites.contains(
                                        FavouriteType.series,
                                        widget.series.seriesId,
                                      )
                                      ? 'Remove from favourites'
                                      : 'Add to favourites',
                                  icon: Icon(
                                    model.favourites.contains(
                                          FavouriteType.series,
                                          widget.series.seriesId,
                                        )
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    size: 20,
                                    color:
                                        model.favourites.contains(
                                          FavouriteType.series,
                                          widget.series.seriesId,
                                        )
                                        ? AppColors.accent
                                        : AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Series',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (widget.series.rating != null)
                                  MetaChip(
                                    label:
                                        '★ ${widget.series.rating!.toStringAsFixed(1)}',
                                    color: AppColors.warning,
                                  ),
                                if (widget.series.releaseDate != null)
                                  MetaChip(label: widget.series.releaseDate!),
                                if (widget.series.genre != null)
                                  MetaChip(label: widget.series.genre!),
                                if (info != null)
                                  MetaChip(
                                    label: '${info.seasons.length} seasons',
                                    icon: Icons.video_library_outlined,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            if (_loading)
                              Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Loading episodes…',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              )
                            else if (_error != null)
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12.5,
                                ),
                              ),
                            if (info?.plot != null && info!.plot!.isNotEmpty)
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 700,
                                ),
                                child: Text(
                                  info.plot!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.6,
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (info != null && info.seasons.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isCompact(context) ? 16 : 30,
                      0,
                      isCompact(context) ? 16 : 30,
                      14,
                    ),
                    child: SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: info.seasons.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final season = info.seasons.keys.elementAt(index);
                          final active = season == _season;
                          return GestureDetector(
                            onTap: () => setState(() => _season = season),
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: active
                                    ? _accent.withValues(alpha: 0.16)
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: active
                                      ? _accent.withValues(alpha: 0.65)
                                      : AppColors.border,
                                ),
                              ),
                              child: Text(
                                'Season $season',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: active
                                      ? AppColors.text
                                      : AppColors.textMuted,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  isCompact(context) ? 16 : 30,
                  0,
                  isCompact(context) ? 16 : 30,
                  32,
                ),
                sliver: SliverList.separated(
                  itemCount: episodes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final episode = episodes[index];
                    final model = AppScope.of(context);
                    final entry = model.progress.entryFor('ep:${episode.id}');
                    return _EpisodeTile(
                      episode: episode,
                      entry: entry,
                      onContextMenu: (position) => showItemMenu(
                        context,
                        position,
                        watchId: 'ep:${episode.id}',
                      ),
                      onTap: () async {
                        Duration? startAt;
                        if (entry != null &&
                            !entry.completed &&
                            entry.position > const Duration(seconds: 20)) {
                          startAt = await showResumeDialog(
                            context,
                            entry,
                            episode.title,
                          );
                          if (startAt == null) return;
                        }
                        final playlist = [
                          for (final e in episodes)
                            episodeToMedia(model, e, widget.series.name, cover),
                        ];
                        if (startAt != null) {
                          playlist[index] = playlist[index].copyWith(
                            startAt: startAt,
                          );
                        }
                        model.recents.add(
                          recentForSeries(model, widget.series),
                        );
                        if (!context.mounted) return;
                        openPlayer(context, playlist, index);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EpisodeTile extends StatefulWidget {
  const _EpisodeTile({
    required this.episode,
    required this.entry,
    required this.onTap,
    required this.onContextMenu,
  });

  final Episode episode;
  final WatchEntry? entry;
  final VoidCallback onTap;
  final ValueChanged<Offset> onContextMenu;

  @override
  State<_EpisodeTile> createState() => _EpisodeTileState();
}

class _EpisodeTileState extends State<_EpisodeTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final episode = widget.episode;
    final entry = widget.entry;
    final progress =
        entry != null && entry.duration.inSeconds > 0 && !entry.completed
        ? entry.fraction
        : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPressStart: (details) =>
            widget.onContextMenu(details.globalPosition),
        onSecondaryTapUp: (details) =>
            widget.onContextMenu(details.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.surface
                : AppColors.surface.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: _hovered ? AppColors.border : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: entry?.completed == true
                          ? AppColors.success.withValues(alpha: 0.16)
                          : AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'E${episode.episodeNum.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: entry?.completed == true
                            ? AppColors.success
                            : AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          episode.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (episode.plot != null)
                          Text(
                            episode.plot!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (entry?.completed == true)
                    MetaChip(
                      label: 'Watched',
                      icon: Icons.check_rounded,
                      color: AppColors.success,
                    )
                  else if (progress != null)
                    MetaChip(
                      label: '${entry!.remaining.inMinutes} min left',
                      icon: Icons.timelapse_rounded,
                      color: AppColors.accent,
                    ),
                  const SizedBox(width: 10),
                  if (episode.duration != null) ...[
                    MetaChip(label: episode.duration!),
                    const SizedBox(width: 10),
                  ],
                  Icon(
                    entry?.completed == true
                        ? Icons.check_circle_rounded
                        : Icons.play_arrow_rounded,
                    size: 21,
                    color: entry?.completed == true
                        ? AppColors.success
                        : AppColors.textMuted,
                  ),
                ],
              ),
              if (progress != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 2.5,
                    backgroundColor: AppColors.surfaceHigh,
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

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}
