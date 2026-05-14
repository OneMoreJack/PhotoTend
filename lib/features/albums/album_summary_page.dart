import 'package:flutter/material.dart';
import 'package:rephoto/domain/models/album_summary_entry.dart';
import 'package:rephoto/domain/models/media_item.dart';
import 'package:rephoto/domain/services/permanent_delete_service.dart';
import 'package:rephoto/features/home/home_controller.dart';
import 'package:rephoto/features/media/media_browser_page.dart';

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
        return Scaffold(
          backgroundColor: const Color(0xFFF6F7F9),
          appBar: AppBar(
            backgroundColor: const Color(0xFFF6F7F9),
            elevation: 0,
            title: const Text('RePhoto'),
            actions: [
              IconButton(
                tooltip: 'Trash',
                onPressed: null,
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
                for (final entry in recentEntries)
                  _AlbumSummaryTile(
                    entry: entry,
                    onTap: entry.hasMedia
                        ? () => _openBrowser(context, entry)
                        : null,
                    compact: true,
                  ),
                if (yearGroups.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(2, 18, 2, 8),
                    child: Text(
                      '按年份',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  for (final group in yearGroups)
                    _YearSummarySection(
                      group: group,
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
}

class _AlbumSummaryTile extends StatelessWidget {
  const _AlbumSummaryTile({
    required this.entry,
    required this.onTap,
    this.compact = false,
  });

  final AlbumSummaryEntry entry;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final row = ListTile(
      dense: compact,
      enabled: onTap != null,
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 12,
        vertical: compact ? 0 : 2,
      ),
      title: Text(
        entry.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(_summaryText(entry)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: onTap == null ? const Color(0xFFEDEFF3) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE7E9EE)),
          ),
          child: row,
        ),
      );
    }
    return row;
  }

  static String _summaryText(AlbumSummaryEntry entry) {
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

class _YearSummarySection extends StatelessWidget {
  const _YearSummarySection({
    required this.group,
    required this.expanded,
    required this.onToggle,
    required this.onOpenMonth,
  });

  final YearAlbumSummaryGroup group;
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
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${group.year}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _AlbumSummaryTile._summaryText(group.summary),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
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
                    _AlbumSummaryTile(
                      entry: entry,
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
