import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/bike_info.dart';
import '../services/active_trip_controller.dart';
import '../services/cyclix_api_service.dart';
import '../theme/cyclix_colors.dart';
import '../widgets/cyclix_header.dart';
import 'pago_screen.dart';

class FinalizarViajeScreen extends StatefulWidget {
  const FinalizarViajeScreen({
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
  State<FinalizarViajeScreen> createState() => _FinalizarViajeScreenState();
}

class _FinalizarViajeScreenState extends State<FinalizarViajeScreen> {
  final CyclixApiService _api = CyclixApiService();
  bool _bloqueada = false;
  bool _loading = false;

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
    if (widget.startLatitude == null || widget.startLongitude == null) {
      return null;
    }
    final meters = Geolocator.distanceBetween(
      widget.startLatitude!,
      widget.startLongitude!,
      position.latitude,
      position.longitude,
    );
    return meters / 1000;
  }

  Future<void> _finish() async {
    if (!_bloqueada) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Confirma que la bicicleta quedó bloqueada.'),
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
        ActiveTripController.instance.clear();
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
      ActiveTripController.instance.clear();
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
    final canFinish = _bloqueada && !_loading;

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
                'Confirma el bloqueo y la API calculará tarifa, suscripción aplicada y cobro a la billetera.',
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
              const Spacer(),
              _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: CyclixColors.primaryBlue,
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: canFinish ? _finish : null,
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
