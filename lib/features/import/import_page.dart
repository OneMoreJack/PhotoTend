import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rephoto/data/mobile/external_import_repository.dart';
import 'package:rephoto/domain/models/media_item.dart';
import 'package:rephoto/features/import/import_controller.dart';

class ImportPage extends StatefulWidget {
  const ImportPage({super.key, ImportController? controller})
    : _controller = controller;

  final ImportController? _controller;

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  late final ImportController _controller;
  late final bool _ownsController;
  final ExternalImportRepository _repository =
      MethodChannelExternalImportRepository();
  final Map<String, Uint8List> _previewBytes = <String, Uint8List>{};
  final Map<String, Uint8List> _fullImageBytes = <String, Uint8List>{};
  final Set<String> _previewLoadingIds = <String>{};
  final Set<String> _fullImageLoadingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _ownsController = widget._controller == null;
    _controller =
        widget._controller ?? ImportController(repository: _repository);
    _controller.addListener(_onControllerChanged);
    unawaited(_controller.refresh());
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    final message = _controller.completionMessage;
    if (message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _controller.items;
    return Scaffold(
      key: const Key('import-page'),
      backgroundColor: const Color(0xFFFFFAFD),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('导入'),
            Text(
              '${items.length} 个项目',
              style: const TextStyle(
                color: Color(0xFF747783),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          if (_controller.isImporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Center(child: Text('正在导入')),
            )
          else
            TextButton(
              onPressed: items.isEmpty ? null : _controller.selectAllPending,
              child: const Text('选择全部'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildBody(items)),
            _ImportBottomBar(
              selectedCount: _controller.selectedCount,
              isImporting: _controller.isImporting,
              importCompletedCount: _controller.importCompletedCount,
              importTotalCount: _controller.importTotalCount,
              importProgress: _controller.importProgress,
              onChoose: _controller.chooseStorageCard,
              onRefresh: _controller.refresh,
              onImport: _controller.selectedCount == 0
                  ? null
                  : () => unawaited(_controller.importSelected()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<ExternalImportItem> items) {
    if (_controller.isLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return _ImportEmptyState(
        message: _controller.statusMessage ?? '请连接外接储存卡。',
        onChoose: _controller.chooseStorageCard,
        onRefresh: _controller.refresh,
      );
    }
    final groups = _groupByDay(items);
    return CustomScrollView(
      slivers: [
        if (_controller.statusMessage != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
              child: Text(
                _controller.statusMessage!,
                style: const TextStyle(color: Color(0xFF747783)),
              ),
            ),
          ),
        for (final group in groups) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      group.title,
                      style: const TextStyle(
                        color: Color(0xFF1D1D21),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  Text(
                    '${group.items.length} 个项目',
                    style: const TextStyle(
                      color: Color(0xFF747783),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 1,
                crossAxisSpacing: 1,
              ),
              itemCount: group.items.length,
              itemBuilder: (context, index) {
                final item = group.items[index];
                return _ImportGridTile(
                  item: item,
                  previewBytes: _previewBytes[item.id],
                  selected: _controller.isSelected(item.id),
                  status: _controller.statusFor(item.id),
                  onNeedPreview: _ensurePreviewBytes,
                  onTap: () => _openPreview(item, items),
                  onSelect: () => _controller.toggleSelection(item.id),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  List<_ImportDayGroup> _groupByDay(List<ExternalImportItem> items) {
    final buckets = <String, List<ExternalImportItem>>{};
    for (final item in items) {
      final date = item.createdAt;
      final key = date == null
          ? '未知日期'
          : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      buckets.putIfAbsent(key, () => <ExternalImportItem>[]).add(item);
    }
    final keys = buckets.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final key in keys)
        _ImportDayGroup(title: _formatGroupTitle(key), items: buckets[key]!),
    ];
  }

  String _formatGroupTitle(String key) {
    if (key == '未知日期') return key;
    final parts = key.split('-');
    if (parts.length != 3) return key;
    return '${int.parse(parts[1])}月${int.parse(parts[2])}日';
  }

  Future<void> _ensurePreviewBytes(ExternalImportItem item) async {
    if (_previewBytes.containsKey(item.id) ||
        !_previewLoadingIds.add(item.id)) {
      return;
    }
    try {
      final bytes = await _repository.fetchPreviewImageData(item.pathOrUri);
      if (!mounted || bytes == null || bytes.isEmpty) return;
      setState(() => _previewBytes[item.id] = bytes);
    } on MissingPluginException {
      // Placeholder remains available on unsupported hosts.
    } catch (_) {
      // Thumbnail loading is best effort.
    } finally {
      _previewLoadingIds.remove(item.id);
    }
  }

  Future<void> _ensureFullImageBytes(ExternalImportItem item) async {
    if (item.type != MediaType.photo ||
        _fullImageBytes.containsKey(item.id) ||
        !_fullImageLoadingIds.add(item.id)) {
      return;
    }
    try {
      final bytes = await _repository.fetchFullImageData(item.pathOrUri);
      if (!mounted || bytes == null || bytes.isEmpty) return;
      setState(() => _fullImageBytes[item.id] = bytes);
    } on MissingPluginException {
      // Fallback to thumbnail preview on unsupported hosts.
    } catch (_) {
      // Full image loading is best effort.
    } finally {
      _fullImageLoadingIds.remove(item.id);
    }
  }

  Future<void> _openPreview(
    ExternalImportItem item,
    List<ExternalImportItem> items,
  ) async {
    final initialIndex = items.indexWhere(
      (candidate) => candidate.id == item.id,
    );
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (context) => _ImportPreviewDialog(
        items: items,
        initialIndex: initialIndex < 0 ? 0 : initialIndex,
        previewBytesById: _previewBytes,
        fullImageBytesById: _fullImageBytes,
        isSelected: _controller.isSelected,
        onNeedFullImage: _ensureFullImageBytes,
        onToggle: _controller.toggleSelection,
      ),
    );
  }
}

class _ImportDayGroup {
  const _ImportDayGroup({required this.title, required this.items});

  final String title;
  final List<ExternalImportItem> items;
}

class _ImportGridTile extends StatefulWidget {
  const _ImportGridTile({
    required this.item,
    required this.previewBytes,
    required this.selected,
    required this.status,
    required this.onNeedPreview,
    required this.onTap,
    required this.onSelect,
  });

  final ExternalImportItem item;
  final Uint8List? previewBytes;
  final bool selected;
  final ImportItemStatus status;
  final ValueChanged<ExternalImportItem> onNeedPreview;
  final VoidCallback onTap;
  final VoidCallback onSelect;

  @override
  State<_ImportGridTile> createState() => _ImportGridTileState();
}

class _ImportGridTileState extends State<_ImportGridTile> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onNeedPreview(widget.item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onSelect,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: const Color(0xFFEDEEF2),
            child: widget.previewBytes == null
                ? Icon(
                    widget.item.type == MediaType.video
                        ? Icons.videocam_rounded
                        : Icons.image_rounded,
                    color: const Color(0xFFB7BAC3),
                  )
                : Image.memory(widget.previewBytes!, fit: BoxFit.cover),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: _HistoricalImportMark(visible: widget.item.imported),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onSelect,
              child: _ImportStatusMark(
                selected: widget.selected,
                status: widget.status,
              ),
            ),
          ),
          if (widget.item.type == MediaType.video)
            const Positioned(
              left: 8,
              bottom: 8,
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }
}

class _ImportStatusMark extends StatelessWidget {
  const _ImportStatusMark({required this.selected, required this.status});

  final bool selected;
  final ImportItemStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == ImportItemStatus.importing) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.4),
      );
    }
    final imported = status == ImportItemStatus.imported;
    final failed = status == ImportItemStatus.failed;
    final active = selected || imported || failed;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: imported
            ? const Color(0xFF32C759)
            : failed
            ? const Color(0xFFFF3B30)
            : active
            ? const Color(0xFF007AFF)
            : Colors.white.withValues(alpha: 0.25),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Icon(
        failed
            ? Icons.priority_high_rounded
            : active
            ? Icons.check_rounded
            : null,
        size: 16,
        color: Colors.white,
      ),
    );
  }
}

class _HistoricalImportMark extends StatelessWidget {
  const _HistoricalImportMark({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.history_rounded, size: 15, color: Colors.white),
    );
  }
}

