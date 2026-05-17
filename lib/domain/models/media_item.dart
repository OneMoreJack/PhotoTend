enum MediaType { photo, video }

class MediaItem {
  const MediaItem({
    required this.id,
    required this.type,
    this.createdAt,
    this.locationKey,
    this.pathOrUri,
    this.sizeBytes,
    this.livePhotoVideoUri,
  });

  final String id;
  final MediaType type;
  final DateTime? createdAt;
  final String? locationKey;
  final String? pathOrUri;
  final int? sizeBytes;
  final String? livePhotoVideoUri;
}
