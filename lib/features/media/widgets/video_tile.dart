import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

VideoPlayerController buildVideoPlayerController(String uri) {
  final parsed = Uri.parse(uri);
  if (parsed.hasScheme &&
      (parsed.scheme == 'http' || parsed.scheme == 'https')) {
    return VideoPlayerController.networkUrl(parsed);
  }
  if (parsed.hasScheme && parsed.scheme == 'content' && Platform.isAndroid) {
    return VideoPlayerController.contentUri(parsed);
  }
  if (parsed.hasScheme && parsed.scheme == 'file') {
    return VideoPlayerController.file(File(parsed.toFilePath()));
  }
  return VideoPlayerController.file(File(uri));
}

class VideoTile extends StatefulWidget {
  const VideoTile({
    super.key,
    required this.uri,
    this.thumbnailProvider,
    this.preloadedController,
    this.autoPlay = false,
    this.showOverlayControls = true,
    this.enableLongPressBoost = true,
    this.onScrubStart,
    this.onScrubEnd,
  });

  final String uri;
  final ImageProvider<Object>? thumbnailProvider;
  final VideoPlayerController? preloadedController;
  final bool autoPlay;
  final bool showOverlayControls;
  final bool enableLongPressBoost;
  final VoidCallback? onScrubStart;
  final VoidCallback? onScrubEnd;

  @override
  State<VideoTile> createState() => _VideoTileState();
}

class _VideoTileState extends State<VideoTile> {
  VideoPlayerController? _controller;
  String? _controllerUri;
  bool _isInitializing = false;
  bool _isBoosting = false;
  bool _isScrubbing = false;
  int _configureVersion = 0;

  @override
  void initState() {
    super.initState();
    _configureController();
  }

  @override
  void didUpdateWidget(covariant VideoTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri == widget.uri &&
        oldWidget.preloadedController == widget.preloadedController &&
        oldWidget.autoPlay == widget.autoPlay) {
      return;
    }
    _configureController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: widget.thumbnailProvider != null
                ? Image(
                    image: widget.thumbnailProvider!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const DecoratedBox(
                      decoration: BoxDecoration(color: Color(0x22000000)),
                      child: SizedBox.expand(),
                    ),
                  )
                : const DecoratedBox(
                    decoration: BoxDecoration(color: Color(0x22000000)),
                    child: SizedBox.expand(),
                  ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(color: Color(0x22000000)),
            ),
          ),
          if (widget.showOverlayControls)
            GestureDetector(
              onTap: _isInitializing ? null : _togglePlay,
              child: _isInitializing
                  ? Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Color(0x99000000),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Color(0x99000000),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
            )
          else
            const Icon(Icons.videocam, color: Colors.white70),
        ],
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (widget.showOverlayControls) {
          _togglePlay();
        }
      },
      onLongPressStart: widget.enableLongPressBoost
          ? (_) => _setBoostPlayback(true)
          : null,
      onLongPressEnd: widget.enableLongPressBoost
          ? (_) => _setBoostPlayback(false)
          : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox.fromSize(
                    size: controller.value.size,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
              if (widget.showOverlayControls &&
                  !controller.value.isPlaying &&
                  !_isScrubbing)
                IgnorePointer(
                  child: Container(
                    key: const Key('video-play-overlay'),
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Color(0x99000000),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (widget.showOverlayControls)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 240,
                  child: ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: controller,
                    builder: (context, value, _) {
                      return _VideoProgressBar(
                        controller: controller,
                        value: value,
                        isBoosting: _isBoosting,
                        uri: widget.uri,
                        thumbnailProvider: widget.thumbnailProvider,
                        onScrubStart: _handleScrubStart,
                        onScrubEnd: _handleScrubEnd,
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _configureController() async {
    final version = ++_configureVersion;
    var controller = widget.preloadedController;
    final controllerUri = widget.uri;

    if (controller != null) {
      if (_controller != controller) {
        await _controller?.dispose();
        _controller = controller;
      }
      _controllerUri = controllerUri;
      await _initializeController(controller, version: version);
      return;
    }

    final current = _controller;
    if (current != null && _controllerUri == controllerUri) {
      await _initializeController(current, version: version);
      return;
    }

    await current?.dispose();
    controller = buildVideoPlayerController(controllerUri);
    _controller = controller;
    _controllerUri = controllerUri;
    await _initializeController(controller, version: version);
  }

  Future<void> _initializeController(
    VideoPlayerController controller, {
    required int version,
  }) async {
    if (controller.value.isInitialized) {
      if (widget.autoPlay) {
        await controller.play();
      } else {
        await controller.pause();
      }
      if (mounted && version == _configureVersion) {
        setState(() => _isInitializing = false);
      }
      return;
    }

    if (mounted && version == _configureVersion) {
      setState(() => _isInitializing = true);
    }
    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setPlaybackSpeed(1.0);
      if (widget.autoPlay) {
        await controller.play();
      } else {
        await controller.pause();
      }
    } catch (_) {
      if (mounted && version == _configureVersion) {
        setState(() => _isInitializing = false);
      }
      return;
    }
    if (mounted && version == _configureVersion) {
      setState(() => _isInitializing = false);
    }
  }

  Future<void> _setBoostPlayback(bool enabled) async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        !controller.value.isPlaying) {
      return;
    }
    final target = enabled ? 2.0 : 1.0;
    await controller.setPlaybackSpeed(target);
    if (mounted) {
      setState(() => _isBoosting = enabled);
    }
  }

  Future<void> _resetBoostPlaybackIfNeeded() async {
    if (!_isBoosting) {
      return;
    }
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      await controller.setPlaybackSpeed(1.0);
    }
    if (mounted) {
      setState(() => _isBoosting = false);
    }
  }

  Future<void> _handleScrubStart() async {
    widget.onScrubStart?.call();
    if (mounted) {
      setState(() => _isScrubbing = true);
    }
  }

  Future<void> _handleScrubEnd() async {
    widget.onScrubEnd?.call();
    if (mounted) {
      setState(() => _isScrubbing = false);
    }
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null) {
      await _configureController();
      return;
    }
    if (!controller.value.isInitialized) {
      await _initializeController(controller, version: _configureVersion);
      return;
    }

    if (controller.value.isPlaying) {
      await _resetBoostPlaybackIfNeeded();
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) {
      setState(() {});
    }
  }
}

