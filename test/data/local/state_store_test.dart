import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:rephoto/data/local/state_store.dart';
import 'package:rephoto/domain/models/deletion_stats.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists trash count and selected filter after restart', () async {
    final store = InMemoryStateStore();
    await store.saveTrashIds({'1', '2'});
    await store.saveLocationFilter('CN/SH/XH');

    expect(await store.loadTrashIds(), {'1', '2'});
    expect(await store.loadLocationFilter(), 'CN/SH/XH');
  });

  test('persists cumulative deletion stats', () async {
    final store = InMemoryStateStore();
    const stats = DeletionStats(
      photoCount: 3,
      videoCount: 2,
      knownSizeBytes: 2048,
      hasUnknownSize: true,
    );

    await store.saveDeletionStats(stats);

    final restored = await store.loadDeletionStats();
    expect(restored.photoCount, 3);
    expect(restored.videoCount, 2);
    expect(restored.knownSizeBytes, 2048);
    expect(restored.hasUnknownSize, isTrue);
  });

  test('persists browse progress by collection id', () async {
    final store = InMemoryStateStore();

    await store.saveBrowseProgress('month-2026-04', 'late-april');
    await store.saveBrowseProgress('month-2026-05', 'may-photo');

    expect(await store.loadBrowseProgress('month-2026-04'), 'late-april');
    expect(await store.loadBrowseProgress('month-2026-05'), 'may-photo');
    expect(await store.loadBrowseProgress('month-2026-06'), isNull);
  });

  test('method channel store saves and loads deletion stats', () async {
    const channel = MethodChannelLocalStateStore.channel;
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'loadDeletionStats') {
            return <String, Object>{
              'photoCount': 5,
              'videoCount': 1,
              'knownSizeBytes': 4096,
              'hasUnknownSize': false,
            };
          }
          return null;
        });

    final store = MethodChannelLocalStateStore();
    await store.saveDeletionStats(
      const DeletionStats(photoCount: 2, videoCount: 3, knownSizeBytes: 1024),
    );
    final restored = await store.loadDeletionStats();

    expect(calls.first.method, 'saveDeletionStats');
    expect((calls.first.arguments as Map)['photoCount'], 2);
    expect(restored.photoCount, 5);
    expect(restored.videoCount, 1);
    expect(restored.knownSizeBytes, 4096);
  });

  test('method channel store saves and loads browse progress', () async {
    const channel = MethodChannelLocalStateStore.channel;
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'loadBrowseProgress') {
            return 'late-april';
          }
          return null;
        });

    final store = MethodChannelLocalStateStore();
    await store.saveBrowseProgress('month-2026-04', 'late-april');
    final restored = await store.loadBrowseProgress('month-2026-04');

    expect(calls.first.method, 'saveBrowseProgress');
    expect((calls.first.arguments as Map)['collectionId'], 'month-2026-04');
    expect((calls.first.arguments as Map)['mediaId'], 'late-april');
    expect(calls.last.method, 'loadBrowseProgress');
    expect((calls.last.arguments as Map)['collectionId'], 'month-2026-04');
    expect(restored, 'late-april');
  });
}
