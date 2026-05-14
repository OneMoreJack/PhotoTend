class MediaCollectionQuery {
  const MediaCollectionQuery({
    required this.title,
    this.timeStart,
    this.timeEnd,
    this.mediaIds,
  });

  final String title;
  final DateTime? timeStart;
  final DateTime? timeEnd;
  final Set<String>? mediaIds;
}
