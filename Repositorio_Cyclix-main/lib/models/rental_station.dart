import 'package:google_maps_flutter/google_maps_flutter.dart';

class RentalStation {
  const RentalStation({
    required this.id,
    required this.name,
    required this.position,
  });

  final String id;
  final String name;
  final LatLng position;
}
