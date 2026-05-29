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
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: CyclixColors.backgroundWhite,
          border: const Border(
            top: BorderSide(color: Color(0xFFEEEEEE), width: 1),
          ),
        ),
        child: NavigationBar(
          height: 68,
          backgroundColor: CyclixColors.backgroundWhite,
          selectedIndex: currentIndex,
          onDestinationSelected: onTap,
          indicatorColor: CyclixColors.primaryBlue.withValues(alpha: 0.1),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          elevation: 0,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: CyclixColors.primaryBlue),
              selectedIcon: Icon(Icons.home, color: CyclixColors.primaryBlue),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.nfc_outlined, color: CyclixColors.primaryBlue),
              selectedIcon: Icon(Icons.nfc, color: CyclixColors.primaryBlue),
              label: 'Escanear',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.storefront_outlined,
                color: CyclixColors.primaryBlue,
              ),
              selectedIcon: Icon(
                Icons.storefront,
                color: CyclixColors.primaryBlue,
              ),
              label: 'Puestos',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.account_balance_wallet_outlined,
                color: CyclixColors.primaryBlue,
              ),
              selectedIcon: Icon(
                Icons.account_balance_wallet,
                color: CyclixColors.primaryBlue,
              ),
              label: 'Billetera',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, color: CyclixColors.primaryBlue),
              selectedIcon: Icon(Icons.person, color: CyclixColors.primaryBlue),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}
