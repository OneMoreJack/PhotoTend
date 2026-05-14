import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rephoto/data/mobile/mobile_media_repository.dart';
import 'package:rephoto/domain/models/album_summary_entry.dart';
import 'package:rephoto/domain/models/media_item.dart';
import 'package:rephoto/domain/services/permanent_delete_service.dart';
import 'package:rephoto/features/home/home_controller.dart';
import 'package:rephoto/features/media/media_browser_page.dart';
import 'package:rephoto/features/trash/trash_page.dart';

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
  final Set<int> _expandedYears = <int>{};
  final MobileMediaRepository _mobileMediaRepository =
      MethodChannelMobileMediaRepository();
  final Map<String, Uint8List> _mobilePreviewBytes = <String, Uint8List>{};
  final Set<String> _mobilePreviewLoadingIds = <String>{};
  bool _didApplyDefaultExpansion = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final recentEntries = widget.controller.recentAlbumSummaryEntries;
        final yearGroups = widget.controller.yearlyAlbumSummaryGroups;
        if (!_didApplyDefaultExpansion && yearGroups.isNotEmpty) {
          _expandedYears.addAll(
            yearGroups
                .where((group) => group.defaultExpanded)
                .map((group) => group.year),
          );
          _didApplyDefaultExpansion = true;
        }
        final monthEntries = yearGroups
            .expand((group) => group.months)
            .toList(growable: false);
        final onThisDay = widget.controller.onThisDayMemoryEntry;
        final mediaById = _mediaByIdForEntries([
          onThisDay,
          ...recentEntries,
          ...monthEntries,
        ]);
        final recent3 = recentEntries
            .where((entry) => entry.id == 'recent-3-days')
            .firstOrNull;
        final recent7 = recentEntries
            .where((entry) => entry.id == 'recent-7-days')
            .firstOrNull;
        return Scaffold(
          backgroundColor: const Color(0xFFF6F7F9),
          appBar: AppBar(
            backgroundColor: const Color(0xFFF6F7F9),
            elevation: 0,
            title: const Text('RePhoto'),
            actions: [
              IconButton(
                tooltip: 'Trash',
                onPressed: _openTrash,
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.delete_outline),
                    if (widget.controller.trashCount > 0)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          key: const Key('trash-badge'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          child: Text(
                            '${widget.controller.trashCount}',
                            key: const Key('trash-badge-text'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                if (widget.statusMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      widget.statusMessage!,
                      key: const Key('mobile-library-status'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
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
                    if (recent3 != null) recent3,
                    if (recent7 != null) recent7,
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
                      expanded: _expandedYears.contains(group.year),
                      onToggle: () {
                        setState(() {
                          if (!_expandedYears.add(group.year)) {
                            _expandedYears.remove(group.year);
                          }
                        });
                      },
                      onOpenMonth: (entry) => _openBrowser(context, entry),
                    ),
                ] else if (widget.statusMessage == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 64),
                    child: Text(
                      '暂无可显示的照片或视频',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
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
    final enabled = widget.onTap != null;
    final previewIds = widget.entry.previewMediaIds;
    final activeCoverId = previewIds.isEmpty
        ? widget.entry.coverMediaId
        : previewIds[_coverIndex % previewIds.length];
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: InkWell(
        key: const Key('album-memory-hero-on-this-day'),
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 184,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  child: KeyedSubtree(
                    key: Key('album-memory-cover-${activeCoverId ?? 'empty'}'),
                    child: _SummaryCover(
                      entry: widget.entry,
                      coverMediaId: activeCoverId,
                      mediaById: widget.mediaById,
                      previewBytesById: widget.previewBytesById,
                      onNeedPreview: widget.onNeedPreview,
                      dense: false,
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
                  left: 18,
                  right: 18,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '那年今日',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        enabled
                            ? '${widget.entry.totalCount} 段回忆'
                            : '还没有往年今日的照片',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
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
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E8ED)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
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
                left: 12,
                right: 12,
                bottom: 10,
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
                    const SizedBox(height: 3),
                    Text(
                      '${entry.totalCount} 项',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
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
}

abstract final class _AlbumSummaryFormatter {
  static String summaryText(AlbumSummaryEntry entry) {
    return '${entry.photoCount} 张照片 · ${entry.videoCount} 个视频 · '
        '${_formatBytes(entry.knownSizeBytes)}'
        '${entry.hasUnknownSize ? '+' : ''}';
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

class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard({
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: InkWell(
        key: Key('album-month-card-${entry.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFFFBFCFD),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8EBF0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                SizedBox(
                  key: Key('album-cover-${entry.id}'),
                  width: 76,
                  height: 76,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _SummaryCover(
                      entry: entry,
                      mediaById: mediaById,
                      previewBytesById: previewBytesById,
                      onNeedPreview: onNeedPreview,
                      dense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _AlbumSummaryFormatter.summaryText(entry),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF68707A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.black45,
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
        fit: BoxFit.cover,
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
              : const [Color(0xFFE7EEF6), Color(0xFFD7E1EA)],
        ),
      ),
      child: Center(
        child: Icon(
          isVideo ? Icons.play_circle_fill_rounded : Icons.photo_outlined,
          color: isVideo ? Colors.white : const Color(0xFF6B7684),
          size: dense ? 28 : 42,
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
    required this.expanded,
    required this.onToggle,
    required this.onOpenMonth,
  });

  final YearAlbumSummaryGroup group;
  final Map<String, MediaItem> mediaById;
  final Map<String, Uint8List> previewBytesById;
  final ValueChanged<MediaItem> onNeedPreview;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<AlbumSummaryEntry> onOpenMonth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: Column(
          children: [
            InkWell(
              key: Key('year-summary-${group.year}'),
              borderRadius: BorderRadius.circular(8),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            '${group.year}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (expanded)
              Column(
                children: [
                  const Divider(height: 1, color: Color(0xFFECEEF2)),
                  for (final entry in group.months)
                    _MonthSummaryCard(
                      entry: entry,
                      mediaById: mediaById,
                      previewBytesById: previewBytesById,
                      onNeedPreview: onNeedPreview,
                      onTap: () => onOpenMonth(entry),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
