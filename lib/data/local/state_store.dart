abstract class StateStore {
  Future<void> saveTrashIds(Set<String> ids);
  Future<Set<String>> loadTrashIds();

  Future<void> saveLocationFilter(String? locationKey);
  Future<String?> loadLocationFilter();
}

class InMemoryStateStore implements StateStore {
  Set<String> _trashIds = <String>{};
  String? _locationFilter;

  @override
  Future<void> saveTrashIds(Set<String> ids) async {
    _trashIds = Set<String>.from(ids);
  }

  @override
  Future<Set<String>> loadTrashIds() async {
    return Set<String>.from(_trashIds);
  }

  @override
  Future<void> saveLocationFilter(String? locationKey) async {
    _locationFilter = locationKey;
  }

  @override
  Future<String?> loadLocationFilter() async {
    return _locationFilter;
  }
}
