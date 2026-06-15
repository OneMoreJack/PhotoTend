import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rephoto/domain/models/deletion_stats.dart';
import 'package:rephoto/features/settings/settings_page.dart';
import 'package:rephoto/l10n/app_localizations.dart';

void main() {
  Widget localizedSettings({
    required Locale locale,
    AppLanguage selectedLanguage = AppLanguage.en,
    ValueChanged<AppLanguage>? onLanguageChanged,
  }) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SettingsPage(
        selectedLanguage: selectedLanguage,
        onLanguageChanged: onLanguageChanged,
        deletionStats: const DeletionStats(
          photoCount: 1,
          videoCount: 2,
          knownSizeBytes: 3072,
        ),
      ),
    );
  }

  testWidgets('does not expose reset random pool action', (tester) async {
    await tester.pumpWidget(localizedSettings(locale: const Locale('en')));

    expect(find.text('Reset Random Pool'), findsNothing);
    expect(find.byIcon(Icons.shuffle_rounded), findsNothing);
  });

  testWidgets('renders English settings copy', (tester) async {
    await tester.pumpWidget(localizedSettings(locale: const Locale('en')));

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Language'), findsNothing);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('中文'), findsNothing);
    expect(find.text('Cumulative deleted'), findsOneWidget);
    expect(find.text('1 photo'), findsOneWidget);
    expect(find.text('2 videos'), findsOneWidget);
    expect(find.text('3.0 KB saved'), findsOneWidget);
  });

  testWidgets('renders Chinese settings copy', (tester) async {
    await tester.pumpWidget(
      localizedSettings(
        locale: const Locale('zh'),
        selectedLanguage: AppLanguage.zh,
      ),
    );

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('语言'), findsNothing);
    expect(find.text('中文'), findsOneWidget);
    expect(find.text('English'), findsNothing);
    expect(find.text('累计删除'), findsOneWidget);
    expect(find.text('1 张照片'), findsOneWidget);
    expect(find.text('2 个视频'), findsOneWidget);
    expect(find.text('已节省 3.0 KB'), findsOneWidget);
  });

  testWidgets('notifies when language changes', (tester) async {
    AppLanguage? changedLanguage;
    await tester.pumpWidget(
      localizedSettings(
        locale: const Locale('zh'),
        selectedLanguage: AppLanguage.zh,
        onLanguageChanged: (language) => changedLanguage = language,
      ),
    );

    await tester.tap(find.byKey(const Key('language-setting')));
    await tester.pumpAndSettle();

    expect(find.text('选择语言'), findsOneWidget);
    expect(find.text('中文'), findsWidgets);
    expect(find.text('English'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(changedLanguage, AppLanguage.en);
  });
}