class _ImportEmptyState extends StatelessWidget {
  const _ImportEmptyState({
    required this.message,
    required this.onChoose,
    required this.onRefresh,
  });

  final String message;
  final VoidCallback onChoose;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sd_storage_outlined,
              size: 56,
              color: Color(0xFF747783),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF363A45),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onChoose,
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('选择储存卡'),
                ),
                OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('刷新'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportBottomBar extends StatelessWidget {
  const _ImportBottomBar({
    required this.selectedCount,
    required this.isImporting,
    required this.importCompletedCount,
    required this.importTotalCount,
    required this.importProgress,
    required this.onChoose,
    required this.onRefresh,
    required this.onImport,
  });

  final int selectedCount;
  final bool isImporting;
  final int importCompletedCount;
  final int importTotalCount;
  final double importProgress;
  final VoidCallback onChoose;
  final VoidCallback onRefresh;
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xF7FFFAFD),
        border: Border(top: BorderSide(color: Color(0x0F000000))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isImporting || importTotalCount > 0) ...[
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: importTotalCount == 0 ? null : importProgress,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$importCompletedCount/$importTotalCount',
                    style: const TextStyle(
                      color: Color(0xFF363A45),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                IconButton(
                  tooltip: '选择储存卡',
                  onPressed: isImporting ? null : onChoose,
                  icon: const Icon(Icons.folder_open_rounded),
                ),
                IconButton(
                  tooltip: '刷新',
                  onPressed: isImporting ? null : onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                Expanded(
                  child: Text(
                    selectedCount == 0 ? '选择要导入的照片' : '已选择 $selectedCount 个项目',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF363A45),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: isImporting ? null : onImport,
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('导入'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportPreviewDialog extends StatefulWidget {
  const _ImportPreviewDialog({
    required this.items,
    required this.initialIndex,
    required this.previewBytesById,
    required this.fullImageBytesById,
    required this.isSelected,
    required this.onNeedFullImage,
    required this.onToggle,
  });

  final List<ExternalImportItem> items;
  final int initialIndex;
  final Map<String, Uint8List> previewBytesById;
  final Map<String, Uint8List> fullImageBytesById;
  final bool Function(String id) isSelected;
  final Future<void> Function(ExternalImportItem item) onNeedFullImage;
  final ValueChanged<String> onToggle;

  @override
  State<_ImportPreviewDialog> createState() => _ImportPreviewDialogState();
}

class _ImportPreviewDialogState extends State<_ImportPreviewDialog> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadFullImage(widget.items[_currentIndex]));
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.items[_currentIndex];
    final selected = widget.isSelected(current.id);
    return Stack(
      children: [
        Positioned.fill(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.items.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              unawaited(_loadFullImage(widget.items[index]));
            },
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: _ImportPreviewPane(
                  item: item,
                  previewBytes: widget.previewBytesById[item.id],
                  fullImageBytes: widget.fullImageBytesById[item.id],
                ),
              );
            },
          ),
        ),
        Positioned(
          left: 18,
          top: 22,
          child: SafeArea(
            child: Text(
              '${_currentIndex + 1}/${widget.items.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        Positioned(
          top: 22,
          right: 18,
          child: SafeArea(
            child: FilledButton.icon(
              onPressed: () {
                widget.onToggle(current.id);
                setState(() {});
              },
              icon: Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              ),
              label: Text(selected ? '已选择' : '选择'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _loadFullImage(ExternalImportItem item) async {
    await widget.onNeedFullImage(item);
    if (mounted) setState(() {});
  }
}

class _ImportPreviewPane extends StatelessWidget {
  const _ImportPreviewPane({
    required this.item,
    required this.previewBytes,
    required this.fullImageBytes,
  });

  final ExternalImportItem item;
  final Uint8List? previewBytes;
  final Uint8List? fullImageBytes;

  @override
  Widget build(BuildContext context) {
    final bytes = fullImageBytes ?? previewBytes;
    return Center(
      child: bytes == null
          ? Icon(
              item.type == MediaType.video
                  ? Icons.videocam_rounded
                  : Icons.image_rounded,
              color: Colors.white54,
              size: 72,
            )
          : InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
    );
  }
}
