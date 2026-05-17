class MediaCollectionQuery {
  const MediaCollectionQuery({
    required this.title,
    this.collectionId,
    this.timeStart,
    this.timeEnd,
    this.mediaIds,
  });

  final String title;
  final String? collectionId;
  final DateTime? timeStart;
  final DateTime? timeEnd;
  final Set<String>? mediaIds;
}
