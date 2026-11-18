import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_model.dart';
import '../state/catalog_controller.dart';
import '../theme.dart';
import 'catalog_widgets.dart';
import 'detail_screens.dart';
import 'favourites_actions.dart';
import 'responsive.dart';
import 'widgets.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final catalog = model.catalog;

    final needle = _query.trim();
    final channels = catalog.searchChannels(needle);
    final movies = catalog.searchMovies(needle);
    final seriesItems = catalog.searchSeries(needle);
    final empty = channels.isEmpty && movies.isEmpty && seriesItems.isEmpty;

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
            title: 'Search',
            subtitle:
                '${catalog.countFor(CatalogSegment.live, null) + catalog.countFor(CatalogSegment.vod, null) + catalog.countFor(CatalogSegment.series, null)} items indexed locally',
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 520,
            child: SearchField(
              controller: _controller,
              autofocus: true,
              hint: 'Search channels, movies and series…',
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: needle.isEmpty
                ? const StatusPane(
                    icon: Icons.keyboard_rounded,
                    title: 'Start typing',
                    message: 'Filtering happens on-device against the catalogue already loaded, so results appear as you type.',
                  )
                : empty
                ? StatusPane(
                    icon: Icons.search_off_rounded,
                    title: 'Nothing found',
                    message: 'No channels, movies or series match "$needle".',
                  )
                : Scrollbar(
                    child: CustomScrollView(
                      slivers: [
                        if (channels.isNotEmpty) ...[
                          _header('Channels', channels.length),
                          SliverList.builder(
                            itemCount: channels.length > 40
                                ? 40
                                : channels.length,
                            itemBuilder: (context, index) {
                              final channel = channels[index];
                              return _ChannelResult(
                                channel: channel,
                                onTap: () {
                                  final playlist = [
                                    for (final c in channels)
                                      liveToMedia(model, c),
                                  ];
                                  openPlayer(context, playlist, index);
                                },
                              );
                            },
                          ),
                        ],
                        if (movies.isNotEmpty) ...[
                          _header('Movies', movies.length),
                          _posterGrid(movies, (movie) {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                settings: RouteSettings(
                                  name: 'movie:${movie.streamId}',
                                ),
                                builder: (_) => MovieDetailScreen(movie: movie),
                              ),
                            );
                          }),
                        ],
                        if (seriesItems.isNotEmpty) ...[
                          _header('Series', seriesItems.length),
                          _posterGrid(seriesItems, (item) {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                settings: RouteSettings(
                                  name: 'series:${item.seriesId}',
                                ),
                                builder: (_) =>
                                    SeriesDetailScreen(series: item),
                              ),
                            );
                          }),
                        ],
                        const SliverToBoxAdapter(child: SizedBox(height: 30)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _header(String label, int count) {
    final capped = label == 'Channels' && count > 40;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 10),
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
            if (capped) ...[
              const SizedBox(width: 8),
              Text(
                '(showing first 40)',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _posterGrid<T>(List<T> items, void Function(T item) onTap) {
    final limited = items.length > 30 ? items.sublist(0, 30) : items;
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 172,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final item = limited[index];
        if (item is VodStream) {
          return PosterCard(
            title: item.name,
            subtitle: item.containerExtension.toUpperCase(),
            image: item.icon,
            progress: AppScope.of(context).progress
                .entryFor('vod:${item.streamId}')
                ?.fraction,
            watched:
                AppScope.of(context).progress
                    .entryFor('vod:${item.streamId}')
                    ?.completed ==
                true,
            onContextMenu: (position) => showItemMenu(
              context,
              position,
              favourite: favouriteForMovie(AppScope.read(context), item),
              watchId: 'vod:${item.streamId}',
            ),
            onTap: () => onTap(item),
          );
        }
        final show = item as SeriesItem;
        return PosterCard(
          title: show.name,
          subtitle: show.genre,
          image: show.cover,
          onContextMenu: (position) => showFavouriteMenu(
            context,
            position,
            favouriteForSeries(AppScope.read(context), show),
          ),
          onTap: () => onTap(item),
        );
      }, childCount: limited.length),
    );
  }
}

class _ChannelResult extends StatelessWidget {
  const _ChannelResult({required this.channel, required this.onTap});

  final LiveStream channel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final now = model.epg.now(channel.epgChannelId);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            ChannelAvatar(name: channel.name, image: channel.icon, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    now?.title ?? 'No guide data',
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
            Icon(
              Icons.play_arrow_rounded,
              size: 19,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
