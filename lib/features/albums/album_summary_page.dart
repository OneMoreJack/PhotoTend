import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rephoto/data/mobile/mobile_media_repository.dart';
import 'package:rephoto/domain/models/album_summary_entry.dart';
import 'package:rephoto/domain/models/media_item.dart';
import 'package:rephoto/domain/services/permanent_delete_service.dart';
import 'package:rephoto/features/home/home_controller.dart';
import 'package:rephoto/features/import/import_page.dart';
import 'package:rephoto/features/media/media_browser_page.dart';
import 'package:rephoto/features/settings/settings_page.dart';
import 'package:rephoto/features/trash/trash_page.dart';
import 'package:rephoto/theme/huashu_theme.dart';

class AlbumSummaryPage extends StatefulWidget {
  const AlbumSummaryPage({
    super.key,
    required this.controller,
    this.statusMessage,
    this.deleteService,
    this.pickDirectoryPath,
    this.scanImportedDirectory,
  });

  final HomeController controller;
  final String? statusMessage;
  final PermanentDeleteService? deleteService;
  final Future<String?> Function()? pickDirectoryPath;
  final Future<List<MediaItem>> Function(String path)? scanImportedDirectory;

  @override
  State<AlbumSummaryPage> createState() => _AlbumSummaryPageState();
}

class _AlbumSummaryPageState extends State<AlbumSummaryPage> {
  final MobileMediaRepository _mobileMediaRepository =
      MethodChannelMobileMediaRepository();
  final Map<String, Uint8List> _mobilePreviewBytes = <String, Uint8List>{};
  final Set<String> _mobilePreviewLoadingIds = <String>{};

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final recentEntries = widget.controller.recentAlbumSummaryEntries;
        final yearGroups = widget.controller.yearlyAlbumSummaryGroups;
        final monthEntries = yearGroups
            .expand((group) => group.months)
            .toList(growable: false);
        final onThisDay = widget.controller.onThisDayMemoryEntry;
        final mediaById = _mediaByIdForEntries([
          onThisDay,
          ...recentEntries,
          ...monthEntries,
        ]);
        final recent7 = recentEntries
            .where((entry) => entry.id == 'recent-7-days')
            .firstOrNull;
        final allMedia = recentEntries
            .where((entry) => entry.id == 'all-media')
            .firstOrNull;
        return Scaffold(
          backgroundColor: HuashuColors.paper,
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                    children: [
                      _AlbumHomeHeader(onSettings: _openSettings),
                      if (widget.statusMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12, top: 6),
                          child: Text(
                            widget.statusMessage!,
                            key: const Key('mobile-library-status'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: HuashuColors.muted,
                            ),
                          ),
                        ),
                      _OnThisDayHeroCard(
                        entry: onThisDay,
                        mediaById: mediaById,
                        previewBytesById: _mobilePreviewBytes,
                        onNeedPreview: _ensureMobilePreviewBytes,
                        onTap: onThisDay.hasMedia
                            ? () => _openBrowser(context, onThisDay)
                            : null,
                      ),
                      _RecentShortcutSection(
                        entries: [
                          if (recent7 != null) recent7,
                          if (allMedia != null) allMedia,
                        ],
                        mediaById: mediaById,
                        previewBytesById: _mobilePreviewBytes,
                        onNeedPreview: _ensureMobilePreviewBytes,
                        onOpen: (entry) => _openBrowser(context, entry),
                      ),
                      if (yearGroups.isNotEmpty) ...[
                        for (final group in yearGroups)
                          _YearSummarySection(
                            group: group,
                            mediaById: mediaById,
                            previewBytesById: _mobilePreviewBytes,
                            onNeedPreview: _ensureMobilePreviewBytes,
                            isCompleted:
                                widget.controller.isCollectionCompleted,
                            onOpenMonth: (entry) =>
                                _openBrowser(context, entry),
                          ),
                      ] else if (widget.statusMessage == null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 64),
                          child: Text(
                            '暂无可显示的照片或视频',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: HuashuColors.muted),
                          ),
                        ),
                    ],
                  ),
                ),
                _AlbumBottomNav(
                  trashCount: widget.controller.trashCount,
                  onImport: _openImport,
                  onTrash: _openTrash,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openBrowser(
    BuildContext context,
    AlbumSummaryEntry entry,
  ) async {
    widget.controller.applyCollectionQuery(entry.query);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MediaBrowserPage(
          controller: widget.controller,
          deleteService: widget.deleteService,
          pickDirectoryPath: widget.pickDirectoryPath,
          scanImportedDirectory: widget.scanImportedDirectory,
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    final action = await Navigator.of(context).push<SettingsAction>(
      MaterialPageRoute(
        builder: (_) =>
            SettingsPage(deletionStats: widget.controller.deletionStats),
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    if (action == SettingsAction.resetRandomPool) {
      widget.controller.resetRandomPool();
    }
  }

  Future<void> _openImport() async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const ImportPage()));
  }

  Map<String, MediaItem> _mediaByIdForEntries(List<AlbumSummaryEntry> entries) {
    final ids = <String>{
      for (final entry in entries) ...[
        if (entry.coverMediaId != null) entry.coverMediaId!,
        ...entry.previewMediaIds,
      ],
    };
    return {
      for (final item in widget.controller.mediaItemsByIds(ids)) item.id: item,
    };
  }

  Future<void> _openTrash() async {
    final result = await Navigator.of(context).push<TrashPageResult>(
      MaterialPageRoute(
        builder: (_) => TrashPage(
          initialIds: widget.controller.orderedTrashIds,
          initialMediaItems: widget.controller.mediaItemsByIds(
            widget.controller.trashIds,
          ),
          deleteService: widget.deleteService,
        ),
      ),
    );
    if (result == null) {
      return;
    }
    widget.controller.recordPermanentDeletionStats(
      result.permanentlyDeletedIds,
    );
    widget.controller.updateTrash(result.trashIds);
    widget.controller.removeMediaItems(result.permanentlyDeletedIds);
  }

  Future<void> _ensureMobilePreviewBytes(MediaItem media) async {
    final pathOrUri = media.pathOrUri;
    if ((media.type != MediaType.photo && media.type != MediaType.video) ||
        pathOrUri == null ||
        !_canLoadPlatformPreview(pathOrUri) ||
        _mobilePreviewBytes.containsKey(media.id) ||
        !_mobilePreviewLoadingIds.add(media.id)) {
      return;
    }

    try {
      final bytes = await _mobileMediaRepository.fetchPreviewImageData(
        pathOrUri,
      );
      if (!mounted || bytes == null || bytes.isEmpty) {
        return;
      }
      setState(() {
        _mobilePreviewBytes[media.id] = bytes;
      });
    } on MissingPluginException {
      // Host preview loading is best-effort; placeholder remains available.
    } catch (_) {
      // Preview loading should never block the timeline.
    } finally {
      _mobilePreviewLoadingIds.remove(media.id);
    }
  }
}

