typedef DeleteExecutor = Future<void> Function(Set<String> ids);

class DeleteResult {
  DeleteResult({
    required this.succeededIds,
    required this.failedIds,
    this.failureReasons = const <String, String>{},
  });

  final Set<String> succeededIds;
  final Set<String> failedIds;
  final Map<String, String> failureReasons;

  int get attemptedCount => succeededIds.length + failedIds.length;
}

class PermanentDeleteService {
  PermanentDeleteService({
    required this.fakeDeleteResult,
    this.fakeFailureReasons = const <String, String>{},
    this.simulatedDelay,
  }) : _deleteExecutor = null;

  PermanentDeleteService.real({
    required DeleteExecutor deleteExecutor,
    this.simulatedDelay,
  }) : _deleteExecutor = deleteExecutor,
       fakeDeleteResult = const <String, bool>{},
       fakeFailureReasons = const <String, String>{};

  final Map<String, bool> fakeDeleteResult;
  final Map<String, String> fakeFailureReasons;
  final Duration? simulatedDelay;
  final DeleteExecutor? _deleteExecutor;

  Future<DeleteResult> delete(Set<String> ids) async {
    if (simulatedDelay != null) {
      await Future<void>.delayed(simulatedDelay!);
    }

    final executor = _deleteExecutor;
    if (executor != null) {
      try {
        await executor(ids);
        return DeleteResult(
          succeededIds: Set<String>.from(ids),
          failedIds: <String>{},
        );
      } catch (error) {
        final reason = error.toString();
        return DeleteResult(
          succeededIds: <String>{},
          failedIds: Set<String>.from(ids),
          failureReasons: {for (final id in ids) id: reason},
        );
      }
    }

    final succeededIds = <String>{};
    final failedIds = <String>{};
    final failureReasons = <String, String>{};
    for (final id in ids) {
      final ok = fakeDeleteResult[id] == true;
      if (ok) {
        succeededIds.add(id);
      } else {
        failedIds.add(id);
        failureReasons[id] = fakeFailureReasons[id] ?? 'unknown';
      }
    }

    return DeleteResult(
      succeededIds: succeededIds,
      failedIds: failedIds,
      failureReasons: failureReasons,
    );
  }
}
