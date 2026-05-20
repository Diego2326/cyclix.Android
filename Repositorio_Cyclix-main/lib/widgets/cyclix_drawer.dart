import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/cyclix_colors.dart';
import '../screens/datos_usuario_screen.dart';
import '../screens/ayuda_screen.dart';
import '../services/auth_service.dart';

class CyclixDrawer extends StatelessWidget {
  const CyclixDrawer({super.key});

  void _snack(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje, style: GoogleFonts.poppins()),
        behavior: SnackBarBehavior.floating,
        backgroundColor: CyclixColors.primaryBlue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: CyclixColors.backgroundWhite,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: CyclixColors.primaryBlue),
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
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
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
                _DrawerTile(
                  icon: Icons.calendar_today_outlined,
                  title: 'Historial de viajes',
                  onTap: () =>
                      _snack(context, 'Historial de viajes — próximamente'),
                ),
                _DrawerTile(
                  icon: Icons.volume_up_outlined,
                  title: 'Promociones',
                  onTap: () => _snack(context, 'Promociones — próximamente'),
                ),
                _DrawerTile(
                  icon: Icons.chat_bubble_outline,
                  title: 'Centro de Ayuda',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AyudaScreen()),
                    );
                  },
                ),
                _DrawerTile(
                  icon: Icons.phone_outlined,
                  title: 'Contacto',
                  onTap: () => _snack(context, 'Contacto — próximamente'),
                ),
              ],
            ),
          ),
          const Divider(),
          _DrawerTile(
            icon: Icons.logout,
            title: 'Cerrar Sesión',
            color: Colors.redAccent,
            onTap: () async {
              await AuthService().logout();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

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
