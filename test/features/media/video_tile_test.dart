import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/features/media/widgets/video_tile.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  late VideoPlayerPlatform originalPlatform;
  late _FakeVideoPlayerPlatform fakePlatform;

  setUp(() {
    originalPlatform = VideoPlayerPlatform.instance;
    fakePlatform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakePlatform;
  });

  tearDown(() {
    VideoPlayerPlatform.instance = originalPlatform;
  });

  testWidgets('video item renders play control', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: VideoTile(uri: 'file:///tmp/a.mp4')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('video time label is shown at top center', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: VideoTile(uri: 'file:///tmp/a.mp4')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final badge = find.byKey(const Key('video-time-label'));
    expect(badge, findsOneWidget);

    final badgeCenter = tester.getCenter(badge);
    final rootCenter = tester.getCenter(find.byType(Scaffold));

    expect((badgeCenter.dx - rootCenter.dx).abs(), lessThanOrEqualTo(4));
    expect(badgeCenter.dy, lessThan(80));
  });

  testWidgets('tap video surface toggles play and pause', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: VideoTile(uri: 'file:///tmp/a.mp4')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byType(VideoTile));
    await tester.pump();

    expect(fakePlatform.playCalls, 1);

    await tester.tap(find.byType(VideoTile));
    await tester.pump();

    expect(fakePlatform.pauseCalls, greaterThanOrEqualTo(2));
  });

  testWidgets('playing video does not show centered pause button', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: VideoTile(uri: 'file:///tmp/a.mp4')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byType(VideoTile));
    await tester.pump();

    expect(find.byIcon(Icons.pause_rounded), findsNothing);
  });

  testWidgets('boost badge appears after time label in same top row', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: VideoTile(uri: 'file:///tmp/a.mp4')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byType(VideoTile));
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(VideoTile)),
    );
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();

    final timeBadge = find.byKey(const Key('video-time-label'));
    final speedBadge = find.byKey(const Key('video-speed-label'));

    expect(speedBadge, findsOneWidget);
    expect(
      tester.getCenter(speedBadge).dy,
      closeTo(tester.getCenter(timeBadge).dy, 2),
    );
    expect(
      tester.getCenter(speedBadge).dx,
      greaterThan(tester.getCenter(timeBadge).dx),
    );

    await gesture.up();
    await tester.pump();
  });
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  int _nextPlayerId = 0;
  int playCalls = 0;
  int pauseCalls = 0;
  final Map<int, StreamController<VideoEvent>> _streams =
      <int, StreamController<VideoEvent>>{};

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final playerId = _nextPlayerId++;
    final stream = StreamController<VideoEvent>();
    _streams[playerId] = stream;
    stream.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        size: const Size(1920, 1080),
        duration: const Duration(minutes: 1, seconds: 35),
      ),
    );
    return playerId;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    return _streams[playerId]!.stream;
  }

  @override
  Widget buildView(int playerId) {
    return ColoredBox(
      color: Colors.black,
      child: Text('video-$playerId', textDirection: TextDirection.ltr),
    );
  }

  @override
  Future<void> dispose(int playerId) async {
    await _streams.remove(playerId)?.close();
  }

  @override
  Future<void> pause(int playerId) async {
    pauseCalls += 1;
    _streams[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: false,
      ),
    );
  }

  @override
  Future<void> play(int playerId) async {
    playCalls += 1;
    _streams[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ),
    );
  }

  @override
  Future<Duration> getPosition(int playerId) async =>
      const Duration(seconds: 12);

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}
