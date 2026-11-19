import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_model.dart';
import '../state/catalog_controller.dart';
import '../core/app_log.dart';
import '../theme.dart';
import 'focusable_tap.dart';
import 'player_screen.dart';
import 'responsive.dart';
import 'widgets.dart';

/// Shared page chrome for the catalogue tabs.
class CatalogScaffold extends StatelessWidget {
  const CatalogScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.child,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: SectionHeader(title: title, subtitle: subtitle),
              ),
              ...actions,
            ],
          ),
          const SizedBox(height: 18),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class CategoryRail extends StatelessWidget {
  const CategoryRail({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<CategoryItem> items;
  final int? selected;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 214,
      margin: const EdgeInsets.only(right: 20, bottom: 18),
      decoration: glassPanel(radius: 14),
      clipBehavior: Clip.antiAlias,
      child: Scrollbar(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final active = item.id == selected;
            return _CategoryRow(
              item: item,
              active: active,
              onTap: () => onSelected(item.id),
            );
          },
        ),
      ),
    );
  }
}

class CategoryItem {
  const CategoryItem({
    required this.id,
    required this.name,
    required this.count,
  });

  final int? id;
  final String name;
  final int count;
}

class _CategoryRow extends StatefulWidget {
  const _CategoryRow({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final CategoryItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends State<_CategoryRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    return FocusableTap(
      onTap: widget.onTap,
      builder: (context, focused) => MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: active
                ? AppColors.accent.withValues(alpha: 0.13)
                : focused || _hovered
                ? AppColors.surfaceHigh.withValues(alpha: 0.7)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: focused ? AppColors.accent : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? AppColors.text : AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${widget.item.count}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? AppColors.accent
                      : AppColors.textMuted.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<CategoryItem> categoriesToRail(
  List<Category> categories,
  int total,
  int Function(int) countFor,
) {
  return [
    CategoryItem(id: null, name: 'All', count: total),
    for (final category in categories)
      CategoryItem(
        id: category.id,
        name: category.name,
        count: countFor(category.id),
      ),
  ];
}

void openPlayer(BuildContext context, List<PlayableMedia> playlist, int index) {
  if (playlist.isEmpty) return;
  AppLog.write(
    'open player index=$index of ${playlist.length} '
    'title="${playlist[index].title}" live=${playlist[index].isLive}',
  );
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'player'),
      builder: (_) => PlayerScreen(playlist: playlist, initialIndex: index),
    ),
  );
}

PlayableMedia liveToMedia(AppModel model, LiveStream channel) {
  final extension = model.preferences.liveExtension;
  final api = model.session.api;
  final now = model.epg.now(channel.epgChannelId);
  return PlayableMedia(
    url: api?.liveUrl(channel.streamId, extension: extension) ?? '',
    title: channel.name,
    subtitle: now?.title,
    poster: model.session.api?.absolute(channel.icon),
    isLive: true,
  );
}

PlayableMedia vodToMedia(AppModel model, VodStream movie, {String? poster}) {
  final api = model.session.api;
  return PlayableMedia(
    url: api?.vodUrl(movie.streamId, movie.containerExtension) ?? '',
    title: movie.name,
    subtitle: movie.containerExtension.toUpperCase(),
    poster: poster ?? api?.absolute(movie.icon),
    progressId: 'vod:${movie.streamId}',
  );
}

PlayableMedia episodeToMedia(
  AppModel model,
  Episode episode,
  String seriesName,
  String? poster,
) {
  final api = model.session.api;
  return PlayableMedia(
    url: api?.seriesUrl(episode.id, episode.containerExtension) ?? '',
    title: seriesName,
    subtitle:
        'S${episode.season.toString().padLeft(2, '0')}E${episode.episodeNum.toString().padLeft(2, '0')} · ${episode.title}',
    poster: poster,
    progressId: 'ep:${episode.id}',
  );
}

/// Small helper so the three catalogue tabs share the same refresh affordance.
Widget refreshButton({required bool busy, required VoidCallback onPressed}) {
  return IconButton(
    onPressed: busy ? null : onPressed,
    tooltip: 'Refresh',
    icon: busy
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.refresh_rounded, size: 19),
    style: IconButton.styleFrom(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textMuted,
      side: BorderSide(color: AppColors.border),
    ),
  );
}

/// Used by catalogue tabs before the first payload lands.
Widget segmentStatus({
  required CatalogController catalog,
  required CatalogSegment segment,
  required VoidCallback onRetry,
}) {
  final loading = catalog.loading[segment] ?? false;
  final error = catalog.errors[segment];
  if (loading) {
    return const StatusPane(
      icon: Icons.downloading_rounded,
      title: 'Loading catalogue…',
      message: 'Fetching categories and streams from your panel. Large panels can take a minute.',
      busy: true,
    );
  }
  if (error != null) {
    return StatusPane(
      icon: Icons.cloud_off_rounded,
      title: 'Could not load ${segment.label}',
      message: error,
      actionLabel: 'Try again',
      onAction: onRetry,
    );
  }
  return StatusPane(
    icon: Icons.inbox_outlined,
    title: 'Nothing here yet',
    message:
        'Your panel returned no ${segment.label.toLowerCase()} for this account.',
    actionLabel: 'Reload',
    onAction: onRetry,
  );
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
    return FocusableTap(
      onTap: widget.onTap,
      builder: (context, focused) => MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active
                ? AppColors.accent.withValues(alpha: 0.15)
                : focused || _hovered
                ? AppColors.surfaceHigh
                : AppColors.surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: active || focused
                  ? AppColors.accent.withValues(alpha: 0.8)
                  : AppColors.border,
              width: focused ? 1.6 : 1,
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
