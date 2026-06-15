import 'package:flutter/material.dart';
import 'package:rephoto/domain/models/deletion_stats.dart';
import 'package:rephoto/l10n/app_localizations.dart';
import 'package:rephoto/theme/huashu_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    this.deletionStats = DeletionStats.empty,
    this.selectedLanguage = AppLanguage.zh,
    this.onLanguageChanged,
  });

  final DeletionStats deletionStats;
  final AppLanguage selectedLanguage;
  final ValueChanged<AppLanguage>? onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final localeScope = RePhotoLocaleScope.maybeOf(context);
    final effectiveLanguage = localeScope?.language ?? selectedLanguage;
    final effectiveOnLanguageChanged =
        localeScope?.setLanguage ?? onLanguageChanged;
    return Scaffold(
      backgroundColor: HuashuColors.paper,
      appBar: AppBar(title: Text(localizations.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          _SettingsTile(
            key: const Key('language-setting'),
            icon: Icons.language_rounded,
            title: _languageName(effectiveLanguage),
            showChevron: true,
            onTap: () => _showLanguagePicker(
              context,
              selectedLanguage: effectiveLanguage,
              onLanguageChanged: effectiveOnLanguageChanged,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            key: const Key('cumulative-deletion-stats'),
            icon: Icons.delete_sweep_outlined,
            title: localizations.cumulativeDeleted,
            subtitleWidget: Wrap(
              spacing: 8,
              runSpacing: 2,
              children: [
                Text(
                  localizations.deletionPhotoCount(deletionStats.photoCount),
                ),
                Text(
                  localizations.deletionVideoCount(deletionStats.videoCount),
                ),
                Text(
                  localizations.deletionSaved(
                    _formatBytes(deletionStats.knownSizeBytes),
                    deletionStats.hasUnknownSize,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLanguagePicker(
    BuildContext context, {
    required AppLanguage selectedLanguage,
    required ValueChanged<AppLanguage>? onLanguageChanged,
  }) async {
    final localizations = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<AppLanguage>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  localizations.chooseLanguageTitle,
                  style: const TextStyle(
                    color: HuashuColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                RadioGroup<AppLanguage>(
                  groupValue: selectedLanguage,
                  onChanged: (value) {
                    if (value != null) {
                      Navigator.of(context).pop(value);
                    }
                  },
                  child: Column(
                    children: [
                      for (final language in AppLanguage.values)
                        RadioListTile<AppLanguage>(
                          value: language,
                          title: Text(_languageName(language)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null) {
      onLanguageChanged?.call(selected);
    }
  }

  String _languageName(AppLanguage language) {
    return switch (language) {
      AppLanguage.zh => '中文',
      AppLanguage.en => 'English',
    };
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
    this.subtitleWidget,
    this.showChevron = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final Widget? subtitleWidget;
  final bool showChevron;
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
                    if (subtitleWidget != null) ...[
                      const SizedBox(height: 4),
                      DefaultTextStyle(
                        style: const TextStyle(
                          color: HuashuColors.muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                        child: subtitleWidget!,
                      ),
                    ],
                  ],
                ),
              ),
              if (showChevron) ...[
                const SizedBox(width: 12),
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: HuashuColors.faint,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