class _VideoProgressBar extends StatefulWidget {
  const _VideoProgressBar({
    required this.controller,
    required this.value,
    required this.isBoosting,
    required this.uri,
    required this.thumbnailProvider,
    required this.onScrubStart,
    required this.onScrubEnd,
  });

  final VideoPlayerController controller;
  final VideoPlayerValue value;
  final bool isBoosting;
  final String uri;
  final ImageProvider<Object>? thumbnailProvider;
  final Future<void> Function()? onScrubStart;
  final Future<void> Function()? onScrubEnd;

  @override
  State<_VideoProgressBar> createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends State<_VideoProgressBar> {
  VideoPlayerController? _previewController;
  String? _previewUri;
  bool _isPreviewInitializing = false;
  bool _isScrubbing = false;
  double _scrubFraction = 0;
  Duration? _pendingMainSeek;

  @override
  void didUpdateWidget(covariant _VideoProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) {
      _disposePreviewController();
      _pendingMainSeek = null;
      _isScrubbing = false;
    }
  }

  @override
  void dispose() {
    _disposePreviewController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final duration = value.duration;
    final progress = duration.inMilliseconds <= 0
        ? 0.0
        : (value.position.inMilliseconds / duration.inMilliseconds).clamp(
            0.0,
            1.0,
          );
    final displayProgress = _isScrubbing ? _scrubFraction : progress;
    final scrubPosition = Duration(
      milliseconds: (duration.inMilliseconds * displayProgress).round(),
    );

    return SizedBox(
      height: 240,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackWidth = (constraints.maxWidth - 36).clamp(
            0.0,
            double.infinity,
          );
          final thumbX = 18 + trackWidth * displayProgress;
          final previewLeft = (thumbX - 44).clamp(
            8.0,
            (constraints.maxWidth - 88).clamp(8.0, double.infinity),
          );
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    key: const Key('video-progress-gradient'),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0),
                          Colors.black.withValues(alpha: 0.42),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_isScrubbing)
                _buildScrubPreview(
                  previewLeft: previewLeft,
                  scrubPosition: scrubPosition,
                ),
              if (widget.isBoosting)
                const Positioned(
                  top: 18,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _ProgressBadge(
                      key: Key('video-speed-label'),
                      label: '2x',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 52,
                child: GestureDetector(
                  key: const Key('video-progress-bar'),
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) =>
                      _commitMainSeek(context, details.localPosition),
                  onTap: () {},
                  onHorizontalDragStart: (details) {
                    widget.onScrubStart?.call();
                    _updateScrubFraction(context, details.localPosition);
                    _seekPreviewFromLocalPosition(
                      context,
                      details.localPosition,
                    );
                  },
                  onHorizontalDragUpdate: (details) {
                    _updateScrubFraction(context, details.localPosition);
                    _seekPreviewFromLocalPosition(
                      context,
                      details.localPosition,
                    );
                  },
                  onHorizontalDragEnd: (_) {
                    _commitPendingMainSeek();
                    _endScrub();
                    widget.onScrubEnd?.call();
                  },
                  onHorizontalDragCancel: () {
                    _pendingMainSeek = null;
                    _endScrub();
                    widget.onScrubEnd?.call();
                  },
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 12,
                        height: 28,
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(
                              key: const Key('video-progress-track'),
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.36),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: displayProgress,
                              child: Container(
                                key: const Key('video-progress-fill'),
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment(displayProgress * 2 - 1, 0),
                              child: Container(
                                key: const Key('video-progress-thumb'),
                                width: _isScrubbing ? 18 : 16,
                                height: _isScrubbing ? 18 : 16,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x66000000),
                                      blurRadius: 10,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildScrubPreview({
    required double previewLeft,
    required Duration scrubPosition,
  }) {
    final preview = _previewController;
    final previewSize = preview?.value.size ?? widget.controller.value.size;
    return Positioned(
      key: const Key('video-scrub-preview'),
      left: previewLeft,
      bottom: 74,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 88,
              height: 124,
              decoration: BoxDecoration(
                color: const Color(0xCC111111),
                border: Border.all(color: Colors.white, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox.fromSize(
                  size: previewSize,
                  child: preview != null && preview.value.isInitialized
                      ? VideoPlayer(preview)
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _ProgressBadge(
            key: const Key('video-time-label'),
            label: _formatDuration(scrubPosition),
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ],
      ),
    );
  }

  void _updateScrubFraction(BuildContext context, Offset localPosition) {
    final fraction = _fractionFromLocalPosition(context, localPosition);
    if (fraction == null) {
      return;
    }
    setState(() {
      _isScrubbing = true;
      _scrubFraction = fraction;
    });
  }

  void _endScrub() {
    if (!_isScrubbing) {
      return;
    }
    setState(() => _isScrubbing = false);
  }

  Future<void> _ensurePreviewController() async {
    if (_previewController != null && _previewUri == widget.uri) {
      return;
    }
    _disposePreviewController();
    final controller = buildVideoPlayerController(widget.uri);
    _previewController = controller;
    _previewUri = widget.uri;
    _isPreviewInitializing = true;
    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setPlaybackSpeed(1.0);
      await controller.pause();
    } catch (_) {
      if (_previewController == controller) {
        _disposePreviewController();
      }
      return;
    }
    if (!mounted || _previewController != controller) {
      return;
    }
    setState(() => _isPreviewInitializing = false);
  }

  void _disposePreviewController() {
    _previewController?.dispose();
    _previewController = null;
    _previewUri = null;
    _isPreviewInitializing = false;
  }

  double? _fractionFromLocalPosition(
    BuildContext context,
    Offset localPosition,
  ) {
    final box = context.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 0;
    if (width <= 0) {
      return null;
    }
    return (localPosition.dx / width).clamp(0.0, 1.0);
  }

  Future<void> _commitMainSeek(
    BuildContext context,
    Offset localPosition,
  ) async {
    final target = _targetFromLocalPosition(context, localPosition);
    if (target == null) {
      return;
    }
    await widget.controller.seekTo(target);
  }

  Future<void> _commitPendingMainSeek() async {
    final target = _pendingMainSeek;
    _pendingMainSeek = null;
    if (target == null) {
      return;
    }
    await widget.controller.seekTo(target);
  }

  Future<void> _seekPreviewFromLocalPosition(
    BuildContext context,
    Offset localPosition,
  ) async {
    final target = _targetFromLocalPosition(context, localPosition);
    if (target == null) {
      return;
    }
    _pendingMainSeek = target;
    await _ensurePreviewController();
    final preview = _previewController;
    if (preview == null || _isPreviewInitializing) {
      return;
    }
    await preview.seekTo(target);
    await preview.pause();
  }

  Duration? _targetFromLocalPosition(
    BuildContext context,
    Offset localPosition,
  ) {
    final fraction = _fractionFromLocalPosition(context, localPosition);
    final duration = widget.value.duration;
    if (fraction == null || duration.inMilliseconds <= 0) {
      return null;
    }
    return Duration(milliseconds: (duration.inMilliseconds * fraction).round());
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({
    super.key,
    required this.label,
    this.fontWeight = FontWeight.w600,
    this.fontSize = 12,
  });

  final String label;
  final FontWeight fontWeight;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x99000000),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
