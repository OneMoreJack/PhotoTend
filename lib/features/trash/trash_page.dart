import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:rephoto/data/mobile/mobile_media_repository.dart';
import 'package:rephoto/domain/models/media_item.dart';
import 'package:rephoto/domain/services/permanent_delete_service.dart';
import 'package:rephoto/features/media/widgets/video_tile.dart';
import 'package:rephoto/features/trash/trash_controller.dart';
import 'package:rephoto/theme/huashu_theme.dart';

class TrashPageResult {
  const TrashPageResult({
    required this.trashIds,
    required this.permanentlyDeletedIds,
  });

  final Set<String> trashIds;
  final Set<String> permanentlyDeletedIds;
}

class TrashPage extends StatefulWidget {
  const TrashPage({
    super.key,
    required this.initialIds,
    this.deleteService,
    this.initialMediaItems = const <MediaItem>[],
  });

  final List<String> initialIds;
  final PermanentDeleteService? deleteService;
  final List<MediaItem> initialMediaItems;

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  late final TrashController _controller;
  late final Map<String, MediaItem> _mediaById;
  final MobileMediaRepository _mobileMediaRepository =
      MethodChannelMobileMediaRepository();
  final Map<String, Uint8List> _mobilePreviewBytes = <String, Uint8List>{};
  final Set<String> _mobilePreviewLoadingIds = <String>{};
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _controller = TrashController(widget.initialIds);
    _mediaById = {for (final item in widget.initialMediaItems) item.id: item};
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return PopScope<TrashPageResult>(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              _closeWithResult();
            }
          },
          child: Scaffold(
            backgroundColor: HuashuColors.paper,
            appBar: AppBar(
              backgroundColor: HuashuColors.paper,
              scrolledUnderElevation: 0,
              leading: IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                color: HuashuColors.accent,
                onPressed: _closeWithResult,
              ),
              title: const Text('Trash'),
              titleTextStyle: const TextStyle(
                color: HuashuColors.ink,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
              actions: [
                Tooltip(
                  message: 'Select All',
                  child: TextButton(
                    onPressed: _isDeleting || _controller.ids.isEmpty
                        ? null
                        : _controller.toggleSelectAll,
                    child: Text(
                      _controller.isAllSelected ? 'Deselect' : 'Select',
                      style: const TextStyle(
                        color: HuashuColors.accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
              ],
            ),
            body: Column(
              children: [
                if (_isDeleting)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        LinearProgressIndicator(),
                        SizedBox(height: 8),
                        Text('Deleting...'),
                      ],
                    ),
                  ),
                Expanded(
                  child: _controller.ids.isEmpty
                      ? const _TrashEmptyState()
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = (constraints.maxWidth / 150)
                                .floor()
                                .clamp(3, 6);
                            return GridView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                17,
                                26,
                                17,
                                24,
                              ),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                  ),
                              itemCount: _controller.ids.length,
                              itemBuilder: (context, index) {
                                final id = _controller.ids[index];
                                final selected = _controller.selected.contains(
                                  id,
                                );
                                return GestureDetector(
                                  key: Key('trash-grid-item-$id'),
                                  onTap: () => _controller.toggleSelection(id),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 140),
                                    curve: Curves.easeOutCubic,
                                    padding: EdgeInsets.zero,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          _buildGridPreview(id),
                                          AnimatedOpacity(
                                            opacity: selected ? 1 : 0,
                                            duration: const Duration(
                                              milliseconds: 140,
                                            ),
                                            child: Container(
                                              color: HuashuColors.accent
                                                  .withValues(alpha: 0.12),
                                            ),
                                          ),
                                          if (_isVideo(id))
                                            const Positioned(
                                              right: 8,
                                              bottom: 8,
                                              child: Icon(
                                                Icons
                                                    .play_circle_outline_rounded,
                                                color: HuashuColors.surface,
                                                size: 25,
                                              ),
                                            ),
                                          Positioned(
                                            right: 9,
                                            top: 9,
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 120,
                                              ),
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                color: selected
                                                    ? HuashuColors.accent
                                                    : Colors.black.withValues(
                                                        alpha: 0.18,
                                                      ),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: HuashuColors.surface,
                                                  width: 1.4,
                                                ),
                                              ),
                                              child: selected
                                                  ? const Icon(
                                                      Icons.check,
                                                      size: 16,
                                                      color:
                                                          HuashuColors.surface,
                                                    )
                                                  : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
                _buildBottomBar(),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteSelectedPermanently() async {
    if (_controller.selected.isEmpty) {
      return;
    }
    final fallbackService = PermanentDeleteService(
      fakeDeleteResult: {for (final id in _controller.selected) id: true},
    );
    setState(() => _isDeleting = true);
    final result = await _controller.permanentDeleteSelected(
      widget.deleteService ?? fallbackService,
    );
    if (mounted) {
      setState(() => _isDeleting = false);
    }
    _showDeleteResult(result);
  }

  Future<void> _deleteAllPermanently() async {
    if (_controller.ids.isEmpty) {
      return;
    }
    final fallbackService = PermanentDeleteService(
      fakeDeleteResult: {for (final id in _controller.ids) id: true},
    );
    setState(() => _isDeleting = true);
    final result = await _controller.permanentDeleteAll(
      widget.deleteService ?? fallbackService,
    );
    if (mounted) {
      setState(() => _isDeleting = false);
    }
    _showDeleteResult(result);
  }

  void _showDeleteResult(DeleteResult result) {
    final success = result.succeededIds.length;
    final failed = result.failedIds.length;
    final message = switch ((success, failed)) {
      (final s, 0) => 'Permanently deleted $s item(s).',
      (0, final f) =>
        'Failed to permanently delete $f item(s). Retry from trash.',
      (final s, final f) =>
        'Permanently deleted $s item(s), failed $f item(s). Retry from trash.',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _closeWithResult() {
    Navigator.of(context).pop(
      TrashPageResult(
        trashIds: _controller.currentTrashIds,
        permanentlyDeletedIds: Set<String>.from(
          _controller.permanentlyDeletedIds,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final selectedCount = _controller.selected.length;
    final stats = _trashStats();
    final statItems = <Widget>[
      if (stats.photoCount > 0)
        _buildTrashStat(
          icon: Icons.photo_outlined,
          label: _countText(stats.photoCount, 'photo'),
        ),
      if (stats.videoCount > 0)
        _buildTrashStat(
          icon: Icons.movie_creation_outlined,
          label: _countText(stats.videoCount, 'video'),
        ),
      if (stats.knownSizeBytes > 0 || stats.hasUnknownSize)
        Flexible(
          child: _buildTrashStat(
            icon: Icons.sd_storage_outlined,
            label:
                '${_formatBytes(stats.knownSizeBytes)}'
                '${stats.hasUnknownSize ? '+' : ''}',
          ),
        ),
    ];
    return SafeArea(
      top: false,
      child: Container(
        key: const Key('trash-bottom-bar'),
        margin: const EdgeInsets.fromLTRB(17, 8, 17, 20),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: HuashuColors.surfaceRaised,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: HuashuColors.line),
          boxShadow: [
            BoxShadow(
              color: HuashuColors.ink.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                selectedCount > 0
                    ? '$selectedCount selected'
                    : '${_controller.ids.length} in trash',
                style: const TextStyle(
                  color: HuashuColors.inkSoft,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
            if (statItems.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                key: const Key('trash-bottom-stats'),
                children: [
                  for (var index = 0; index < statItems.length; index++) ...[
                    if (index > 0) const SizedBox(width: 12),
                    statItems[index],
                  ],
                ],
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildBarButton(
                    key: const Key('trash-bottom-restore-btn'),
                    icon: Icons.restore_from_trash_outlined,
                    label: 'Restore',
                    active: selectedCount > 0,
                    onPressed: _isDeleting || selectedCount == 0
                        ? null
                        : _controller.restoreSelected,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildBarButton(
                    key: const Key('trash-bottom-delete-btn'),
                    icon: Icons.delete_forever_outlined,
                    label: 'Delete',
                    danger: true,
                    active: selectedCount > 0,
                    onPressed: _isDeleting || selectedCount == 0
                        ? null
                        : _deleteSelectedPermanently,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildBarButton(
                    key: const Key('trash-bottom-empty-btn'),
                    icon: Icons.delete_sweep_outlined,
                    label: 'Empty',
                    danger: true,
                    filledDanger: true,
                    onPressed: _isDeleting || _controller.ids.isEmpty
                        ? null
                        : _deleteAllPermanently,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarButton({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool danger = false,
    bool filledDanger = false,
    bool active = false,
  }) {
    final enabled = onPressed != null;
    final foreground = !enabled
        ? HuashuColors.faint
        : active
        ? (danger ? HuashuColors.danger : HuashuColors.accent)
        : danger
        ? HuashuColors.danger
        : HuashuColors.inkSoft;
    final background = !enabled
        ? HuashuColors.surfaceAlt.withValues(alpha: 0.58)
        : active
        ? (danger ? HuashuColors.dangerSoft : HuashuColors.accentSoft)
        : filledDanger
        ? HuashuColors.dangerSoft
        : HuashuColors.paperWarm;
    return TextButton(
      key: key,
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledForegroundColor: HuashuColors.faint,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19),
            const SizedBox(width: 5),
            Text(label, maxLines: 1),
          ],
        ),
      ),
    );
  }

  _TrashStats _trashStats() {
    var photos = 0;
    var videos = 0;
    var size = 0;
    var unknown = false;
    for (final id in _controller.ids) {
      final media = _mediaById[id];
      if (media == null) {
        unknown = true;
        continue;
      }
      switch (media.type) {
        case MediaType.photo:
          photos += 1;
        case MediaType.video:
          videos += 1;
      }
      final bytes = media.sizeBytes;
      if (bytes == null) {
        unknown = true;
      } else {
        size += bytes;
      }
    }
    return _TrashStats(
      photoCount: photos,
      videoCount: videos,
      knownSizeBytes: size,
      hasUnknownSize: unknown,
    );
  }

  Widget _buildTrashStat({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: HuashuColors.muted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: HuashuColors.inkSoft,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }

  String _countText(int count, String singular) {
    return '$count $singular${count == 1 ? '' : 's'}';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(kb >= 10 ? 0 : 1)} KB';
    }
    final mb = kb / 1024;
    if (mb < 1024) {
      return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB';
    }
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(gb >= 10 ? 1 : 2)} GB';
  }

  Widget _buildGridPreview(String id) {
    final media = _mediaById[id];
    if (media == null) {
      return _buildMissingPreview();
    }
    if (_isVideo(id)) {
      final path = media.pathOrUri;
      if (path == null || path.isEmpty) {
        return _buildMissingPreview();
      }
      final thumbnailProvider = _buildImageProvider(path, mediaId: media.id);
      if (thumbnailProvider == null) {
        _ensureMobilePreviewBytes(media);
      }
      return VideoTile(
        uri: path,
        thumbnailProvider: thumbnailProvider,
        showOverlayControls: false,
        enableLongPressBoost: false,
      );
    }

    final provider = _buildImageProvider(media.pathOrUri, mediaId: media.id);
    if (provider == null) {
      _ensureMobilePreviewBytes(media);
    }
    if (provider != null) {
      return Image(
        image: provider,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildMissingPreview(),
      );
    }
    return _buildMissingPreview();
  }

  bool _isVideo(String id) {
    return _mediaById[id]?.type == MediaType.video;
  }

  bool _isLocalFilePath(String value) {
    return !value.contains('://') || value.startsWith('file://');
  }

  bool _isPhAssetUri(String value) => value.startsWith('phasset://');

  ImageProvider<Object>? _buildImageProvider(
    String? pathOrUri, {
    String? mediaId,
  }) {
    if (pathOrUri == null || pathOrUri.isEmpty) {
      return null;
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

  bool _isContentUri(String value) => value.startsWith('content://');
  bool _canLoadPlatformPreview(String value) {
    return _isPhAssetUri(value) ||
        _isContentUri(value) ||
        _isLocalFilePath(value);
  }

  Widget _buildMissingPreview() {
    return Container(
      color: const Color(0x22000000),
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: HuashuColors.muted,
        ),
      ),
    );
  }
}

class _TrashStats {
  const _TrashStats({
    required this.photoCount,
    required this.videoCount,
    required this.knownSizeBytes,
    required this.hasUnknownSize,
  });

  final int photoCount;
  final int videoCount;
  final int knownSizeBytes;
  final bool hasUnknownSize;
}

class _TrashEmptyState extends StatelessWidget {
  const _TrashEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 0, 36, 72),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: HuashuColors.surfaceRaised,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: HuashuColors.line),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                size: 38,
                color: HuashuColors.faint,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Trash is empty',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: HuashuColors.ink,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Photos you remove while browsing will wait here before they are permanently deleted.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: HuashuColors.muted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
