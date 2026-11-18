import 'search_text.dart';

/// Tokens that identify adult categories across common panel dialects.
const _adultTokens = [
  'adult',
  'xxx',
  'porn',
  'erotic',
  'foradults',
  'adultxxx',
];

/// True when a category name looks like adult content.
///
/// Normalised via [searchKey], so "For Adults", "VIP | Adult" and "XXX" all
/// match. "Adult Swim" is explicitly exempted because it is a mainstream brand.
bool isAdultCategoryName(String name) {
  final key = searchKey(name);
  if (key.isEmpty) return false;
  if (key.contains('adultswim')) return false;
  for (final token in _adultTokens) {
    if (key.contains(token)) return true;
  }
  return false;
}
