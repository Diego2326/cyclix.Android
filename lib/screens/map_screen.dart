import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/rental_station.dart';
import '../services/cyclix_api_service.dart';
import '../theme/cyclix_colors.dart';
import 'qr_scan_screen.dart';
import 'subscriptions_screen.dart';
import '../widgets/cyclix_subscription_cta.dart';

/// Ciudad de Guatemala como vista inicial (ajusta si el backend envia otra region).
const LatLng _kInitialCenter = LatLng(14.6349, -90.5069);

const double _kArrivalRadiusMeters = 45;

class _RouteInfo {
  const _RouteInfo({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final CyclixApiService _api = CyclixApiService();

  static final List<RentalStation> _fallbackStations = [
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

  List<RentalStation> _stations = _fallbackStations;
  Position? _lastPosition;
  StreamSubscription<Position>? _positionSub;
  RentalStation? _navigatingTo;
  List<LatLng> _routePoints = const [];
  double? _routeDistanceMeters;
  double? _routeDurationSeconds;
  bool _locationReady = false;
  bool _routeLoading = false;
  bool _stationsLoading = false;

  List<Marker> get _stationMarkers {
    return _stations.map((s) {
      return Marker(
        point: s.position,
        width: 52,
        height: 60,
        alignment: Alignment.bottomCenter,
        child: Tooltip(
          message: s.name,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _onStationTapped(s),
            child: const Align(
              alignment: Alignment.bottomCenter,
              child: Icon(
                Icons.location_on,
                color: CyclixColors.brandGreen,
                size: 44,
              ),
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
    _loadStations();
    _initLocation();
  }

  Future<void> _loadStations() async {
    setState(() => _stationsLoading = true);
    try {
      final stations = await _api.getStations();
      final mapped = stations
          .map(
            (station) => RentalStation(
              id: station['id']?.toString() ?? '',
              name: station['nombre']?.toString() ?? 'Puesto Cyclix',
              position: LatLng(
                (station['latitud'] as num).toDouble(),
                (station['longitud'] as num).toDouble(),
              ),
            ),
          )
          .where((station) => station.id.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _stations = mapped.isEmpty ? _fallbackStations : mapped;
        _stationsLoading = false;
      });
    } catch (e) {
      debugPrint('Error cargando puestos desde API: $e');
      if (mounted) setState(() => _stationsLoading = false);
    }
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
    _routeDistanceMeters = null;
    _routeDurationSeconds = null;
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

  String _formatTime(double? seconds) {
    if (seconds == null) return 'Tiempo no disponible';
    final minutes = (seconds / 60).ceil().clamp(1, 9999);
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours h' : '$hours h $rest min';
  }

  double? _remainingMetersToTarget() {
    final target = _navigatingTo;
    final pos = _lastPosition;
    if (target == null) return null;
    if (pos == null) return _routeDistanceMeters;
    return Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      target.position.latitude,
      target.position.longitude,
    );
  }

  double? _remainingSecondsToTarget() {
    final remainingMeters = _remainingMetersToTarget();
    final routeMeters = _routeDistanceMeters;
    final routeSeconds = _routeDurationSeconds;
    if (remainingMeters == null) return null;
    if (routeMeters == null || routeMeters <= 0 || routeSeconds == null) {
      // Ritmo conservador de bicicleta urbana cuando OSRM no devolvio tiempo.
      return remainingMeters / 4.2;
    }
    final ratio = (remainingMeters / routeMeters).clamp(0.0, 1.0);
    return routeSeconds * ratio;
  }

  Future<_RouteInfo> _fetchBikeRoute(RentalStation station) async {
    final pos = _lastPosition;
    if (pos == null) {
      return const _RouteInfo(
        points: [],
        distanceMeters: 0,
        durationSeconds: 0,
      );
    }

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
      final distance = route is Map<String, dynamic>
          ? (route['distance'] as num?)?.toDouble()
          : null;
      final duration = route is Map<String, dynamic>
          ? (route['duration'] as num?)?.toDouble()
          : null;
      final coordinates = geometry is Map<String, dynamic>
          ? geometry['coordinates'] as List<dynamic>?
          : null;

      if (coordinates == null || coordinates.isEmpty) {
        throw Exception('La ruta no devolvio coordenadas');
      }

      final points = coordinates.map((point) {
        final pair = point as List<dynamic>;
        return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
      }).toList();

      final fallbackDistance = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        station.position.latitude,
        station.position.longitude,
      );
      return _RouteInfo(
        points: points,
        distanceMeters: distance ?? fallbackDistance,
        durationSeconds: duration ?? fallbackDistance / 4.2,
      );
    } catch (e) {
      debugPrint('Error obteniendo ruta: $e');
      final distance = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        station.position.latitude,
        station.position.longitude,
      );
      return _RouteInfo(
        points: [LatLng(pos.latitude, pos.longitude), station.position],
        distanceMeters: distance,
        durationSeconds: distance / 4.2,
      );
    }
  }

  Future<void> _showRouteInApp(RentalStation station) async {
    final pos = _lastPosition;
    if (pos == null) {
      setState(() {
        _navigatingTo = station;
        _routePoints = [station.position];
        _routeDistanceMeters = null;
        _routeDurationSeconds = null;
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
      _routePoints = route.points;
      _routeDistanceMeters = route.distanceMeters;
      _routeDurationSeconds = route.durationSeconds;
      _routeLoading = false;
    });

    if (route.points.length >= 2) {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: route.points,
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

  RentalStation _nearestStation() {
    final pos = _lastPosition;
    final origin = pos == null
        ? _kInitialCenter
        : LatLng(pos.latitude, pos.longitude);
    final stations = [..._stations];
    stations.sort((a, b) {
      final da = const Distance().as(LengthUnit.Meter, origin, a.position);
      final db = const Distance().as(LengthUnit.Meter, origin, b.position);
      return da.compareTo(db);
    });
    return stations.first;
  }

  Future<void> _goToNearestStation() async {
    if (_stations.isEmpty) return;
    final station = _nearestStation();
    await _showRouteInApp(station);
  }

  Future<void> _openSubscriptions() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SubscriptionsScreen()));
  }

  void _onStationTapped(RentalStation s) {
    final dist = _distanceTo(s);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              24 + MediaQuery.paddingOf(ctx).bottom,
            ),
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
    final remainingMeters = _remainingMetersToTarget();
    final remainingSeconds = _remainingSecondsToTarget();

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
        Positioned(
          top: 16,
          right: 16,
          child: CyclixSubscriptionPill(
            label: 'Suscripciones',
            subtitle: 'Cubre minutos',
            onTap: _openSubscriptions,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _routeLoading
                                ? 'Calculando ruta...'
                                : 'Ruta hacia ${_navigatingTo!.name}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (!_routeLoading)
                            Text(
                              'Restan ${_formatDistance(remainingMeters)} • ${_formatTime(remainingSeconds)}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: CyclixColors.instructionGray,
                                  ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cancelar ruta',
                      onPressed: () {
                        setState(() {
                          _navigatingTo = null;
                          _routePoints = const [];
                          _routeDistanceMeters = null;
                          _routeDurationSeconds = null;
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
        Positioned(
          left: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'nearest_station',
            onPressed: _stationsLoading ? null : _goToNearestStation,
            backgroundColor: CyclixColors.primaryBlue,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.near_me_outlined),
            label: const Text('Más cercana'),
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
        if (_stationsLoading)
          const Positioned(
            left: 16,
            right: 16,
            top: 72,
            child: LinearProgressIndicator(color: CyclixColors.primaryBlue),
          ),
      ],
    );
  }
}
