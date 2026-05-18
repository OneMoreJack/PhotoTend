import 'package:flutter/material.dart';
import 'package:rephoto/features/home/home_page.dart';
import 'package:rephoto/theme/huashu_theme.dart';

void main() {
  runApp(const RePhotoApp());
}

class RePhotoApp extends StatelessWidget {
  const RePhotoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(theme: HuashuTheme.build(), home: const HomePage());
  }
}
