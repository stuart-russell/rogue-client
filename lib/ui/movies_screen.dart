import 'package:flutter/material.dart';

import '../core/search_text.dart';
import '../state/app_model.dart';
import '../state/catalog_controller.dart';
import 'catalog_widgets.dart';
import 'detail_screens.dart';
import 'favourites_actions.dart';
import 'responsive.dart';
import 'widgets.dart';

class MoviesScreen extends StatefulWidget {
  const MoviesScreen({super.key});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  final _search = TextEditingController();
  int? _categoryId;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final catalog = model.catalog;

    var movies = catalog.moviesIn(_categoryId);
    if (_query.isNotEmpty) {
      movies = movies
          .where((m) => matchesSearch(m.name, _query))
          .toList(growable: false);
    }

    final categories = catalog.categoriesFor(CatalogSegment.vod);
    final ready = catalog.countFor(CatalogSegment.vod, null) > 0;
    final compact = isCompact(context);

    return CatalogScaffold(
      title: 'Movies',
      subtitle: ready
          ? '${catalog.countFor(CatalogSegment.vod, null)} titles · ${categories.length} categories'
          : 'Browse the film library on your panel',
      actions: [
        refreshButton(
          busy: catalog.loading[CatalogSegment.vod] ?? false,
          onPressed: () => catalog.load(CatalogSegment.vod, force: true),
        ),
        const SizedBox(width: 10),
        if (!compact)
          SizedBox(
            width: 260,
            child: SearchField(
              controller: _search,
              hint: 'Search movies…',
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ),
      ],
      child: !ready
          ? segmentStatus(
              catalog: catalog,
              segment: CatalogSegment.vod,
              onRetry: () => catalog.load(CatalogSegment.vod, force: true),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (compact) ...[
                  SearchField(
                    controller: _search,
                    hint: 'Search movies…',
                    onChanged: (value) => setState(() => _query = value.trim()),
                  ),
                  const SizedBox(height: 10),
                ],
                CategoryChips(
                  categories: categories,
                  total: catalog.countFor(CatalogSegment.vod, null),
                  selected: _categoryId,
                  countFor: (id) => catalog.countFor(CatalogSegment.vod, id),
                  onSelected: (id) => setState(() => _categoryId = id),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: movies.isEmpty
                      ? StatusPane(
                          icon: Icons.search_off_rounded,
                          title: 'No movies match',
                          message: _query.isEmpty
                              ? 'This category is empty on your panel.'
                              : 'Nothing here matches "$_query".',
                        )
                      : Scrollbar(
                          child: GridView.builder(
                            padding: const EdgeInsets.only(
                              right: 8,
                              bottom: 24,
                            ),
                            gridDelegate:
                                SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: compact ? 124 : 178,
                                  mainAxisSpacing: compact ? 14 : 18,
                                  crossAxisSpacing: compact ? 10 : 14,
                                  childAspectRatio: 0.60,
                                ),
                            itemCount: movies.length,
                            itemBuilder: (context, index) {
                              final movie = movies[index];
                              return PosterCard(
                                title: movie.name,
                                subtitle: movie.rating == null
                                    ? movie.containerExtension.toUpperCase()
                                    : '★ ${movie.rating!.toStringAsFixed(1)}',
                                image: movie.icon,
                                progress: model.progress
                                    .entryFor('vod:${movie.streamId}')
                                    ?.fraction,
                                watched:
                                    model.progress
                                        .entryFor('vod:${movie.streamId}')
                                        ?.completed ==
                                    true,
                                onContextMenu: (position) => showItemMenu(
                                  context,
                                  position,
                                  favourite: favouriteForMovie(model, movie),
                                  watchId: 'vod:${movie.streamId}',
                                ),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    settings: RouteSettings(
                                      name: 'movie:${movie.streamId}',
                                    ),
                                    builder: (_) =>
                                        MovieDetailScreen(movie: movie),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
