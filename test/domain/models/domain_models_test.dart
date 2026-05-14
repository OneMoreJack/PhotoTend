import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/domain/models/media_item.dart';

void main() {
  test('media item supports photo and video types', () {
    const photo = MediaItem(id: '1', type: MediaType.photo);
    const video = MediaItem(id: '2', type: MediaType.video);

    expect(photo.type, MediaType.photo);
    expect(video.type, MediaType.video);
  });
}
