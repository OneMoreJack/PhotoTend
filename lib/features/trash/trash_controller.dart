import 'package:flutter/foundation.dart';
import 'package:rephoto/domain/services/permanent_delete_service.dart';

class TrashController extends ChangeNotifier {
  TrashController(List<String> initialIds)
    : ids = List<String>.from(initialIds);

  final List<String> ids;
  final Set<String> selected = <String>{};
  final Set<String> lastFailedDeleteIds = <String>{};
  final Set<String> permanentlyDeletedIds = <String>{};
  Set<String> get currentTrashIds => ids.toSet();
  bool get isAllSelected => ids.isNotEmpty && selected.length == ids.length;

  void toggleSelection(String id) {
    if (selected.contains(id)) {
      selected.remove(id);
    } else {
      selected.add(id);
    }
    notifyListeners();
  }

  void restoreSelected() {
    ids.removeWhere(selected.contains);
    selected.clear();
    notifyListeners();
  }

  void toggleSelectAll() {
    if (isAllSelected) {
      selected.clear();
    } else {
      selected
        ..clear()
        ..addAll(ids);
    }
    notifyListeners();
  }

  Future<DeleteResult> permanentDeleteSelected(
    PermanentDeleteService service,
  ) async {
    final deletingIds = Set<String>.from(selected);
    final result = await service.delete(deletingIds);
    ids.removeWhere(
      (id) => deletingIds.contains(id) && !result.failedIds.contains(id),
    );
    selected
      ..clear()
      ..addAll(result.failedIds);
    lastFailedDeleteIds
      ..clear()
      ..addAll(result.failedIds);
    permanentlyDeletedIds.addAll(result.succeededIds);
    notifyListeners();
    return result;
  }

  Future<DeleteResult> permanentDeleteAll(
    PermanentDeleteService service,
  ) async {
    final deletingIds = Set<String>.from(ids);
    final result = await service.delete(deletingIds);
    ids
      ..clear()
      ..addAll(result.failedIds);
    selected
      ..clear()
      ..addAll(result.failedIds);
    lastFailedDeleteIds
      ..clear()
      ..addAll(result.failedIds);
    permanentlyDeletedIds.addAll(result.succeededIds);
    notifyListeners();
    return result;
  }
}
