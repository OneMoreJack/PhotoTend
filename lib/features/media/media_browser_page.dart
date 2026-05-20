import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rephoto/data/macos/folder_import_repository.dart';
import 'package:rephoto/data/mobile/mobile_media_repository.dart';
import 'package:rephoto/data/mobile/mobile_permissions_service.dart';
import 'package:rephoto/domain/models/media_item.dart';
import 'package:rephoto/domain/services/permanent_delete_service.dart';
import 'package:rephoto/features/home/home_controller.dart';
import 'package:rephoto/features/media/widgets/media_thumbnail_strip.dart';
import 'package:rephoto/features/media/widgets/video_tile.dart';
import 'package:rephoto/features/settings/settings_page.dart';
import 'package:rephoto/features/trash/trash_page.dart';
import 'package:rephoto/theme/huashu_theme.dart';
import 'package:video_player/video_player.dart';

class MediaBrowserPage extends StatefulWidget {
  const MediaBrowserPage({
    super.key,
    this.controller,
    this.deleteService,
    this.pickDirectoryPath,
    this.scanImportedDirectory,
  });

  final HomeController? controller;
  final PermanentDeleteService? deleteService;
  final Future<String?> Function()? pickDirectoryPath;
  final Future<List<MediaItem>> Function(String path)? scanImportedDirectory;

  @override
  State<MediaBrowserPage> createState() => _MediaBrowserPageState();
}

enum _DragDirection { none, horizontal, vertical }

class _ActionDivider extends StatelessWidget {
  const _ActionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 34, color: HuashuColors.line);
  }
}

