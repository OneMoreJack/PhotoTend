import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rephoto/data/mobile/external_import_repository.dart';
import 'package:rephoto/data/mobile/mobile_media_repository.dart';
import 'package:rephoto/domain/models/media_item.dart';
import 'package:rephoto/features/import/import_controller.dart';
import 'package:rephoto/theme/huashu_theme.dart';

const _importBlue = HuashuColors.accent;
const _importInk = HuashuColors.ink;
const _importMuted = HuashuColors.muted;
const _importSurface = HuashuColors.paper;

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }
  final digits = value >= 10 || unitIndex == 0 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[unitIndex]}';
}

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
  final MobileMediaRepository _mobileMediaRepository =
      MethodChannelMobileMediaRepository();
  final Map<String, Uint8List> _previewBytes = <String, Uint8List>{};
  final Map<String, Uint8List> _fullImageBytes = <String, Uint8List>{};
  final Set<String> _previewLoadingIds = <String>{};
  final Set<String> _fullImageLoadingIds = <String>{};
  final Set<String> _collapsedGroupKeys = <String>{};
  List<MediaAlbum> _systemAlbums = const <MediaAlbum>[];
  bool _albumsLoading = false;
  bool _storagePickerPrompted = false;
  String _selectedAlbumName = '你的图库';

  @override
  void initState() {
    super.initState();
    _ownsController = widget._controller == null;
    _controller =
        widget._controller ?? ImportController(repository: _repository);
    _controller.addListener(_onControllerChanged);
    unawaited(_refreshAndPromptForStorageCard());
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _refreshAndPromptForStorageCard() async {
    await _controller.refresh();
    if (!mounted ||
        _storagePickerPrompted ||
        !_controller.needsStorageCard ||
        _controller.items.isNotEmpty) {
      return;
    }
    final roots = await _controller.listStorageCards();
    if (!mounted || roots.isEmpty) return;
    _storagePickerPrompted = true;
    await _showStorageCardPicker(initialRoots: roots);
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
      backgroundColor: _importSurface,
      body: SafeArea(
        child: Column(
          children: [
            _ImportHeader(
              itemCount: items.length,
              totalSizeBytes: _controller.totalSizeBytes,
              selectedCount: _controller.selectedCount,
              selectedSizeBytes: _controller.selectedSizeBytes,
              albumName: _selectedAlbumName,
              isImporting: _controller.isImporting,
              onBack: () => Navigator.of(context).maybePop(),
              onAlbumTap: _showAlbumPicker,
            ),
            Expanded(child: _buildBody(items)),
            if (items.isNotEmpty)
              _ImportBottomBar(
                selectedCount: _controller.selectedCount,
                isBusy: _controller.isImporting || _controller.isLoading,
                importCompletedCount: _controller.importCompletedCount,
                importTotalCount: _controller.importTotalCount,
                importProgress: _controller.importProgress,
                onChoose: _showStorageCardPicker,
                onRefresh: _controller.refresh,
                onMoveToTrash: _controller.selectedCount == 0
                    ? null
                    : _confirmDeleteSelectedItems,
                onImport: () => unawaited(
                  _controller.importPendingOrSelected(
                    albumName: _selectedAlbumName,
                  ),
                ),
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
        onChoose: _showStorageCardPicker,
        onRefresh: _controller.refresh,
      );
    }
    final groups = _groupByDay(items);
    return CustomScrollView(
      slivers: [
        if (_controller.statusMessage != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 2, 26, 6),
              child: Text(
                _controller.statusMessage!,
                style: const TextStyle(color: _importMuted),
              ),
            ),
          ),
        for (final group in groups) ...[
          SliverToBoxAdapter(
            child: _ImportGroupHeader(
              title: group.title,
              itemCount: group.items.length,
              collapsed: _collapsedGroupKeys.contains(group.key),
              allSelected: _controller.arePendingSelected(
                group.items.map((item) => item.id),
              ),
              isImporting: _controller.isImporting,
              onToggleCollapsed: () {
                setState(() {
                  if (!_collapsedGroupKeys.remove(group.key)) {
                    _collapsedGroupKeys.add(group.key);
                  }
                });
              },
              onToggleSelection: () => _controller.togglePendingSelection(
                group.items.map((item) => item.id),
              ),
            ),
          ),
          if (!_collapsedGroupKeys.contains(group.key))
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
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

  Future<void> _showStorageCardPicker({
    List<ExternalImportRoot>? initialRoots,
  }) async {
    final roots = initialRoots ?? await _controller.listStorageCards();
    if (!mounted) return;
    if (roots.isEmpty) {
      await _controller.chooseStorageCard();
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HuashuColors.surfaceAlt,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: Center(
                  child: Text(
                    '选择要导入的储存卡',
                    style: TextStyle(
                      color: _importInk,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              for (final root in roots)
                _AlbumPickerTile(
                  icon: Icons.sd_card_rounded,
                  title: root.label,
                  subtitle: root.description ?? '点按后授权访问并加载照片',
                  selected: false,
                  onTap: () => Navigator.of(context).pop(root.id),
                ),
              const SizedBox(height: 8),
              _AlbumPickerTile(
                icon: Icons.folder_open_rounded,
                title: '手动授权位置',
                subtitle: '检测不到储存卡时使用',
                selected: false,
                onTap: () => Navigator.of(context).pop('__manual__'),
              ),
              const SizedBox(height: 18),
            ],
          ),
        );
      },
    );
    if (!mounted || selected == null) return;
    await _controller.chooseStorageCard(
      rootId: selected == '__manual__' ? null : selected,
    );
  }

  Future<void> _confirmDeleteSelectedItems() async {
    final count = _controller.selectedCount;
    if (count == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('从储存卡删除？'),
        content: Text('将从储存卡上永久删除 $count 张照片。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HuashuColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _controller.deleteSelectedItems();
  }

  Future<void> _showAlbumPicker() async {
    await _loadSystemAlbums();
    if (!mounted) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: HuashuColors.surfaceAlt,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Center(
                  child: Text(
                    '导入至相簿',
                    style: TextStyle(
                      color: _importInk,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              _AlbumPickerSectionLabel(label: '图库'),
              _AlbumPickerTile(
                icon: Icons.person_outline_rounded,
                title: '你的图库',
                selected: _selectedAlbumName == '你的图库',
                onTap: () => Navigator.of(context).pop('你的图库'),
              ),
              const SizedBox(height: 18),
              _AlbumPickerSectionLabel(label: '相簿'),
              _AlbumPickerTile(
                icon: Icons.add_rounded,
                title: '新建相簿...',
                selected: false,
                onTap: () => Navigator.of(context).pop('__new_album__'),
              ),
              if (_albumsLoading)
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_systemAlbums.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 22, 24, 28),
                  child: Text(
                    '系统相册中暂无用户创建的相簿',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _importMuted, fontSize: 16),
                  ),
                ),
              for (final album in _orderedSystemAlbums)
                _AlbumPickerTile(
                  icon: Icons.photo_album_outlined,
                  title: album.name,
                  subtitle: album.count > 0 ? '${album.count} 个项目' : null,
                  selected: _selectedAlbumName == album.name,
                  onTap: () => Navigator.of(context).pop(album.name),
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
    if (!mounted || selected == null) return;
    if (selected == '__new_album__') {
      final created = await _showCreateAlbumDialog();
      if (!mounted || created == null || created.trim().isEmpty) return;
      final album = created.trim();
      setState(() => _selectedAlbumName = album);
      return;
    }
    setState(() => _selectedAlbumName = selected);
  }

  List<MediaAlbum> get _orderedSystemAlbums {
    final selected = _systemAlbums
        .where((album) => album.name == _selectedAlbumName)
        .toList(growable: false);
    final rest = _systemAlbums
        .where((album) => album.name != _selectedAlbumName)
        .toList(growable: false);
    return [...selected, ...rest];
  }

  Future<void> _loadSystemAlbums() async {
    setState(() => _albumsLoading = true);
    try {
      final albums = await _mobileMediaRepository.fetchUserAlbums();
      if (!mounted) return;
      setState(() => _systemAlbums = albums);
    } on MissingPluginException {
      if (!mounted) return;
      setState(() => _systemAlbums = const <MediaAlbum>[]);
    } catch (_) {
      if (!mounted) return;
      setState(() => _systemAlbums = const <MediaAlbum>[]);
    } finally {
      if (mounted) {
        setState(() => _albumsLoading = false);
      }
    }
  }

  Future<String?> _showCreateAlbumDialog() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建相簿'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '相簿名'),
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('创建'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
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
        _ImportDayGroup(
          key: key,
          title: _formatGroupTitle(key),
          items: buckets[key]!,
        ),
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
  const _ImportDayGroup({
    required this.key,
    required this.title,
    required this.items,
  });

  final String key;
  final String title;
  final List<ExternalImportItem> items;
}

class _ImportHeader extends StatelessWidget {
  const _ImportHeader({
    required this.itemCount,
    required this.totalSizeBytes,
    required this.selectedCount,
    required this.selectedSizeBytes,
    required this.albumName,
    required this.isImporting,
    required this.onBack,
    required this.onAlbumTap,
  });

  final int itemCount;
  final int totalSizeBytes;
  final int selectedCount;
  final int selectedSizeBytes;
  final String albumName;
  final bool isImporting;
  final VoidCallback onBack;
  final VoidCallback onAlbumTap;

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedCount > 0;
    final statLines = <String>[
      if (hasSelection)
        '$selectedCount 个项目'
      else if (itemCount > 0)
        '$itemCount 个项目',
      if (hasSelection && selectedSizeBytes > 0)
        _formatBytes(selectedSizeBytes)
      else if (!hasSelection && totalSizeBytes > 0)
        _formatBytes(totalSizeBytes),
    ];
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _importSurface,
        border: Border(bottom: BorderSide(color: Color(0x14000000))),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
            child: Row(
              children: [
                IconButton(
                  tooltip: '返回',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  iconSize: 28,
                  color: HuashuColors.ink,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '导入',
                    textAlign: TextAlign.left,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _importInk,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (statLines.isNotEmpty)
                  Text(
                    statLines.join('  '),
                    style: const TextStyle(
                      color: _importMuted,
                      fontSize: 14,
                      height: 1.1,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const Spacer(),
                Flexible(
                  child: InkWell(
                    key: const Key('import-album-picker-btn'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: isImporting ? null : onAlbumTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '导入至:',
                            style: TextStyle(
                              color: _importInk,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              albumName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _importBlue,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: _importBlue,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportGroupHeader extends StatelessWidget {
  const _ImportGroupHeader({
    required this.title,
    required this.itemCount,
    required this.collapsed,
    required this.allSelected,
    required this.isImporting,
    required this.onToggleCollapsed,
    required this.onToggleSelection,
  });

  final String title;
  final int itemCount;
  final bool collapsed;
  final bool allSelected;
  final bool isImporting;
  final VoidCallback onToggleCollapsed;
  final VoidCallback onToggleSelection;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 22, 8, 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onToggleCollapsed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(10, 5, 4, 7),
          decoration: BoxDecoration(
            color: collapsed
                ? HuashuColors.surfaceAlt.withValues(alpha: 0.65)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _importInk,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '$itemCount 个项目',
                          style: const TextStyle(
                            color: HuashuColors.faint,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedRotation(
                          turns: collapsed ? 0.5 : 0,
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOutCubic,
                          child: const Icon(
                            Icons.expand_more_rounded,
                            color: HuashuColors.faint,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: isImporting ? null : onToggleSelection,
                style: TextButton.styleFrom(
                  foregroundColor: _importBlue,
                  textStyle: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(allSelected ? '取消选择' : '选择'),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: HuashuColors.surfaceAlt,
              child: widget.previewBytes == null
                  ? Icon(
                      widget.item.type == MediaType.video
                          ? Icons.videocam_rounded
                          : Icons.image_rounded,
                      color: HuashuColors.faint,
                    )
                  : Image.memory(widget.previewBytes!, fit: BoxFit.cover),
            ),
            Positioned(
              left: 8,
              bottom: 8,
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
                top: 8,
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
          ],
        ),
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
      width: active ? 26 : 25,
      height: active ? 26 : 25,
      decoration: BoxDecoration(
        color: imported
            ? HuashuColors.positive
            : failed
            ? HuashuColors.danger
            : active
            ? _importBlue
            : Colors.white.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: active ? 1.5 : 2),
      ),
      child: Icon(
        failed
            ? Icons.priority_high_rounded
            : active
            ? Icons.check_rounded
            : null,
        size: 17,
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
        color: Colors.white.withValues(alpha: 0.88),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.history_rounded, size: 15, color: _importInk),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final illustrationSize = constraints.maxWidth.clamp(220.0, 280.0);
        return Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SizedBox(
                    width: illustrationSize,
                    height: illustrationSize * 0.82,
                    child: const _ImportEmptyIllustration(),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '未发现可导入内容',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _importInk,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _importMuted,
                    fontSize: 18,
                    height: 1.55,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: onChoose,
                  style: FilledButton.styleFrom(
                    backgroundColor: _importBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(58),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  icon: const Icon(Icons.folder_open_rounded, size: 24),
                  label: const Text('选择存储源'),
                ),
                const SizedBox(height: 18),
                TextButton.icon(
                  onPressed: onRefresh,
                  style: TextButton.styleFrom(
                    foregroundColor: _importBlue,
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 22),
                  label: const Text('重新刷新'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ImportEmptyIllustration extends StatelessWidget {
  const _ImportEmptyIllustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(size: Size.infinite, painter: _ImportEmptyHaloPainter()),
        Container(
          width: 158,
          height: 158,
          decoration: BoxDecoration(
            color: HuashuColors.surface,
            borderRadius: BorderRadius.circular(46),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: HuashuColors.accent.withValues(alpha: 0.12),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: const Icon(
            Icons.image_search_outlined,
            size: 72,
            color: HuashuColors.faint,
          ),
        ),
        const Positioned(
          right: 34,
          top: 18,
          child: _ImportFloatingBadge(icon: Icons.sd_storage_outlined),
        ),
        const Positioned(
          left: 24,
          bottom: 38,
          child: _ImportFloatingBadge(icon: Icons.usb_rounded),
        ),
      ],
    );
  }
}

class _ImportFloatingBadge extends StatelessWidget {
  const _ImportFloatingBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.18,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: HuashuColors.accent.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Icon(icon, color: HuashuColors.accent, size: 30),
      ),
    );
  }
}

class _ImportEmptyHaloPainter extends CustomPainter {
  const _ImportEmptyHaloPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = HuashuColors.accentSoft;
    canvas.drawCircle(center, size.shortestSide * 0.38, paint);
    paint.color = HuashuColors.surfaceAlt;
    canvas.drawCircle(center, size.shortestSide * 0.30, paint);

    final dotPaint = Paint()..color = HuashuColors.accent;
    canvas.drawCircle(center + const Offset(-72, -66), 9, dotPaint);
    canvas.drawCircle(center + const Offset(72, 58), 6, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AlbumPickerSectionLabel extends StatelessWidget {
  const _AlbumPickerSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Text(
        label,
        style: const TextStyle(
          color: _importMuted,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _AlbumPickerTile extends StatelessWidget {
  const _AlbumPickerTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: Colors.white,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: HuashuColors.surfaceAlt,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, color: _importBlue),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: icon == Icons.add_rounded ? _importBlue : _importInk,
          fontSize: 19,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: _importBlue, size: 30)
          : null,
      onTap: onTap,
    );
  }
}

class _ImportBottomBar extends StatelessWidget {
  const _ImportBottomBar({
    required this.selectedCount,
    required this.isBusy,
    required this.importCompletedCount,
    required this.importTotalCount,
    required this.importProgress,
    required this.onChoose,
    required this.onRefresh,
    required this.onMoveToTrash,
    required this.onImport,
  });

  final int selectedCount;
  final bool isBusy;
  final int importCompletedCount;
  final int importTotalCount;
  final double importProgress;
  final VoidCallback onChoose;
  final VoidCallback onRefresh;
  final VoidCallback? onMoveToTrash;
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HuashuColors.surfaceRaised.withValues(alpha: 0.98),
        boxShadow: [
          BoxShadow(
            color: HuashuColors.ink.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 12, 26, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isBusy || importTotalCount > 0) ...[
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
                      color: _importInk,
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
                  onPressed: isBusy ? null : onChoose,
                  color: HuashuColors.inkSoft,
                  iconSize: 32,
                  icon: const Icon(Icons.folder_open_rounded),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: '刷新',
                  onPressed: isBusy ? null : onRefresh,
                  color: HuashuColors.inkSoft,
                  iconSize: 32,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '删除选中',
                  onPressed: isBusy ? null : onMoveToTrash,
                  color: _importBlue,
                  disabledColor: HuashuColors.line,
                  iconSize: 32,
                  icon: const Icon(Icons.delete_forever_outlined),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: isBusy ? null : onImport,
                  style: FilledButton.styleFrom(
                    backgroundColor: _importBlue,
                    disabledBackgroundColor: HuashuColors.line,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white.withValues(
                      alpha: 0.72,
                    ),
                    elevation: 2,
                    shadowColor: _importBlue.withValues(alpha: 0.28),
                    minimumSize: const Size(150, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  icon: const Icon(Icons.file_download_outlined, size: 26),
                  label: Text(selectedCount == 0 ? '导入全部' : '导入选中'),
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
  late final ScrollController _stripController;
  late int _currentIndex;
  int? _preloadCenterIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _pageController.addListener(_handlePageScroll);
    _stripController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadAround(_currentIndex);
      _scrollStripToIndex(_currentIndex, jump: true);
    });
  }

  @override
  void dispose() {
    _pageController.removeListener(_handlePageScroll);
    _pageController.dispose();
    _stripController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.items.length,
                allowImplicitScrolling: true,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                  _scrollStripToIndex(index);
                  _preloadAround(index);
                },
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  return _ImportPreviewPane(
                    item: item,
                    previewBytes: widget.previewBytesById[item.id],
                    fullImageBytes: widget.fullImageBytesById[item.id],
                    selected: widget.isSelected(item.id),
                    onToggle: () {
                      widget.onToggle(item.id);
                      setState(() {});
                    },
                  );
                },
              ),
            ),
            _ImportPreviewStrip(
              items: widget.items,
              controller: _stripController,
              currentIndex: _currentIndex,
              previewBytesById: widget.previewBytesById,
              isSelected: widget.isSelected,
              onTap: (index) {
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                );
                setState(() => _currentIndex = index);
                _scrollStripToIndex(index);
                _preloadAround(index);
              },
            ),
          ],
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
      ],
    );
  }

  Future<void> _loadFullImage(ExternalImportItem item) async {
    await widget.onNeedFullImage(item);
    if (mounted) setState(() {});
  }

  void _handlePageScroll() {
    if (!_pageController.hasClients) return;
    final page = _pageController.page;
    if (page == null) return;
    final targetIndex = page.round().clamp(0, widget.items.length - 1);
    _preloadAround(targetIndex);
  }

  void _preloadAround(int centerIndex) {
    if (_preloadCenterIndex == centerIndex) return;
    _preloadCenterIndex = centerIndex;
    const offsets = <int>[0, 1, -1, 2, -2];
    for (final offset in offsets) {
      final index = centerIndex + offset;
      if (index < 0 || index >= widget.items.length) continue;
      unawaited(_loadFullImage(widget.items[index]));
    }
  }

  void _scrollStripToIndex(int index, {bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_stripController.hasClients) return;
      final position = _stripController.position;
      if (!position.hasContentDimensions) return;
      const tileWidth = 58.0;
      const gap = 8.0;
      const horizontalPadding = 10.0;
      final viewportWidth = position.viewportDimension;
      final centeredOffset =
          horizontalPadding +
          index * (tileWidth + gap) -
          (viewportWidth - tileWidth) / 2;
      final target = centeredOffset.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (jump) {
        _stripController.jumpTo(target);
        return;
      }
      _stripController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }
}

class _ImportPreviewStrip extends StatelessWidget {
  const _ImportPreviewStrip({
    required this.items,
    required this.controller,
    required this.currentIndex,
    required this.previewBytesById,
    required this.isSelected,
    required this.onTap,
  });

  final List<ExternalImportItem> items;
  final ScrollController controller;
  final int currentIndex;
  final Map<String, Uint8List> previewBytesById;
  final bool Function(String id) isSelected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 92,
        color: Colors.black,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
        child: ListView.separated(
          controller: controller,
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            return _ImportPreviewStripTile(
              item: item,
              previewBytes: previewBytesById[item.id],
              selected: isSelected(item.id),
              active: index == currentIndex,
              onTap: () => onTap(index),
            );
          },
        ),
      ),
    );
  }
}

class _ImportPreviewStripTile extends StatelessWidget {
  const _ImportPreviewStripTile({
    required this.item,
    required this.previewBytes,
    required this.selected,
    required this.active,
    required this.onTap,
  });

  final ExternalImportItem item;
  final Uint8List? previewBytes;
  final bool selected;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: HuashuColors.darkroomSoft,
                child: previewBytes == null
                    ? Icon(
                        item.type == MediaType.video
                            ? Icons.videocam_rounded
                            : Icons.image_rounded,
                        color: Colors.white54,
                        size: 22,
                      )
                    : Image.memory(previewBytes!, fit: BoxFit.cover),
              ),
              if (selected)
                ColoredBox(
                  color: Colors.white.withValues(alpha: 0.68),
                  child: const Center(
                    child: Icon(
                      Icons.check_rounded,
                      color: _importBlue,
                      size: 30,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportPreviewPane extends StatefulWidget {
  const _ImportPreviewPane({
    required this.item,
    required this.previewBytes,
    required this.fullImageBytes,
    required this.selected,
    required this.onToggle,
  });

  final ExternalImportItem item;
  final Uint8List? previewBytes;
  final Uint8List? fullImageBytes;
  final bool selected;
  final VoidCallback onToggle;

  @override
  State<_ImportPreviewPane> createState() => _ImportPreviewPaneState();
}

class _ImportPreviewPaneState extends State<_ImportPreviewPane> {
  Uint8List? _decodedBytes;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _ensureImageSize();
  }

  @override
  void didUpdateWidget(covariant _ImportPreviewPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_currentBytes != _decodedBytes) {
      _ensureImageSize();
    }
  }

  Uint8List? get _currentBytes => widget.fullImageBytes ?? widget.previewBytes;

  Future<void> _ensureImageSize() async {
    final bytes = _currentBytes;
    if (bytes == null || bytes == _decodedBytes) return;
    _decodedBytes = bytes;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final size = Size(image.width.toDouble(), image.height.toDouble());
      image.dispose();
      if (!mounted || _decodedBytes != bytes) return;
      setState(() => _imageSize = size);
    } catch (_) {
      if (!mounted || _decodedBytes != bytes) return;
      setState(() => _imageSize = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _currentBytes;
    if (bytes == null) {
      return Center(
        child: Icon(
          widget.item.type == MediaType.video
              ? Icons.videocam_rounded
              : Icons.image_rounded,
          color: Colors.white54,
          size: 72,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageSize = _imageSize;
        final preview = Image.memory(
          bytes,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        );
        if (imageSize == null) {
          return Center(
            child: InteractiveViewer(minScale: 1, maxScale: 5, child: preview),
          );
        }
        final bounds = Offset.zero & constraints.biggest;
        final fitted = applyBoxFit(BoxFit.contain, imageSize, bounds.size);
        final imageRect = Alignment.center.inscribe(fitted.destination, bounds);
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fromRect(
              rect: imageRect,
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
            ),
            Positioned(
              right: constraints.maxWidth - imageRect.right + 14,
              bottom: constraints.maxHeight - imageRect.bottom + 14,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onToggle,
                child: _ImportStatusMark(
                  selected: widget.selected,
                  status: ImportItemStatus.idle,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
