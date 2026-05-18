import 'package:flutter/material.dart';
import 'package:rephoto/domain/models/deletion_stats.dart';
import 'package:rephoto/theme/huashu_theme.dart';

enum SettingsAction { resetRandomPool }

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.deletionStats = DeletionStats.empty});

  final DeletionStats deletionStats;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HuashuColors.paper,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          _SettingsTile(
            icon: Icons.shuffle_rounded,
            title: 'Reset Random Pool',
            subtitle: 'Start a new random round for remaining media',
            onTap: () =>
                Navigator.of(context).pop(SettingsAction.resetRandomPool),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            key: const Key('cumulative-deletion-stats'),
            icon: Icons.delete_sweep_outlined,
            title: 'Cumulative deleted',
            subtitleWidget: Wrap(
              spacing: 8,
              runSpacing: 2,
              children: [
                Text(_countText(deletionStats.photoCount, 'photo')),
                Text(_countText(deletionStats.videoCount, 'video')),
                Text(
                  '${_formatBytes(deletionStats.knownSizeBytes)}'
                  '${deletionStats.hasUnknownSize ? '+' : ''} saved',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _countText(int count, String singular) {
    return '$count $singular${count == 1 ? '' : 's'}';
  }

  String _formatBytes(int bytes) {
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
    return '${gb.toStringAsFixed(gb >= 10 ? 1 : 2)} GB';
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HuashuColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: HuashuColors.accentSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: HuashuColors.accentDeep, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: HuashuColors.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DefaultTextStyle(
                      style: const TextStyle(
                        color: HuashuColors.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                      child:
                          subtitleWidget ?? Text(subtitle ?? '', maxLines: 2),
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
