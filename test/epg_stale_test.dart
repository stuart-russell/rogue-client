import 'package:flutter_test/flutter_test.dart';
import 'package:rogue/data/disk_cache.dart';
import 'package:rogue/state/epg_controller.dart';

void main() {
  test('EPG is stale when never loaded or older than three hours', () {
    final epg = EpgController(DiskCache());

    expect(epg.isStale, isTrue);

    epg.updatedAt = DateTime.now().subtract(const Duration(hours: 4));
    expect(epg.isStale, isTrue);

    epg.updatedAt = DateTime.now().subtract(const Duration(hours: 1));
    expect(epg.isStale, isFalse);
  });
}
