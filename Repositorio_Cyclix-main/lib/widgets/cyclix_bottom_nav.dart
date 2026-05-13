import 'package:flutter/material.dart';

import '../theme/cyclix_colors.dart';

class CyclixBottomNav extends StatelessWidget {
  const CyclixBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      indicatorColor: CyclixColors.brandGreen.withValues(alpha: 0.15),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined, color: CyclixColors.brandGreen),
          selectedIcon: Icon(Icons.home, color: CyclixColors.brandGreen),
          label: 'Inicio',
        ),
        NavigationDestination(
          icon: Icon(Icons.search, color: CyclixColors.brandGreen),
          selectedIcon: Icon(Icons.search, color: CyclixColors.brandGreen),
          label: 'Buscar',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline, color: CyclixColors.brandGreen),
          selectedIcon: Icon(Icons.person, color: CyclixColors.brandGreen),
          label: 'Perfil',
        ),
      ],
    );
  }
}
