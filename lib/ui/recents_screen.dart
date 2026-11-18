import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_model.dart';
import '../state/recents.dart';
import '../theme.dart';
import 'catalog_widgets.dart';
import 'detail_screens.dart';
import 'widgets.dart';

class RecentsScreen extends StatelessWidget {
  const RecentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final catalog = model.catalog;

    final channels = model.recents
        .of(RecentType.live)
        .where((item) => !catalog.isAdultCategoryId(item.categoryId))
        .toList(growable: false);
    final movies = model.recents
        .of(RecentType.vod)
        .where((item) => !catalog.isAdultCategoryId(item.categoryId))
        .toList(growable: false);
    final series = model.recents
        .of(RecentType.series)
        .where((item) => !catalog.isAdultCategoryId(item.categoryId))
        .toList(growable: false);
    final empty = channels.isEmpty && movies.isEmpty && series.isEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Recents',
            subtitle: empty
                ? 'The last ${RecentsStore.perTypeLimit} channels, films and series you played'
                : 'Last ${RecentsStore.perTypeLimit} per type · right-click or long-press to remove',
            trailing: empty
                ? null
                : TextButton.icon(
                    onPressed: () => model.recents.clear(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                    ),
                    icon: const Icon(Icons.clear_all_rounded, size: 16),
                    label: const Text('Clear'),
                  ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: empty
                ? const StatusPane(
                    icon: Icons.history_rounded,
                    title: 'Nothing played yet',
                    message: 'Channels, films and series appear here after you watch them.',
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
                            _RecentChannelRow(
                              item: channels[i],
                              onPlay: () =>
                                  _playChannel(context, model, channels, i),
                              onContextMenu: (position) => _showRecentMenu(
                                context,
                                model,
                                channels[i],
                                position,
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
    List<RecentItem> items,
  ) {
    return Wrap(
      spacing: 14,
      runSpacing: 18,
      children: [
        for (final item in items)
          SizedBox(
            width: 150,
            height: 224,
            child: PosterCard(
              title: item.name,
              image: item.image,
              progress: item.type == RecentType.vod
                  ? model.progress.entryFor('vod:${item.id}')?.fraction
                  : null,
              watched:
                  item.type == RecentType.vod &&
                  model.progress.entryFor('vod:${item.id}')?.completed == true,
              onTap: () => _openDetail(context, item),
              onContextMenu: (position) =>
                  _showRecentMenu(context, model, item, position),
            ),
          ),
      ],
    );
  }

  void _openDetail(BuildContext context, RecentItem item) {
    if (item.type == RecentType.vod) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: RouteSettings(name: 'movie:${item.id}'),
          builder: (_) => MovieDetailScreen(
            movie: VodStream(
              streamId: item.id,
              name: item.name,
              icon: item.image,
            ),
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: 'series:${item.id}'),
        builder: (_) => SeriesDetailScreen(
          series: SeriesItem(
            seriesId: item.id,
            name: item.name,
            cover: item.image,
          ),
        ),
      ),
    );
  }

  void _playChannel(
    BuildContext context,
    AppModel model,
    List<RecentItem> channels,
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
        openedAt: DateTime.now(),
      ),
    );
    final playlist = [
      for (final channel in channels)
        PlayableMedia(
          url: api.liveUrl(
            channel.id,
            extension: model.preferences.liveExtension,
          ),
          title: channel.name,
          poster: channel.image,
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

class _RecentChannelRow extends StatefulWidget {
  const _RecentChannelRow({
    required this.item,
    required this.onPlay,
    required this.onContextMenu,
  });

  final RecentItem item;
  final VoidCallback onPlay;

  /// Right-click (desktop) or long-press (touch) position.
  final ValueChanged<Offset> onContextMenu;

  @override
  State<_RecentChannelRow> createState() => _RecentChannelRowState();
}

class _RecentChannelRowState extends State<_RecentChannelRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPlay,
        onLongPressStart: (details) =>
            widget.onContextMenu(details.globalPosition),
        onSecondaryTapUp: (details) =>
            widget.onContextMenu(details.globalPosition),
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
                name: widget.item.name,
                image: widget.item.image,
                size: 36,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _relative(widget.item.openedAt),
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(width: 10),
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

  static String _relative(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// Right-click / long-press menu for a recents entry.
Future<void> _showRecentMenu(
  BuildContext context,
  AppModel model,
  RecentItem item,
  Offset position,
) async {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  final size = overlay?.size ?? MediaQuery.sizeOf(context);

  final choice = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      size.width - position.dx,
      size.height - position.dy,
    ),
    color: AppColors.surfaceHigh,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    constraints: const BoxConstraints(minWidth: 210, maxWidth: 340),
    items: [
      PopupMenuItem<String>(
        value: 'remove',
        child: Row(
          children: [
            Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: AppColors.warning,
            ),
            SizedBox(width: 10),
            Text('Remove from recents', style: TextStyle(fontSize: 13)),
          ],
        ),
      ),
    ],
  );

  if (choice != 'remove' || !context.mounted) return;
  await model.recents.remove(item.key);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        width: 320,
        content: Text('Removed "${item.name}" from recents'),
      ),
    );
}
