import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/cyclix_colors.dart';
import '../widgets/cyclix_header.dart';

class MaintenanceGuideScreen extends StatelessWidget {
  const MaintenanceGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: CyclixColors.backgroundWhite,
      appBar: const CyclixHeader(showBack: true),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(18, 18, 18, 24 + bottom),
          children: const [
            _GuideHeader(),
            SizedBox(height: 16),
            _GuideStep(
              icon: Icons.assignment_outlined,
              title: '1. Revisa tus órdenes',
              body:
                  'En Inicio ves los reportes nuevos y el estado general. En Bicicletas puedes filtrar por todas, en revisión o fuera de servicio.',
            ),
            _GuideStep(
              icon: Icons.search_outlined,
              title: '2. Abre el detalle',
              body:
                  'Cada orden muestra bicicleta, estación, prioridad, problema reportado y el historial que viene del API.',
            ),
            _GuideStep(
              icon: Icons.build_outlined,
              title: '3. Registra avance',
              body:
                  'Usa diagnóstico para actualizar estado, notas, ubicación y tiempo estimado. Esto alimenta el seguimiento de mantenimiento.',
            ),
            _GuideStep(
              icon: Icons.verified_outlined,
              title: '4. Resuelve la orden',
              body:
                  'Al terminar, indica si la bicicleta vuelve a disponible, sigue en taller o queda fuera de servicio.',
            ),
            _GuideStep(
              icon: Icons.person_outline,
              title: 'Cuenta y salida',
              body:
                  'Desde el menú lateral puedes abrir Mi cuenta o cerrar sesión sin volver al flujo de usuario normal.',
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideHeader extends StatelessWidget {
  const _GuideHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CyclixColors.primaryBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.engineering_outlined, color: Colors.white, size: 34),
          const SizedBox(height: 14),
          Text(
            'Guía de mantenimiento',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Flujo rápido para trabajar órdenes asignadas desde el API.',
            style: GoogleFonts.poppins(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: CyclixColors.accentGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    color: CyclixColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.poppins(
                    color: CyclixColors.instructionGray,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
