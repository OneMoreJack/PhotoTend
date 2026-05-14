import 'package:rephoto/domain/models/media_collection_query.dart';

class AlbumSummaryEntry {
  const AlbumSummaryEntry({
    required this.id,
    required this.title,
    required this.query,
    required this.photoCount,
    required this.videoCount,
    required this.knownSizeBytes,
    required this.hasUnknownSize,
  });

  final String id;
  final String title;
  final MediaCollectionQuery query;
  final int photoCount;
  final int videoCount;
  final int knownSizeBytes;
  final bool hasUnknownSize;

  int get totalCount => photoCount + videoCount;
  bool get hasMedia => totalCount > 0;
}

class YearAlbumSummaryGroup {
  const YearAlbumSummaryGroup({
    required this.year,
    required this.summary,
    required this.months,
    required this.defaultExpanded,
  });

  final int year;
  final AlbumSummaryEntry summary;
  final List<AlbumSummaryEntry> months;
  final bool defaultExpanded;
}
