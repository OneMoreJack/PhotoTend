import 'package:rephoto/domain/models/media_item.dart';

class FilterService {
  static List<MediaItem> apply(
    List<MediaItem> items, {
    DateTime? timeStart,
    DateTime? timeEnd,
    String? locationKey,
  }) {
    return items.where((item) {
      final createdAt = item.createdAt;
      if (timeStart != null &&
          (createdAt == null || createdAt.isBefore(timeStart))) {
        return false;
      }
      if (timeEnd != null &&
          (createdAt == null || createdAt.isAfter(timeEnd))) {
        return false;
      }
      if (locationKey != null && item.locationKey != locationKey) {
        return false;
      }
      return true;
    }).toList();
  }
}
