class MediaCollectionQuery {
  const MediaCollectionQuery({
    required this.title,
    this.timeStart,
    this.timeEnd,
  });

  final String title;
  final DateTime? timeStart;
  final DateTime? timeEnd;
}
