import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/domain/models/deletion_stats.dart';
import 'package:rephoto/domain/models/media_item.dart';

void main() {
  test('media item supports photo and video types', () {
    const photo = MediaItem(id: '1', type: MediaType.photo);
    const video = MediaItem(id: '2', type: MediaType.video);

    expect(photo.type, MediaType.photo);
    expect(video.type, MediaType.video);
  });

  test('deletion stats round-trips through a local storage map', () {
    const stats = DeletionStats(
      photoCount: 2,
      videoCount: 1,
      knownSizeBytes: 4096,
      hasUnknownSize: true,
    );

    final restored = DeletionStats.fromMap(stats.toMap());

    expect(restored.photoCount, 2);
    expect(restored.videoCount, 1);
    expect(restored.knownSizeBytes, 4096);
    expect(restored.hasUnknownSize, isTrue);
  });
}
