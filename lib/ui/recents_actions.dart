import '../data/models.dart';
import '../state/app_model.dart';
import '../state/recents.dart';

RecentItem recentForChannel(AppModel model, LiveStream channel) => RecentItem(
  type: RecentType.live,
  id: channel.streamId,
  name: channel.name,
  image: model.session.api?.absolute(channel.icon),
  categoryId: channel.categoryId,
  openedAt: DateTime.now(),
);

RecentItem recentForMovie(AppModel model, VodStream movie) => RecentItem(
  type: RecentType.vod,
  id: movie.streamId,
  name: movie.name,
  image: model.session.api?.absolute(movie.icon),
  categoryId: movie.categoryId,
  openedAt: DateTime.now(),
);

RecentItem recentForSeries(AppModel model, SeriesItem series) => RecentItem(
  type: RecentType.series,
  id: series.seriesId,
  name: series.name,
  image: model.session.api?.absolute(series.cover),
  categoryId: series.categoryId,
  openedAt: DateTime.now(),
);
