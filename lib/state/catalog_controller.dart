import 'package:flutter/foundation.dart' hide Category;

import '../core/adult_filter.dart';
import '../core/app_log.dart';
import '../core/search_text.dart';
import '../data/disk_cache.dart';
import '../data/models.dart';
import '../data/xtream_api.dart';

enum CatalogSegment { live, vod, series }

extension CatalogSegmentInfo on CatalogSegment {
  String get label => switch (this) {
    CatalogSegment.live => 'Live TV',
    CatalogSegment.vod => 'Movies',
    CatalogSegment.series => 'Series',
  };

  String get categoriesAction => switch (this) {
    CatalogSegment.live => 'get_live_categories',
    CatalogSegment.vod => 'get_vod_categories',
    CatalogSegment.series => 'get_series_categories',
  };

  String get itemsAction => switch (this) {
    CatalogSegment.live => 'get_live_streams',
    CatalogSegment.vod => 'get_vod_streams',
    CatalogSegment.series => 'get_series',
  };
}

/// Holds categories + the full catalogue for each segment.
///
/// Strategy: hydrate from disk immediately so scrolling works on launch, then
/// refresh from the panel in the background.
class CatalogController extends ChangeNotifier {
  CatalogController(this._cache);

  final DiskCache _cache;
  XtreamApi? _api;
  String? _scope;

  final Map<CatalogSegment, List<Category>> categories = {
    CatalogSegment.live: const [],
    CatalogSegment.vod: const [],
    CatalogSegment.series: const [],
  };
  final Map<CatalogSegment, bool> loading = {
    for (final s in CatalogSegment.values) s: false,
  };
  final Map<CatalogSegment, String?> errors = {
    for (final s in CatalogSegment.values) s: null,
  };
  final Map<String, int> _countCache = {};
  bool _hideAdult = false;

  bool get adultFilterEnabled => _hideAdult;

  List<LiveStream> live = const [];
  List<VodStream> movies = const [];
  List<SeriesItem> series = const [];

  DateTime? updatedAt;

  bool get hasData => live.isNotEmpty || movies.isNotEmpty || series.isNotEmpty;
  bool get busy => loading.values.any((v) => v);

  void bind(XtreamApi api) {
    final scope = '${api.origin}|${api.username}';
    if (_scope == scope) return;
    _scope = scope;
    _api = api;
    _resetData();
    _hydrateAll();
  }

  void unbind() {
    _api = null;
    _scope = null;
    _resetData();
    notifyListeners();
  }

  String _key(CatalogSegment segment) =>
      'catalog_${segment.name}_${(_scope ?? 'none').hashCode.toRadixString(16)}';

  void _resetData() {
    categories[CatalogSegment.live] = const [];
    categories[CatalogSegment.vod] = const [];
    categories[CatalogSegment.series] = const [];
    live = const [];
    movies = const [];
    series = const [];
    updatedAt = null;
    for (final segment in CatalogSegment.values) {
      errors[segment] = null;
    }
    _countCache.clear();
  }

  Future<void> _hydrateAll() async {
    for (final segment in CatalogSegment.values) {
      await _hydrate(segment);
    }
    notifyListeners();
  }

  Future<void> _hydrate(CatalogSegment segment) async {
    if (_hasData(segment)) return;
    final envelope = await _cache.read(_key(segment));
    if (envelope == null) return;
    final payload = envelope['payload'];
    if (payload is! Map) return;
    _applyPayload(segment, payload.cast<String, dynamic>());
    _countCache.clear();
    updatedAt = DiskCache.savedAtOf(envelope) ?? updatedAt;
  }

  bool _hasData(CatalogSegment segment) => switch (segment) {
    CatalogSegment.live => live.isNotEmpty,
    CatalogSegment.vod => movies.isNotEmpty,
    CatalogSegment.series => series.isNotEmpty,
  };

  void _applyPayload(CatalogSegment segment, Map<String, dynamic> payload) {
    final rawCategories = (payload['categories'] as List?) ?? const [];
    final rawItems = (payload['items'] as List?) ?? const [];

    categories[segment] = [
      for (final row in rawCategories)
        if (row is Map) Category.fromJson(row.cast<String, dynamic>()),
    ];

    switch (segment) {
      case CatalogSegment.live:
        live = [
          for (final row in rawItems)
            if (row is Map) LiveStream.fromJson(row.cast<String, dynamic>()),
        ];
      case CatalogSegment.vod:
        movies = [
          for (final row in rawItems)
            if (row is Map) VodStream.fromJson(row.cast<String, dynamic>()),
        ];
      case CatalogSegment.series:
        series = [
          for (final row in rawItems)
            if (row is Map) SeriesItem.fromJson(row.cast<String, dynamic>()),
        ];
    }
  }

