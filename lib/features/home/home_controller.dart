import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rephoto/data/local/state_store.dart';
import 'package:rephoto/domain/models/album_summary_entry.dart';
import 'package:rephoto/domain/models/deletion_stats.dart';
import 'package:rephoto/domain/models/media_collection_query.dart';
import 'package:rephoto/domain/models/media_item.dart';
import 'package:rephoto/domain/services/filter_service.dart';
import 'package:rephoto/domain/services/gesture_session_service.dart';
import 'package:rephoto/domain/services/random_pool_service.dart';

enum TimeFilterPreset {
  all,
  today,
  last7Days,
  last30Days,
  thisMonth,
  thisYear,
  lastYear,
  custom,
}

enum BrowseMode { random, sequential }

class BrowseProgress {
  const BrowseProgress({
    required this.collectionId,
    required this.mediaId,
    required this.displayIndex,
    required this.totalCount,
    required this.media,
  });

  final String collectionId;
  final String mediaId;
  final int displayIndex;
  final int totalCount;
  final MediaItem media;
}

class HomeController extends ChangeNotifier {
  static const String unknownLocationLabel = 'Unknown Location';

  HomeController({
    List<String>? initialMediaIds,
    List<MediaItem>? initialMediaItems,
    int? seed,
    DateTime Function()? nowProvider,
    RandomPoolService? randomPoolService,
    GestureSessionService? gestureSessionService,
    StateStore? stateStore,
  }) : _allMediaItems = List<MediaItem>.from(
         initialMediaItems ??
             _buildDefaultItems(initialMediaIds ?? const ['m1', 'm2', 'm3']),
       ),
       _nowProvider = nowProvider ?? DateTime.now,
       _randomPoolService = randomPoolService ?? RandomPoolService(seed: seed),
       _gestureSessionService =
           gestureSessionService ?? GestureSessionService(),
       _stateStore = stateStore {
    _recomputeFilteredIds();
    _rebuildRandomPool();
    _showNext();
  }

  final List<MediaItem> _allMediaItems;
  final DateTime Function() _nowProvider;
  final RandomPoolService _randomPoolService;
  final GestureSessionService _gestureSessionService;
  final StateStore? _stateStore;
  final List<String> _shownHistory = <String>[];
  int _currentHistoryIndex = -1;
  String? _queuedNextMediaId;

  final Set<String> _availableLocationKeys = <String>{};
  final Set<String> _availableCountries = <String>{};
  final Set<String> _availableProvinces = <String>{};
  final Set<String> _availableCities = <String>{};
  final Set<String> _availableDistricts = <String>{};

  TimeFilterPreset selectedTimeFilter = TimeFilterPreset.all;
  DateTime? customStart;
  DateTime? customEnd;

  /// Overlay day filter applied on top of the existing time filter without
  /// modifying [selectedTimeFilter]. Used by the date chip in the photo overlay.
  DateTime? _overlayDayStart;
  DateTime? _overlayDayEnd;

  String? selectedCountry;
  String? selectedProvince;
  String? selectedCity;
  String? selectedDistrict;
  String? selectedLocationKey;

  List<String> _filteredMediaIds = <String>[];
  String? currentMediaId;
  bool _videoOnlyEnabled = false;
  BrowseMode _browseMode = BrowseMode.sequential;
  final Map<String, String?> _deviceModelCache = <String, String?>{};
  String? _activeDeviceFilter;
  String? _exactLocationKeyFilter;
  MediaCollectionQuery? _activeCollectionQuery;
  final Set<String> _completedCollectionIds = <String>{};
  DeletionStats _deletionStats = DeletionStats.empty;

