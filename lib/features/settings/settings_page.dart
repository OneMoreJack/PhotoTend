import 'package:flutter/material.dart';

enum SettingsAction { resetRandomPool }

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
        ],
      ),
    );
  }
}
