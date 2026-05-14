import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:rephoto/data/mobile/mobile_media_repository.dart';
import 'package:rephoto/domain/models/media_item.dart';
import 'package:rephoto/domain/services/permanent_delete_service.dart';
import 'package:rephoto/features/media/widgets/video_tile.dart';
import 'package:rephoto/features/trash/trash_controller.dart';

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
            appBar: AppBar(
              title: const Text('Trash'),
              actions: [
                IconButton(
                  tooltip: 'Select All',
                  onPressed: _isDeleting || _controller.ids.isEmpty
                      ? null
                      : _controller.toggleSelectAll,
                  icon: Icon(
                    _controller.isAllSelected
                        ? Icons.deselect_outlined
                        : Icons.select_all_outlined,
                  ),
                ),
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = (constraints.maxWidth / 150)
                          .floor()
                          .clamp(3, 7);
                      return GridView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                        itemCount: _controller.ids.length,
                        itemBuilder: (context, index) {
                          final id = _controller.ids[index];
                          final selected = _controller.selected.contains(id);
                          return GestureDetector(
                            key: Key('trash-grid-item-$id'),
                            onTap: () => _controller.toggleSelection(id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              curve: Curves.easeOutCubic,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFF2A5BD7)
                                      : Colors.transparent,
                                  width: 2,
                                ),
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
                                        color: const Color(
                                          0xFF2A5BD7,
                                        ).withValues(alpha: 0.18),
                                      ),
                                    ),
                                    if (_isVideo(id))
                                      const Positioned(
                                        left: 6,
                                        bottom: 6,
                                        child: Icon(
                                          Icons.videocam,
                                          color: Colors.white,
                                        ),
                                      ),
                                    Positioned(
                                      right: 6,
                                      top: 6,
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 120,
                                        ),
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? const Color(0xFF2A5BD7)
                                              : const Color(0x70000000),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Icon(
                                          selected ? Icons.check : Icons.add,
                                          size: 14,
                                          color: Colors.white,
                                        ),
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
    return SafeArea(
      top: false,
      child: Container(
        key: const Key('trash-bottom-bar'),
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE6E8ED)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                selectedCount == 0
                    ? '${_controller.ids.length} in trash'
                    : '$selectedCount selected',
                style: const TextStyle(
                  color: Color(0xFF5F6670),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildBarButton(
                    key: const Key('trash-bottom-restore-btn'),
                    icon: Icons.restore_from_trash_outlined,
                    label: 'Restore',
                    onPressed: _isDeleting || selectedCount == 0
                        ? null
                        : _controller.restoreSelected,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildBarButton(
                    key: const Key('trash-bottom-delete-btn'),
                    icon: Icons.delete_forever_outlined,
                    label: 'Delete',
                    danger: true,
                    onPressed: _isDeleting || selectedCount == 0
                        ? null
                        : _deleteSelectedPermanently,
                  ),
                ),
                const SizedBox(width: 8),
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
  }) {
    final foreground = danger
        ? const Color(0xFFD92D20)
        : const Color(0xFF263241);
    final background = filledDanger
        ? const Color(0xFFFFE8E6)
        : const Color(0xFFF5F7FA);
    return TextButton.icon(
      key: key,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: TextButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledForegroundColor: const Color(0xFF9CA3AF),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
    );
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
        child: Icon(Icons.image_not_supported_outlined, color: Colors.black45),
      ),
    );
  }
}