  Set<String> get trashIds => _gestureSessionService.trashIds;
  int get trashCount => _gestureSessionService.trashIds.length;
  List<String> get orderedTrashIds => _gestureSessionService.trashOrderedIds;
  List<String> get filteredMediaIds => List.unmodifiable(_filteredMediaIds);
  bool get videoOnlyEnabled => _videoOnlyEnabled;
  BrowseMode get browseMode => _browseMode;
  bool get isPoolExhausted => _randomPoolService.isExhausted;
  List<String> get availableLocationKeys =>
      _availableLocationKeys.toList()..sort();
  List<String> get availableCountries => _availableCountries.toList()..sort();
  List<String> get availableProvinces => _availableProvinces.toList()..sort();
  List<String> get availableCities => _availableCities.toList()..sort();
  List<String> get availableDistricts => _availableDistricts.toList()..sort();
  List<AlbumSummaryEntry> get recentAlbumSummaryEntries {
    final now = _nowProvider();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));
    final allItems = _summarySourceItems().toList(growable: false);
    return [
      _buildSummaryEntry(
        id: 'recent-7-days',
        title: '近一周',
        start: todayStart.subtract(const Duration(days: 6)),
        end: todayEnd,
      ),
      _buildSummaryEntryFromItems(
        id: 'all-media',
        title: '所有照片',
        items: allItems,
        query: MediaCollectionQuery(
          collectionId: 'all-media',
          title: '所有照片',
          mediaIds: allItems.map((item) => item.id).toSet(),
        ),
      ),
    ];
  }

  AlbumSummaryEntry get onThisDayMemoryEntry {
    final now = _nowProvider();
    final items =
        _summarySourceItems()
            .where((item) {
              final createdAt = item.createdAt;
              if (createdAt == null || createdAt.year >= now.year) {
                return false;
              }
              return createdAt.month == now.month && createdAt.day == now.day;
            })
            .toList(growable: false)
          ..sort(_compareMediaNewestFirst);
    return _buildSummaryEntryFromItems(
      id: 'on-this-day',
      title: '那年今日',
      items: items,
      previewLimit: null,
      query: MediaCollectionQuery(
        collectionId: 'on-this-day',
        title: '那年今日',
        mediaIds: items.map((item) => item.id).toSet(),
      ),
    );
  }

  List<AlbumSummaryEntry> get monthlyAlbumSummaryEntries {
    return yearlyAlbumSummaryGroups
        .expand((group) => group.months)
        .toList(growable: false);
  }

  List<YearAlbumSummaryGroup> get yearlyAlbumSummaryGroups {
    final sourceItems = _summarySourceItems();
    final yearBuckets = <int, List<MediaItem>>{};
    final monthBuckets = <DateTime, List<MediaItem>>{};
    for (final item in sourceItems) {
      final createdAt = item.createdAt;
      if (createdAt == null) {
        continue;
      }
      yearBuckets.putIfAbsent(createdAt.year, () => <MediaItem>[]).add(item);
      final month = DateTime(createdAt.year, createdAt.month);
      monthBuckets.putIfAbsent(month, () => <MediaItem>[]).add(item);
    }

    final currentYear = _nowProvider().year;
    final years = yearBuckets.keys.toList()..sort((a, b) => b.compareTo(a));
    return years
        .map((year) {
          final yearStart = DateTime(year);
          final yearEnd = DateTime(
            year + 1,
          ).subtract(const Duration(milliseconds: 1));
          final months =
              monthBuckets.keys.where((month) => month.year == year).toList()
                ..sort((a, b) => b.compareTo(a));
          return YearAlbumSummaryGroup(
            year: year,
            summary: _buildSummaryEntry(
              id: 'year-$year',
              title: '$year',
              start: yearStart,
              end: yearEnd,
            ),
            months: months
                .map((month) {
                  final nextMonth = DateTime(month.year, month.month + 1);
                  return _buildSummaryEntry(
                    id:
                        'month-${month.year.toString().padLeft(4, '0')}-'
                        '${month.month.toString().padLeft(2, '0')}',
                    title: _monthTitle(month.month),
                    start: month,
                    end: nextMonth.subtract(const Duration(milliseconds: 1)),
                  );
                })
                .where((entry) => entry.hasMedia)
                .toList(growable: false),
            defaultExpanded: year == currentYear,
          );
        })
        .where((group) => group.summary.hasMedia)
        .toList(growable: false);
  }

  List<AlbumSummaryEntry> get albumSummaryEntries => [
    ...recentAlbumSummaryEntries,
    ...monthlyAlbumSummaryEntries,
  ];

  String? get currentDeviceModel {
    final id = currentMediaId;
    if (id == null) return null;
    return _deviceModelCache[id];
  }

  bool get hasDeviceFilter => _activeDeviceFilter != null;
  String? get activeDeviceFilter => _activeDeviceFilter;
  MediaCollectionQuery? get activeCollectionQuery => _activeCollectionQuery;
  DeletionStats get deletionStats => _deletionStats;

  bool get hasOverlayDayFilter => _overlayDayStart != null;

  bool isCollectionCompleted(String id) => _completedCollectionIds.contains(id);

  MediaItem? get currentMedia {
    final currentId = currentMediaId;
    if (currentId == null) {
      return null;
    }
    for (final item in _allMediaItems) {
      if (item.id == currentId) {
        return item;
      }
    }
    return null;
  }

  void onSwipeLeftRandom() {
    if (_browseMode == BrowseMode.sequential) {
      final nextId = _pickNextSequentialId();
      if (nextId == null) {
        if (_shouldCompleteActiveCollection()) {
          currentMediaId = null;
          _markActiveCollectionCompleted();
          _saveActiveBrowseProgress();
          notifyListeners();
        }
        return;
      }
      _moveToSequentialId(nextId);
      _saveActiveBrowseProgress();
      notifyListeners();
      return;
    }
    _showNext();
    _saveActiveBrowseProgress();
    notifyListeners();
  }

  void onSwipeRightPrevious() {
    if (_browseMode == BrowseMode.sequential) {
      final previousId = _pickPreviousSequentialId();
      if (previousId == null) {
        return;
      }
      _moveToSequentialId(previousId);
      _saveActiveBrowseProgress();
      notifyListeners();
      return;
    }
    final targetIndex = _findPreviousNavigableIndex();
    if (targetIndex == null) {
      return;
    }
    _moveToHistoryIndex(targetIndex);
    _saveActiveBrowseProgress();
    notifyListeners();
  }

  void onSwipeUpDelete() {
    final current = currentMediaId;
    if (current == null || trashIds.contains(current)) {
      return;
    }

    _gestureSessionService.onDeleteCurrent(current);
    _rebuildRandomPool(retainSeen: true);
    _showNext();
    _saveActiveBrowseProgress();
    notifyListeners();
  }

  void onSwipeDownUndoDelete() {
    final before = trashCount;
    _gestureSessionService.undoLastDelete();
    if (trashCount != before) {
      _rebuildRandomPool(retainSeen: true);
      notifyListeners();
    }
  }

  void resetRandomPool() {
    _rebuildRandomPool();
    if (currentMediaId == null) {
      _showNext();
    }
    notifyListeners();
  }

  void resetAllFiltersAndRestart() {
    selectedTimeFilter = TimeFilterPreset.all;
    customStart = null;
    customEnd = null;
    _overlayDayStart = null;
    _overlayDayEnd = null;
    selectedCountry = null;
    selectedProvince = null;
    selectedCity = null;
    selectedDistrict = null;
    selectedLocationKey = null;
    _activeDeviceFilter = null;
    _exactLocationKeyFilter = null;
    _videoOnlyEnabled = false;
    _applyFilters();
  }

  void updateTrash(Set<String> ids) {
    _gestureSessionService.syncTrash(ids);
    _rebuildRandomPool(retainSeen: true);
    if (currentMediaId != null && ids.contains(currentMediaId)) {
      _showNext();
    }
    notifyListeners();
  }

  void replaceMediaItems(List<MediaItem> items) {
    _allMediaItems
      ..clear()
      ..addAll(items);
    _shownHistory.clear();
    _currentHistoryIndex = -1;
    currentMediaId = null;
    _applyFilters();
  }

  /// Append new media items without resetting current display or history.
  void addMediaItems(List<MediaItem> items) {
    final existingIds = _allMediaItems.map((e) => e.id).toSet();
    final newItems = items
        .where((item) => !existingIds.contains(item.id))
        .toList();
    if (newItems.isEmpty) return;
    _allMediaItems.addAll(newItems);
    _recomputeFilteredIds();
    _rebuildRandomPool(retainSeen: true);
    // If nothing is showing yet, show the first item
    if (currentMediaId == null) {
      _showNext();
    }
    notifyListeners();
  }

  void updateMediaLocationKeys(Map<String, String> locationKeysById) {
    if (locationKeysById.isEmpty) return;
    var changed = false;
    for (var i = 0; i < _allMediaItems.length; i += 1) {
      final item = _allMediaItems[i];
      final key = locationKeysById[item.id];
      if (key == null || key.isEmpty || key == item.locationKey) {
        continue;
      }
      _allMediaItems[i] = MediaItem(
        id: item.id,
        type: item.type,
        createdAt: item.createdAt,
        locationKey: key,
        pathOrUri: item.pathOrUri,
        sizeBytes: item.sizeBytes,
      );
      changed = true;
    }
    if (!changed) return;
    _applyFiltersKeepingCurrent();
  }

  void removeMediaItems(Set<String> ids) {
    if (ids.isEmpty) {
      return;
    }

    final before = _allMediaItems.length;
    _allMediaItems.removeWhere((item) => ids.contains(item.id));
    if (_allMediaItems.length == before) {
      return;
    }

    _gestureSessionService.trashIds.removeWhere(ids.contains);
    _gestureSessionService.syncTrash(_gestureSessionService.trashIds);
    _applyFilters();
  }

  void toggleVideoOnlyMode() {
    _videoOnlyEnabled = !_videoOnlyEnabled;
    _applyFilters();
  }

  void setDeviceModelForId(String id, String? model) {
    _deviceModelCache[id] = model;
    notifyListeners();
  }

  void updateDeviceModelCache(Map<String, String?> models) {
    _deviceModelCache.addAll(models);
    notifyListeners();
  }

  bool hasDeviceModelCached(String id) {
    return _deviceModelCache.containsKey(id);
  }

  void applyDeviceFilterKeepingCurrent(String deviceModel) {
    _activeDeviceFilter = deviceModel;
    _applyFiltersKeepingCurrent();
  }

  void clearDeviceFilter() {
    _activeDeviceFilter = null;
    _applyFiltersKeepingCurrent();
  }

  /// Apply an overlay day filter for [date] without changing [selectedTimeFilter].
  void applyOverlayDayFilter(DateTime date) {
    _overlayDayStart = DateTime(date.year, date.month, date.day);
    _overlayDayEnd = _overlayDayStart!
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));
    _applyFiltersKeepingCurrent();
  }

  /// Clear the overlay day filter without changing [selectedTimeFilter].
  void clearOverlayDayFilter() {
    _overlayDayStart = null;
    _overlayDayEnd = null;
    _applyFiltersKeepingCurrent();
  }

  void toggleBrowseMode() {
    _browseMode = _browseMode == BrowseMode.random
        ? BrowseMode.sequential
        : BrowseMode.random;
    _queuedNextMediaId = null;
    notifyListeners();
  }

  void setTimeFilter(TimeFilterPreset preset) {
    selectedTimeFilter = preset;
    if (preset != TimeFilterPreset.custom) {
      customStart = null;
      customEnd = null;
    }
    _applyFilters();
  }

  void setCustomDateRange(DateTime? start, DateTime? end) {
    selectedTimeFilter = TimeFilterPreset.custom;
    customStart = start;
    customEnd = end;
    _applyFilters();
  }

  void applyCollectionQuery(MediaCollectionQuery query) {
    _activeCollectionQuery = query;
    _applyFilters();
  }

  void clearCollectionQuery() {
    _activeCollectionQuery = null;
    _applyFilters();
  }

  void recordPermanentDeletionStats(Set<String> ids) {
    if (ids.isEmpty) {
      return;
    }
    final items = mediaItemsByIds(ids);
    if (items.isEmpty) {
      return;
    }
    _deletionStats = _deletionStats.add(DeletionStats.fromItems(items));
    unawaited(_stateStore?.saveDeletionStats(_deletionStats));
    notifyListeners();
  }

  Future<void> restoreDeletionStats() async {
    final stats = await _stateStore?.loadDeletionStats();
    if (stats == null) {
      return;
    }
    _deletionStats = stats;
    notifyListeners();
  }

  void jumpToMedia(String id) {
    if (!_isNavigableId(id)) {
      return;
    }
    _shownHistory.removeRange(_currentHistoryIndex + 1, _shownHistory.length);
    if (_shownHistory.isEmpty || _shownHistory.last != id) {
      _shownHistory.add(id);
    }
    _currentHistoryIndex = _shownHistory.length - 1;
    _gestureSessionService.onShown(id);
    _randomPoolService.markConsumed(id);
    currentMediaId = id;
    _queuedNextMediaId = null;
    _saveActiveBrowseProgress();
    notifyListeners();
  }

  Future<BrowseProgress?> loadActiveBrowseProgress() async {
    final collectionId = _activeCollectionQuery?.collectionId;
    if (!_canPersistBrowseProgressFor(collectionId)) {
      return null;
    }
    final mediaId = await _stateStore?.loadBrowseProgress(collectionId!);
    if (mediaId == null ||
        mediaId == currentMediaId ||
        !_isNavigableId(mediaId)) {
      return null;
    }
    final media = mediaItemsByIds({mediaId}).firstOrNull;
    if (media == null) {
      return null;
    }
    final availableIds = _filteredMediaIds
        .where((id) => !trashIds.contains(id))
        .toList(growable: false);
    final index = availableIds.indexOf(mediaId);
    if (index < 0) {
      return null;
    }
    if (_completedCollectionIds.contains(collectionId) &&
        index == availableIds.length - 1) {
      return null;
    }
    return BrowseProgress(
      collectionId: collectionId!,
      mediaId: mediaId,
      displayIndex: index + 1,
      totalCount: availableIds.length,
      media: media,
    );
  }

  void setCountry(String? country) {
    _exactLocationKeyFilter = null;
    selectedCountry = country;
    selectedProvince = null;
    selectedCity = null;
    selectedDistrict = null;
    _applyFilters();
  }

  void setProvince(String? province) {
    _exactLocationKeyFilter = null;
    selectedProvince = province;
    selectedCity = null;
    selectedDistrict = null;
    _applyFilters();
  }

  void setCity(String? city) {
    _exactLocationKeyFilter = null;
    selectedCity = city;
    selectedDistrict = null;
    _applyFilters();
  }

  void setDistrict(String? district) {
    _exactLocationKeyFilter = null;
    selectedDistrict = district;
    _applyFilters();
  }

  void setLocationFilter(String? locationKey) {
    if (locationKey == null) {
      _exactLocationKeyFilter = null;
      selectedCountry = null;
      selectedProvince = null;
      selectedCity = null;
      selectedDistrict = null;
      _applyFilters();
      return;
    }

    if (locationKey == unknownLocationLabel) {
      _exactLocationKeyFilter = null;
      selectedCountry = unknownLocationLabel;
      selectedProvince = null;
      selectedCity = null;
      selectedDistrict = null;
      _applyFilters();
      return;
    }

    final parts = _LocationPath.parse(locationKey);
    if (parts.isUnknown || parts.country == null) {
      _exactLocationKeyFilter = null;
      selectedCountry = unknownLocationLabel;
      selectedProvince = null;
      selectedCity = null;
      selectedDistrict = null;
      _applyFilters();
      return;
    }
    _exactLocationKeyFilter = locationKey;
    selectedCountry = parts.country;
    selectedProvince = parts.province;
    selectedCity = parts.city;
    selectedDistrict = parts.district;
    _applyFilters();
  }

  void applyCurrentDayFilter() {
    final media = currentMedia;
    final timestamp = media?.createdAt;
    if (timestamp == null) {
      return;
    }

    final dayStart = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final dayEnd = dayStart
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));
    setCustomDateRange(dayStart, dayEnd);
  }

  void applyCurrentDayFilterKeepingCurrent() {
    final media = currentMedia;
    final timestamp = media?.createdAt;
    if (timestamp == null) {
      return;
    }

    final dayStart = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final dayEnd = dayStart
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));
    selectedTimeFilter = TimeFilterPreset.custom;
    customStart = dayStart;
    customEnd = dayEnd;
    _applyFiltersKeepingCurrent();
  }

  void applyCurrentLocationFilterKeepingCurrent() {
    final mediaLocation = currentMedia?.locationKey;
    final key = mediaLocation ?? unknownLocationLabel;
    if (key == unknownLocationLabel) {
      _exactLocationKeyFilter = null;
      selectedCountry = unknownLocationLabel;
      selectedProvince = null;
      selectedCity = null;
      selectedDistrict = null;
    } else {
      final parts = _LocationPath.parse(key);
      if (parts.isUnknown || parts.country == null) {
        _exactLocationKeyFilter = null;
        selectedCountry = unknownLocationLabel;
        selectedProvince = null;
        selectedCity = null;
        selectedDistrict = null;
      } else {
        _exactLocationKeyFilter = mediaLocation;
        selectedCountry = parts.country;
        selectedProvince = parts.province;
        selectedCity = parts.city;
        selectedDistrict = parts.district;
      }
    }
    _applyFiltersKeepingCurrent();
  }

  void applyCurrentLocationFilter() {
    final mediaLocation = currentMedia?.locationKey;
    setLocationFilter(mediaLocation ?? unknownLocationLabel);
  }

  List<MediaItem> mediaItemsByIds(Set<String> ids) {
    if (ids.isEmpty) {
      return const <MediaItem>[];
    }
    return _allMediaItems.where((item) => ids.contains(item.id)).toList();
  }

  MediaItem? prepareUpcomingMediaForPreload() {
    final upcoming = prepareUpcomingMediaForPreloadQueue(limit: 1);
    if (upcoming.isEmpty) {
      return null;
    }
    return upcoming.first;
  }

  List<MediaItem> prepareUpcomingMediaForPreloadQueue({int limit = 1}) {
    final upcomingIds = _peekUpcomingIds(limit: limit);
    if (upcomingIds.isEmpty) {
      return const <MediaItem>[];
    }
    final mediaById = <String, MediaItem>{
      for (final item in _allMediaItems) item.id: item,
    };
    return upcomingIds
        .map((id) => mediaById[id])
        .whereType<MediaItem>()
        .toList(growable: false);
  }

  MediaItem? preparePreviousMediaForPreload() {
    final previousIndex = _findPreviousNavigableIndex();
    if (previousIndex == null) {
      return null;
    }
    final previousId = _shownHistory[previousIndex];
    for (final item in _allMediaItems) {
      if (item.id == previousId) {
        return item;
      }
    }
    return null;
  }

  DateTimeRangeValues _effectiveTimeRange() {
    final now = _nowProvider();
    switch (selectedTimeFilter) {
      case TimeFilterPreset.all:
        return const DateTimeRangeValues(null, null);
      case TimeFilterPreset.today:
        final start = DateTime(now.year, now.month, now.day);
        final end = start
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1));
        return DateTimeRangeValues(start, end);
      case TimeFilterPreset.last7Days:
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        final start = end.subtract(const Duration(days: 6));
        return DateTimeRangeValues(start, end);
      case TimeFilterPreset.last30Days:
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        final start = end.subtract(const Duration(days: 29));
        return DateTimeRangeValues(start, end);
      case TimeFilterPreset.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(
          now.year,
          now.month + 1,
          1,
        ).subtract(const Duration(milliseconds: 1));
        return DateTimeRangeValues(start, end);
      case TimeFilterPreset.thisYear:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(
          now.year + 1,
          1,
          1,
        ).subtract(const Duration(milliseconds: 1));
        return DateTimeRangeValues(start, end);
      case TimeFilterPreset.lastYear:
        final start = DateTime(now.year - 1, 1, 1);
        final end = DateTime(
          now.year,
          1,
          1,
        ).subtract(const Duration(milliseconds: 1));
        return DateTimeRangeValues(start, end);
      case TimeFilterPreset.custom:
        return DateTimeRangeValues(customStart, customEnd);
    }
  }

  void _applyFilters() {
    _recomputeFilteredIds();
    _shownHistory.clear();
    _currentHistoryIndex = -1;
    currentMediaId = null;
    _rebuildRandomPool();
    _startFromFirstFilteredMedia();
    notifyListeners();
  }

  void _applyFiltersKeepingCurrent() {
    final savedId = currentMediaId;
    _recomputeFilteredIds();
    _rebuildRandomPool(retainSeen: true);
    // If the current media is still in the filtered set, keep it
    if (savedId != null &&
        _filteredMediaIds.contains(savedId) &&
        !trashIds.contains(savedId)) {
      currentMediaId = savedId;
      // Mark it as consumed so it won't repeat
      _randomPoolService.markConsumed(savedId);
    } else {
      _shownHistory.clear();
      _currentHistoryIndex = -1;
      currentMediaId = null;
      _startFromFirstFilteredMedia();
    }
    notifyListeners();
  }

  void _startFromFirstFilteredMedia() {
    _queuedNextMediaId = null;
    for (final id in _filteredMediaIds) {
      if (!_isNavigableId(id)) {
        continue;
      }
      _shownHistory.add(id);
      _currentHistoryIndex = _shownHistory.length - 1;
      _gestureSessionService.onShown(id);
      _randomPoolService.markConsumed(id);
      currentMediaId = id;
      return;
    }
    currentMediaId = null;
  }

  List<String> _peekUpcomingIds({required int limit}) {
    if (limit <= 0) {
      return const <String>[];
    }

    final upcoming = <String>[];
    final excluded = <String>{};
    final forwardIndex = _findNextNavigableIndex();
    if (forwardIndex != null) {
      final id = _shownHistory[forwardIndex];
      upcoming.add(id);
      excluded.add(id);
    } else {
      final nextId = _ensureQueuedNextId();
      if (nextId != null) {
        upcoming.add(nextId);
        excluded.add(nextId);
      }
    }

    if (upcoming.length >= limit) {
      return upcoming;
    }

    if (_browseMode == BrowseMode.random) {
      final remaining = _randomPoolService.peekNextIds(
        limit: limit - upcoming.length,
      );
      for (final id in remaining) {
        if (excluded.add(id)) {
          upcoming.add(id);
        }
      }
      return upcoming;
    }

    upcoming.addAll(
      _peekSequentialIds(limit: limit - upcoming.length, excludedIds: excluded),
    );
    return upcoming;
  }

  List<String> _peekSequentialIds({
    required int limit,
    required Set<String> excludedIds,
  }) {
    if (limit <= 0 || _filteredMediaIds.isEmpty) {
      return const <String>[];
    }

    final upcoming = <String>[];
    final startId = excludedIds.isNotEmpty ? excludedIds.last : currentMediaId;
    final currentIndex = startId != null
        ? _filteredMediaIds.indexOf(startId)
        : -1;

    for (
      var i = 1;
      i <= _filteredMediaIds.length && upcoming.length < limit;
      i += 1
    ) {
      final nextIndex = (currentIndex + i) % _filteredMediaIds.length;
      final candidate = _filteredMediaIds[nextIndex];
      if (!_isNavigableId(candidate) || !excludedIds.add(candidate)) {
        continue;
      }
      upcoming.add(candidate);
    }
    return upcoming;
  }

  void _recomputeFilteredIds() {
    final range = _effectiveTimeRange();
    final timeStart = _laterDate(
      range.start,
      _activeCollectionQuery?.timeStart,
    );
    final timeEnd = _earlierDate(range.end, _activeCollectionQuery?.timeEnd);
    final timeFiltered = FilterService.apply(
      _allMediaItems,
      timeStart: timeStart,
      timeEnd: timeEnd,
    );

    final pathsById = {
      for (final item in timeFiltered)
        item.id: _LocationPath.parse(item.locationKey),
    };
    final knownPaths = pathsById.values
        .where((path) => !path.isUnknown)
        .toList();
    final hasUnknown = pathsById.values.any((path) => path.isUnknown);

    _availableLocationKeys
      ..clear()
      ..addAll(
        knownPaths.map((path) => path.normalizedKey).whereType<String>(),
      );
    if (hasUnknown) {
      _availableLocationKeys.add(unknownLocationLabel);
    }

    _availableCountries
      ..clear()
      ..addAll(knownPaths.map((path) => path.country).whereType<String>());
    if (hasUnknown) {
      _availableCountries.add(unknownLocationLabel);
    }

    if (selectedCountry != null &&
        !_availableCountries.contains(selectedCountry)) {
      selectedCountry = null;
      selectedProvince = null;
      selectedCity = null;
      selectedDistrict = null;
    }

    final countryScoped = knownPaths.where((path) {
      if (selectedCountry == null || selectedCountry == unknownLocationLabel) {
        return true;
      }
      return path.country == selectedCountry;
    }).toList();

    _availableProvinces
      ..clear()
      ..addAll(countryScoped.map((path) => path.province).whereType<String>());
    if (selectedProvince != null &&
        !_availableProvinces.contains(selectedProvince)) {
      selectedProvince = null;
      selectedCity = null;
      selectedDistrict = null;
    }

    final provinceScoped = countryScoped.where((path) {
      if (selectedProvince == null) {
        return true;
      }
      return path.province == selectedProvince;
    }).toList();

    _availableCities
      ..clear()
      ..addAll(provinceScoped.map((path) => path.city).whereType<String>());
    if (selectedCity != null && !_availableCities.contains(selectedCity)) {
      selectedCity = null;
      selectedDistrict = null;
    }

    final cityScoped = provinceScoped.where((path) {
      if (selectedCity == null) {
        return true;
      }
      return path.city == selectedCity;
    }).toList();

    _availableDistricts
      ..clear()
      ..addAll(cityScoped.map((path) => path.district).whereType<String>());
    if (selectedDistrict != null &&
        !_availableDistricts.contains(selectedDistrict)) {
      selectedDistrict = null;
    }

    final locationFiltered = timeFiltered.where((item) {
      if (_exactLocationKeyFilter != null) {
        return item.locationKey == _exactLocationKeyFilter;
      }
      final path = pathsById[item.id]!;
      if (selectedCountry == null) {
        return true;
      }
      if (selectedCountry == unknownLocationLabel) {
        return path.isUnknown;
      }
      if (path.isUnknown || path.country != selectedCountry) {
        return false;
      }
      if (selectedProvince != null && path.province != selectedProvince) {
        return false;
      }
      if (selectedCity != null && path.city != selectedCity) {
        return false;
      }
      if (selectedDistrict != null && path.district != selectedDistrict) {
        return false;
      }
      return true;
    }).toList();

    selectedLocationKey = _composeSelectedLocationKey();
    final mediaFiltered = _videoOnlyEnabled
        ? locationFiltered
              .where((item) => item.type == MediaType.video)
              .toList()
        : locationFiltered;
    var finalIds = mediaFiltered.map((item) => item.id).toList();
    if (_activeDeviceFilter != null) {
      finalIds = finalIds.where((id) {
        final cached = _deviceModelCache[id];
        return cached == _activeDeviceFilter;
      }).toList();
    }
    final collectionIds = _activeCollectionQuery?.mediaIds;
    if (collectionIds != null) {
      finalIds = finalIds.where(collectionIds.contains).toList();
    }
    // Apply overlay day filter (independent from time filter bar)
    final overlayStart = _overlayDayStart;
    final overlayEnd = _overlayDayEnd;
    if (overlayStart != null && overlayEnd != null) {
      final idSet = finalIds.toSet();
      finalIds = _allMediaItems
          .where((item) {
            if (!idSet.contains(item.id)) return false;
            final t = item.createdAt;
            if (t == null) return false;
            return !t.isBefore(overlayStart) && !t.isAfter(overlayEnd);
          })
          .map((item) => item.id)
          .toList();
    }
    if (_activeCollectionQuery != null) {
      final itemById = {for (final item in _allMediaItems) item.id: item};
      finalIds.sort((a, b) {
        final left = itemById[a];
        final right = itemById[b];
        final leftDate = left?.createdAt;
        final rightDate = right?.createdAt;
        if (leftDate == null && rightDate == null) {
          return a.compareTo(b);
        }
        if (leftDate == null) {
          return 1;
        }
        if (rightDate == null) {
          return -1;
        }
        final dateCompare = rightDate.compareTo(leftDate);
        if (dateCompare != 0) {
          return dateCompare;
        }
        return a.compareTo(b);
      });
    }
    _filteredMediaIds = finalIds;
  }

  void _showNext() {
    final forwardIndex = _findNextNavigableIndex();
    if (forwardIndex != null) {
      _moveToHistoryIndex(forwardIndex);
      return;
    }

    final next = _consumeQueuedOrPickNextId();
    if (next == null) {
      if (_shouldCompleteActiveCollection()) {
        currentMediaId = null;
        _markActiveCollectionCompleted();
        return;
      }
      if (currentMediaId != null && _isNavigableId(currentMediaId!)) {
        return;
      }
      currentMediaId = null;
      return;
    }

    _shownHistory.removeRange(_currentHistoryIndex + 1, _shownHistory.length);
    _shownHistory.add(next);
    _currentHistoryIndex = _shownHistory.length - 1;
    _gestureSessionService.onShown(next);
    currentMediaId = next;
  }

  void _rebuildRandomPool({bool retainSeen = false}) {
    final queued = _queuedNextMediaId;
    final availableIds = _filteredMediaIds
        .where((id) => !trashIds.contains(id))
        .toList();
    _randomPoolService.reset(availableIds, retainSeen: retainSeen);
    if (retainSeen &&
        queued != null &&
        availableIds.contains(queued) &&
        _isNavigableId(queued)) {
      _queuedNextMediaId = queued;
    } else {
      _queuedNextMediaId = null;
    }
  }

  int? _findPreviousNavigableIndex() {
    if (_shownHistory.isEmpty) {
      return null;
    }
    // If current media is null (e.g. at the end of photos card), swiping back
    // should show the last photo in history, which is at _currentHistoryIndex.
    var startIndex = currentMediaId == null
        ? _currentHistoryIndex
        : _currentHistoryIndex - 1;

    for (var index = startIndex; index >= 0; index -= 1) {
      if (_isNavigableId(_shownHistory[index])) {
        return index;
      }
    }
    return null;
  }

  int? _findNextNavigableIndex() {
    if (_shownHistory.isEmpty ||
        _currentHistoryIndex >= _shownHistory.length - 1) {
      return null;
    }
    for (
      var index = _currentHistoryIndex + 1;
      index < _shownHistory.length;
      index += 1
    ) {
      if (_isNavigableId(_shownHistory[index])) {
        return index;
      }
    }
    return null;
  }

  String? _consumeQueuedOrPickNextId() {
    final queued = _ensureQueuedNextId();
    _queuedNextMediaId = null;
    return queued;
  }

  String? _ensureQueuedNextId() {
    final queued = _queuedNextMediaId;
    if (queued != null && _isNavigableId(queued)) {
      return queued;
    }
    _queuedNextMediaId = null;

    final next = _browseMode == BrowseMode.random
        ? _pickNextRandomId()
        : _pickNextSequentialId();
    if (next == null) {
      return null;
    }
    _queuedNextMediaId = next;
    return next;
  }

  String? _pickNextRandomId() {
    final maxAttempts = _filteredMediaIds.length * 2;
    for (var i = 0; i < maxAttempts; i += 1) {
      final candidate = _randomPoolService.next();
      if (candidate == null) {
        return null;
      }
      if (!_isNavigableId(candidate)) {
        continue;
      }
      return candidate;
    }
    return null;
  }

  String? _pickNextSequentialId() {
    final availableIds = _filteredMediaIds
        .where((id) => !trashIds.contains(id))
        .toList();
    if (availableIds.isEmpty) {
      return null;
    }

    // We want to find the next valid ID after currentMediaId in the raw filtered list.
    final targetId = currentMediaId;
    final currentIndex = targetId != null
        ? _filteredMediaIds.indexOf(targetId)
        : -1;

    final shouldWrap = _activeCollectionQuery?.collectionId == null;
    final maxSteps = shouldWrap
        ? _filteredMediaIds.length
        : _filteredMediaIds.length - currentIndex - 1;

    for (var i = 1; i <= maxSteps; i++) {
      final nextIndex = shouldWrap
          ? (currentIndex + i) % _filteredMediaIds.length
          : currentIndex + i;
      final candidate = _filteredMediaIds[nextIndex];
      if (_isNavigableId(candidate)) {
        _randomPoolService.markConsumed(candidate);
        return candidate;
      }
    }

    return null;
  }

  String? _pickPreviousSequentialId() {
    final availableIds = _filteredMediaIds
        .where((id) => !trashIds.contains(id))
        .toList();
    if (availableIds.isEmpty) {
      return null;
    }

    final targetId = currentMediaId;
    final currentIndex = targetId != null
        ? _filteredMediaIds.indexOf(targetId)
        : _filteredMediaIds.length;
    if (currentIndex < 0) {
      return null;
    }

    final shouldWrap = _activeCollectionQuery?.collectionId == null;
    final maxSteps = shouldWrap ? _filteredMediaIds.length : currentIndex;

    for (var i = 1; i <= maxSteps; i++) {
      final previousIndex = shouldWrap
          ? (currentIndex - i) % _filteredMediaIds.length
          : currentIndex - i;
      final candidate = _filteredMediaIds[previousIndex];
      if (_isNavigableId(candidate)) {
        _randomPoolService.markConsumed(candidate);
        return candidate;
      }
    }

    return null;
  }

  void _moveToSequentialId(String id) {
    _shownHistory.removeRange(_currentHistoryIndex + 1, _shownHistory.length);
    if (_shownHistory.isEmpty || _shownHistory.last != id) {
      _shownHistory.add(id);
    }
    _currentHistoryIndex = _shownHistory.length - 1;
    _gestureSessionService.onShown(id);
    _randomPoolService.markConsumed(id);
    currentMediaId = id;
    _queuedNextMediaId = null;
  }

  bool _shouldCompleteActiveCollection() {
    final collectionId = _activeCollectionQuery?.collectionId;
    return collectionId != null &&
        collectionId.startsWith('month-') &&
        currentMediaId != null;
  }

  void _markActiveCollectionCompleted() {
    final collectionId = _activeCollectionQuery?.collectionId;
    if (collectionId == null || !collectionId.startsWith('month-')) {
      return;
    }
    _completedCollectionIds.add(collectionId);
  }

  void _saveActiveBrowseProgress() {
    final collectionId = _activeCollectionQuery?.collectionId;
    final mediaId = currentMediaId;
    if (!_canPersistBrowseProgressFor(collectionId) || mediaId == null) {
      return;
    }
    unawaited(_stateStore?.saveBrowseProgress(collectionId!, mediaId));
  }

  bool _canPersistBrowseProgressFor(String? collectionId) {
    return collectionId != null && collectionId.startsWith('month-');
  }

  bool _isNavigableId(String id) {
    return !trashIds.contains(id) && _filteredMediaIds.contains(id);
  }

  void _moveToHistoryIndex(int index) {
    _currentHistoryIndex = index;
    currentMediaId = _shownHistory[index];
  }

  String? _composeSelectedLocationKey() {
    if (_exactLocationKeyFilter != null) {
      return _exactLocationKeyFilter;
    }
    if (selectedCountry == null) {
      return null;
    }
    if (selectedCountry == unknownLocationLabel) {
      return unknownLocationLabel;
    }
    return <String>[
      selectedCountry!,
      if (selectedProvince != null) selectedProvince!,
      if (selectedCity != null) selectedCity!,
      if (selectedDistrict != null) selectedDistrict!,
    ].join('/');
  }

  static List<MediaItem> _buildDefaultItems(List<String> ids) {
    final now = DateTime.now();
    return List<MediaItem>.generate(ids.length, (index) {
      final id = ids[index];
      return MediaItem(
        id: id,
        type: index.isEven ? MediaType.photo : MediaType.video,
        createdAt: now.subtract(Duration(days: index * 5)),
        locationKey: switch (index % 3) {
          0 => 'CN/SH/SHC/XH',
          1 => 'CN/BJ/BJC/HD',
          _ => 'US/CA/SF/SOMA',
        },
      );
    });
  }

  List<MediaItem> _summarySourceItems() {
    return _allMediaItems
        .where((item) => !trashIds.contains(item.id))
        .toList(growable: false);
  }

  AlbumSummaryEntry _buildSummaryEntry({
    required String id,
    required String title,
    required DateTime start,
    required DateTime end,
  }) {
    final items = _summarySourceItems()
        .where((item) {
          final createdAt = item.createdAt;
          if (createdAt == null) {
            return false;
          }
          return !createdAt.isBefore(start) && !createdAt.isAfter(end);
        })
        .toList(growable: false);

    return _buildSummaryEntryFromItems(
      id: id,
      title: title,
      items: items,
      query: MediaCollectionQuery(
        collectionId: id,
        title: title,
        timeStart: start,
        timeEnd: end,
      ),
    );
  }

  AlbumSummaryEntry _buildSummaryEntryFromItems({
    required String id,
    required String title,
    required List<MediaItem> items,
    required MediaCollectionQuery query,
    int? previewLimit = 4,
  }) {
    var photoCount = 0;
    var videoCount = 0;
    var knownSizeBytes = 0;
    var hasUnknownSize = false;
    final displayItems = List<MediaItem>.from(items)
      ..sort(_compareMediaNewestFirst);
    for (final item in items) {
      switch (item.type) {
        case MediaType.photo:
          photoCount += 1;
        case MediaType.video:
          videoCount += 1;
      }
      final sizeBytes = item.sizeBytes;
      if (sizeBytes == null) {
        hasUnknownSize = true;
      } else {
        knownSizeBytes += sizeBytes;
      }
    }
    final cover = _selectSummaryCover(displayItems);

    return AlbumSummaryEntry(
      id: id,
      title: title,
      query: query,
      photoCount: photoCount,
      videoCount: videoCount,
      knownSizeBytes: knownSizeBytes,
      hasUnknownSize: hasUnknownSize,
      coverMediaId: cover?.id,
      previewMediaIds:
          (previewLimit == null
                  ? displayItems
                  : displayItems.take(previewLimit))
              .map((item) => item.id)
              .toList(growable: false),
    );
  }

  MediaItem? _selectSummaryCover(List<MediaItem> items) {
    if (items.isEmpty) {
      return null;
    }
    MediaItem? firstPhoto;
    MediaItem? firstVideo;
    for (final item in items) {
      switch (item.type) {
        case MediaType.photo:
          firstPhoto ??= item;
          final path = item.pathOrUri;
          if (path != null && path.isNotEmpty) {
            return item;
          }
        case MediaType.video:
          firstVideo ??= item;
      }
    }
    return firstPhoto ?? firstVideo;
  }

  static int _compareMediaNewestFirst(MediaItem left, MediaItem right) {
    final leftDate = left.createdAt;
    final rightDate = right.createdAt;
    if (leftDate == null && rightDate == null) {
      return left.id.compareTo(right.id);
    }
    if (leftDate == null) {
      return 1;
    }
    if (rightDate == null) {
      return -1;
    }
    final dateCompare = rightDate.compareTo(leftDate);
    if (dateCompare != 0) {
      return dateCompare;
    }
    return left.id.compareTo(right.id);
  }

  static String _monthTitle(int month) {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    if (month < 1 || month > 12) {
      return '$month月';
    }
    return monthNames[month - 1];
  }

  DateTime? _laterDate(DateTime? a, DateTime? b) {
    if (a == null) {
      return b;
    }
    if (b == null) {
      return a;
    }
    return a.isAfter(b) ? a : b;
  }

  DateTime? _earlierDate(DateTime? a, DateTime? b) {
    if (a == null) {
      return b;
    }
    if (b == null) {
      return a;
    }
    return a.isBefore(b) ? a : b;
  }
}

