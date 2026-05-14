import 'package:flutter/material.dart';
import 'package:rephoto/features/home/home_page.dart';

void main() {
  runApp(const RePhotoApp());
}

class RePhotoApp extends StatelessWidget {
  const RePhotoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: HomePage());
  }
}
