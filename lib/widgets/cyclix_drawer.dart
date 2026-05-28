import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/admin_api_screen.dart';
import '../screens/ayuda_screen.dart';
import '../screens/datos_usuario_screen.dart';
import '../screens/historial_viajes_screen.dart';
import '../screens/maintenance_guide_screen.dart';
import '../screens/planes_screen.dart';
import '../screens/puestos_bicicletas_screen.dart';
import '../screens/soporte_screen.dart';
import '../screens/wallet_screen.dart';
import '../services/auth_service.dart';
import '../theme/cyclix_colors.dart';

class CyclixDrawer extends StatelessWidget {
  const CyclixDrawer({super.key});

  bool _isMaintenanceRole(String? role) {
    final value = role?.toUpperCase() ?? '';
    return value == 'MAINTENANCE' ||
        value == 'MANTENIMIENTO' ||
        value == 'TECHNICIAN' ||
        value == 'TECNICO' ||
        value == 'TÉCNICO';
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: CyclixColors.backgroundWhite,
      child: SafeArea(
        top: false,
        child: FutureBuilder<Map<String, dynamic>?>(
          future: AuthService().getUserData(),
          builder: (context, snapshot) {
            final role = snapshot.data?['role']?.toString();
            final isMaintenance = _isMaintenanceRole(role);
            final isAdmin = role?.toUpperCase() == 'ADMIN';

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(
                    color: CyclixColors.primaryBlue,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.directions_bike,
                          size: 50,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'CYCLIX',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _DrawerTile(
                  icon: Icons.person_outline,
                  title: 'Mi cuenta',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DatosUsuarioScreen(),
                      ),
                    );
                  },
                ),
                if (!isMaintenance) ...[
                  _DrawerTile(
                    icon: Icons.calendar_today_outlined,
                    title: 'Historial de viajes',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HistorialViajesScreen(),
                        ),
                      );
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Wallet',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WalletScreen()),
                      );
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.workspace_premium_outlined,
                    title: 'Planes',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PlanesScreen()),
                      );
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.storefront_outlined,
                    title: 'Puestos y bicicletas',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PuestosBicicletasScreen(),
                        ),
                      );
                    },
                  ),
                ],
                _DrawerTile(
                  icon: Icons.chat_bubble_outline,
                  title: isMaintenance
                      ? 'Guía de mantenimiento'
                      : 'Centro de Ayuda',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => isMaintenance
                            ? const MaintenanceGuideScreen()
                            : const AyudaScreen(),
                      ),
                    );
                  },
                ),
                _DrawerTile(
                  icon: Icons.support_agent_outlined,
                  title: 'Mis tickets',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SoporteScreen()),
                    );
                  },
                ),
                if (isAdmin)
                  _DrawerTile(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Administración API',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminApiScreen(),
                        ),
                      );
                    },
                  ),
                const Divider(),
                _DrawerTile(
                  icon: Icons.logout,
                  title: 'Cerrar Sesión',
                  color: Colors.redAccent,
                  onTap: () async {
                    await AuthService().logout();
                    if (!context.mounted) return;
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/',
                      (route) => false,
                    );
                  },
                ),
                SizedBox(height: 28 + MediaQuery.paddingOf(context).bottom),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? CyclixColors.primaryBlue),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: color ?? CyclixColors.textDark,
        ),
      ),
      onTap: onTap,
    );
  }
}
