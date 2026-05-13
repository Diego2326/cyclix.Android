import 'package:flutter/material.dart';

import '../theme/cyclix_colors.dart';
import 'ayuda_screen.dart';

class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  void _snack(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: CyclixColors.brandGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _MenuTile(
          icono: Icons.person_outline,
          titulo: 'Mi cuenta',
          onTap: () => _snack(context, 'Mi cuenta — próximamente'),
        ),
        _MenuTile(
          icono: Icons.calendar_today_outlined,
          titulo: 'Historial de viajes',
          onTap: () =>
              _snack(context, 'Historial de viajes — próximamente'),
        ),
        _MenuTile(
          icono: Icons.volume_up_outlined,
          titulo: 'Promociones',
          onTap: () => _snack(context, 'Promociones — próximamente'),
        ),
        _MenuTile(
          icono: Icons.chat_bubble_outline,
          titulo: 'Centro de Ayuda',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AyudaScreen()),
          ),
        ),
        _MenuTile(
          icono: Icons.phone_outlined,
          titulo: 'Contacto',
          onTap: () => _snack(context, 'Contacto — próximamente'),
        ),
      ],
    );
  }
}

// ── Widget privado ────────────────────────────────────────────────────────────

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icono,
    required this.titulo,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Icon(icono, size: 26, color: Colors.black87),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: CyclixColors.brandGreen,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
        Divider(
          height: 1,
          indent: 20,
          endIndent: 20,
          color: Colors.grey.shade200,
        ),
      ],
    );
  }
}