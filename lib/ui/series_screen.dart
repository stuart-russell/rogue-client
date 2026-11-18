import 'package:flutter/material.dart';

import '../core/search_text.dart';
import '../state/app_model.dart';
import '../state/catalog_controller.dart';
import 'catalog_widgets.dart';
import 'detail_screens.dart';
import 'favourites_actions.dart';
import 'responsive.dart';
import 'widgets.dart';

class SeriesScreen extends StatefulWidget {
  const SeriesScreen({super.key});

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
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

    var series = catalog.seriesIn(_categoryId);
    if (_query.isNotEmpty) {
      series = series
          .where((s) => matchesSearch(s.name, _query))
          .toList(growable: false);
    }

    final categories = catalog.categoriesFor(CatalogSegment.series);
    final ready = catalog.countFor(CatalogSegment.series, null) > 0;
    final compact = isCompact(context);

    return CatalogScaffold(
      title: 'Series',
      subtitle: ready
          ? '${catalog.countFor(CatalogSegment.series, null)} shows · ${categories.length} categories'
          : 'Box sets from your panel',
      actions: [
        refreshButton(
          busy: catalog.loading[CatalogSegment.series] ?? false,
          onPressed: () => catalog.load(CatalogSegment.series, force: true),
        ),
        if (!compact) ...[
          const SizedBox(width: 10),
          SizedBox(
            width: 260,
            child: SearchField(
              controller: _search,
              hint: 'Search series…',
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ),
        ],
      ],
      child: !ready
          ? segmentStatus(
              catalog: catalog,
              segment: CatalogSegment.series,
              onRetry: () => catalog.load(CatalogSegment.series, force: true),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (compact) ...[
                  SearchField(
                    controller: _search,
                    hint: 'Search series…',
                    onChanged: (value) => setState(() => _query = value.trim()),
                  ),
                  const SizedBox(height: 10),
                ],
                CategoryChips(
                  categories: categories,
                  total: catalog.countFor(CatalogSegment.series, null),
                  selected: _categoryId,
                  countFor: (id) => catalog.countFor(CatalogSegment.series, id),
                  onSelected: (id) => setState(() => _categoryId = id),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: series.isEmpty
                      ? StatusPane(
                          icon: Icons.search_off_rounded,
                          title: 'No series match',
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
                            itemCount: series.length,
                            itemBuilder: (context, index) {
                              final item = series[index];
                              return PosterCard(
                                title: item.name,
                                subtitle: item.genre ?? item.releaseDate,
                                image: item.cover,
                                onContextMenu: (position) => showFavouriteMenu(
                                  context,
                                  position,
                                  favouriteForSeries(model, item),
                                ),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    settings: RouteSettings(
                                      name: 'series:${item.seriesId}',
                                    ),
                                    builder: (_) =>
                                        SeriesDetailScreen(series: item),
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