class _MediaInfoRow extends StatelessWidget {
  const _MediaInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: HuashuColors.muted),
          const SizedBox(width: 12),
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: const TextStyle(
                color: HuashuColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: HuashuColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaBrowserPageState extends State<MediaBrowserPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final HomeController _controller;
  late final bool _ownsController;
  final MobilePermissionsService _permissionsService =
      MethodChannelMobilePermissionsService();
  final MobileMediaRepository _mobileMediaRepository =
      MethodChannelMobileMediaRepository();
  PermanentDeleteService? _deleteService;
  String? _mobileLibraryStatusMessage;
  bool _isImporting = false;
  bool _handledCurrentDrag = false;
  double _dragDx = 0;
  double _dragDy = 0;
  int _activePointers = 0;
  int? _primaryPointer;
  Offset? _lastPointerPosition;
  String? _lastCurrentMediaId;
  VideoPlayerController? _preloadedVideoController;
  String? _preloadedVideoUri;
  int _preloadVersion = 0;
  int _mediaLoadSession = 0;
  int _locationResolveSession = 0;
  final Map<String, double> _photoAspectRatios = <String, double>{};
  final Set<String> _aspectRatioLoadingIds = <String>{};
  final Map<String, Uint8List> _mobilePreviewBytes = <String, Uint8List>{};
  final Set<String> _mobilePreviewLoadingIds = <String>{};
  final Map<String, String> _resolvedPlayableUris = <String, String>{};
  final Set<String> _playableUriLoadingIds = <String>{};
  MediaItem? _transitionTargetMedia;
  MediaItem? _outgoingMedia;

  // ---- Gesture animation state ----
  Offset _cardOffset = Offset.zero;
  _DragDirection _dragDirection = _DragDirection.none;
  late AnimationController _flyAnimController;
  Animation<Offset>? _flyAnimation;
  bool _isFlyingOut = false;
  static const double _deleteThreshold = 100.0;
  static const double _swipeThreshold = 60.0;
  static const double _directionLockThreshold = 12.0;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        HomeController(initialMediaItems: const <MediaItem>[]);
    _deleteService = widget.deleteService;
    _lastCurrentMediaId = _controller.currentMediaId;
    _controller.addListener(_onControllerChanged);
    _flyAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _flyAnimController.addListener(_onFlyAnimTick);
    _flyAnimController.addStatusListener(_onFlyAnimStatus);
    if (_ownsController) {
      _bootstrapMobileLibrary();
    }
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _preloadUpcomingMedia(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onControllerChanged);
    _flyAnimController.removeListener(_onFlyAnimTick);
    _flyAnimController.removeStatusListener(_onFlyAnimStatus);
    _flyAnimController.dispose();
    _disposePreloadedVideoController();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _ownsController) {
      _refreshMediaLibrary();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      key: const Key('media-browser-page'),
      animation: _controller,
      builder: (context, _) {
        final currentMedia = _controller.currentMedia;
        final backgroundProvider = currentMedia?.type == MediaType.photo
            ? _buildImageProvider(
                currentMedia?.pathOrUri,
                mediaId: currentMedia?.id,
              )
            : null;
        final deleteProgress =
            _dragDirection == _DragDirection.vertical &&
                _cardOffset.dy < 0 &&
                _controller.currentMediaId != null
            ? (_cardOffset.dy.abs() / _deleteThreshold).clamp(0.0, 1.0)
            : 0.0;
        return Stack(
          children: [
            Scaffold(
              key: _scaffoldKey,
              backgroundColor: HuashuColors.paper,
              drawer: _buildSideMenu(),
              appBar: AppBar(
                backgroundColor: HuashuColors.paper,
                foregroundColor: HuashuColors.ink,
                elevation: 0,
                titleSpacing: 0,
                leading: IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back_rounded, size: 28),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                title: _buildAppBarTitle(),
                actions: [
                  IconButton(
                    onPressed: _openTrash,
                    tooltip: 'Trash',
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.delete_outline),
                        if (_controller.trashCount > 0)
                          Positioned(
                            right: -6,
                            top: -6,
                            child: Container(
                              key: const Key('trash-badge'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: const BoxDecoration(
                                color: HuashuColors.danger,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(10),
                                ),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 16,
                              ),
                              child: Text(
                                '${_controller.trashCount}',
                                key: const Key('trash-badge-text'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: HuashuColors.surface,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              body: Stack(
                children: [
                  // 1. Blurred background image
                  if (backgroundProvider != null)
                    Positioned.fill(
                      child: Image(
                        image: backgroundProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  if (currentMedia != null)
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                        child: Container(
                          color: HuashuColors.surface.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  // 2. Main content
                  Positioned.fill(
                    child: SafeArea(
                      child: Column(
                        children: [
                          if (_mobileLibraryStatusMessage != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: Text(
                                _mobileLibraryStatusMessage!,
                                key: const Key('mobile-library-status'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: HuashuColors.muted,
                                ),
                              ),
                            ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildMediaAreaWithGestures(),
                            ),
                          ),
                          _buildThumbnailStrip(),
                          _buildBottomActionBar(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 3. Delete arc overlay — renders on top of EVERYTHING
            if (deleteProgress > 0)
              _buildDeleteArcIndicator(context, deleteProgress),
          ],
        );
      },
    );
  }

  Widget _buildAppBarTitle() {
    return GestureDetector(
      onTap: () => _scaffoldKey.currentState?.openDrawer(),
      child: Tooltip(
        message: 'Menu',
        child: Text(
          _browserTitle(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: HuashuColors.ink,
            fontSize: 25,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }

  String _browserTitle() {
    final current = _controller.currentMedia;
    final createdAt = current?.createdAt;
    final activeQuery = _controller.activeCollectionQuery;
    final queryStart = activeQuery?.timeStart;
    if (createdAt == null) {
      if (activeQuery?.collectionId?.startsWith('month-') == true &&
          queryStart != null) {
        return _formatMonthTitle(queryStart);
      }
      return 'RePhoto';
    }
    return _formatMonthTitle(createdAt);
  }

  String _formatMonthTitle(DateTime value) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[value.month - 1]} ${value.year}';
  }

  Widget _buildMediaAreaWithGestures() {
    final media = _controller.currentMedia;
    final showStatusCard =
        _controller.currentMediaId == null &&
        _mobileLibraryStatusMessage != null;
    final showEndCard =
        _controller.currentMediaId == null &&
        _mobileLibraryStatusMessage == null &&
        _controller.filteredMediaIds.isNotEmpty;
    final showEmptyCard =
        _controller.currentMediaId == null &&
        _mobileLibraryStatusMessage == null &&
        _controller.filteredMediaIds.isEmpty;

    // Calculate delete progress for the trash icon overlay
    final deleteProgress =
        _dragDirection == _DragDirection.vertical &&
            _cardOffset.dy < 0 &&
            media != null
        ? (_cardOffset.dy.abs() / _deleteThreshold).clamp(0.0, 1.0)
        : 0.0;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_outgoingMedia != null)
            _buildPreviewShell(
              child: media == null
                  ? const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 80,
                      ),
                      child: CircularProgressIndicator(
                        color: HuashuColors.faint,
                      ),
                    )
                  : _buildMediaPreviewFor(media),
            )
          else if (_transitionTargetMedia != null &&
              _dragDirection == _DragDirection.horizontal)
            Align(
              key: const Key('transition-backdrop-preview'),
              alignment: Alignment.center,
              child: _buildPreviewShell(
                child: _buildMediaPreviewFor(
                  _transitionTargetMedia!,
                  interactive: false,
                ),
              ),
            ),
          Transform.translate(
            offset: _cardOffset,
            child: Transform.rotate(
              angle: _dragDirection == _DragDirection.horizontal
                  ? _cardOffset.dx * 0.0003
                  : 0.0,
              child: Opacity(
                opacity:
                    _dragDirection == _DragDirection.vertical &&
                        _cardOffset.dy < 0
                    ? (1.0 - deleteProgress * 0.3).clamp(0.7, 1.0)
                    : 1.0,
                child: _outgoingMedia == null
                    ? showStatusCard
                          ? _buildStatusPreview(_mobileLibraryStatusMessage!)
                          : showEndCard
                          ? _buildEndStatusPreview()
                          : showEmptyCard
                          ? _buildStatusPreview('当前条件下暂无可显示的照片')
                          : _buildPreviewShell(
                              deleteProgress: deleteProgress,
                              child: media == null
                                  ? const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 48,
                                        vertical: 80,
                                      ),
                                      child: CircularProgressIndicator(
                                        color: HuashuColors.faint,
                                      ),
                                    )
                                  : _buildMediaPreviewFor(media),
                            )
                    : KeyedSubtree(
                        key: const Key('outgoing-media-preview'),
                        child: _buildPreviewShell(
                          child: _buildMediaPreviewFor(
                            _outgoingMedia!,
                            interactive: false,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewShell({
    required Widget child,
    double deleteProgress = 0,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        return Align(
          alignment: Alignment.center,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width,
              maxHeight: maxHeight,
            ),
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                child,
                if (deleteProgress > 0)
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: HuashuColors.danger.withValues(
                          alpha: 0.08 * deleteProgress,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusPreview(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: HuashuColors.muted),
        ),
      ),
    );
  }

  /// Builds a delete arc indicator that peeks from the very top of the screen.
  /// Uses a CustomPainter to guarantee a beautiful curve that always accounts for the
  /// status bar height, ensuring the icon is visible and appropriately sized.
  Widget _buildDeleteArcIndicator(BuildContext context, double progress) {
    // 1. Account for status bar / notch height.
    final safeTop = MediaQuery.paddingOf(context).top;

    // 2. Calculate dynamic visible height of the arc below the status bar.
    //    Starts slightly visible (30px), grows to 100px.
    final arcHeight = 30.0 + 70.0 * progress;
    final totalHeight = safeTop + arcHeight;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: SizedBox(
          height: totalHeight,
          child: CustomPaint(
            painter: _TopArcPainter(
              color: HuashuColors.danger.withValues(
                alpha: (0.65 + 0.35 * progress).clamp(0.0, 1.0),
              ),
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                // Position the icon near the bottom edge of the arc
                padding: const EdgeInsets.only(bottom: 12),
                child: Opacity(
                  // Fade in icon early
                  opacity: (progress * 2.5).clamp(0.0, 1.0),
                  child: Icon(
                    Icons.delete_rounded,
                    size: 28 + 10 * progress, // Icon gets larger as you wipe
                    color: HuashuColors.surface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(58, 6, 58, 14),
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: HuashuColors.surface.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: HuashuColors.line),
              boxShadow: [
                BoxShadow(
                  color: HuashuColors.ink.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildBottomActionIcon(
                    key: const Key('browse-mode-btn'),
                    icon: _controller.browseMode == BrowseMode.random
                        ? Icons.shuffle_rounded
                        : Icons.format_list_numbered_rounded,
                    active: _controller.browseMode == BrowseMode.sequential,
                    onTap: _toggleBrowseMode,
                  ),
                ),
                const _ActionDivider(),
                Expanded(
                  child: _buildBottomActionIcon(
                    key: const Key('video-only-btn'),
                    icon: Icons.movie_creation_outlined,
                    active: _controller.videoOnlyEnabled,
                    onTap: _toggleVideoOnlyMode,
                  ),
                ),
                const _ActionDivider(),
                Expanded(
                  child: _buildBottomActionIcon(
                    key: const Key('browser-more-btn'),
                    icon: Icons.share_outlined,
                    active: false,
                    onTap: _handleShareButton,
                  ),
                ),
                const _ActionDivider(),
                Expanded(
                  child: _buildBottomActionIcon(
                    key: const Key('browser-info-btn'),
                    icon: Icons.info_outline_rounded,
                    active: false,
                    onTap: _showMediaInfoSheet,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBrowserMoreMenu() {
    final canOpenGallery = _controller.currentMedia?.pathOrUri != null;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  key: const Key('open-in-gallery-btn'),
                  enabled: canOpenGallery,
                  leading: const Icon(Icons.ios_share_rounded),
                  title: const Text('Open in gallery'),
                  onTap: canOpenGallery
                      ? () {
                          Navigator.of(sheetContext).pop();
                          _openInGallery();
                        }
                      : null,
                ),
                if (_shouldShowImportFolderAction)
                  ListTile(
                    key: const Key('import-folder-btn'),
                    enabled: !_isImporting,
                    leading: const Icon(Icons.folder_open_outlined),
                    title: const Text('Import Folder'),
                    onTap: _isImporting
                        ? null
                        : () {
                            Navigator.of(sheetContext).pop();
                            unawaited(_importFolder());
                          },
                  ),
                ListTile(
                  key: const Key('browser-settings-btn'),
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Settings'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    unawaited(_openSettings());
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleShareButton() {
    final pathOrUri = _controller.currentMedia?.pathOrUri;
    if (pathOrUri == null || pathOrUri.isEmpty) {
      _showBrowserMoreMenu();
      return;
    }
    _showShareSheet(pathOrUri);
  }

  void _showMediaInfoSheet() {
    final media = _controller.currentMedia;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            key: const Key('media-info-sheet'),
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
            child: media == null
                ? const Text(
                    '暂无照片信息',
                    style: TextStyle(
                      color: HuashuColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '照片信息',
                        style: TextStyle(
                          color: HuashuColors.ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _MediaInfoRow(
                        icon: Icons.calendar_today_outlined,
                        label: '日期',
                        value: media.createdAt == null
                            ? '未知'
                            : _formatDate(media.createdAt!),
                      ),
                      _MediaInfoRow(
                        icon: Icons.phone_iphone_rounded,
                        label: '设备',
                        value: _controller.currentDeviceModel ?? '未知',
                      ),
                      _MediaInfoRow(
                        icon: Icons.place_outlined,
                        label: '地点',
                        value: _readableLocation(media.locationKey) ?? '未知',
                      ),
                      _MediaInfoRow(
                        icon: media.type == MediaType.video
                            ? Icons.movie_creation_outlined
                            : Icons.photo_outlined,
                        label: '类型',
                        value: media.type == MediaType.video ? '视频' : '照片',
                      ),
                      _MediaInfoRow(
                        icon: Icons.sd_storage_outlined,
                        label: '大小',
                        value: _formatMediaSize(media.sizeBytes),
                      ),
                      if (media.pathOrUri != null &&
                          media.pathOrUri!.isNotEmpty)
                        _MediaInfoRow(
                          icon: Icons.link_rounded,
                          label: '路径',
                          value: media.pathOrUri!,
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildThumbnailStrip() {
    final mediaById = {
      for (final item in _controller.mediaItemsByIds(
        _controller.filteredMediaIds.toSet(),
      ))
        item.id: item,
    };
    final items = _controller.filteredMediaIds
        .where((id) => !_controller.trashIds.contains(id))
        .map((id) => mediaById[id])
        .whereType<MediaItem>()
        .toList(growable: false);
    return MediaThumbnailStrip(
      items: items,
      currentMediaId: _controller.currentMediaId,
      onTap: _controller.jumpToMedia,
      thumbnailBuilder: _buildThumbnailTile,
    );
  }

  Widget _buildThumbnailTile(
    BuildContext context,
    MediaItem item,
    bool selected,
  ) {
    unawaited(_ensureMobilePreviewBytes(item));
    final provider = item.type == MediaType.video
        ? _buildVideoThumbnailProvider(item)
        : _buildImageProvider(item.pathOrUri, mediaId: item.id);
    final content = provider == null
        ? _buildThumbnailPlaceholder(item, loading: true)
        : Image(
            image: provider,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildThumbnailPlaceholder(item),
          );
    if (item.type != MediaType.video) {
      return content;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        const Center(
          child: Icon(
            Icons.play_circle_fill_rounded,
            color: HuashuColors.surface,
            size: 22,
          ),
        ),
      ],
    );
  }

  ImageProvider<Object>? _buildVideoThumbnailProvider(MediaItem item) {
    final bytes = _mobilePreviewBytes[item.id];
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    return MemoryImage(bytes);
  }

  Widget _buildThumbnailPlaceholder(MediaItem item, {bool loading = false}) {
    final icon = item.type == MediaType.video
        ? Icons.movie_creation_outlined
        : Icons.photo_outlined;
    if (item.type == MediaType.video) {
      return DecoratedBox(
        key: loading ? Key('media-thumbnail-loading-${item.id}') : null,
        decoration: const BoxDecoration(color: HuashuColors.darkroomSoft),
        child: Center(
          child: Icon(
            icon,
            color: HuashuColors.surface.withValues(alpha: 0.54),
            size: 18,
          ),
        ),
      );
    }
    return Container(
      key: loading ? Key('media-thumbnail-loading-${item.id}') : null,
      color: HuashuColors.surfaceAlt,
      child: Center(child: Icon(icon, color: HuashuColors.muted, size: 20)),
    );
  }

  Widget _buildBottomActionIcon({
    required Key key,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    final color = active ? HuashuColors.accent : HuashuColors.inkSoft;
    return InkWell(
      key: key,
      onTap: onTap,
      child: SizedBox.expand(child: Icon(icon, size: 34, color: color)),
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_controller.currentMediaId == null) return;
    if (_isFlyingOut) return;
    _activePointers += 1;
    if (_activePointers == 1) {
      _primaryPointer = event.pointer;
      _lastPointerPosition = event.position;
      _flyAnimController.stop();
      _resetPanState();
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_controller.currentMediaId == null) return;
    if (_isFlyingOut) return;
    if (_activePointers != 1 ||
        _primaryPointer != event.pointer ||
        _handledCurrentDrag) {
      _lastPointerPosition = event.position;
      return;
    }
    final last = _lastPointerPosition;
    _lastPointerPosition = event.position;
    if (last == null) return;

    final delta = event.position - last;
    _dragDx += delta.dx;
    _dragDy += delta.dy;

    // Lock direction after initial movement
    if (_dragDirection == _DragDirection.none) {
      if (_dragDx.abs() > _directionLockThreshold ||
          _dragDy.abs() > _directionLockThreshold) {
        _dragDirection = _dragDx.abs() > _dragDy.abs()
            ? _DragDirection.horizontal
            : _DragDirection.vertical;
        if (_dragDirection == _DragDirection.horizontal) {
          _setTransitionTargetForHorizontalDrag(_dragDx);
        } else {
          _transitionTargetMedia = null;
        }
      } else {
        return; // Not enough movement yet to determine direction
      }
    }

    // Update card offset based on locked direction
    setState(() {
      if (_dragDirection == _DragDirection.horizontal) {
        _cardOffset = Offset(_dragDx, 0);
      } else {
        // Only allow upward drag (negative dy), or small downward for undo feel
        _cardOffset = Offset(0, _dragDy);
      }
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_controller.currentMediaId == null) return;
    if (_activePointers > 0) _activePointers -= 1;
    if (_primaryPointer != event.pointer) return;
    _primaryPointer = null;
    _lastPointerPosition = null;

    if (_isFlyingOut) return;
    if (_handledCurrentDrag) {
      _startSnapBack();
      return;
    }

    final dir = _dragDirection;
    final offset = _cardOffset;

    if (dir == _DragDirection.vertical && offset.dy < -_deleteThreshold) {
      if (_controller.currentMediaId == null) {
        _startSnapBack();
      } else {
        // Commit swipe-up delete: fly card out upward
        _startFlyOut(Offset(0, -MediaQuery.of(context).size.height), () {
          _controller.onSwipeUpDelete();
        });
      }
    } else if (dir == _DragDirection.vertical && offset.dy > _deleteThreshold) {
      // Swipe down → undo delete, snap back
      _controller.onSwipeDownUndoDelete();
      _startSnapBack();
    } else if (dir == _DragDirection.horizontal &&
        offset.dx < -_swipeThreshold) {
      if (_controller.currentMediaId == null) {
        _startSnapBack();
      } else {
        _startHorizontalFlyOut(
          Offset(-MediaQuery.of(context).size.width, 0),
          _controller.onSwipeLeftRandom,
        );
      }
    } else if (dir == _DragDirection.horizontal &&
        offset.dx > _swipeThreshold) {
      _startHorizontalFlyOut(
        Offset(MediaQuery.of(context).size.width, 0),
        _controller.onSwipeRightPrevious,
      );
    } else {
      // Not enough → snap back
      _startSnapBack();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_controller.currentMediaId == null) return;
    if (_activePointers > 0) _activePointers -= 1;
    if (_primaryPointer == event.pointer) {
      _primaryPointer = null;
      _lastPointerPosition = null;
      if (!_isFlyingOut) _startSnapBack();
    }
  }

  void _resetPanState() {
    _handledCurrentDrag = false;
    _dragDx = 0;
    _dragDy = 0;
    _dragDirection = _DragDirection.none;
    _transitionTargetMedia = null;
    _outgoingMedia = null;
  }

  void _handleVideoScrubStart() {
    _handledCurrentDrag = true;
    _dragDx = 0;
    _dragDy = 0;
    _dragDirection = _DragDirection.none;
    _transitionTargetMedia = null;
    _outgoingMedia = null;
    if (_cardOffset != Offset.zero && mounted) {
      setState(() => _cardOffset = Offset.zero);
    }
  }

  void _setTransitionTargetForHorizontalDrag(double dragDx) {
    final target = dragDx < 0
        ? _controller.prepareUpcomingMediaForPreload()
        : _controller.preparePreviousMediaForPreload();
    _transitionTargetMedia = target;
    if (target != null) {
      unawaited(
        _warmUpcomingMedia(
          target,
          version: ++_preloadVersion,
          initializeVideoController: true,
        ),
      );
    }
  }

  // ---- Fly-out and snap-back animations ----
  VoidCallback? _flyOutCallback;

  void _startHorizontalFlyOut(Offset target, VoidCallback switchCurrent) {
    final outgoing = _controller.currentMedia;
    if (outgoing == null) {
      _startSnapBack();
      return;
    }
    _outgoingMedia = outgoing;
    _transitionTargetMedia = null;
    switchCurrent();
    _startFlyOut(target, () {});
  }

  void _startFlyOut(Offset target, VoidCallback onComplete) {
    _isFlyingOut = true;
    _flyOutCallback = onComplete;
    _flyAnimation = Tween<Offset>(begin: _cardOffset, end: target).animate(
      CurvedAnimation(parent: _flyAnimController, curve: Curves.easeInCubic),
    );
    _flyAnimController.duration = const Duration(milliseconds: 180);
    _flyAnimController.forward(from: 0);
  }

  void _startSnapBack() {
    _isFlyingOut = false;
    _flyOutCallback = null;
    _flyAnimation = Tween<Offset>(begin: _cardOffset, end: Offset.zero).animate(
      CurvedAnimation(parent: _flyAnimController, curve: Curves.easeOutQuart),
    );
    _flyAnimController.duration = const Duration(milliseconds: 350);
    _flyAnimController.forward(from: 0);
  }

  void _onFlyAnimTick() {
    if (_flyAnimation != null) {
      setState(() {
        _cardOffset = _flyAnimation!.value;
      });
    }
  }

  void _onFlyAnimStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (_isFlyingOut && _flyOutCallback != null) {
        _flyOutCallback!();
        _flyOutCallback = null;
      }
      setState(() {
        _cardOffset = Offset.zero;
        _isFlyingOut = false;
        _flyAnimation = null;
        _dragDirection = _DragDirection.none;
        _outgoingMedia = null;
      });
      _resetPanState();
    }
  }

  void _onControllerChanged() {
    final current = _controller.currentMediaId;
    if (current != _lastCurrentMediaId) {
      _lastCurrentMediaId = current;
      _loadCurrentMediaMetadata();
      final currentMedia = _controller.currentMedia;
      if (currentMedia != null) {
        unawaited(_ensureMobilePreviewBytes(currentMedia));
        unawaited(_ensurePlayableMediaUri(currentMedia));
        unawaited(_ensurePhotoAspectRatio(currentMedia));
      }
    }

    _preloadUpcomingMedia();
  }

  Widget _buildEndStatusPreview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: HuashuColors.positive.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.done_all_rounded,
                    size: 48,
                    color: HuashuColors.positive,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  '当前月份已经浏览完毕',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: HuashuColors.ink,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '这个月的照片和视频都看完了',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: HuashuColors.muted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),
                ElevatedButton.icon(
                  key: const Key('end-replay-button'),
                  onPressed: () => _controller.resetRandomPool(),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text(
                    '再看一遍',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HuashuColors.ink,
                    foregroundColor: HuashuColors.surface,
                    elevation: 4,
                    shadowColor: HuashuColors.faint,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Drawer _buildSideMenu() {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            color: HuashuColors.surface.withValues(alpha: 0.72),
            child: SafeArea(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const ListTile(
                    title: Text(
                      'RePhoto',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: HuashuColors.ink,
                      ),
                    ),
                  ),
                  Divider(color: HuashuColors.ink.withValues(alpha: 0.1)),
                  ListTile(
                    leading: const Icon(Icons.shuffle, color: HuashuColors.ink),
                    title: const Text(
                      'Reset Random Pool',
                      style: TextStyle(color: HuashuColors.ink),
                    ),
                    subtitle: const Text(
                      'Start a new random round for remaining media',
                      style: TextStyle(color: HuashuColors.muted),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _controller.resetRandomPool();
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.settings,
                      color: HuashuColors.ink,
                    ),
                    title: const Text(
                      'Settings',
                      style: TextStyle(color: HuashuColors.ink),
                    ),
                    onTap: _openSettingsFromDrawer,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openSettingsFromDrawer() async {
    Navigator.of(context).pop();
    await _openSettings();
  }

  Future<void> _openSettings() async {
    final action = await Navigator.of(context).push<SettingsAction>(
      MaterialPageRoute(
        builder: (_) => SettingsPage(deletionStats: _controller.deletionStats),
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    if (action == SettingsAction.resetRandomPool) {
      _controller.resetRandomPool();
    }
  }

  Future<void> _openTrash() async {
    final result = await Navigator.of(context).push<TrashPageResult>(
      MaterialPageRoute(
        builder: (_) => TrashPage(
          initialIds: _controller.orderedTrashIds,
          initialMediaItems: _controller.mediaItemsByIds(_controller.trashIds),
          deleteService: _deleteService,
        ),
      ),
    );
    if (result != null) {
      _controller.recordPermanentDeletionStats(result.permanentlyDeletedIds);
      _controller.updateTrash(result.trashIds);
      _controller.removeMediaItems(result.permanentlyDeletedIds);
    }
  }

  void _openInGallery() {
    final media = _controller.currentMedia;
    if (media == null || media.pathOrUri == null) return;

    // iOS: UIActivityViewController already shows fine-grained targets
    if (Platform.isIOS || Platform.isMacOS) {
      try {
        _mobileMediaRepository.openInGallery(media.pathOrUri!);
      } catch (_) {}
      return;
    }

    // Android: show custom share sheet
    _showShareSheet(media.pathOrUri!);
  }

  void _showShareSheet(String pathOrUri) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '分享到',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _shareTarget(
                      icon: Icons.chat_bubble,
                      color: const Color(0xFF07C160),
                      label: '微信',
                      onTap: () {
                        Navigator.pop(ctx);
                        _shareToApp(
                          pathOrUri,
                          'com.tencent.mm',
                          'com.tencent.mm.ui.tools.ShareImgUI',
                        );
                      },
                    ),
                    _shareTarget(
                      icon: Icons.camera_alt,
                      color: const Color(0xFF07C160),
                      label: '朋友圈',
                      onTap: () {
                        Navigator.pop(ctx);
                        _shareToApp(
                          pathOrUri,
                          'com.tencent.mm',
                          'com.tencent.mm.ui.tools.ShareToTimeLineUI',
                        );
                      },
                    ),
                    _shareTarget(
                      icon: Icons.message,
                      color: const Color(0xFF12B7F5),
                      label: 'QQ',
                      onTap: () {
                        Navigator.pop(ctx);
                        _shareToApp(pathOrUri, 'com.tencent.mobileqq', null);
                      },
                    ),
                    _shareTarget(
                      icon: Icons.more_horiz,
                      color: Colors.grey.shade600,
                      label: '更多',
                      onTap: () {
                        Navigator.pop(ctx);
                        try {
                          _mobileMediaRepository.openInGallery(pathOrUri);
                        } catch (_) {}
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _shareTarget({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: HuashuColors.muted),
          ),
        ],
      ),
    );
  }

  void _shareToApp(String pathOrUri, String package, String? activity) {
    try {
      _mobileMediaRepository.shareToTarget(pathOrUri, package, activity);
    } catch (_) {
      // Fallback to system share if anything goes wrong
      try {
        _mobileMediaRepository.openInGallery(pathOrUri);
      } catch (_) {}
    }
  }

  void _toggleVideoOnlyMode() {
    _controller.toggleVideoOnlyMode();
  }

  void _toggleBrowseMode() {
    _controller.toggleBrowseMode();
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatMediaSize(int? bytes) {
    if (bytes == null || bytes <= 0) {
      return '未知';
    }
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex += 1;
    }
    final formatted = value >= 10 || unitIndex == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$formatted ${units[unitIndex]}';
  }

  String? _readableLocation(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    if (value.startsWith('geo/')) {
      final segments = value.split('/');
      if (segments.length >= 3) {
        return '${segments[1]}, ${segments[2]}';
      }
      return value;
    }
    final segments = value
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.length >= 4) {
      return '${segments[2]} · ${segments[3]}';
    }
    if (segments.length >= 3) {
      return '${segments[1]} · ${segments[2]}';
    }
    if (segments.length == 2) {
      return segments[1];
    }
    return segments.isEmpty ? value : segments.first;
  }

  Future<void> _bootstrapMobileLibrary() async {
    final session = ++_mediaLoadSession;
    if (mounted) {
      setState(() => _mobileLibraryStatusMessage = 'Loading device media...');
    }
    try {
      final permission = await _permissionsService.requestMediaReadPermission();
      if (!mounted || session != _mediaLoadSession) return;
      if (permission == MediaPermissionStatus.denied) {
        _deleteService = null;
        if (mounted) {
          setState(() {
            _mobileLibraryStatusMessage =
                'Media permission denied. Please allow photos/videos in system settings.';
          });
        }
        return;
      }
      _deleteService = PermanentDeleteService.real(
        deleteExecutor: _mobileMediaRepository.permanentDelete,
      );
      const initialPageSize = 60;
      final items = await _mobileMediaRepository.fetchMediaPage(
        offset: 0,
        limit: initialPageSize,
      );
      if (!mounted) {
        return;
      }
      if (session != _mediaLoadSession) return;
      final validItems = items
          .where((item) => item.pathOrUri != null && item.pathOrUri!.isNotEmpty)
          .toList();
      if (validItems.isEmpty) {
        setState(() {
          _mobileLibraryStatusMessage = 'No media returned from system album.';
        });
        return;
      }
      _controller.replaceMediaItems(validItems);
      setState(() => _mobileLibraryStatusMessage = null);

      // Prioritize loading metadata for the immediately visible item
      _loadCurrentMediaMetadata();
      _loadExifForNewItems(validItems);
      _locationResolveSession += 1;
      _scheduleBackgroundLocationResolve(
        validItems,
        prioritizeCount: 40,
        session: _locationResolveSession,
      );
      _loadRemainingMediaInBackground(
        session: session,
        startOffset: items.length,
      );
    } on MissingPluginException {
      if (mounted) {
        setState(() => _mobileLibraryStatusMessage = null);
      }
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() {
          _mobileLibraryStatusMessage =
              'Failed to read device media: ${error.code}';
        });
      }
    }
  }

  Future<void> _loadRemainingMediaInBackground({
    required int session,
    required int startOffset,
  }) async {
    const pageSize = 300;
    var offset = startOffset;
    while (mounted && session == _mediaLoadSession) {
      final page = await _mobileMediaRepository.fetchMediaPage(
        offset: offset,
        limit: pageSize,
      );
      if (!mounted || session != _mediaLoadSession || page.isEmpty) {
        return;
      }
      final validItems = page
          .where((item) => item.pathOrUri != null && item.pathOrUri!.isNotEmpty)
          .toList();
      if (validItems.isNotEmpty) {
        _controller.addMediaItems(validItems);
        _loadExifForNewItems(validItems);
        _scheduleBackgroundLocationResolve(
          validItems,
          prioritizeCount: 0,
          session: _locationResolveSession,
        );
      }
      offset += page.length;
      if (page.length < pageSize) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  /// Refresh media library when app resumes from background to pick up new photos.
  Future<void> _refreshMediaLibrary() async {
    try {
      final items = await _mobileMediaRepository.fetchMediaPage(
        offset: 0,
        limit: 300,
      );
      if (!mounted || items.isEmpty) return;
      final validItems = items
          .where((item) => item.pathOrUri != null && item.pathOrUri!.isNotEmpty)
          .toList();
      if (validItems.isEmpty) return;
      _controller.addMediaItems(validItems);
      // Load EXIF for any new items in background
      _loadExifForNewItems(validItems);
    } catch (_) {
      // Best-effort refresh
    }
  }

  /// Load EXIF device models for items not yet in the cache.
  Future<void> _loadExifForNewItems(List<MediaItem> items) async {
    final uncached = items.where((item) {
      final id = item.id;
      return !_controller.hasDeviceModelCached(id);
    }).toList();
    if (uncached.isEmpty) return;
    const batchSize = 50;
    for (var i = 0; i < uncached.length; i += batchSize) {
      if (!mounted) return;
      final end = (i + batchSize).clamp(0, uncached.length);
      final batch = uncached.sublist(i, end);
      try {
        final models = await _mobileMediaRepository.batchGetDeviceModels(batch);
        if (!mounted) return;
        _controller.updateDeviceModelCache(models);
        if (mounted) setState(() {});
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<void> _loadLocationKeysProgressively(
    List<MediaItem> items, {
    required int prioritizeCount,
    required int session,
  }) async {
    final candidates = items
        .where(
          (item) =>
              item.pathOrUri != null &&
              item.pathOrUri!.isNotEmpty &&
              (item.locationKey == null || item.locationKey!.isEmpty),
        )
        .toList();
    if (candidates.isEmpty) return;
    final firstBatchSize = prioritizeCount.clamp(0, candidates.length);
    if (firstBatchSize > 0) {
      await _resolveLocationBatch(
        candidates.sublist(0, firstBatchSize),
        session,
      );
    }
    if (firstBatchSize >= candidates.length) return;
    const batchSize = 50;
    for (var i = firstBatchSize; i < candidates.length; i += batchSize) {
      if (!mounted || session != _locationResolveSession) return;
      final end = (i + batchSize).clamp(0, candidates.length);
      await _resolveLocationBatch(candidates.sublist(i, end), session);
      await Future<void>.delayed(const Duration(milliseconds: 24));
    }
  }

  void _scheduleBackgroundLocationResolve(
    List<MediaItem> items, {
    required int prioritizeCount,
    required int session,
  }) {
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 1800), () async {
        if (!mounted || session != _locationResolveSession) return;
        await _loadLocationKeysProgressively(
          items,
          prioritizeCount: prioritizeCount,
          session: session,
        );
      }),
    );
  }

  Future<void> _resolveLocationBatch(List<MediaItem> batch, int session) async {
    if (batch.isEmpty || !mounted || session != _locationResolveSession) return;
    try {
      final keys = await _mobileMediaRepository.batchGetLocationKeys(batch);
      if (!mounted || session != _locationResolveSession || keys.isEmpty) {
        return;
      }
      _controller.updateMediaLocationKeys(keys);
    } catch (_) {}
  }

  Future<void> _importFolder() async {
    if (_isImporting) {
      return;
    }
    setState(() => _isImporting = true);
    try {
      final pick = widget.pickDirectoryPath ?? getDirectoryPath;
      final path = await pick();
      if (!mounted || path == null || path.isEmpty) {
        return;
      }

      final scanner =
          widget.scanImportedDirectory ?? _defaultScanImportedDirectory;
      final items = await scanner(path);
      if (!mounted || items.isEmpty) {
        return;
      }
      _deleteService = PermanentDeleteService.real(
        deleteExecutor: _deleteImportedFiles,
      );
      _controller.replaceMediaItems(items);
    } on MissingPluginException {
      // Desktop plugin unavailable in host; no-op.
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<List<MediaItem>> _defaultScanImportedDirectory(String path) async {
    final repo = MacosFolderImportRepository(rootDirectory: path);
    return repo.scanMediaItems();
  }

  bool get _shouldShowImportFolderAction {
    if (widget.pickDirectoryPath != null ||
        widget.scanImportedDirectory != null) {
      return true;
    }
    return Platform.isMacOS;
  }

  Future<void> _deleteImportedFiles(Set<String> ids) async {
    for (final id in ids) {
      final file = File(id);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Widget _buildMediaPreviewFor(MediaItem media, {bool interactive = true}) {
    final playableLivePhotoUri = media.livePhotoVideoUri;
    if (playableLivePhotoUri != null && playableLivePhotoUri.isNotEmpty) {
      unawaited(_ensureMobilePreviewBytes(media));
      unawaited(
        _ensurePlayableMediaUri(media, sourceUri: playableLivePhotoUri),
      );
      final thumbnailProvider = _buildImageProvider(
        media.pathOrUri,
        mediaId: media.id,
      );
      final playableUri = _resolvedPlayableUris[playableLivePhotoUri];
      final requiresResolution = playableLivePhotoUri.startsWith('phlive://');
      if (requiresResolution && playableUri == null) {
        return _buildVideoPlaceholder(thumbnailProvider);
      }
      final videoTile = VideoTile(
        uri: playableUri ?? playableLivePhotoUri,
        thumbnailProvider: thumbnailProvider,
        preloadedController: _takePreloadedController(
          playableUri ?? playableLivePhotoUri,
        ),
        onScrubStart: interactive ? _handleVideoScrubStart : null,
        showOverlayControls: interactive,
        enableLongPressBoost: interactive,
      );
      if (!interactive) {
        return _buildVideoPlaceholder(thumbnailProvider);
      }
      return InteractiveViewer(
        key: ValueKey<String>('zoom-${media.id}'),
        minScale: 1,
        maxScale: 4,
        panEnabled: false,
        child: videoTile,
      );
    }

    if (media.type == MediaType.video && media.pathOrUri != null) {
      unawaited(_ensureMobilePreviewBytes(media));
      unawaited(_ensurePlayableMediaUri(media));
      final thumbnailProvider = _buildImageProvider(
        media.pathOrUri,
        mediaId: media.id,
      );
      final playableUri = _resolvedPlayableUris[media.id];
      if (_isPhAssetUri(media.pathOrUri!) && playableUri == null) {
        return _buildVideoPlaceholder(thumbnailProvider);
      }
      if (!interactive) {
        return _buildVideoPlaceholder(thumbnailProvider);
      }
      final videoTile = VideoTile(
        uri: playableUri ?? media.pathOrUri!,
        thumbnailProvider: thumbnailProvider,
        preloadedController: _takePreloadedController(
          playableUri ?? media.pathOrUri!,
        ),
        onScrubStart: _handleVideoScrubStart,
      );
      return InteractiveViewer(
        key: ValueKey<String>('zoom-${media.id}'),
        minScale: 1,
        maxScale: 4,
        panEnabled: false,
        child: videoTile,
      );
    }

    unawaited(_ensureMobilePreviewBytes(media));
    final provider = _buildImageProvider(
      media.pathOrUri,
      mediaId: media.id,
      preferOriginalFile: true,
    );
    if (media.type == MediaType.photo && provider != null) {
      unawaited(_ensurePhotoAspectRatio(media));
      final aspectRatio = _photoAspectRatios[media.id] ?? 3 / 4;
      final photoPreview = LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final maxHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height * 0.62;
          var width = maxWidth;
          var height = width / aspectRatio;
          if (height > maxHeight) {
            height = maxHeight;
            width = height * aspectRatio;
          }
          return SizedBox(
            key: const Key('current-media-preview'),
            width: width,
            height: height,
            child: Image(
              image: provider,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded) return child;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: frame != null
                      ? child
                      : Center(
                          child: Padding(
                            padding: EdgeInsets.all(48),
                            child: CircularProgressIndicator(
                              color: Color(0x1A171A1C),
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                );
              },
              errorBuilder: (_, __, ___) => _buildPlaceholderCard(),
            ),
          );
        },
      );
      if (!interactive) {
        return photoPreview;
      }
      return InteractiveViewer(
        key: ValueKey<String>('zoom-${media.id}'),
        minScale: 1,
        maxScale: 4,
        panEnabled: false,
        child: photoPreview,
      );
    }

    return _buildPlaceholderCard();
  }

  bool _isLocalFilePath(String value) {
    return !value.contains('://') || value.startsWith('file://');
  }

  ImageProvider<Object>? _buildImageProvider(
    String? pathOrUri, {
    String? mediaId,
    bool preferOriginalFile = false,
  }) {
    if (pathOrUri == null || pathOrUri.isEmpty) {
      return null;
    }
    if (preferOriginalFile && _isLocalFilePath(pathOrUri)) {
      final localPath = pathOrUri.startsWith('file://')
          ? Uri.parse(pathOrUri).toFilePath()
          : pathOrUri;
      return FileImage(File(localPath));
    }
    if (mediaId != null && _canLoadPlatformPreview(pathOrUri)) {
      final bytes = _mobilePreviewBytes[mediaId];
      if (bytes != null) {
        return MemoryImage(bytes);
      }
      if (_isPhAssetUri(pathOrUri) || _isContentUri(pathOrUri)) {
        return null;
      }
    }
    if (_isLocalFilePath(pathOrUri)) {
      final localPath = pathOrUri.startsWith('file://')
          ? Uri.parse(pathOrUri).toFilePath()
          : pathOrUri;
      return FileImage(File(localPath));
    }
    final parsed = Uri.tryParse(pathOrUri);
    if (parsed != null &&
        (parsed.scheme == 'http' || parsed.scheme == 'https')) {
      return NetworkImage(pathOrUri);
    }
    return null;
  }

  bool _isPhAssetUri(String value) => value.startsWith('phasset://');
  bool _isContentUri(String value) => value.startsWith('content://');
  bool _canLoadPlatformPreview(String value) {
    return _isPhAssetUri(value) ||
        _isContentUri(value) ||
        _isLocalFilePath(value);
  }

  Future<void> _ensureMobilePreviewBytes(MediaItem media) async {
    final pathOrUri = media.pathOrUri;
    if ((media.type != MediaType.photo && media.type != MediaType.video) ||
        pathOrUri == null ||
        !_canLoadPlatformPreview(pathOrUri) ||
        _mobilePreviewBytes.containsKey(media.id) ||
        !_mobilePreviewLoadingIds.add(media.id)) {
      return;
    }

    try {
      final bytes = await _mobileMediaRepository.fetchPreviewImageData(
        pathOrUri,
      );
      if (!mounted || bytes == null || bytes.isEmpty) {
        return;
      }
      setState(() {
        _mobilePreviewBytes[media.id] = bytes;
      });
    } catch (_) {
      // Best-effort preview loading only.
    } finally {
      _mobilePreviewLoadingIds.remove(media.id);
    }
  }

  Future<void> _ensurePlayableMediaUri(
    MediaItem media, {
    String? sourceUri,
  }) async {
    final pathOrUri = sourceUri ?? media.pathOrUri;
    final cacheKey = sourceUri ?? media.id;
    if (pathOrUri == null ||
        pathOrUri.isEmpty ||
        (media.type != MediaType.video && sourceUri == null) ||
        _resolvedPlayableUris.containsKey(cacheKey) ||
        !_playableUriLoadingIds.add(cacheKey)) {
      return;
    }

    try {
      final resolved = await _mobileMediaRepository.resolvePlayableMediaUri(
        pathOrUri,
      );
      if (!mounted || resolved == null || resolved.isEmpty) {
        return;
      }
      setState(() {
        _resolvedPlayableUris[cacheKey] = resolved;
      });
    } catch (_) {
      // Best-effort resolution only.
    } finally {
      _playableUriLoadingIds.remove(cacheKey);
    }
  }

  Future<void> _ensurePhotoAspectRatio(MediaItem media) async {
    if (media.type != MediaType.photo) return;
    if (_photoAspectRatios.containsKey(media.id)) return;
    if (!_aspectRatioLoadingIds.add(media.id)) return;
    final provider = _buildImageProvider(media.pathOrUri, mediaId: media.id);
    if (provider == null) {
      _aspectRatioLoadingIds.remove(media.id);
      return;
    }
    final stream = provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        final width = info.image.width.toDouble();
        final height = info.image.height.toDouble();
        if (width > 0 && height > 0 && mounted) {
          setState(() {
            _photoAspectRatios[media.id] = width / height;
          });
        }
        _aspectRatioLoadingIds.remove(media.id);
        stream.removeListener(listener);
      },
      onError: (_, __) {
        _aspectRatioLoadingIds.remove(media.id);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
  }

  Future<void> _preloadUpcomingMedia() async {
    if (!mounted) {
      return;
    }
    final candidates = _controller.prepareUpcomingMediaForPreloadQueue(
      limit: 3,
    );
    if (candidates.isEmpty) {
      _disposePreloadedVideoController();
      return;
    }

    final version = ++_preloadVersion;
    for (var i = 0; i < candidates.length; i += 1) {
      await _warmUpcomingMedia(
        candidates[i],
        version: version,
        initializeVideoController: i == 0,
      );
      if (!mounted || version != _preloadVersion) {
        return;
      }
    }
  }

  Future<void> _loadCurrentMediaMetadata({bool preloading = false}) async {
    final media = preloading
        ? _controller.prepareUpcomingMediaForPreload()
        : _controller.currentMedia;
    if (media == null) return;
    await _loadMediaMetadataFor(media);
  }

  Future<void> _warmUpcomingMedia(
    MediaItem media, {
    required int version,
    required bool initializeVideoController,
  }) async {
    await _loadMediaMetadataFor(media);
    unawaited(_ensureMobilePreviewBytes(media));

    if (media.type == MediaType.photo) {
      if (initializeVideoController) {
        _disposePreloadedVideoController();
      }
      unawaited(_ensurePhotoAspectRatio(media));
      final provider = _buildImageProvider(media.pathOrUri, mediaId: media.id);
      if (provider == null) {
        return;
      }
      if (!mounted) {
        return;
      }
      try {
        await precacheImage(provider, context);
      } catch (_) {
        // Best-effort preload only.
      }
      return;
    }

    await _ensurePlayableMediaUri(media);
    if (!initializeVideoController) {
      return;
    }

    final uri = _resolvedPlayableUris[media.id] ?? media.pathOrUri;
    if (uri == null || uri.isEmpty || _isPhAssetUri(uri)) {
      _disposePreloadedVideoController();
      return;
    }
    if (_preloadedVideoUri == uri && _preloadedVideoController != null) {
      return;
    }

    final controller = buildVideoPlayerController(uri);
    try {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setPlaybackSpeed(1.0);
      await controller.pause();
    } catch (_) {
      await controller.dispose();
      return;
    }

    if (!mounted || version != _preloadVersion) {
      await controller.dispose();
      return;
    }

    _disposePreloadedVideoController();
    _preloadedVideoController = controller;
    _preloadedVideoUri = uri;
  }

  Future<void> _loadMediaMetadataFor(MediaItem media) async {
    if (media.pathOrUri == null || _controller.hasDeviceModelCached(media.id)) {
      return;
    }

    try {
      final model = await _mobileMediaRepository.getDeviceModel(
        media.pathOrUri!,
      );
      _controller.setDeviceModelForId(media.id, model);
    } catch (_) {}
  }

  VideoPlayerController? _takePreloadedController(String uri) {
    final controller = _preloadedVideoController;
    if (controller == null || _preloadedVideoUri != uri) {
      return null;
    }
    _preloadedVideoController = null;
    _preloadedVideoUri = null;
    return controller;
  }

  void _disposePreloadedVideoController() {
    final controller = _preloadedVideoController;
    _preloadedVideoController = null;
    _preloadedVideoUri = null;
    controller?.dispose();
  }

  Widget _buildVideoPlaceholder(ImageProvider<Object>? thumbnailProvider) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: thumbnailProvider != null
              ? Image(
                  image: thumbnailProvider,
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
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: Color(0x99000000),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            size: 40,
            color: HuashuColors.surface,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderCard() {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: const Color(0x22000000),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_not_supported_outlined, size: 42),
          const SizedBox(height: 8),
          const Text('Preview unavailable'),
        ],
      ),
    );
  }
}

/// Custom painter that draws a massive circle precisely aligned so its
/// bottom edge touches exactly the bottom bounding box of the widget.
class _TopArcPainter extends CustomPainter {
  _TopArcPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Use an extremely large radius (1.2x screen width) for a gentle curve.
    final radius = size.width * 1.2;
    // Position center so the bottom edge of the circle is at `size.height`.
    final center = Offset(size.width / 2, size.height - radius);

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_TopArcPainter oldDelegate) => color != oldDelegate.color;
}
