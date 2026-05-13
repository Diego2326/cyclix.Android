import 'package:flutter/material.dart';

import '../theme/cyclix_colors.dart';
import '../widgets/cyclix_bottom_nav.dart';
import '../widgets/cyclix_header.dart';
import 'map_screen.dart';
import 'qr_scan_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyclixColors.scaffoldBackground,
      appBar: const CyclixHeader(),
      body: switch (_index) {
        0 => const MapScreen(),
        1 => const QrScanScreen(embeddedInShell: true),
        _ => _PlaceholderTab(
            title: 'Perfil',
            message:
                'Pantalla de perfil de usuario (otro módulo del proyecto grupal).',
          ),
      },
      bottomNavigationBar: CyclixBottomNav(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}
