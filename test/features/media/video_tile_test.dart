import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/features/media/widgets/video_tile.dart';
import 'package:video_player/video_player.dart';
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

  testWidgets('video autoplays after initialization when enabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VideoTile(uri: 'file:///tmp/a.mp4', autoPlay: true),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(fakePlatform.playCalls, 1);
  });

  testWidgets('video time label is hidden until progress is dragged', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: VideoTile(uri: 'file:///tmp/a.mp4')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('video-time-label')), findsNothing);
  });

  testWidgets('video scrub shows time bubble and preview above thumb', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: VideoTile(uri: 'file:///tmp/a.mp4')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final progressBar = find.byKey(const Key('video-progress-bar'));
    final center = tester.getCenter(progressBar);
    final gesture = await tester.startGesture(center);
    await tester.pump();
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();

    final badge = find.byKey(const Key('video-time-label'));
    expect(badge, findsOneWidget);
    expect(find.byKey(const Key('video-scrub-preview')), findsOneWidget);

    final badgeCenter = tester.getCenter(badge);
    final previewCenter = tester.getCenter(
      find.byKey(const Key('video-scrub-preview')),
    );
    final trackCenter = tester.getCenter(
      find.byKey(const Key('video-progress-track')),
    );

    expect(badgeCenter.dy, lessThan(trackCenter.dy - 48));
    expect(previewCenter.dy, lessThan(trackCenter.dy - 48));

    final text = tester.widget<Text>(
      find.descendant(of: badge, matching: find.byType(Text)),
    );
    expect(text.style?.fontSize, 16);

    await gesture.up();
    await tester.pump();
    expect(find.byKey(const Key('video-time-label')), findsNothing);
  });

  testWidgets('video scrub thumb stays white while dragging', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: VideoTile(uri: 'file:///tmp/a.mp4')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final progressBar = find.byKey(const Key('video-progress-bar'));
    final gesture = await tester.startGesture(tester.getCenter(progressBar));
    await tester.pump();
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();

    final thumb = tester.widget<Container>(
      find.byKey(const Key('video-progress-thumb')),
    );
    final decoration = thumb.decoration! as BoxDecoration;
    expect(decoration.color, Colors.white);

    await gesture.up();
  });

  testWidgets(
    'video scrub preview renders current video frame instead of cover',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: VideoTile(uri: 'file:///tmp/a.mp4')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final progressBar = find.byKey(const Key('video-progress-bar'));
      final gesture = await tester.startGesture(tester.getCenter(progressBar));
      await tester.pump();
      await gesture.moveBy(const Offset(80, 0));
      await tester.pump();

      final preview = find.byKey(const Key('video-scrub-preview'));
      expect(
        find.descendant(of: preview, matching: find.byType(VideoPlayer)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: preview, matching: find.byType(Image)),
        findsNothing,
      );

      await gesture.up();
    },
  );

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

  testWidgets('scrubbing leaves main video playing and commits on release', (
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
    expect(fakePlatform.playCalls, 1);
    final mainPlayerId = fakePlatform.mainPlayerId;
    final initialMainPauseCalls = fakePlatform.pauseCallsFor(mainPlayerId);

    final progressBar = find.byKey(const Key('video-progress-bar'));
    final gesture = await tester.startGesture(tester.getCenter(progressBar));
    await tester.pump();
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();

    expect(fakePlatform.pauseCallsFor(mainPlayerId), initialMainPauseCalls);
    expect(fakePlatform.playCalls, 1);
    expect(fakePlatform.seekCallsFor(mainPlayerId), 0);
    expect(find.byKey(const Key('video-scrub-preview')), findsOneWidget);

    await gesture.up();
    await tester.pump();

    expect(find.byKey(const Key('video-scrub-preview')), findsNothing);
    expect(fakePlatform.playCalls, 1);
    expect(fakePlatform.seekCallsFor(mainPlayerId), 1);
  });

  testWidgets('tapping above progress track toggles playback without seeking', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 620,
            child: VideoTile(uri: 'file:///tmp/a.mp4'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final tileBottom = tester.getBottomLeft(find.byType(VideoTile)).dy;
    await tester.tapAt(Offset(180, tileBottom - 140));
    await tester.pump();

    expect(fakePlatform.playCalls, 1);
    expect(fakePlatform.seekCallsFor(fakePlatform.mainPlayerId), 0);
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

  testWidgets('boost badge appears while long pressing playing video', (
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
    expect(timeBadge, findsNothing);

    await gesture.up();
    await tester.pump();
  });

  testWidgets('video progress bar can seek playback position', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: VideoTile(uri: 'file:///tmp/a.mp4')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final progressBar = find.byKey(const Key('video-progress-bar'));
    expect(progressBar, findsOneWidget);

    final start = tester.getTopLeft(progressBar);
    final size = tester.getSize(progressBar);
    await tester.tapAt(Offset(start.dx + size.width * 0.5, start.dy + 4));
    await tester.pump();

    expect(fakePlatform.seekCalls, 1);
    expect(
      fakePlatform.lastSeek,
      const Duration(seconds: 47, milliseconds: 500),
    );
  });

  testWidgets('video progress bar uses bottom gradient and white progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: VideoTile(uri: 'file:///tmp/a.mp4')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final gradient = tester.widget<Container>(
      find.byKey(const Key('video-progress-gradient')),
    );
    final gradientDecoration = gradient.decoration! as BoxDecoration;
    expect(gradientDecoration.color, isNull);
    expect(gradientDecoration.gradient, isA<LinearGradient>());

    final fill = tester.widget<Container>(
      find.byKey(const Key('video-progress-fill')),
    );
    final fillDecoration = fill.decoration! as BoxDecoration;
    expect(fillDecoration.color, Colors.white);
  });

  testWidgets('video progress gradient is pinned to tile bottom', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 620,
            child: VideoTile(uri: 'file:///tmp/a.mp4'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final tileBottom = tester.getBottomLeft(find.byType(VideoTile)).dy;
    final gradientBottom = tester
        .getBottomLeft(find.byKey(const Key('video-progress-gradient')))
        .dy;

    expect(gradientBottom, closeTo(tileBottom, 1));
  });

  testWidgets('video progress drag reports scrub lifecycle', (tester) async {
    var starts = 0;
    var ends = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoTile(
            uri: 'file:///tmp/a.mp4',
            onScrubStart: () => starts += 1,
            onScrubEnd: () => ends += 1,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final progressBar = find.byKey(const Key('video-progress-bar'));
    final start = tester.getCenter(progressBar);
    final gesture = await tester.startGesture(start);
    await tester.pump();
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(starts, 1);
    expect(ends, 1);
    expect(fakePlatform.seekCalls, greaterThan(0));
  });
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  int _nextPlayerId = 0;
  int playCalls = 0;
  int pauseCalls = 0;
  int seekCalls = 0;
  Duration? lastSeek;
  int get mainPlayerId => 0;
  final Map<int, int> _pauseCallsByPlayer = <int, int>{};
  final Map<int, int> _seekCallsByPlayer = <int, int>{};
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
    _pauseCallsByPlayer[playerId] = pauseCallsFor(playerId) + 1;
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
  Future<void> seekTo(int playerId, Duration position) async {
    seekCalls += 1;
    _seekCallsByPlayer[playerId] = seekCallsFor(playerId) + 1;
    lastSeek = position;
  }

  int pauseCallsFor(int playerId) => _pauseCallsByPlayer[playerId] ?? 0;

  int seekCallsFor(int playerId) => _seekCallsByPlayer[playerId] ?? 0;

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}
