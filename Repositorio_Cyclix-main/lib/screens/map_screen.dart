import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/rental_station.dart';
import '../theme/cyclix_colors.dart';
import 'qr_scan_screen.dart';

/// Ciudad de Guatemala como vista inicial (ajusta si el backend envia otra region).
const LatLng _kInitialCenter = LatLng(14.6349, -90.5069);

const double _kArrivalRadiusMeters = 45;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  static final List<RentalStation> _stations = [
    RentalStation(
      id: '1',
      name: 'Puesto Zona 1',
      position: const LatLng(14.6407, -90.5133),
    ),
    RentalStation(
      id: '2',
      name: 'Puesto Cayala',
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
  List<LatLng> _routePoints = const [];
  bool _locationReady = false;
  bool _routeLoading = false;

  List<Marker> get _stationMarkers {
    return _stations.map((s) {
      return Marker(
        point: s.position,
        width: 48,
        height: 48,
        child: Tooltip(
          message: s.name,
          child: GestureDetector(
            onTap: () => _onStationTapped(s),
            child: const Icon(
              Icons.location_on,
              color: CyclixColors.brandGreen,
              size: 44,
            ),
          ),
        ),
      );
    }).toList();
  }

  Marker? get _userMarker {
    final pos = _lastPosition;
    if (!_locationReady || pos == null) return null;

    return Marker(
      point: LatLng(pos.latitude, pos.longitude),
      width: 34,
      height: 34,
      child: Container(
        decoration: BoxDecoration(
          color: CyclixColors.primaryBlue.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            color: CyclixColors.primaryBlue,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
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
        const SnackBar(
          content: Text('Activa el GPS para ver tu ubicacion y la distancia.'),
        ),
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

    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((pos) {
          _lastPosition = pos;
          if (mounted) {
            setState(() => _locationReady = true);
          }
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
    _routePoints = const [];
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
    if (meters == null) return 'Ubicacion no disponible';
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  Future<List<LatLng>> _fetchBikeRoute(RentalStation station) async {
    final pos = _lastPosition;
    if (pos == null) return [station.position];

    final start = '${pos.longitude},${pos.latitude}';
    final end = '${station.position.longitude},${station.position.latitude}';
    final uri = Uri.parse(
      'https://routing.openstreetmap.de/routed-bike/route/v1/bike/'
      '$start;$end?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('OSRM respondio ${response.statusCode}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = body['routes'] as List<dynamic>?;
      final route = routes?.isNotEmpty == true ? routes!.first : null;
      final geometry = route is Map<String, dynamic> ? route['geometry'] : null;
      final coordinates = geometry is Map<String, dynamic>
          ? geometry['coordinates'] as List<dynamic>?
          : null;

      if (coordinates == null || coordinates.isEmpty) {
        throw Exception('La ruta no devolvio coordenadas');
      }

      return coordinates.map((point) {
        final pair = point as List<dynamic>;
        return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
      }).toList();
    } catch (e) {
      debugPrint('Error obteniendo ruta: $e');
      return [LatLng(pos.latitude, pos.longitude), station.position];
    }
  }

  Future<void> _showRouteInApp(RentalStation station) async {
    final pos = _lastPosition;
    if (pos == null) {
      setState(() {
        _navigatingTo = station;
        _routePoints = [station.position];
      });
      _mapController.move(station.position, 16);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activa tu ubicacion para trazar la ruta desde aqui.'),
        ),
      );
      return;
    }

    setState(() {
      _routeLoading = true;
      _navigatingTo = station;
    });

    final route = await _fetchBikeRoute(station);
    if (!mounted) return;

    setState(() {
      _routePoints = route;
      _routeLoading = false;
    });

    if (route.length >= 2) {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: route,
          padding: const EdgeInsets.fromLTRB(32, 96, 32, 180),
          maxZoom: 16,
        ),
      );
    }
  }

  void _centerOnUser() {
    final pos = _lastPosition;
    if (pos == null) return;
    _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
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
                'pasaras automaticamente a la lectura NFC.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: CyclixColors.instructionGray,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showRouteInApp(s);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: CyclixColors.brandGreen,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.directions_bike),
                label: const Text('Mostrar ruta en el mapa'),
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
    final userMarker = _userMarker;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: FlutterMap(
            key: const ValueKey<String>('cyclix_open_street_map'),
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _kInitialCenter,
              initialZoom: 12,
              minZoom: 3,
              maxZoom: 19,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.cyclixMapaDetalle',
              ),
              if (_routePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 6,
                      color: CyclixColors.primaryBlue,
                      borderStrokeWidth: 3,
                      borderColor: Colors.white,
                    ),
                  ],
                ),
              MarkerLayer(markers: [..._stationMarkers, ?userMarker]),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
        ),
        if (_navigatingTo != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 84,
            child: Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    _routeLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Icon(
                            Icons.directions_bike,
                            color: CyclixColors.primaryBlue,
                          ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _routeLoading
                            ? 'Calculando ruta...'
                            : 'Ruta hacia ${_navigatingTo!.name}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cancelar ruta',
                      onPressed: () {
                        setState(() {
                          _navigatingTo = null;
                          _routePoints = const [];
                          _routeLoading = false;
                        });
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.small(
            heroTag: 'center_on_user',
            onPressed: _locationReady ? _centerOnUser : null,
            backgroundColor: Colors.white,
            foregroundColor: CyclixColors.primaryBlue,
            child: const Icon(Icons.my_location),
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
                  'Permite ubicacion para ver distancia y deteccion de llegada.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
