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
    this.showOverlayControls = true,
    this.enableLongPressBoost = true,
    this.onScrubStart,
    this.onScrubEnd,
  });

  final String uri;
  final ImageProvider<Object>? thumbnailProvider;
  final VideoPlayerController? preloadedController;
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
        oldWidget.preloadedController == widget.preloadedController) {
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
              if (widget.showOverlayControls && !controller.value.isPlaying)
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
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: controller,
                      builder: (context, value, _) {
                        return Row(
                          key: const Key('video-overlay-row'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildOverlayBadge(
                              key: const Key('video-time-label'),
                              label:
                                  '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                            ),
                            if (_isBoosting) ...[
                              const SizedBox(width: 8),
                              _buildOverlayBadge(
                                key: const Key('video-speed-label'),
                                label: '2x',
                                fontWeight: FontWeight.w700,
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
              if (widget.showOverlayControls)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 74,
                  child: ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: controller,
                    builder: (context, value, _) {
                      return _VideoProgressBar(
                        controller: controller,
                        value: value,
                        onScrubStart: widget.onScrubStart,
                        onScrubEnd: widget.onScrubEnd,
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

  Widget _buildOverlayBadge({
    required Key key,
    required String label,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x99000000),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: fontWeight,
        ),
      ),
    );
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
      await controller.pause();
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

class _VideoProgressBar extends StatelessWidget {
  const _VideoProgressBar({
    required this.controller,
    required this.value,
    required this.onScrubStart,
    required this.onScrubEnd,
  });

  final VideoPlayerController controller;
  final VideoPlayerValue value;
  final VoidCallback? onScrubStart;
  final VoidCallback? onScrubEnd;

  @override
  Widget build(BuildContext context) {
    final duration = value.duration;
    final progress = duration.inMilliseconds <= 0
        ? 0.0
        : (value.position.inMilliseconds / duration.inMilliseconds).clamp(
            0.0,
            1.0,
          );
    return GestureDetector(
      key: const Key('video-progress-bar'),
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) =>
          _seekFromLocalPosition(context, details.localPosition),
      onTap: () {},
      onHorizontalDragStart: (details) {
        onScrubStart?.call();
        _seekFromLocalPosition(context, details.localPosition);
      },
      onHorizontalDragUpdate: (details) =>
          _seekFromLocalPosition(context, details.localPosition),
      onHorizontalDragEnd: (_) => onScrubEnd?.call(),
      onHorizontalDragCancel: () => onScrubEnd?.call(),
      child: Container(
        key: const Key('video-progress-gradient'),
        height: 74,
        padding: const EdgeInsets.fromLTRB(18, 34, 18, 12),
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
        child: Center(
          child: SizedBox(
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
                  widthFactor: progress,
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
                  alignment: Alignment(progress * 2 - 1, 0),
                  child: Container(
                    width: 16,
                    height: 16,
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
        ),
      ),
    );
  }

  Future<void> _seekFromLocalPosition(
    BuildContext context,
    Offset localPosition,
  ) async {
    final box = context.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 0;
    final duration = value.duration;
    if (width <= 0 || duration.inMilliseconds <= 0) {
      return;
    }
    final fraction = (localPosition.dx / width).clamp(0.0, 1.0);
    final target = Duration(
      milliseconds: (duration.inMilliseconds * fraction).round(),
    );
    await controller.seekTo(target);
  }
}
