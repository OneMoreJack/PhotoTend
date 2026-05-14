import 'package:flutter/material.dart';
import 'package:rephoto/features/home/home_page.dart';

void main() {
  runApp(const RePhotoApp());
}

class RePhotoApp extends StatelessWidget {
  const RePhotoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFFAFD),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0066D6),
          surface: const Color(0xFFFFFAFD),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Color(0xFFFFFAFD),
          foregroundColor: Color(0xFF1D1D21),
          titleTextStyle: TextStyle(
            color: Color(0xFF1D1D21),
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}
