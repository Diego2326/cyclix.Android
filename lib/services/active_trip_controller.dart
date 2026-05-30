import 'package:flutter/material.dart';

import '../models/bike_info.dart';
import '../screens/viaje_activo_screen.dart';
import 'cyclix_api_service.dart';

class ActiveTripSession {
  const ActiveTripSession({
    required this.trip,
    required this.bike,
    this.startLatitude,
    this.startLongitude,
  });

  final Map<String, dynamic> trip;
  final BikeInfo bike;
  final double? startLatitude;
  final double? startLongitude;
}

class ActiveTripController {
  ActiveTripController._();

  static final ActiveTripController instance = ActiveTripController._();

  final CyclixApiService _api = CyclixApiService();
  final ValueNotifier<ActiveTripSession?> sessionListenable = ValueNotifier(
    null,
  );

  bool _loadingFromApi = false;
  bool _didLoadFromApi = false;

  ActiveTripSession? get session => sessionListenable.value;

  void setSession(ActiveTripSession? value) {
    sessionListenable.value = value;
    _didLoadFromApi = true;
  }

  void clear() {
    setSession(null);
  }

  Future<void> ensureLoaded() async {
    if (_didLoadFromApi || _loadingFromApi) return;

    _loadingFromApi = true;
    try {
      final trips = await _api.getMyTrips();
      final activeTrip = trips.cast<Map<String, dynamic>?>().firstWhere((trip) {
        final status = trip?['status']?.toString().toUpperCase();
        return status == 'ACTIVE' || status == 'IN_PROGRESS';
      }, orElse: () => null);

      if (activeTrip == null) {
        sessionListenable.value = null;
        _didLoadFromApi = true;
        return;
      }

      final bike = await _loadBike(activeTrip);
      sessionListenable.value = ActiveTripSession(
        trip: activeTrip,
        bike: bike,
        startLatitude: _readDouble(activeTrip, const [
          'startLatitude',
          'startLat',
          'latitude',
        ]),
        startLongitude: _readDouble(activeTrip, const [
          'startLongitude',
          'startLng',
          'longitude',
        ]),
      );
      _didLoadFromApi = true;
    } catch (error) {
      debugPrint('No se pudo restaurar el viaje activo: $error');
    } finally {
      _loadingFromApi = false;
    }
  }

  Route<void> buildRoute(ActiveTripSession value) {
    return MaterialPageRoute(
      builder: (_) => ViajeActivoScreen(
        trip: value.trip,
        bike: value.bike,
        startLatitude: value.startLatitude,
        startLongitude: value.startLongitude,
      ),
    );
  }

  Future<BikeInfo> _loadBike(Map<String, dynamic> trip) async {
    final bikeId = trip['bikeId'];
    if (bikeId == null) {
      return _fallbackBike('0');
    }

    try {
      final bike = await _api.getBikeById(bikeId);
      return BikeInfo.fromJson(bike);
    } catch (_) {
      return _fallbackBike(bikeId.toString());
    }
  }

  BikeInfo _fallbackBike(String bikeId) {
    return BikeInfo(
      id: bikeId,
      status: 'ACTIVE',
      costPerMinuteDisplay: 'Tarifa del viaje en curso',
      costPerMinute: 0,
    );
  }

  double? _readDouble(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value == null) continue;
      final number = double.tryParse(value.toString());
      if (number != null) return number;
    }
    return null;
  }
}
