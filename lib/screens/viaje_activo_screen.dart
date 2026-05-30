import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/bike_info.dart';
import '../theme/cyclix_colors.dart';
import '../widgets/cyclix_header.dart';
import 'finalizar_viaje_screen.dart';
import 'soporte_screen.dart';

class ViajeActivoScreen extends StatefulWidget {
  const ViajeActivoScreen({
    super.key,
    required this.trip,
    required this.bike,
    this.startLatitude,
    this.startLongitude,
  });

  final Map<String, dynamic> trip;
  final BikeInfo bike;
  final double? startLatitude;
  final double? startLongitude;

  @override
  State<ViajeActivoScreen> createState() => _ViajeActivoScreenState();
}

class _ViajeActivoScreenState extends State<ViajeActivoScreen> {
  late final DateTime _startedAt;
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startedAt =
        DateTime.tryParse(widget.trip['startedAt']?.toString() ?? '') ??
        DateTime.now();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    setState(() => _elapsed = DateTime.now().difference(_startedAt));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  Future<void> _finishTrip() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FinalizarViajeScreen(
          trip: widget.trip,
          bike: widget.bike,
          startLatitude: widget.startLatitude,
          startLongitude: widget.startLongitude,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: CyclixColors.backgroundWhite,
      appBar: const CyclixHeader(showBack: true),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Viaje activo',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: CyclixColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bicicleta #${widget.bike.id}',
                style: GoogleFonts.poppins(color: CyclixColors.instructionGray),
              ),
              const SizedBox(height: 28),
              _MetricCard(
                icon: Icons.timer_outlined,
                label: 'Tiempo',
                value: _formatDuration(_elapsed),
              ),
              const SizedBox(height: 12),
              _MetricCard(
                icon: Icons.attach_money,
                label: 'Tarifa base de referencia',
                value: widget.bike.costPerMinuteDisplay,
              ),
              const SizedBox(height: 12),
              const _MetricCard(
                icon: Icons.route_outlined,
                label: 'Distancia',
                value: 'Se calculará al finalizar',
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _finishTrip,
                style: FilledButton.styleFrom(
                  backgroundColor: CyclixColors.accentGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.lock_outline),
                label: Text(
                  'Finalizar viaje',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SoporteScreen(
                        initialCategory: 'EMERGENCY',
                        initialPriority: 'CRITICAL',
                        tripId: widget.trip['id'],
                        bikeId: widget.bike.id,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.emergency_outlined),
                label: const Text('Emergencia o soporte'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CyclixColors.cardGrey,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: CyclixColors.primaryBlue),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CyclixColors.instructionGray,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
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
