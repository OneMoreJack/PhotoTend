import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/domain/models/album_summary_entry.dart';
import 'package:rephoto/domain/models/media_collection_query.dart';
import 'package:rephoto/domain/models/media_item.dart';

void main() {
  test('album summary entry exposes counts and known size state', () {
    final entry = AlbumSummaryEntry(
      id: 'month-2026-04',
      title: '2026年4月',
      query: MediaCollectionQuery(
        title: '2026年4月',
        timeStart: DateTime(2026, 4),
        timeEnd: DateTime(2026, 5).subtract(const Duration(milliseconds: 1)),
      ),
      photoCount: 2,
      videoCount: 1,
      knownSizeBytes: 1024,
      hasUnknownSize: true,
    );

    expect(entry.totalCount, 3);
    expect(entry.hasMedia, isTrue);
    expect(entry.hasUnknownSize, isTrue);
  });

  test('media item can carry optional byte size', () {
    const item = MediaItem(id: 'a', type: MediaType.photo, sizeBytes: 42);

    expect(item.sizeBytes, 42);
  });
}
