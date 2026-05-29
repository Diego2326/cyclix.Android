import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/bike_info.dart';
import '../services/cyclix_api_service.dart';
import '../theme/cyclix_colors.dart';
import '../widgets/cyclix_header.dart';
import 'pago_screen.dart';

class FinalizarViajeScreen extends StatefulWidget {
  const FinalizarViajeScreen({
    super.key,
    required this.trip,
    required this.bike,
    required this.startLatitude,
    required this.startLongitude,
    this.closurePhotoPath,
  });

  final Map<String, dynamic> trip;
  final BikeInfo bike;
  final double startLatitude;
  final double startLongitude;
  final String? closurePhotoPath;

  @override
  State<FinalizarViajeScreen> createState() => _FinalizarViajeScreenState();
}

class _FinalizarViajeScreenState extends State<FinalizarViajeScreen> {
  final CyclixApiService _api = CyclixApiService();
  bool _bloqueada = false;
  bool _fotoConfirmada = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fotoConfirmada = widget.closurePhotoPath != null;
  }

  Future<Position?> _getPosition() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    return Geolocator.getCurrentPosition();
  }

  double? _distanceKm(Position position) {
    final meters = Geolocator.distanceBetween(
      widget.startLatitude,
      widget.startLongitude,
      position.latitude,
      position.longitude,
    );
    return meters / 1000;
  }

  Future<void> _finish() async {
    if (!_bloqueada || !_fotoConfirmada) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Confirma el bloqueo y la foto antes de finalizar.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      if (widget.bike.isDemo) {
        final startedAt =
            DateTime.tryParse(widget.trip['startedAt']?.toString() ?? '') ??
            DateTime.now().subtract(const Duration(minutes: 18));
        final durationSeconds = DateTime.now().difference(startedAt).inSeconds;
        final billableMinutes = (durationSeconds / 60).ceil().clamp(1, 9999);
        final baseFare = 20.0;
        const includedMinutes = 120;
        const extraBlockMinutes = 30;
        final extraAmount = (billableMinutes > includedMinutes)
            ? ((billableMinutes - includedMinutes) / extraBlockMinutes).ceil() *
                  5.0
            : 0.0;
        final total = baseFare + extraAmount;

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PagoScreen(
              trip: {
                'id': widget.trip['id'],
                'bikeId': widget.bike.id,
                'status': 'COMPLETED',
                'durationSeconds': durationSeconds,
                'distanceKm': 2.4,
                'pricingRuleName': 'Tarifa demo',
                'subscriptionMinutesCovered': 0,
                'billableMinutes': billableMinutes,
                'baseFareApplied': baseFare,
                'includedMinutesApplied': includedMinutes,
                'extraFarePerBlockApplied': 5.0,
                'extraBlockMinutesApplied': extraBlockMinutes,
                'extraAmount': extraAmount,
                'totalAmount': total,
                'walletChargedAmount': total,
              },
            ),
          ),
        );
        return;
      }

      final position = await _getPosition();
      if (position == null) {
        throw const CyclixApiException(
          'Permite la ubicación para finalizar el viaje.',
        );
      }

      final zone = await _api.validateZone(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (zone['allowed'] == false) {
        throw CyclixApiException(
          zone['message']?.toString() ??
              'Debes finalizar el viaje dentro de una zona habilitada.',
        );
      }

      final finishedTrip = await _api.finishTrip(
        tripId: widget.trip['id'],
        latitude: position.latitude,
        longitude: position.longitude,
        distanceKm: _distanceKm(position),
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PagoScreen(trip: finishedTrip)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                'Finalizar viaje',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: CyclixColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'La API calculará tarifa, suscripción aplicada y cobro a la billetera.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: CyclixColors.instructionGray),
              ),
              const SizedBox(height: 28),
              _CheckAction(
                value: _bloqueada,
                icon: Icons.lock_outline,
                title: 'Bicicleta bloqueada',
                subtitle: 'Confirma que el candado quedó cerrado.',
                onChanged: (value) =>
                    setState(() => _bloqueada = value ?? false),
              ),
              const SizedBox(height: 12),
              _CheckAction(
                value: _fotoConfirmada,
                icon: Icons.camera_alt_outlined,
                title: 'Foto del cierre tomada',
                subtitle: widget.closurePhotoPath == null
                    ? 'Marca esta opción cuando tengas evidencia del cierre.'
                    : 'Foto capturada. Se enviará al API cuando esté disponible.',
                onChanged: (value) =>
                    setState(() => _fotoConfirmada = value ?? false),
              ),
              if (widget.closurePhotoPath != null) ...[
                const SizedBox(height: 12),
                _ClosurePhotoPreview(path: widget.closurePhotoPath!),
              ],
              const Spacer(),
              _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: CyclixColors.primaryBlue,
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: _finish,
                      style: FilledButton.styleFrom(
                        backgroundColor: CyclixColors.accentGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(
                        'Finalizar y cobrar',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClosurePhotoPreview extends StatelessWidget {
  const _ClosurePhotoPreview({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final isDemo = path.startsWith('demo://');
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: CyclixColors.cardGrey,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: isDemo
                ? const ColoredBox(
                    color: CyclixColors.primaryBlue,
                    child: Icon(
                      Icons.image_search_outlined,
                      color: Colors.white,
                      size: 34,
                    ),
                  )
                : Image.file(File(path), fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isDemo
                  ? 'Foto simulada lista para pruebas'
                  : 'Foto de cierre lista',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(
              Icons.check_circle_rounded,
              color: CyclixColors.accentGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckAction extends StatelessWidget {
  const _CheckAction({
    required this.value,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  final bool value;
  final IconData icon;
  final String title;
  final String subtitle;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CyclixColors.cardGrey,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        controlAffinity: ListTileControlAffinity.leading,
        secondary: Icon(icon, color: CyclixColors.primaryBlue),
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
