import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/domain/services/gesture_session_service.dart';

void main() {
  test('up deletes to trash and down undoes last delete', () {
    final service = GestureSessionService();
    service.onShown('a');
    service.onDeleteCurrent('a');

    expect(service.trashIds, contains('a'));

    service.undoLastDelete();
    expect(service.trashIds, isNot(contains('a')));
  });

  test('tracks trash order as newest first', () {
    final service = GestureSessionService();
    service.onDeleteCurrent('a');
    service.onDeleteCurrent('b');
    service.onDeleteCurrent('c');

    expect(service.trashOrderedIds, ['c', 'b', 'a']);

    service.undoLastDelete();
    expect(service.trashOrderedIds, ['b', 'a']);
  });
}
