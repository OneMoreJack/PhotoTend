class FilterState {
  const FilterState({this.timeStart, this.timeEnd, this.locationKey});

  final DateTime? timeStart;
  final DateTime? timeEnd;
  final String? locationKey;

  FilterState copyWith({
    DateTime? timeStart,
    DateTime? timeEnd,
    String? locationKey,
  }) {
    return FilterState(
      timeStart: timeStart ?? this.timeStart,
      timeEnd: timeEnd ?? this.timeEnd,
      locationKey: locationKey ?? this.locationKey,
    );
  }
}
