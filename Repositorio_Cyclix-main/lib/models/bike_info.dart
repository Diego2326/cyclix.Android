class BikeInfo {
  const BikeInfo({
    required this.id,
    required this.costPerMinuteDisplay,
    this.costPerMinute = 1.0,
  });

  final String id;
  final String costPerMinuteDisplay;
  final double costPerMinute;
}
