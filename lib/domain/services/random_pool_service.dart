import 'dart:math';

class RandomPoolService {
  RandomPoolService({int? seed}) : _random = Random(seed);

  final Random _random;
  final List<String> _all = <String>[];
  final Set<String> _seen = <String>{};
  final List<String> _remaining = <String>[];

  /// Whether the pool has items but all have been seen (exhausted).
  bool get isExhausted => _all.isNotEmpty && _remaining.isEmpty;

  void reset(List<String> ids, {bool retainSeen = false}) {
    _all
      ..clear()
      ..addAll(ids);
    if (!retainSeen) {
      _seen.clear();
    } else {
      _seen.retainWhere((id) => ids.contains(id));
    }
    final unseen = ids.where((id) => !_seen.contains(id)).toList();
    _remaining.clear();
    while (unseen.isNotEmpty) {
      final index = _random.nextInt(unseen.length);
      _remaining.add(unseen.removeAt(index));
    }
  }

  String? next() {
    if (_remaining.isEmpty) {
      return null;
    }
    final picked = _remaining.removeAt(0);
    _seen.add(picked);
    return picked;
  }

  void markConsumed(String id) {
    _seen.add(id);
    _remaining.remove(id);
  }

  bool isSeen(String id) => _seen.contains(id);

  List<String> peekNextIds({required int limit}) {
    if (limit <= 0 || _remaining.isEmpty) {
      return const <String>[];
    }
    final capped = limit.clamp(0, _remaining.length);
    return List<String>.unmodifiable(_remaining.take(capped).toList());
  }
}
