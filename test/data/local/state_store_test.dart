import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/data/local/state_store.dart';

void main() {
  test('persists trash count and selected filter after restart', () async {
    final store = InMemoryStateStore();
    await store.saveTrashIds({'1', '2'});
    await store.saveLocationFilter('CN/SH/XH');

    expect(await store.loadTrashIds(), {'1', '2'});
    expect(await store.loadLocationFilter(), 'CN/SH/XH');
  });
}
