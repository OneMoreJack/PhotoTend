import 'package:flutter/foundation.dart';
import 'package:rephoto/data/mobile/external_import_repository.dart';

enum ImportItemStatus { idle, importing, imported, failed }

class ImportController extends ChangeNotifier {
  ImportController({required ExternalImportRepository repository})
    : _repository = repository;

  final ExternalImportRepository _repository;
  final List<ExternalImportItem> _items = <ExternalImportItem>[];
  final List<ExternalImportItem> _trashedItems = <ExternalImportItem>[];
  final Set<String> _selectedIds = <String>{};
  final Map<String, ImportItemStatus> _statuses = <String, ImportItemStatus>{};

  bool isLoading = false;
  bool isImporting = false;
  bool needsStorageCard = false;
  String? statusMessage;
  String? completionMessage;
  String? debugMessage;
  int importTotalCount = 0;
  int importCompletedCount = 0;

  List<ExternalImportItem> get items => List.unmodifiable(_visibleItems);
  List<ExternalImportItem> get trashedItems => List.unmodifiable(_trashedItems);
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);
  int get selectedCount => _selectedIds.length;
  int get trashCount => _trashedItems.length;
  int get totalSizeBytes => _sumSizeBytes(items);
  int get selectedSizeBytes => _sumSizeBytes(
    _visibleItems.where((item) => _selectedIds.contains(item.id)),
  );
  double get importProgress {
    if (importTotalCount <= 0) return 0;
    return (importCompletedCount / importTotalCount).clamp(0.0, 1.0);
  }

  List<ExternalImportItem> get _visibleItems {
    final trashedIds = _trashedItems.map((item) => item.id).toSet();
    return _items.where((item) => !trashedIds.contains(item.id)).toList();
  }

  ImportItemStatus statusFor(String id) {
    return _statuses[id] ?? ImportItemStatus.idle;
  }

  bool isSelected(String id) => _selectedIds.contains(id);

  Future<void> refresh() async {
    isLoading = true;
    statusMessage = null;
    completionMessage = null;
    debugMessage = null;
    _resetImportProgress();
    notifyListeners();
    try {
      final root = await _repository.getSavedImportRoot();
      if (root == null || root.isEmpty) {
        _items.clear();
        _selectedIds.clear();
        _statuses.clear();
        needsStorageCard = true;
        statusMessage = '请连接外接储存卡，或选择储存卡目录。';
        debugMessage = await _repository.getImportDebugInfo();
        return;
      }
      final scanned = await _repository.scanImportRoot();
      _items
        ..clear()
        ..addAll(scanned);
      _syncCurrentItems(scanned);
      _syncTrash(scanned);
      _selectedIds.removeWhere(
        (id) => !_visibleItems.any((item) => item.id == id),
      );
      needsStorageCard = scanned.isEmpty;
      statusMessage = scanned.isEmpty ? '没有找到可导入的照片或视频。' : null;
      debugMessage = scanned.isEmpty
          ? await _repository.getImportDebugInfo()
          : null;
    } catch (_) {
      needsStorageCard = true;
      statusMessage = '读取外接储存卡失败，请重新选择或刷新。';
      debugMessage = await _safeImportDebugInfo();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<ExternalImportRoot>> listStorageCards() async {
    try {
      return await _repository.listImportRoots();
    } catch (_) {
      return const <ExternalImportRoot>[];
    }
  }

  Future<void> chooseStorageCard({String? rootId}) async {
    isLoading = true;
    statusMessage = null;
    completionMessage = null;
    debugMessage = null;
    _resetImportProgress();
    notifyListeners();
    try {
      final root = await _repository.requestImportRoot(rootId: rootId);
      if (root == null || root.isEmpty) {
        needsStorageCard = true;
        statusMessage = '请连接外接储存卡，或选择储存卡目录。';
        debugMessage = await _repository.getImportDebugInfo();
        return;
      }
      final scanned = await _repository.scanImportRoot();
      _items
        ..clear()
        ..addAll(scanned);
      _selectedIds.clear();
      _statuses.clear();
      _trashedItems.clear();
      _syncCurrentItems(scanned);
      needsStorageCard = scanned.isEmpty;
      statusMessage = scanned.isEmpty ? '没有找到可导入的照片或视频。' : null;
      debugMessage = scanned.isEmpty
          ? await _repository.getImportDebugInfo()
          : null;
    } catch (_) {
      needsStorageCard = true;
      statusMessage = '读取外接储存卡失败，请重新选择或刷新。';
      debugMessage = await _safeImportDebugInfo();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void toggleSelection(String id) {
    if (isImporting || statusFor(id) == ImportItemStatus.imported) return;
    if (!_selectedIds.remove(id)) {
      _selectedIds.add(id);
    }
    completionMessage = null;
    notifyListeners();
  }

  void selectAllPending() {
    if (isImporting) return;
    _selectedIds
      ..clear()
      ..addAll(
        _visibleItems
            .where((item) => statusFor(item.id) != ImportItemStatus.imported)
            .map((item) => item.id),
      );
    completionMessage = null;
    notifyListeners();
  }

  void selectPending(Iterable<String> ids) {
    if (isImporting) return;
    _selectedIds.addAll(
      ids.where((id) => statusFor(id) != ImportItemStatus.imported),
    );
    completionMessage = null;
    notifyListeners();
  }

  bool arePendingSelected(Iterable<String> ids) {
    final pendingIds = ids
        .where((id) => statusFor(id) != ImportItemStatus.imported)
        .toList(growable: false);
    return pendingIds.isNotEmpty &&
        pendingIds.every((id) => _selectedIds.contains(id));
  }

  void togglePendingSelection(Iterable<String> ids) {
    if (isImporting) return;
    final pendingIds = ids
        .where((id) => statusFor(id) != ImportItemStatus.imported)
        .toList(growable: false);
    if (pendingIds.isEmpty) return;
    if (pendingIds.every((id) => _selectedIds.contains(id))) {
      _selectedIds.removeAll(pendingIds);
    } else {
      _selectedIds.addAll(pendingIds);
    }
    completionMessage = null;
    notifyListeners();
  }

  Future<void> deleteSelectedItems() async {
    if (isImporting || _selectedIds.isEmpty) return;
    isLoading = true;
    completionMessage = null;
    statusMessage = null;
    notifyListeners();
    final ids = Set<String>.from(_selectedIds);
    final byId = {for (final item in _visibleItems) item.id: item};
    final deletedIds = <String>{};
    for (final id in ids) {
      final item = byId[id];
      if (item == null) continue;
      try {
        await _repository.deleteExternalMedia(item);
        deletedIds.add(id);
      } catch (_) {
        // Keep the item visible so the user can retry.
      }
    }
    _items.removeWhere((item) => deletedIds.contains(item.id));
    _trashedItems.removeWhere((item) => deletedIds.contains(item.id));
    _statuses.removeWhere((id, _) => deletedIds.contains(id));
    _selectedIds.removeAll(deletedIds);
    if (deletedIds.length == ids.length) {
      completionMessage = '已从储存卡删除 ${deletedIds.length} 个项目';
      debugMessage = null;
    } else {
      statusMessage = deletedIds.isEmpty
          ? '删除失败，请确认储存卡目录允许写入后重试。'
          : '已删除 ${deletedIds.length} 个项目，${ids.length - deletedIds.length} 个删除失败。';
      debugMessage = await _safeImportDebugInfo();
    }
    isLoading = false;
    notifyListeners();
  }

  void restoreFromTrash(String id) {
    if (isImporting) return;
    _trashedItems.removeWhere((item) => item.id == id);
    completionMessage = null;
    notifyListeners();
  }

  void removeFromTrash(Set<String> ids) {
    if (isImporting || ids.isEmpty) return;
    _trashedItems.removeWhere((item) => ids.contains(item.id));
    completionMessage = null;
    notifyListeners();
  }

  Future<void> importPendingOrSelected({String albumName = 'RePhoto'}) async {
    if (selectedCount == 0) {
      selectAllPending();
    }
    await importSelected(albumName: albumName);
  }

  Future<void> importSelected({String albumName = 'RePhoto'}) async {
    if (isImporting || _selectedIds.isEmpty) return;
    isImporting = true;
    completionMessage = null;
    importTotalCount = _selectedIds.length;
    importCompletedCount = 0;
    notifyListeners();
    final byId = {for (final item in _visibleItems) item.id: item};
    final ids = List<String>.from(_selectedIds);
    for (final id in ids) {
      final item = byId[id];
      if (item == null) continue;
      _statuses[id] = ImportItemStatus.importing;
      notifyListeners();
      try {
        await _repository.importExternalMedia(item, albumName: albumName);
        _statuses[id] = ImportItemStatus.imported;
        _selectedIds.remove(id);
      } catch (_) {
        _statuses[id] = ImportItemStatus.failed;
      }
      importCompletedCount += 1;
      notifyListeners();
    }
    isImporting = false;
    if (_selectedIds.isEmpty) {
      completionMessage = '导入完成';
    } else {
      statusMessage = '部分照片导入失败，可重新选择后重试。';
    }
    notifyListeners();
  }

  void _resetImportProgress() {
    importTotalCount = 0;
    importCompletedCount = 0;
  }

  Future<String?> _safeImportDebugInfo() async {
    try {
      return await _repository.getImportDebugInfo();
    } catch (_) {
      return null;
    }
  }

  void _syncCurrentItems(List<ExternalImportItem> items) {
    final currentIds = items.map((item) => item.id).toSet();
    _statuses.removeWhere((id, _) => !currentIds.contains(id));
  }

  void _syncTrash(List<ExternalImportItem> items) {
    final byId = {for (final item in items) item.id: item};
    _trashedItems
      ..removeWhere((item) => !byId.containsKey(item.id))
      ..replaceRange(
        0,
        _trashedItems.length,
        _trashedItems.map((item) => byId[item.id]!).toList(growable: false),
      );
  }

  int _sumSizeBytes(Iterable<ExternalImportItem> items) {
    var total = 0;
    for (final item in items) {
      total += item.sizeBytes ?? 0;
    }
    return total;
  }
}