class DateTimeRangeValues {
  const DateTimeRangeValues(this.start, this.end);

  final DateTime? start;
  final DateTime? end;
}

class _LocationPath {
  const _LocationPath({
    required this.isUnknown,
    this.country,
    this.province,
    this.city,
    this.district,
    this.normalizedKey,
  });

  final bool isUnknown;
  final String? country;
  final String? province;
  final String? city;
  final String? district;
  final String? normalizedKey;

  factory _LocationPath.parse(String? raw) {
    final input = raw?.trim();
    if (input == null || input.isEmpty) {
      return const _LocationPath(isUnknown: true);
    }
    final segments = input
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.isEmpty) {
      return const _LocationPath(isUnknown: true);
    }
    if (segments.first.toLowerCase() == 'geo') {
      final province = segments.length > 1 ? segments[1] : null;
      final city = segments.length > 2 ? segments[2] : null;
      final district = segments.length > 3 ? segments[3] : null;
      final normalized = <String>[
        'geo',
        if (province != null) province,
        if (city != null) city,
        if (district != null) district,
      ].join('/');
      return _LocationPath(
        isUnknown: false,
        country: 'geo',
        province: province,
        city: city,
        district: district,
        normalizedKey: normalized,
      );
    }

    final country = segments[0];
    final province = segments.length > 1 ? segments[1] : null;
    final city = segments.length > 2 ? segments[2] : null;
    final district = segments.length > 3 ? segments[3] : null;
    final normalized = <String>[
      country,
      if (province != null) province,
      if (city != null) city,
      if (district != null) district,
    ].join('/');

    return _LocationPath(
      isUnknown: false,
      country: country,
      province: province,
      city: city,
      district: district,
      normalizedKey: normalized,
    );
  }
}
