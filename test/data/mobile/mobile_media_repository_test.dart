import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/data/mobile/external_import_repository.dart';
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
              {
                'id': 'motion_1',
                'type': 'photo',
                'pathOrUri': 'content://media/motion_1',
                'motionPhotoXmp':
                    '<Container:Item Item:Semantic="MotionPhoto" '
                    'Item:Length="12345"/>',
              },
            ];
          }
          return null;
        });

    final repo = MethodChannelMobileMediaRepository();
    final items = await repo.fetchAllMediaItems();

    expect(items.length, 3);
    expect(items.first.type, MediaType.photo);
    expect(items[1].type, MediaType.video);
    expect(items.first.locationKey, 'CN/SH/XH');
    expect(items.first.sizeBytes, 4096);
    expect(items.first.livePhotoVideoUri, 'phlive://photo_1');
    expect(items[1].pathOrUri, 'content://media/video_1');
    expect(items[1].sizeBytes, 8192);
    final motionUri = Uri.parse(items.last.livePhotoVideoUri!);
    expect(motionUri.scheme, 'motionphoto');
    expect(motionUri.queryParameters['source'], 'content://media/motion_1');
    expect(motionUri.queryParameters['videoLength'], '12345');
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

  test('external import repository scans and imports selected media', () async {
    const channel = MethodChannelExternalImportRepository.channel;
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'getSavedImportRoot':
              return 'content://tree/sdcard';
            case 'listImportRoots':
              return [
                {
                  'id': 'sd-1234',
                  'label': 'SD Card',
                  'description': '储存卡 sd-1234',
                  'removable': true,
                },
              ];
            case 'requestImportRoot':
              return 'content://tree/sdcard';
            case 'scanImportRoot':
              return [
                {
                  'id': 'content://tree/sdcard/document/1',
                  'type': 'photo',
                  'displayName': 'IMG_0001.JPG',
                  'createdAtMillis': 1735689600000,
                  'sizeBytes': 4096,
                  'pathOrUri': 'content://tree/sdcard/document/1',
                  'imported': true,
                },
              ];
            case 'scanImportRootPage':
              expect((call.arguments as Map)['offset'], 0);
              expect((call.arguments as Map)['limit'], 60);
              expect((call.arguments as Map)['includeRaw'], isFalse);
              return {
                'items': [
                  {
                    'id': 'content://tree/sdcard/document/1',
                    'type': 'photo',
                    'displayName': 'IMG_0001.JPG',
                    'createdAtMillis': 1735689600000,
                    'sizeBytes': 4096,
                    'pathOrUri': 'content://tree/sdcard/document/1',
                    'imported': true,
                  },
                ],
                'hasMore': false,
              };
            case 'importExternalMedia':
              return 'content://media/external/images/media/99';
            case 'fetchImportFullImageData':
              return Uint8List.fromList([1, 2, 3]);
            case 'deleteExternalMedia':
              return null;
          }
          return null;
        });

    final repo = MethodChannelExternalImportRepository();

    expect(await repo.getSavedImportRoot(), 'content://tree/sdcard');
    final roots = await repo.listImportRoots();
    final chosenRoot = await repo.requestImportRoot(rootId: roots.single.id);
    final items = await repo.scanImportRoot();
    final page = await repo.scanImportRootPage(offset: 0, limit: 60);
    final importedUri = await repo.importExternalMedia(
      items.single,
      albumTarget: ImportAlbumTarget.existing(
        id: 'album-1',
        name: 'PhotoTend',
        relativePath: 'Pictures/PhotoTend',
      ),
    );
    final fullBytes = await repo.fetchFullImageData(items.single.pathOrUri);
    await repo.deleteExternalMedia(items.single);

    expect(chosenRoot, 'content://tree/sdcard');
    expect(roots.single.label, 'SD Card');
    expect(items.single.id, 'content://tree/sdcard/document/1');
    expect(items.single.type, MediaType.photo);
    expect(items.single.displayName, 'IMG_0001.JPG');
    expect(items.single.imported, isTrue);
    expect(page.items.single.id, items.single.id);
    expect(page.hasMore, isFalse);
    expect(importedUri, 'content://media/external/images/media/99');
    expect(fullBytes, [1, 2, 3]);
    expect(calls.map((call) => call.method), [
      'getSavedImportRoot',
      'listImportRoots',
      'requestImportRoot',
      'scanImportRoot',
      'scanImportRootPage',
      'importExternalMedia',
      'fetchImportFullImageData',
      'deleteExternalMedia',
    ]);
    expect((calls[2].arguments as Map)['rootId'], 'sd-1234');
    expect((calls[5].arguments as Map)['sourceUri'], items.single.pathOrUri);
    expect((calls[5].arguments as Map)['albumName'], 'PhotoTend');
    expect((calls[5].arguments as Map)['albumId'], 'album-1');
    expect(
      (calls[5].arguments as Map)['albumRelativePath'],
      'Pictures/PhotoTend',
    );
    expect((calls[5].arguments as Map)['useSystemLibrary'], isFalse);
    expect((calls[7].arguments as Map)['sourceUri'], items.single.pathOrUri);
  });

  test(
    'external import repository omits album name for system library',
    () async {
      const channel = MethodChannelExternalImportRepository.channel;
      MethodCall? importCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'importExternalMedia') {
              importCall = call;
              return 'content://media/external/images/media/100';
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final repo = MethodChannelExternalImportRepository();
      await repo.importExternalMedia(
        ExternalImportItem(
          id: 'a',
          type: MediaType.photo,
          displayName: 'a.jpg',
          pathOrUri: 'content://doc/a',
        ),
        albumTarget: const ImportAlbumTarget.systemLibrary(),
      );

      final args = importCall!.arguments as Map<dynamic, dynamic>;
      expect(args['useSystemLibrary'], isTrue);
      expect(args.containsKey('albumName'), isFalse);
      expect(args.containsKey('albumRelativePath'), isFalse);
    },
  );

  test(
    'external import repository starts and reads background import batch',
    () async {
      const channel = MethodChannelExternalImportRepository.channel;
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'startBackgroundImport') {
              return true;
            }
            if (call.method == 'getBackgroundImportStatus') {
              return {
                'running': false,
                'totalCount': 2,
                'completedCount': 2,
                'importedIds': ['a'],
                'failedIds': ['b'],
              };
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final repo = MethodChannelExternalImportRepository();
      final started = await repo.startBackgroundImport([
        ExternalImportItem(
          id: 'a',
          type: MediaType.photo,
          displayName: 'a.jpg',
          pathOrUri: 'content://doc/a',
        ),
      ], albumTarget: const ImportAlbumTarget.systemLibrary());
      final status = await repo.getBackgroundImportStatus();

      expect(started, isTrue);
      expect(status?.running, isFalse);
      expect(status?.totalCount, 2);
      expect(status?.completedCount, 2);
      expect(status?.importedIds, {'a'});
      expect(status?.failedIds, {'b'});
      final args = calls.first.arguments as Map<dynamic, dynamic>;
      expect(args['items'], [
        {
          'id': 'a',
          'sourceUri': 'content://doc/a',
          'displayName': 'a.jpg',
          'type': 'photo',
        },
      ]);
      expect(args['useSystemLibrary'], isTrue);
    },
  );

  test('mobile media repository fetches user albums from platform', () async {
    const channel = MethodChannelMobileMediaRepository.channel;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'fetchUserAlbums') {
            return [
              {'id': 'album-1', 'name': '旅行', 'count': 12},
              {
                'id': 'album-2',
                'name': '家庭',
                'count': 3,
                'relativePath': 'Pictures/家庭',
              },
            ];
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final repo = MethodChannelMobileMediaRepository();
    final albums = await repo.fetchUserAlbums();

    expect(albums.map((album) => album.name), ['旅行', '家庭']);
    expect(albums.first.id, 'album-1');
    expect(albums.first.count, 12);
    expect(albums.last.relativePath, 'Pictures/家庭');
  });
}
