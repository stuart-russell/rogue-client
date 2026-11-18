import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_model.dart';
import '../state/favourites.dart';
import '../theme.dart';

Favourite favouriteForChannel(AppModel model, LiveStream channel) => Favourite(
  type: FavouriteType.live,
  id: channel.streamId,
  name: channel.name,
  image: model.session.api?.absolute(channel.icon),
  categoryId: channel.categoryId,
  addedAt: DateTime.now(),
);

Favourite favouriteForMovie(AppModel model, VodStream movie) => Favourite(
  type: FavouriteType.vod,
  id: movie.streamId,
  name: movie.name,
  image: model.session.api?.absolute(movie.icon),
  categoryId: movie.categoryId,
  containerExtension: movie.containerExtension,
  addedAt: DateTime.now(),
);

Favourite favouriteForSeries(AppModel model, SeriesItem series) => Favourite(
  type: FavouriteType.series,
  id: series.seriesId,
  name: series.name,
  image: model.session.api?.absolute(series.cover),
  categoryId: series.categoryId,
  addedAt: DateTime.now(),
);

/// Right-click / long-press menu for posters, channel rows and episodes.
///
/// [favourite] adds the favourites toggle; [watchId] adds
/// "Mark as watched" / "Mark as unwatched".
Future<void> showItemMenu(
  BuildContext context,
  Offset position, {
  Favourite? favourite,
  String? watchId,
}) async {
  if (favourite == null && watchId == null) return;
  final model = AppScope.read(context);
  final saved =
      favourite != null &&
      model.favourites.contains(favourite.type, favourite.id);
  final watched =
      watchId != null && (model.progress.entryFor(watchId)?.completed ?? false);

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
    items: [
      if (favourite != null)
        PopupMenuItem<String>(
          value: 'favourite',
          child: _MenuRow(
            icon: saved
                ? Icons.heart_broken_rounded
                : Icons.favorite_border_rounded,
            colour: saved ? AppColors.accent : AppColors.textMuted,
            label: saved ? 'Remove from favourites' : 'Add to favourites',
          ),
        ),
      if (watchId != null)
        PopupMenuItem<String>(
          value: 'watched',
          child: _MenuRow(
            icon: watched
                ? Icons.visibility_off_rounded
                : Icons.done_all_rounded,
            colour: watched ? AppColors.warning : AppColors.success,
            label: watched ? 'Mark as unwatched' : 'Mark as watched',
          ),
        ),
    ],
  );

  if (choice == null || !context.mounted) return;

  if (choice == 'favourite' && favourite != null) {
    await model.favourites.toggle(favourite);
    if (!context.mounted) return;
    _snack(context, saved ? 'Removed from favourites' : 'Added to favourites');
    return;
  }

  if (choice == 'watched' && watchId != null) {
    if (watched) {
      await model.progress.clear(watchId);
    } else {
      model.progress.markWatched(watchId);
    }
    if (!context.mounted) return;
    _snack(context, watched ? 'Marked as unwatched' : 'Marked as watched');
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(width: 300, content: Text(message)));
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.colour,
    required this.label,
  });

  final IconData icon;
  final Color colour;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: colour),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

/// Favourites-only variant kept for rows that are not watchable items.
Future<void> showFavouriteMenu(
  BuildContext context,
  Offset position,
  Favourite favourite,
) => showItemMenu(context, position, favourite: favourite);

/// Direct toggle for heart buttons on detail pages.
Future<void> toggleFavourite(BuildContext context, Favourite favourite) async {
  final model = AppScope.read(context);
  final saved = model.favourites.contains(favourite.type, favourite.id);
  await model.favourites.toggle(favourite);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        width: 300,
        content: Text(
          saved ? 'Removed from favourites' : 'Added to favourites',
        ),
      ),
    );
}
