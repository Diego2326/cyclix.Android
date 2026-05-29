import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/bike_info.dart';
import '../services/cyclix_api_service.dart';
import '../theme/cyclix_colors.dart';
import '../widgets/cyclix_header.dart';
import '../widgets/cyclix_primary_button.dart';
import 'viaje_activo_screen.dart';

class BikeDetailScreen extends StatefulWidget {
  const BikeDetailScreen({super.key, required this.bike});

  final BikeInfo bike;

  @override
  State<BikeDetailScreen> createState() => _BikeDetailScreenState();
}

class _BikeDetailScreenState extends State<BikeDetailScreen> {
  final CyclixApiService _api = CyclixApiService();
  late final Future<Map<String, dynamic>?> _pricingFuture = widget.bike.isDemo
      ? Future.value(null)
      : _loadPricingRule();
  bool _starting = false;

  Future<Map<String, dynamic>?> _loadPricingRule() async {
    try {
      return await _api.getCurrentPricingRule();
    } catch (_) {
      return null;
    }
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

  Future<void> _startTrip() async {
    if (_starting) return;
    setState(() => _starting = true);

    try {
      if (widget.bike.isDemo) {
        final startedAt = DateTime.now();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ViajeActivoScreen(
              trip: {
                'id': 'demo-trip',
                'bikeId': widget.bike.id,
                'status': 'ACTIVE',
                'startedAt': startedAt.toIso8601String(),
              },
              bike: widget.bike,
              startLatitude: 14.6349,
              startLongitude: -90.5069,
            ),
          ),
        );
        return;
      }

      final position = await _getPosition();
      if (position == null) {
        throw const CyclixApiException(
          'Permite la ubicación para iniciar el viaje.',
        );
      }

      final zone = await _api.validateZone(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (zone['allowed'] == false) {
        throw CyclixApiException(
          zone['message']?.toString() ??
              'No puedes iniciar el viaje fuera de una zona habilitada.',
        );
      }

      final trip = await _api.createTrip(
        bikeId: widget.bike.id,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ViajeActivoScreen(
            trip: trip,
            bike: widget.bike,
            startLatitude: position.latitude,
            startLongitude: position.longitude,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bike = widget.bike;
    final details = [
      if (bike.code != null) 'Código: ${bike.code}',
      if (bike.brand != null || bike.model != null)
        '${bike.brand ?? ''} ${bike.model ?? ''}'.trim(),
      if (bike.type != null) 'Tipo: ${bike.type}',
      if (bike.color != null) 'Color: ${bike.color}',
      if (bike.stationName != null) 'Puesto: ${bike.stationName}',
      if (bike.status != null) 'Estado: ${bike.status}',
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CyclixHeader(showBack: true),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 660;
            final iconSize = compact ? 108.0 : 150.0;

            return ListView(
              padding: EdgeInsets.fromLTRB(
                24,
                compact ? 12 : 16,
                24,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                Text(
                  'Bicicleta #${bike.id}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: compact ? 18 : 28),
                Icon(Icons.pedal_bike, size: iconSize, color: Colors.black87),
                SizedBox(height: compact ? 12 : 18),
                ...details.map(
                  (detail) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      detail,
                      textAlign: TextAlign.center,
                      softWrap: true,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(thickness: 1),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: compact ? 10 : 14),
                  child: _TariffPreview(
                    bike: bike,
                    pricingFuture: _pricingFuture,
                  ),
                ),
                const Divider(thickness: 1),
                SizedBox(height: compact ? 14 : 20),
                if (bike.status != null && bike.status != 'DISPONIBLE')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Esta bicicleta no aparece como disponible.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: CyclixColors.instructionGray,
                      ),
                    ),
                  ),
                _starting
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: CyclixColors.primaryBlue,
                        ),
                      )
                    : CyclixPrimaryButton(
                        label: 'Desbloquear e iniciar viaje',
                        onPressed:
                            bike.status == null || bike.status == 'DISPONIBLE'
                            ? _startTrip
                            : null,
                      ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TariffPreview extends StatelessWidget {
  const _TariffPreview({required this.bike, required this.pricingFuture});

  final BikeInfo bike;
  final Future<Map<String, dynamic>?> pricingFuture;

  String _money(Object? value) {
    final number = num.tryParse(value?.toString() ?? '');
    return 'Q.${(number ?? 0).toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    if (bike.isDemo) {
      return _TariffBox(
        title: 'Tarifa demo',
        body: bike.costPerMinuteDisplay,
        note: 'El flujo demo usa la misma estructura de cobro del API.',
      );
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: pricingFuture,
      builder: (context, snapshot) {
        final rule = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return const _TariffBox(
            title: 'Tarifa',
            body: 'Consultando regla de tarifa...',
            note: 'El cobro final se calcula al finalizar el viaje.',
          );
        }

        if (rule != null) {
          final name = rule['name']?.toString() ?? 'Tarifa vigente';
          final baseFare = _money(rule['baseFare']);
          final included = rule['includedMinutes']?.toString() ?? '0';
          final extraFare = _money(rule['extraFarePerBlock']);
          final extraBlock = rule['extraBlockMinutes']?.toString() ?? '0';
          return _TariffBox(
            title: name,
            body:
                '$baseFare incluye $included min · Extra $extraFare / $extraBlock min',
            note:
                'Si tienes suscripción activa, el API descuenta primero tus minutos disponibles.',
          );
        }

        return _TariffBox(
          title: 'Tarifa preparada por API',
          body: bike.costPerMinuteDisplay,
          note:
              'El endpoint de reglas está protegido; al finalizar, /trips/{id}/finish devuelve tarifa, minutos cubiertos, extras y total real.',
        );
      },
    );
  }
}

class _TariffBox extends StatelessWidget {
  const _TariffBox({
    required this.title,
    required this.body,
    required this.note,
  });

  final String title;
  final String body;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CyclixColors.cardGrey,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: CyclixColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            note,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: CyclixColors.instructionGray,
            ),
          ),
        ],
      ),
    );
  }
}