  Future<void> load(CatalogSegment segment, {bool force = false}) async {
    final api = _api;
    if (api == null || loading[segment] == true) return;
    if (!force && _hasData(segment)) return;

    loading[segment] = true;
    errors[segment] = null;
    notifyListeners();

    try {
      final rawCategories = await api.rows(
        segment.categoriesAction,
        timeout: const Duration(seconds: 60),
      );
      final rawItems = await api.rows(
        segment.itemsAction,
        timeout: const Duration(minutes: 3),
      );

      final parsedCategories = [
        for (final row in rawCategories) Category.fromJson(row),
      ];
      categories[segment] = parsedCategories;

      switch (segment) {
        case CatalogSegment.live:
          live = [for (final row in rawItems) LiveStream.fromJson(row)]
            ..sort((a, b) => a.num.compareTo(b.num));
        case CatalogSegment.vod:
          movies = [for (final row in rawItems) VodStream.fromJson(row)];
        case CatalogSegment.series:
          series = [for (final row in rawItems) SeriesItem.fromJson(row)];
      }

      updatedAt = DateTime.now();
      _countCache.clear();
      await _cache.write(_key(segment), {
        'categories': [
          for (final c in parsedCategories)
            {
              'category_id': c.id,
              'category_name': c.name,
              if (c.parentId != null) 'parent_id': c.parentId,
            },
        ],
        'items': rawItems,
      });

      final itemCount = switch (segment) {
        CatalogSegment.live => live.length,
        CatalogSegment.vod => movies.length,
        CatalogSegment.series => series.length,
      };
      AppLog.write(
        'catalog ${segment.name}: $itemCount items, ${parsedCategories.length} categories',
      );
    } on Exception catch (e) {
      errors[segment] = e.toString();
    } finally {
      loading[segment] = false;
      notifyListeners();
    }
  }

  Future<void> loadAll({bool force = false}) async {
    for (final segment in CatalogSegment.values) {
      await load(segment, force: force);
    }
  }

  Future<void> refreshAll() => loadAll(force: true);

  // ------------------------------------------------------------- selectors

  void setAdultFilter(bool enabled) {
    if (_hideAdult == enabled) return;
    _hideAdult = enabled;
    _countCache.clear();
    notifyListeners();
  }

  Set<int> get _adultCategoryIds {
    if (!_hideAdult) return const {};
    final ids = <int>{};
    for (final list in categories.values) {
      for (final category in list) {
        if (isAdultCategoryName(category.name)) ids.add(category.id);
      }
    }
    return ids;
  }

  bool isAdultCategoryId(int? id) =>
      id != null && _adultCategoryIds.contains(id);

  /// Categories for a segment, minus adult ones while the filter is on.
  List<Category> categoriesFor(CatalogSegment segment) {
    final list = categories[segment] ?? const <Category>[];
    final adult = _adultCategoryIds;
    if (adult.isEmpty) return list;
    return [
      for (final category in list)
        if (!adult.contains(category.id)) category,
    ];
  }

  List<LiveStream> channelsIn(int? categoryId) {
    final adult = _adultCategoryIds;
    return [
      for (final channel in live)
        if ((categoryId == null || channel.categoryId == categoryId) &&
            !adult.contains(channel.categoryId))
          channel,
    ];
  }

  List<VodStream> moviesIn(int? categoryId) {
    final adult = _adultCategoryIds;
    return [
      for (final movie in movies)
        if ((categoryId == null || movie.categoryId == categoryId) &&
            !adult.contains(movie.categoryId))
          movie,
    ];
  }

  List<SeriesItem> seriesIn(int? categoryId) {
    final adult = _adultCategoryIds;
    return [
      for (final show in series)
        if ((categoryId == null || show.categoryId == categoryId) &&
            !adult.contains(show.categoryId))
          show,
    ];
  }

  int countFor(CatalogSegment segment, int? categoryId) {
    final key = '${segment.name}:${categoryId ?? 'all'}';
    final cached = _countCache[key];
    if (cached != null) return cached;
    final count = switch (segment) {
      CatalogSegment.live => channelsIn(categoryId).length,
      CatalogSegment.vod => moviesIn(categoryId).length,
      CatalogSegment.series => seriesIn(categoryId).length,
    };
    _countCache[key] = count;
    return count;
  }

  List<LiveStream> searchChannels(String query) {
    final key = searchKey(query);
    if (key.isEmpty) return const [];
    final adult = _adultCategoryIds;
    return live
        .where(
          (c) =>
              !adult.contains(c.categoryId) && searchKey(c.name).contains(key),
        )
        .take(300)
        .toList(growable: false);
  }

  List<VodStream> searchMovies(String query) {
    final key = searchKey(query);
    if (key.isEmpty) return const [];
    final adult = _adultCategoryIds;
    return movies
        .where(
          (m) =>
              !adult.contains(m.categoryId) && searchKey(m.name).contains(key),
        )
        .take(300)
        .toList(growable: false);
  }

  List<SeriesItem> searchSeries(String query) {
    final key = searchKey(query);
    if (key.isEmpty) return const [];
    final adult = _adultCategoryIds;
    return series
        .where(
          (s) =>
              !adult.contains(s.categoryId) && searchKey(s.name).contains(key),
        )
        .take(300)
        .toList(growable: false);
  }
}