class _AlbumHomeHeader extends StatelessWidget {
  const _AlbumHomeHeader({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('album-home-header'),
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'RePhoto',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: HuashuColors.ink,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          IconButton(
            key: const Key('album-settings-btn'),
            tooltip: 'Settings',
            onPressed: onSettings,
            icon: const Icon(Icons.settings_outlined),
            color: HuashuColors.inkSoft,
            iconSize: 28,
          ),
        ],
      ),
    );
  }
}

class _AlbumBottomNav extends StatelessWidget {
  const _AlbumBottomNav({
    required this.trashCount,
    required this.onImport,
    required this.onTrash,
  });

  final int trashCount;
  final VoidCallback onImport;
  final VoidCallback onTrash;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: HuashuColors.surfaceRaised.withValues(alpha: 0.96),
          border: const Border(top: BorderSide(color: HuashuColors.line)),
          boxShadow: [
            BoxShadow(
              color: HuashuColors.ink.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _AlbumNavItem(
                icon: Icons.photo_library_outlined,
                label: 'Photos',
                active: true,
                onTap: () {},
              ),
              _AlbumNavItem(
                key: const Key('album-nav-import'),
                icon: Icons.drive_folder_upload_outlined,
                label: 'Import',
                onTap: onImport,
              ),
              _AlbumNavItem(
                icon: Icons.delete_outline,
                label: 'Trash',
                badgeCount: trashCount,
                onTap: onTrash,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlbumNavItem extends StatelessWidget {
  const _AlbumNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color = active ? HuashuColors.accent : HuashuColors.inkSoft;
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 74,
          height: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 22, color: color),
                  if (badgeCount > 0)
                    Positioned(
                      right: -8,
                      top: -5,
                      child: Container(
                        key: const Key('trash-badge'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: const BoxDecoration(
                          color: HuashuColors.danger,
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        child: Text(
                          '$badgeCount',
                          key: const Key('trash-badge-text'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isPhAssetUri(String value) => value.startsWith('phasset://');
bool _isContentUri(String value) => value.startsWith('content://');
bool _isLocalFilePath(String value) {
  return !value.contains('://') || value.startsWith('file://');
}

bool _canLoadPlatformPreview(String value) {
  return _isPhAssetUri(value) ||
      _isContentUri(value) ||
      _isLocalFilePath(value);
}

class _OnThisDayHeroCard extends StatefulWidget {
  const _OnThisDayHeroCard({
    required this.entry,
    required this.mediaById,
    required this.previewBytesById,
    required this.onNeedPreview,
    required this.onTap,
  });

  final AlbumSummaryEntry entry;
  final Map<String, MediaItem> mediaById;
  final Map<String, Uint8List> previewBytesById;
  final ValueChanged<MediaItem> onNeedPreview;
  final VoidCallback? onTap;

  @override
  State<_OnThisDayHeroCard> createState() => _OnThisDayHeroCardState();
}

class _OnThisDayHeroCardState extends State<_OnThisDayHeroCard> {
  Timer? _timer;
  int _coverIndex = 0;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(_OnThisDayHeroCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.previewMediaIds != widget.entry.previewMediaIds) {
      _coverIndex = 0;
      _syncTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    if (widget.entry.previewMediaIds.length < 2) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || widget.entry.previewMediaIds.isEmpty) {
        return;
      }
      setState(() {
        _coverIndex = (_coverIndex + 1) % widget.entry.previewMediaIds.length;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final previewIds = widget.entry.previewMediaIds;
    final activeCoverId = previewIds.isEmpty
        ? widget.entry.coverMediaId
        : previewIds[_coverIndex % previewIds.length];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        key: const Key('album-memory-hero-on-this-day'),
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 164,
          decoration: BoxDecoration(
            color: HuashuColors.surfaceRaised,
            borderRadius: BorderRadius.circular(14),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  child: KeyedSubtree(
                    key: Key('album-memory-cover-${activeCoverId ?? 'empty'}'),
                    child: _MemoryPanCover(
                      entry: widget.entry,
                      coverMediaId: activeCoverId,
                      mediaById: widget.mediaById,
                      previewBytesById: widget.previewBytesById,
                      onNeedPreview: widget.onNeedPreview,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: 0.42),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 15,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'On This Day',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        '那年今日',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemoryPanCover extends StatelessWidget {
  const _MemoryPanCover({
    required this.entry,
    required this.coverMediaId,
    required this.mediaById,
    required this.previewBytesById,
    required this.onNeedPreview,
  });

  final AlbumSummaryEntry entry;
  final String? coverMediaId;
  final Map<String, MediaItem> mediaById;
  final Map<String, Uint8List> previewBytesById;
  final ValueChanged<MediaItem> onNeedPreview;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: -0.024, end: 0.024),
      duration: const Duration(seconds: 8),
      curve: Curves.easeInOutCubic,
      builder: (context, offset, child) {
        return Transform.translate(
          offset: Offset(MediaQuery.sizeOf(context).width * offset, 0),
          child: Transform.scale(scale: 1.08, child: child),
        );
      },
      child: _SummaryCover(
        entry: entry,
        coverMediaId: coverMediaId,
        mediaById: mediaById,
        previewBytesById: previewBytesById,
        onNeedPreview: onNeedPreview,
        dense: false,
      ),
    );
  }
}

class _RecentShortcutSection extends StatelessWidget {
  const _RecentShortcutSection({
    required this.entries,
    required this.mediaById,
    required this.previewBytesById,
    required this.onNeedPreview,
    required this.onOpen,
  });

  final List<AlbumSummaryEntry> entries;
  final Map<String, MediaItem> mediaById;
  final Map<String, Uint8List> previewBytesById;
  final ValueChanged<MediaItem> onNeedPreview;
  final ValueChanged<AlbumSummaryEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < entries.length; index += 1) ...[
            if (index > 0) const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 124,
                child: _RecentShortcutCard(
                  entry: entries[index],
                  mediaById: mediaById,
                  previewBytesById: previewBytesById,
                  onNeedPreview: onNeedPreview,
                  onTap: entries[index].hasMedia
                      ? () => onOpen(entries[index])
                      : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentShortcutCard extends StatelessWidget {
  const _RecentShortcutCard({
    required this.entry,
    required this.mediaById,
    required this.previewBytesById,
    required this.onNeedPreview,
    required this.onTap,
  });

  final AlbumSummaryEntry entry;
  final Map<String, MediaItem> mediaById;
  final Map<String, Uint8List> previewBytesById;
  final ValueChanged<MediaItem> onNeedPreview;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('album-recent-card-${entry.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          color: HuashuColors.surfaceRaised,
          borderRadius: BorderRadius.circular(14),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _SummaryCover(
                entry: entry,
                mediaById: mediaById,
                previewBytesById: previewBytesById,
                onNeedPreview: onNeedPreview,
                dense: true,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0),
                      Colors.black.withValues(alpha: 0.48),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _recentKicker(entry),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _recentTitle(entry),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _recentKicker(AlbumSummaryEntry entry) {
    if (entry.id == 'recent-7-days') return 'Last Week';
    if (entry.id == 'all-media') return 'Library';
    return entry.title;
  }

  String _recentTitle(AlbumSummaryEntry entry) {
    if (entry.id == 'recent-7-days') return '近一周';
    if (entry.id == 'all-media') return '所有照片';
    return entry.title;
  }
}

class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard({
    required this.entry,
    required this.mediaById,
    required this.previewBytesById,
    required this.onNeedPreview,
    required this.completed,
    required this.onTap,
  });

  final AlbumSummaryEntry entry;
  final Map<String, MediaItem> mediaById;
  final Map<String, Uint8List> previewBytesById;
  final ValueChanged<MediaItem> onNeedPreview;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: InkWell(
        key: Key('album-month-card-${entry.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 246,
          height: 154,
          decoration: BoxDecoration(
            color: HuashuColors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                KeyedSubtree(
                  key: Key('album-cover-${entry.id}'),
                  child: _SummaryCover(
                    entry: entry,
                    mediaById: mediaById,
                    previewBytesById: previewBytesById,
                    onNeedPreview: onNeedPreview,
                    dense: true,
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.02),
                        Colors.black.withValues(alpha: 0.62),
                      ],
                    ),
                  ),
                ),
                if (completed)
                  Positioned(
                    key: Key('album-month-completed-${entry.id}'),
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: HuashuColors.positive,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.done_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Done',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _AlbumSummaryStats(entry: entry),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AlbumSummaryStats extends StatelessWidget {
  const _AlbumSummaryStats({required this.entry});

  final AlbumSummaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      if (entry.photoCount > 0)
        _AlbumStatItem(
          key: Key('album-stat-photos-${entry.id}'),
          icon: Icons.photo_outlined,
          label: '${entry.photoCount}',
        ),
      if (entry.videoCount > 0)
        _AlbumStatItem(
          key: Key('album-stat-videos-${entry.id}'),
          icon: Icons.movie_creation_outlined,
          label: '${entry.videoCount}',
        ),
      if (entry.knownSizeBytes > 0)
        Flexible(
          child: _AlbumStatItem(
            key: Key('album-stat-size-${entry.id}'),
            icon: Icons.sd_storage_outlined,
            label: _AlbumSummaryFormatter.sizeText(entry),
          ),
        ),
    ];
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) const SizedBox(width: 10),
          items[index],
        ],
      ],
    );
  }
}

class _AlbumStatItem extends StatelessWidget {
  const _AlbumStatItem({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 13),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _AlbumStatItem._style,
          ),
        ),
      ],
    );
  }

  static final TextStyle _style = TextStyle(
    color: Colors.white.withValues(alpha: 0.92),
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );
}

abstract final class _AlbumSummaryFormatter {
  static String sizeText(AlbumSummaryEntry entry) {
    final size = _formatBytes(entry.knownSizeBytes);
    final suffix = entry.hasUnknownSize ? '+' : '';
    return '$size$suffix';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(kb >= 10 ? 0 : 1)} KB';
    }
    final mb = kb / 1024;
    if (mb < 1024) {
      return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB';
    }
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(gb >= 10 ? 0 : 1)} GB';
  }
}

class _SummaryCover extends StatelessWidget {
  const _SummaryCover({
    required this.entry,
    required this.mediaById,
    required this.previewBytesById,
    required this.onNeedPreview,
    required this.dense,
    this.coverMediaId,
  });

  final AlbumSummaryEntry entry;
  final String? coverMediaId;
  final Map<String, MediaItem> mediaById;
  final Map<String, Uint8List> previewBytesById;
  final ValueChanged<MediaItem> onNeedPreview;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final coverId = coverMediaId ?? entry.coverMediaId;
    final cover = coverId == null ? null : mediaById[coverId];
    final path = cover?.pathOrUri;
    final provider = _buildImageProvider(cover, path);
    if (provider != null) {
      return Image(
        image: provider,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _buildPlaceholder(cover),
      );
    }
    return _buildPlaceholder(cover);
  }

  ImageProvider<Object>? _buildImageProvider(MediaItem? cover, String? path) {
    if (cover == null || path == null || path.isEmpty) {
      return null;
    }
    final bytes = previewBytesById[cover.id];
    if (bytes != null) {
      return MemoryImage(bytes);
    }
    if (_canLoadPlatformPreview(path)) {
      if (_isPhAssetUri(path) || _isContentUri(path)) {
        onNeedPreview(cover);
        return null;
      }
      onNeedPreview(cover);
    }
    if (_isLocalFilePath(path)) {
      final localPath = path.startsWith('file://')
          ? Uri.parse(path).toFilePath()
          : path;
      return FileImage(File(localPath));
    }
    final parsed = Uri.tryParse(path);
    if (parsed != null &&
        (parsed.scheme == 'http' || parsed.scheme == 'https')) {
      return NetworkImage(path);
    }
    return null;
  }

  Widget _buildPlaceholder(MediaItem? cover) {
    final isVideo = cover?.type == MediaType.video;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isVideo
              ? const [Color(0xFF2F3540), Color(0xFF111827)]
              : const [HuashuColors.surfaceAlt, HuashuColors.line],
        ),
      ),
      child: Center(
        child: Container(
          width: dense ? 42 : 64,
          height: dense ? 42 : 64,
          decoration: BoxDecoration(
            color: isVideo
                ? Colors.white.withValues(alpha: 0.12)
                : HuashuColors.surfaceRaised.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(dense ? 12 : 18),
            border: Border.all(
              color: isVideo
                  ? Colors.white.withValues(alpha: 0.18)
                  : HuashuColors.line,
            ),
          ),
          child: Icon(
            isVideo ? Icons.play_circle_fill_rounded : Icons.photo_outlined,
            color: isVideo ? Colors.white : HuashuColors.muted,
            size: dense ? 24 : 34,
          ),
        ),
      ),
    );
  }
}

class _YearSummarySection extends StatelessWidget {
  const _YearSummarySection({
    required this.group,
    required this.mediaById,
    required this.previewBytesById,
    required this.onNeedPreview,
    required this.isCompleted,
    required this.onOpenMonth,
  });

  final YearAlbumSummaryGroup group;
  final Map<String, MediaItem> mediaById;
  final Map<String, Uint8List> previewBytesById;
  final ValueChanged<MediaItem> onNeedPreview;
  final bool Function(String id) isCompleted;
  final ValueChanged<AlbumSummaryEntry> onOpenMonth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        children: [
          Padding(
            key: Key('year-summary-${group.year}'),
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${group.year}',
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 154,
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              children: [
                for (final entry in group.months)
                  _MonthSummaryCard(
                    entry: entry,
                    mediaById: mediaById,
                    previewBytesById: previewBytesById,
                    onNeedPreview: onNeedPreview,
                    completed: isCompleted(entry.id),
                    onTap: () => onOpenMonth(entry),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
