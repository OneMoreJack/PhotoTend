class GestureSessionService {
  final List<String> _displayHistory = <String>[];
  final List<String> _deleteStack = <String>[];
  final List<String> _trashOrderedIds = <String>[];
  final Set<String> trashIds = <String>{};

  List<String> get displayHistory => List.unmodifiable(_displayHistory);
  List<String> get trashOrderedIds => List.unmodifiable(_trashOrderedIds);

  void onShown(String id) {
    _displayHistory.add(id);
  }

  void onDeleteCurrent(String id) {
    if (!trashIds.add(id)) {
      _trashOrderedIds.remove(id);
      _trashOrderedIds.insert(0, id);
      return;
    }
    _deleteStack.add(id);
    _trashOrderedIds.remove(id);
    _trashOrderedIds.insert(0, id);
  }

  String? undoLastDelete() {
    while (_deleteStack.isNotEmpty) {
      final last = _deleteStack.removeLast();
      if (!trashIds.remove(last)) {
        continue;
      }
      _trashOrderedIds.remove(last);
      return last;
    }
    return null;
  }

  void syncTrash(Set<String> ids) {
    trashIds
      ..clear()
      ..addAll(ids);
    _trashOrderedIds.removeWhere((id) => !trashIds.contains(id));
    for (final id in ids) {
      if (_trashOrderedIds.contains(id)) {
        continue;
      }
      _trashOrderedIds.add(id);
    }
    _deleteStack.removeWhere((id) => !trashIds.contains(id));
  }
}
