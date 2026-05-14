import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/domain/services/permanent_delete_service.dart';
import 'package:rephoto/features/trash/trash_controller.dart';

void main() {
  test('permanent delete all keeps failed ids only', () async {
    final controller = TrashController(['1', '2', '3']);
    final service = PermanentDeleteService(
      fakeDeleteResult: {'1': true, '2': false, '3': true},
    );

    final result = await controller.permanentDeleteAll(service);

    expect(result.failedIds, {'2'});
    expect(controller.ids, ['2']);
  });

  test(
    'permanent delete selected keeps failed items selected for retry',
    () async {
      final controller = TrashController(['1', '2', '3']);
      controller.toggleSelection('1');
      controller.toggleSelection('2');
      final service = PermanentDeleteService(
        fakeDeleteResult: {'1': true, '2': false},
      );

      final result = await controller.permanentDeleteSelected(service);

      expect(result.failedIds, {'2'});
      expect(controller.ids, ['2', '3']);
      expect(controller.selected, {'2'});
    },
  );

  test(
    'permanent delete selected tracks succeeded ids for source removal',
    () async {
      final controller = TrashController(['1', '2', '3']);
      controller.toggleSelection('1');
      controller.toggleSelection('2');
      final service = PermanentDeleteService(
        fakeDeleteResult: {'1': true, '2': false},
      );

      await controller.permanentDeleteSelected(service);

      expect(controller.permanentlyDeletedIds, {'1'});
    },
  );
}
