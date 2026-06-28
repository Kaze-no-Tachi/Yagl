import 'package:flutter_test/flutter_test.dart';
import 'package:yagl/api/models.dart';

void main() {
  test('Item.fromJson parses nested photos, loans, platform', () {
    final item = Item.fromJson({
      'id': 1,
      'kind': 'game',
      'format': 'physical',
      'title': 'Halo Infinite',
      'source': 'scan',
      'platform': {'id': 27, 'name': 'Xbox Series X|S', 'igdb_platform_id': 169},
      'photos': [
        {'id': 5, 'url': '/media/ab/abc.jpg', 'is_primary': true}
      ],
      'loans': [
        {
          'id': 9,
          'item_id': 1,
          'borrower_name': 'Sam',
          'loaned_on': '2026-06-01',
          'returned_on': null
        }
      ],
    });

    expect(item.title, 'Halo Infinite');
    expect(item.platform?.name, 'Xbox Series X|S');
    expect(item.photos.single.url, '/media/ab/abc.jpg');
    expect(item.isOnLoan, isTrue);
    expect(item.openLoan?.borrowerName, 'Sam');
  });

  test('GameCandidate and ImportResult parse', () {
    final c = GameCandidate.fromJson({
      'title': 'Portal 2',
      'igdb_id': 7346,
      'source': 'igdb',
      'confidence': 0.6,
    });
    expect(c.igdbId, 7346);

    final r = ImportResult.fromJson({
      'provider': 'steam',
      'fetched': 10,
      'created': 8,
      'skipped_duplicates': 2,
      'unmatched': ['Some Indie'],
    });
    expect(r.created, 8);
    expect(r.unmatched, contains('Some Indie'));
  });
}
