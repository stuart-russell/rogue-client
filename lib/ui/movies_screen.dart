import 'package:flutter/material.dart';

import '../data/models.dart';
import '../core/search_text.dart';
import '../state/app_model.dart';
import '../state/catalog_controller.dart';
import '../theme.dart';
import 'catalog_widgets.dart';
import 'detail_screens.dart';
import 'favourites_actions.dart';
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
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 178,
                                  mainAxisSpacing: 18,
                                  crossAxisSpacing: 14,
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

class CategoryChips extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.categories,
    required this.total,
    required this.selected,
    required this.countFor,
    required this.onSelected,
  });

  final List<Category> categories;
  final int total;
  final int? selected;
  final int Function(int) countFor;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final category = isAll ? null : categories[index - 1];
          final active =
              (isAll && selected == null) ||
              (!isAll && selected == category!.id);
          final label = isAll ? 'All' : category!.name;
          final count = isAll ? total : countFor(category!.id);
          return _CategoryChip(
            label: '$label  ·  $count',
            active: active,
            onTap: () => onSelected(isAll ? null : category!.id),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatefulWidget {
  const _CategoryChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active
                ? AppColors.accent.withValues(alpha: 0.15)
                : _hovered
                ? AppColors.surfaceHigh
                : AppColors.surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: active
                  ? AppColors.accent.withValues(alpha: 0.6)
                  : AppColors.border,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? AppColors.text : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
