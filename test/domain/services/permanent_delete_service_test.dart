import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/domain/services/permanent_delete_service.dart';

void main() {
  test('failed delete ids stay in trash for retry', () async {
    final service = PermanentDeleteService(
      fakeDeleteResult: {'1': true, '2': false},
    );
    final result = await service.delete({'1', '2'});

    expect(result.failedIds, {'2'});
    expect(result.succeededIds, {'1'});
    expect(result.attemptedCount, 2);
  });

  test(
    'executor mode marks all ids as succeeded when delete completes',
    () async {
      Set<String>? deletedIds;
      final service = PermanentDeleteService.real(
        deleteExecutor: (ids) async {
          deletedIds = Set<String>.from(ids);
        },
      );
      final result = await service.delete({'a', 'b'});

      expect(deletedIds, {'a', 'b'});
      expect(result.succeededIds, {'a', 'b'});
      expect(result.failedIds, isEmpty);
    },
  );

  test('executor mode keeps ids for retry when delete throws', () async {
    final service = PermanentDeleteService.real(
      deleteExecutor: (_) async {
        throw Exception('delete failed');
      },
    );
    final result = await service.delete({'a', 'b'});

    expect(result.succeededIds, isEmpty);
    expect(result.failedIds, {'a', 'b'});
    expect(result.failureReasons.keys.toSet(), {'a', 'b'});
  });
}
