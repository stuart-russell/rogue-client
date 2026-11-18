import 'dart:collection';

final _nonAlphanumeric = RegExp(r'[^a-z0-9]+');
final LinkedHashMap<String, String> _cache = LinkedHashMap<String, String>();

/// Canonical form used for search matching.
///
/// Lower-cases, maps `&` to `and`, then strips everything that is not a letter
/// or digit. This makes `Grey's Anatomy` == `greys anatomy`,
/// `Tom & Jerry` == `tom and jerry`, and `S.W.A.T` == `swat`.
String searchKey(String value) {
  final cached = _cache[value];
  if (cached != null) return cached;
  final key = value
      .toLowerCase()
      .replaceAll('&', 'and')
      .replaceAll(_nonAlphanumeric, '');
  // Bound the cache so a long session cannot grow it without limit.
  if (_cache.length > 5000) _cache.clear();
  _cache[value] = key;
  return key;
}

/// True when [haystack] matches [query] ignoring punctuation, spacing and
/// ampersand variants.
bool matchesSearch(String haystack, String query) {
  final key = searchKey(query);
  if (key.isEmpty) return false;
  return searchKey(haystack).contains(key);
}
