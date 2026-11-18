import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_model.dart';
import '../state/favourites.dart';
import '../state/recents.dart';
import '../theme.dart';
import 'catalog_widgets.dart';
import 'detail_screens.dart';
import 'favourites_actions.dart';
import 'responsive.dart';
import 'widgets.dart';

class FavouritesScreen extends StatelessWidget {
  const FavouritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final adult = model.catalog;
    final channels = model.favourites
        .of(FavouriteType.live)
        .where((f) => !adult.isAdultCategoryId(f.categoryId))
        .toList(growable: false);
    final movies = model.favourites
        .of(FavouriteType.vod)
        .where((f) => !adult.isAdultCategoryId(f.categoryId))
        .toList(growable: false);
    final series = model.favourites
        .of(FavouriteType.series)
        .where((f) => !adult.isAdultCategoryId(f.categoryId))
        .toList(growable: false);
    final empty = channels.isEmpty && movies.isEmpty && series.isEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        pagePadding(context),
        pageTopPadding(context),
        pagePadding(context),
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Favourites',
            subtitle: empty
                ? 'Right-click or long-press a channel, film or series to save it here'
                : '${model.favourites.length} saved',
          ),
          const SizedBox(height: 18),
          Expanded(
            child: empty
                ? const StatusPane(
                    icon: Icons.favorite_border_rounded,
                    title: 'No favourites yet',
                    message:
                        'Right-click (or long-press on touch) any channel, movie or series, '
                        'then choose “Add to favourites”. They will appear here.',
                  )
                : Scrollbar(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 30),
                      children: [
                        if (channels.isNotEmpty) ...[
                          _SectionTitle(
                            label: 'Channels',
                            count: channels.length,
                          ),
                          for (var i = 0; i < channels.length; i++)
                            _FavouriteChannelRow(
                              favourite: channels[i],
                              onPlay: () =>
                                  _playChannel(context, model, channels, i),
                              onMenu: (position) => showFavouriteMenu(
                                context,
                                position,
                                channels[i],
                              ),
                            ),
                          const SizedBox(height: 22),
                        ],
                        if (movies.isNotEmpty) ...[
                          _SectionTitle(label: 'Movies', count: movies.length),
                          _posterWrap(context, model, movies),
                          const SizedBox(height: 22),
                        ],
                        if (series.isNotEmpty) ...[
                          _SectionTitle(label: 'Series', count: series.length),
                          _posterWrap(context, model, series),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _posterWrap(
    BuildContext context,
    AppModel model,
    List<Favourite> items,
  ) {
    return Wrap(
      spacing: 14,
      runSpacing: 18,
      children: [
        for (final favourite in items)
          SizedBox(
            width: 150,
            height: 224,
            child: PosterCard(
              title: favourite.name,
              image: favourite.image,
              progress: favourite.type == FavouriteType.vod
                  ? model.progress.entryFor('vod:${favourite.id}')?.fraction
                  : null,
              watched:
                  favourite.type == FavouriteType.vod &&
                  model.progress.entryFor('vod:${favourite.id}')?.completed ==
                      true,
              onContextMenu: (position) => showItemMenu(
                context,
                position,
                favourite: favourite,
                watchId: favourite.type == FavouriteType.vod
                    ? 'vod:${favourite.id}'
                    : null,
              ),
              onTap: () => _openDetail(context, favourite),
            ),
          ),
      ],
    );
  }

  void _openDetail(BuildContext context, Favourite favourite) {
    if (favourite.type == FavouriteType.vod) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: RouteSettings(name: 'movie:${favourite.id}'),
          builder: (_) => MovieDetailScreen(
            movie: VodStream(
              streamId: favourite.id,
              name: favourite.name,
              icon: favourite.image,
              categoryId: favourite.categoryId,
              containerExtension: favourite.containerExtension ?? 'mp4',
            ),
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: 'series:${favourite.id}'),
        builder: (_) => SeriesDetailScreen(
          series: SeriesItem(
            seriesId: favourite.id,
            name: favourite.name,
            cover: favourite.image,
            categoryId: favourite.categoryId,
          ),
        ),
      ),
    );
  }

  void _playChannel(
    BuildContext context,
    AppModel model,
    List<Favourite> channels,
    int index,
  ) {
    final api = model.session.api;
    if (api == null) return;
    final tapped = channels[index];
    model.recents.add(
      RecentItem(
        type: RecentType.live,
        id: tapped.id,
        name: tapped.name,
        image: tapped.image,
        categoryId: tapped.categoryId,
        openedAt: DateTime.now(),
      ),
    );
    final playlist = [
      for (final favourite in channels)
        PlayableMedia(
          url: api.liveUrl(
            favourite.id,
            extension: model.preferences.liveExtension,
          ),
          title: favourite.name,
          poster: favourite.image,
          isLive: true,
        ),
    ];
    openPlayer(context, playlist, index);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _FavouriteChannelRow extends StatefulWidget {
  const _FavouriteChannelRow({
    required this.favourite,
    required this.onPlay,
    required this.onMenu,
  });

  final Favourite favourite;
  final VoidCallback onPlay;
  final ValueChanged<Offset> onMenu;

  @override
  State<_FavouriteChannelRow> createState() => _FavouriteChannelRowState();
}

class _FavouriteChannelRowState extends State<_FavouriteChannelRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPlay,
        onLongPressStart: (details) => widget.onMenu(details.globalPosition),
        onSecondaryTapUp: (details) => widget.onMenu(details.globalPosition),
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.surface
                : AppColors.surface.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered ? AppColors.border : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              ChannelAvatar(
                name: widget.favourite.name,
                image: widget.favourite.image,
                size: 36,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.favourite.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => toggleFavourite(context, widget.favourite),
                tooltip: 'Remove from favourites',
                icon: Icon(
                  Icons.favorite_rounded,
                  size: 17,
                  color: AppColors.accent,
                ),
              ),
              Icon(
                Icons.play_arrow_rounded,
                size: 19,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
