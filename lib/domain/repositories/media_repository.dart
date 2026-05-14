import 'package:rephoto/domain/models/media_item.dart';

abstract class MediaRepository {
  Future<List<MediaItem>> fetchAll();

  Future<void> permanentDelete(Set<String> mediaIds);
}
