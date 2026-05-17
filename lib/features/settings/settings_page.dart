import 'package:flutter/material.dart';
import 'package:rephoto/domain/models/deletion_stats.dart';

enum SettingsAction { resetRandomPool }

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.deletionStats = DeletionStats.empty});

  final DeletionStats deletionStats;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.shuffle),
            title: const Text('Reset Random Pool'),
            subtitle: const Text(
              'Start a new random round for remaining media',
            ),
            onTap: () =>
                Navigator.of(context).pop(SettingsAction.resetRandomPool),
          ),
          const Divider(height: 1),
          ListTile(
            key: const Key('cumulative-deletion-stats'),
            leading: const Icon(Icons.delete_sweep_outlined),
            title: const Text('Cumulative deleted'),
            subtitle: Wrap(
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
