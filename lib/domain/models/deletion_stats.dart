import 'package:rephoto/domain/models/media_item.dart';

class DeletionStats {
  const DeletionStats({
    this.photoCount = 0,
    this.videoCount = 0,
    this.knownSizeBytes = 0,
    this.hasUnknownSize = false,
  });

  final int photoCount;
  final int videoCount;
  final int knownSizeBytes;
  final bool hasUnknownSize;

  static const empty = DeletionStats();

  int get totalCount => photoCount + videoCount;

  DeletionStats add(DeletionStats other) {
    return DeletionStats(
      photoCount: photoCount + other.photoCount,
      videoCount: videoCount + other.videoCount,
      knownSizeBytes: knownSizeBytes + other.knownSizeBytes,
      hasUnknownSize: hasUnknownSize || other.hasUnknownSize,
    );
  }

  static DeletionStats fromItems(Iterable<MediaItem> items) {
    var photos = 0;
    var videos = 0;
    var size = 0;
    var unknown = false;
    for (final item in items) {
      switch (item.type) {
        case MediaType.photo:
          photos += 1;
        case MediaType.video:
          videos += 1;
      }
      final itemSize = item.sizeBytes;
      if (itemSize == null) {
        unknown = true;
      } else {
        size += itemSize;
      }
    }
    return DeletionStats(
      photoCount: photos,
      videoCount: videos,
      knownSizeBytes: size,
      hasUnknownSize: unknown,
    );
  }
}
