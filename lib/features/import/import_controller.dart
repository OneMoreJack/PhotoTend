import 'package:flutter/foundation.dart';
import 'package:rephoto/data/mobile/external_import_repository.dart';

enum ImportItemStatus { idle, importing, imported, failed }

class ImportController extends ChangeNotifier {
  ImportController({required ExternalImportRepository repository})
    : _repository = repository;

  final ExternalImportRepository _repository;
  final List<ExternalImportItem> _items = <ExternalImportItem>[];
  final Set<String> _selectedIds = <String>{};
  final Map<String, ImportItemStatus> _statuses = <String, ImportItemStatus>{};

  bool isLoading = false;
  bool isImporting = false;
  bool needsStorageCard = false;
  String? statusMessage;
  String? completionMessage;
  int importTotalCount = 0;
  int importCompletedCount = 0;

  List<ExternalImportItem> get items => List.unmodifiable(_items);
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);
  int get selectedCount => _selectedIds.length;
  double get importProgress {
    if (importTotalCount <= 0) return 0;
    return (importCompletedCount / importTotalCount).clamp(0.0, 1.0);
  }

  ImportItemStatus statusFor(String id) {
    return _statuses[id] ?? ImportItemStatus.idle;
  }

  bool isSelected(String id) => _selectedIds.contains(id);

  Future<void> refresh() async {
    isLoading = true;
    statusMessage = null;
    completionMessage = null;
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
        return;
      }
      final scanned = await _repository.scanImportRoot();
      _items
        ..clear()
        ..addAll(scanned);
      _syncCurrentItems(scanned);
      _selectedIds.removeWhere((id) => !_items.any((item) => item.id == id));
      needsStorageCard = scanned.isEmpty;
      statusMessage = scanned.isEmpty ? '没有找到可导入的照片或视频。' : null;
    } catch (_) {
      needsStorageCard = true;
      statusMessage = '读取外接储存卡失败，请重新选择或刷新。';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> chooseStorageCard() async {
    isLoading = true;
    statusMessage = null;
    completionMessage = null;
    _resetImportProgress();
    notifyListeners();
    try {
      final root = await _repository.requestImportRoot();
      if (root == null || root.isEmpty) {
        needsStorageCard = true;
        statusMessage = '请连接外接储存卡，或选择储存卡目录。';
        return;
      }
      final scanned = await _repository.scanImportRoot();
      _items
        ..clear()
        ..addAll(scanned);
      _selectedIds.clear();
      _statuses.clear();
      _syncCurrentItems(scanned);
      needsStorageCard = scanned.isEmpty;
      statusMessage = scanned.isEmpty ? '没有找到可导入的照片或视频。' : null;
    } catch (_) {
      needsStorageCard = true;
      statusMessage = '读取外接储存卡失败，请重新选择或刷新。';
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
        _items
            .where((item) => statusFor(item.id) != ImportItemStatus.imported)
            .map((item) => item.id),
      );
    completionMessage = null;
    notifyListeners();
  }

  Future<void> importSelected({String albumName = 'RePhoto'}) async {
    if (isImporting || _selectedIds.isEmpty) return;
    isImporting = true;
    completionMessage = null;
    importTotalCount = _selectedIds.length;
    importCompletedCount = 0;
    notifyListeners();
    final byId = {for (final item in _items) item.id: item};
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

  void _syncCurrentItems(List<ExternalImportItem> items) {
    final currentIds = items.map((item) => item.id).toSet();
    _statuses.removeWhere((id, _) => !currentIds.contains(id));
  }
}
