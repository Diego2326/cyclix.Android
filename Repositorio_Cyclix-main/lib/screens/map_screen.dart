import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/rental_station.dart';
import '../theme/cyclix_colors.dart';
import 'qr_scan_screen.dart';

/// Ciudad de Guatemala como vista inicial (ajusta si el backend envía otra región).
const LatLng _kInitialCenter = LatLng(14.6349, -90.5069);

const double _kArrivalRadiusMeters = 45;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();

  static final List<RentalStation> _stations = [
    RentalStation(
      id: '1',
      name: 'Puesto Zona 1',
      position: const LatLng(14.6407, -90.5133),
    ),
    RentalStation(
      id: '2',
      name: 'Puesto Cayalá',
      position: const LatLng(14.6071, -90.4814),
    ),
    RentalStation(
      id: '3',
      name: 'Puesto Oakland Mall',
      position: const LatLng(14.6289, -90.4810),
    ),
  ];

  Position? _lastPosition;
  StreamSubscription<Position>? _positionSub;
  RentalStation? _navigatingTo;
  bool _locationReady = false;

  Set<Marker> get _markers {
    return _stations.map((s) {
      return Marker(
        markerId: MarkerId(s.id),
        position: s.position,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: s.name),
        onTap: () => _onStationTapped(s),
      );
    }).toSet();
  }

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activa el GPS para ver tu ubicación y la distancia.')),
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      if (mounted) {
        setState(() => _locationReady = false);
      }
      return;
    }

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      _lastPosition = pos;
      // No llamar setState aquí: reconstruir GoogleMap en cada GPS rompe el arrastre/zoom.
      _checkArrival();
    });

    try {
      _lastPosition = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _locationReady = true);
    } catch (_) {
      if (mounted) setState(() => _locationReady = false);
    }
  }

  void _checkArrival() {
    final target = _navigatingTo;
    final pos = _lastPosition;
    if (target == null || pos == null) return;

    final d = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      target.position.latitude,
      target.position.longitude,
    );
    if (d <= _kArrivalRadiusMeters && mounted) {
      _goToQrScanner(target);
    }
  }

  Future<void> _goToQrScanner(RentalStation station) async {
    _navigatingTo = null;
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => QrScanScreen(stationName: station.name),
      ),
    );
  }

  double? _distanceTo(RentalStation s) {
    final pos = _lastPosition;
    if (pos == null) return null;
    return Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      s.position.latitude,
      s.position.longitude,
    );
  }

  String _formatDistance(double? meters) {
    if (meters == null) return 'Ubicación no disponible';
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  Future<void> _openGoogleMapsDirections(RentalStation s) async {
    final lat = s.position.latitude;
    final lng = s.position.longitude;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=bicycling',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir Google Maps.')),
      );
    }
  }

  void _onStationTapped(RentalStation s) {
    final dist = _distanceTo(s);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.name, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Distancia aproximada: ${_formatDistance(dist)}',
                style: Theme.of(ctx).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Al acercarte a menos de ${_kArrivalRadiusMeters.round()} m, '
                'pasarás automáticamente al escaneo QR.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: CyclixColors.instructionGray,
                    ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  setState(() => _navigatingTo = s);
                  Navigator.pop(ctx);
                  _openGoogleMapsDirections(s);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: CyclixColors.brandGreen,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.directions_bike),
                label: const Text('Abrir ruta en Google Maps'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  setState(() => _navigatingTo = s);
                  Navigator.pop(ctx);
                },
                child: const Text('Solo seguir en este mapa'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _goToQrScanner(s);
                },
                child: const Text('Simular llegada (demo sin GPS)'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GoogleMap(
            key: const ValueKey<String>('cyclix_google_map'),
            initialCameraPosition: const CameraPosition(
              target: _kInitialCenter,
              zoom: 12,
            ),
            markers: _markers,
            myLocationEnabled: _locationReady,
            myLocationButtonEnabled: true,
            mapToolbarEnabled: false,
            zoomControlsEnabled: true,
            compassEnabled: true,
            mapType: MapType.normal,
            liteModeEnabled: false,
            onMapCreated: (c) {
              if (!_controller.isCompleted) {
                _controller.complete(c);
              }
            },
          ),
        ),
        if (!_locationReady)
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Permite ubicación para ver distancia y detección de llegada.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
