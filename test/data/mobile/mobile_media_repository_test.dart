import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/data/mobile/mobile_media_repository.dart';
import 'package:rephoto/data/mobile/mobile_permissions_service.dart';
import 'package:rephoto/domain/models/media_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('permanent delete removes trashed ids from source list', () async {
    final repo = FakeMobileMediaRepository(['1', '2', '3']);

    await repo.permanentDelete({'2'});

    expect(await repo.fetchAllIds(), ['1', '3']);
  });

  test(
    'method channel repository fetches ids and sends delete payload',
    () async {
      const channel = MethodChannelMobileMediaRepository.channel;
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'fetchAllIds') {
              return ['10', '11'];
            }
            if (call.method == 'permanentDelete') {
              return null;
            }
            return null;
          });

      final repo = MethodChannelMobileMediaRepository();
      expect(await repo.fetchAllIds(), ['10', '11']);
      await repo.permanentDelete({'11'});

      expect(calls.first.method, 'fetchAllIds');
      expect(calls.last.method, 'permanentDelete');
      expect((calls.last.arguments as Map)['ids'], ['11']);
    },
  );

  test('method channel repository maps media metadata payload', () async {
    const channel = MethodChannelMobileMediaRepository.channel;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'fetchAllMediaItems') {
            return [
              {
                'id': 'photo_1',
                'type': 'photo',
                'createdAtMillis': 1735689600000,
                'locationKey': 'CN/SH/XH',
                'pathOrUri': 'content://media/photo_1',
                'sizeBytes': 4096,
                'livePhotoVideoUri': 'phlive://photo_1',
              },
              {
                'id': 'video_1',
                'type': 'video',
                'createdAtMillis': 1735776000000,
                'locationKey': 'US/CA/SF',
                'pathOrUri': 'content://media/video_1',
                'size': '8192',
              },
            ];
          }
          return null;
        });

    final repo = MethodChannelMobileMediaRepository();
    final items = await repo.fetchAllMediaItems();

    expect(items.length, 2);
    expect(items.first.type, MediaType.photo);
    expect(items.last.type, MediaType.video);
    expect(items.first.locationKey, 'CN/SH/XH');
    expect(items.first.sizeBytes, 4096);
    expect(items.first.livePhotoVideoUri, 'phlive://photo_1');
    expect(items.last.pathOrUri, 'content://media/video_1');
    expect(items.last.sizeBytes, 8192);
  });

  test(
    'method channel repository fetches a media page with offset/limit',
    () async {
      const channel = MethodChannelMobileMediaRepository.channel;
      MethodCall? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            captured = call;
            if (call.method == 'fetchMediaPage') {
              return [
                {
                  'id': 'photo_2',
                  'type': 'photo',
                  'createdAtMillis': 1735689600000,
                  'locationKey': 'geo/31.230/121.473',
                  'pathOrUri': 'content://media/photo_2',
                  'size': 2048,
                },
              ];
            }
            return null;
          });

      final repo = MethodChannelMobileMediaRepository();
      final items = await repo.fetchMediaPage(offset: 10, limit: 20);

      expect(captured?.method, 'fetchMediaPage');
      final args = captured?.arguments as Map<dynamic, dynamic>;
      expect(args['offset'], 10);
      expect(args['limit'], 20);
      expect(items.map((e) => e.id).toList(), ['photo_2']);
      expect(items.single.sizeBytes, 2048);
    },
  );

  test(
    'method channel repository falls back to all media when page API is unavailable',
    () async {
      const channel = MethodChannelMobileMediaRepository.channel;
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'fetchMediaPage') {
              throw MissingPluginException();
            }
            if (call.method == 'fetchAllMediaItems') {
              return [
                {
                  'id': 'photo_1',
                  'type': 'photo',
                  'createdAtMillis': 1735689600000,
                  'pathOrUri': 'content://media/photo_1',
                },
                {
                  'id': 'photo_2',
                  'type': 'photo',
                  'createdAtMillis': 1735776000000,
                  'pathOrUri': 'content://media/photo_2',
                },
                {
                  'id': 'photo_3',
                  'type': 'photo',
                  'createdAtMillis': 1735862400000,
                  'pathOrUri': 'content://media/photo_3',
                },
              ];
            }
            return null;
          });

      final repo = MethodChannelMobileMediaRepository();
      final items = await repo.fetchMediaPage(offset: 1, limit: 2);

      expect(calls.map((call) => call.method).toList(), [
        'fetchMediaPage',
        'fetchAllMediaItems',
      ]);
      expect(items.map((e) => e.id).toList(), ['photo_2', 'photo_3']);
    },
  );

  test('fake repository fetchMediaPage returns sliced items', () async {
    final repo = FakeMobileMediaRepository(['1', '2', '3', '4']);
    final page = await repo.fetchMediaPage(offset: 1, limit: 2);

    expect(page.map((e) => e.id).toList(), ['2', '3']);
    expect(await repo.fetchMediaPage(offset: 10, limit: 2), isEmpty);
  });

  test('method channel repository requests batch location keys', () async {
    const channel = MethodChannelMobileMediaRepository.channel;
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          captured = call;
          if (call.method == 'batchGetLocationKeys') {
            return {'a': 'CN/广东省/深圳市/莲花山公园内'};
          }
          return null;
        });

    final repo = MethodChannelMobileMediaRepository();
    final result = await repo.batchGetLocationKeys([
      MediaItem(
        id: 'a',
        type: MediaType.photo,
        pathOrUri: '/storage/DCIM/a.jpg',
      ),
    ]);

    expect(captured?.method, 'batchGetLocationKeys');
    expect(result['a'], 'CN/广东省/深圳市/莲花山公园内');
  });

  test('method channel repository resolves playable media uri', () async {
    const channel = MethodChannelMobileMediaRepository.channel;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'resolvePlayableMediaUri') {
            return 'file:///tmp/video.mp4';
          }
          return null;
        });

    final repo = MethodChannelMobileMediaRepository();
    final uri = await repo.resolvePlayableMediaUri('phasset://video_1');

    expect(uri, 'file:///tmp/video.mp4');
  });

  test('method channel repository supports location aliases', () async {
    const channel = MethodChannelMobileMediaRepository.channel;
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'getLocationAliases') {
            return {'CN/广东省/深圳市/福田区/@22.5401,114.0601': '家'};
          }
          return null;
        });

    final repo = MethodChannelMobileMediaRepository();
    final aliases = await repo.getLocationAliases();
    await repo.setLocationAlias('CN/广东省/深圳市/福田区/@22.5401,114.0601', '家');
    await repo.removeLocationAlias('CN/广东省/深圳市/福田区/@22.5401,114.0601');

    expect(aliases['CN/广东省/深圳市/福田区/@22.5401,114.0601'], '家');
    expect(calls[0].method, 'getLocationAliases');
    expect(calls[1].method, 'setLocationAlias');
    expect((calls[1].arguments as Map)['alias'], '家');
    expect(calls[2].method, 'removeLocationAlias');
  });

  test('method channel permission service maps granted status', () async {
    const channel = MethodChannelMobilePermissionsService.channel;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'requestMediaReadPermission');
          return 'granted';
        });

    final service = MethodChannelMobilePermissionsService();
    final status = await service.requestMediaReadPermission();
    expect(status, MediaPermissionStatus.granted);
  });
}
