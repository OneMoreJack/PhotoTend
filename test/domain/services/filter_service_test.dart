import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/domain/models/media_item.dart';
import 'package:rephoto/domain/services/filter_service.dart';

void main() {
  test('location filter is scoped by current time range', () {
    final items = [
      MediaItem(
        id: '1',
        type: MediaType.photo,
        createdAt: DateTime(2026, 2, 1),
        locationKey: 'CN/SH/XH',
      ),
      MediaItem(
        id: '2',
        type: MediaType.photo,
        createdAt: DateTime(2025, 2, 1),
        locationKey: 'CN/SH/XH',
      ),
    ];

    final result = FilterService.apply(
      items,
      timeStart: DateTime(2026, 1, 1),
      timeEnd: DateTime(2026, 12, 31),
      locationKey: 'CN/SH/XH',
    );

    expect(result.map((e) => e.id).toList(), ['1']);
  });
}
