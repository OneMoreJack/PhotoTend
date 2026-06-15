import 'package:flutter/material.dart';
import 'package:rephoto/features/home/home_page.dart';
import 'package:rephoto/l10n/app_localizations.dart';
import 'package:rephoto/theme/huashu_theme.dart';

void main() {
  runApp(const RePhotoApp());
}

class RePhotoApp extends StatelessWidget {
  const RePhotoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const _RePhotoAppShell();
  }
}

class _RePhotoAppShell extends StatefulWidget {
  const _RePhotoAppShell();

  @override
  State<_RePhotoAppShell> createState() => _RePhotoAppShellState();
}

class _RePhotoAppShellState extends State<_RePhotoAppShell> {
  AppLanguage _language = AppLanguage.zh;

  void _setLanguage(AppLanguage language) {
    if (_language == language) {
      return;
    }
    setState(() {
      _language = language;
    });
  }

  @override
  Widget build(BuildContext context) {
    return RePhotoLocaleScope(
      language: _language,
      setLanguage: _setLanguage,
      child: MaterialApp(
        locale: _language.locale,
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        theme: HuashuTheme.build(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomePage(),
      ),
    );
  }
}
