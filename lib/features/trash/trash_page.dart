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
                IconButton(
                  tooltip: 'Clear Trash',
                  onPressed: _isDeleting || _controller.ids.isEmpty
                      ? null
                      : _deleteAllPermanently,
                  icon: const Icon(Icons.delete_sweep_outlined),
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
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: _controller.ids.length,
                    itemBuilder: (context, index) {
                      final id = _controller.ids[index];
                      final selected = _controller.selected.contains(id);
                      return GestureDetector(
                        key: Key('trash-grid-item-$id'),
                        onTap: () => _controller.toggleSelection(id),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: _buildGridPreview(id),
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
                                duration: const Duration(milliseconds: 120),
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFF2A5BD7)
                                      : const Color(0x70000000),
                                  shape: BoxShape.circle,
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
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildBottomAction(
                        icon: Icons.restore_from_trash_outlined,
                        label: 'Restore Selected',
                        onTap: _isDeleting ? null : _controller.restoreSelected,
                      ),
                      _buildBottomAction(
                        icon: Icons.delete_forever_outlined,
                        label: 'Delete Selected',
                        onTap: _isDeleting || _controller.selected.isEmpty
                            ? null
                            : _deleteSelectedPermanently,
                      ),
                      _buildBottomAction(
                        icon: Icons.delete_sweep_outlined,
                        label: 'Empty Trash',
                        onTap: _isDeleting || _controller.ids.isEmpty
                            ? null
                            : _deleteAllPermanently,
                      ),
                    ],
                  ),
                ),
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
    final shouldDelete = await _confirmPermanentDelete(
      itemCount: _controller.ids.length,
    );
    if (!shouldDelete) {
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
    final shouldDelete = await _confirmPermanentDelete(
      itemCount: _controller.selected.length,
    );
    if (!shouldDelete) {
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

  Future<bool> _confirmPermanentDelete({required int itemCount}) async {
    final decision = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Permanent Delete'),
          content: Text(
            'This action permanently deletes $itemCount item(s) from system library when applicable.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    return decision ?? false;
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

  Widget _buildBottomAction({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: disabled ? 0.4 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: const Color(0xFF343434)),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF343434),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
    if (_isPhAssetUri(pathOrUri)) {
      if (mediaId == null) {
        return null;
      }
      final bytes = _mobilePreviewBytes[mediaId];
      if (bytes == null) {
        return null;
      }
      return MemoryImage(bytes);
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
    if (media.type != MediaType.photo ||
        pathOrUri == null ||
        !_isPhAssetUri(pathOrUri) ||
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

  Widget _buildMissingPreview() {
    return Container(
      color: const Color(0x22000000),
      child: const Center(
        child: Icon(Icons.image_not_supported_outlined, color: Colors.black45),
      ),
    );
  }
}
