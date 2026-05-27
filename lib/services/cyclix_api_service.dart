import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/maintenance_order.dart';
import 'auth_service.dart';

class CyclixApiException implements Exception {
  const CyclixApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class CyclixApiService {
  CyclixApiService({AuthService? authService})
    : _authService = authService ?? AuthService();

  static const String baseUrl = AuthService.baseUrl;

  final AuthService _authService;

  Future<Map<String, String>> _headers({bool jsonBody = true}) async {
    final token = await _authService.getSavedToken();
    return {
      if (jsonBody) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String path) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
    );
    return _decodeResponse(response);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    final response = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  dynamic _decodeResponse(http.Response response) {
    final text = utf8.decode(response.bodyBytes);
    final dynamic decoded = text.isEmpty ? null : jsonDecode(text);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic> && decoded.containsKey('success')) {
        if (decoded['success'] == true) return decoded['data'];
        throw CyclixApiException(
          decoded['message']?.toString() ?? 'La API rechazó la solicitud.',
          statusCode: response.statusCode,
        );
      }
      return decoded;
    }

    String message = 'Error ${response.statusCode} al comunicarse con Cyclix.';
    if (decoded is Map<String, dynamic>) {
      message =
          decoded['message']?.toString() ??
          decoded['error']?.toString() ??
          decoded['detail']?.toString() ??
          message;
    }

    throw CyclixApiException(message, statusCode: response.statusCode);
  }

  Future<List<Map<String, dynamic>>> getStations({
    bool onlyActive = true,
  }) async {
    final data = await get(onlyActive ? '/puestos/activos' : '/puestos');
    return _asMapList(data);
  }

  Future<List<Map<String, dynamic>>> getAvailableStations() async {
    final data = await get('/puestos/disponibles');
    return _asMapList(data);
  }

  Future<List<Map<String, dynamic>>> getBikes({String? estado}) async {
    final path = estado == null
        ? '/bicicletas'
        : '/bicicletas/filtrar?estado=$estado';
    final data = await get(path);
    return _asMapList(data);
  }

  Future<List<Map<String, dynamic>>> getBikesByStation(
    Object stationId, {
    bool onlyAvailable = false,
  }) async {
    final suffix = onlyAvailable ? '/disponibles' : '';
    final data = await get('/bicicletas/puesto/$stationId$suffix');
    return _asMapList(data);
  }

  Future<Map<String, dynamic>> getBikeByQr(String code) async {
    final encoded = Uri.encodeComponent(code);
    final data = await get('/bicicletas/qr/$encoded');
    return _asMap(data);
  }

  Future<Map<String, dynamic>> getBikeById(Object id) async {
    final data = await get('/bicicletas/$id');
    return _asMap(data);
  }

  Future<Map<String, dynamic>> createTrip({
    required Object bikeId,
    required double latitude,
    required double longitude,
  }) async {
    final data = await post('/trips', {
      'bikeId': int.tryParse(bikeId.toString()) ?? bikeId,
      'startLatitude': latitude,
      'startLongitude': longitude,
    });
    return _asMap(data);
  }

  Future<Map<String, dynamic>> finishTrip({
    required Object tripId,
    required double latitude,
    required double longitude,
    double? distanceKm,
  }) async {
    final body = <String, dynamic>{
      'endLatitude': latitude,
      'endLongitude': longitude,
    };
    if (distanceKm != null) {
      body['distanceKm'] = distanceKm;
    }
    final data = await put('/trips/$tripId/finish', body);
    return _asMap(data);
  }

  Future<Map<String, dynamic>> validateZone({
    required double latitude,
    required double longitude,
  }) async {
    final data = await post('/zones/validate', {
      'latitude': latitude,
      'longitude': longitude,
    });
    return _asMap(data);
  }

  Future<List<Map<String, dynamic>>> getMyTrips() async {
    final data = await get('/trips/my');
    return _asMapList(data);
  }

  Future<Map<String, dynamic>> getWallet() async {
    final data = await get('/wallet/my');
    return _asMap(data);
  }

  Future<List<Map<String, dynamic>>> getWalletTransactions() async {
    final data = await get('/wallet/my/transactions');
    return _asMapList(data);
  }

  Future<Map<String, dynamic>> topUpMyWallet({
    required double amount,
    String paymentMethod = 'CARD',
  }) async {
    final data = await post('/wallet/my/top-up', {
      'amount': amount,
      'paymentMethod': paymentMethod,
    });
    return _asMap(data);
  }

  Future<Map<String, dynamic>> topUpWallet({
    required Object userId,
    required double amount,
  }) async {
    final data = await post('/wallet/top-up', {
      'userId': int.tryParse(userId.toString()) ?? userId,
      'amount': amount,
    });
    return _asMap(data);
  }

  Future<List<Map<String, dynamic>>> getMyTickets() async {
    final data = await get('/support/tickets/my');
    return _asMapList(data);
  }

  Future<Map<String, dynamic>> createTicket({
    required String category,
    required String priority,
    required String title,
    required String description,
    Object? bikeId,
    Object? tripId,
    Object? paymentId,
  }) async {
    final data = await post('/support/tickets', {
      if (bikeId != null) 'bikeId': int.tryParse(bikeId.toString()) ?? bikeId,
      if (tripId != null) 'tripId': int.tryParse(tripId.toString()) ?? tripId,
      if (paymentId != null)
        'paymentId': int.tryParse(paymentId.toString()) ?? paymentId,
      'category': category,
      'priority': priority,
      'title': title,
      'description': description,
    });
    return _asMap(data);
  }

  Future<List<Map<String, dynamic>>> getMyFailureReports() async {
    final data = await get('/support/failure-reports');
    return _asMapList(data);
  }

  Future<Map<String, dynamic>> createFailureReport({
    required Object bikeId,
    Object? tripId,
    required String priority,
    required String title,
    required String description,
  }) async {
    final data = await post('/support/failure-reports', {
      'bikeId': int.tryParse(bikeId.toString()) ?? bikeId,
      if (tripId != null) 'tripId': int.tryParse(tripId.toString()) ?? tripId,
      'priority': priority,
      'title': title,
      'description': description,
    });
    return _asMap(data);
  }

  Future<List<Map<String, dynamic>>> getPricingRules() async {
    final data = await get('/admin/pricing/rules');
    return _asMapList(data);
  }

  Future<Map<String, dynamic>?> getCurrentPricingRule() async {
    final rules = await getPricingRules();
    if (rules.isEmpty) return null;

    final now = DateTime.now();
    final candidates = rules.where((rule) {
      if (rule['active'] == false) return false;
      if (!_matchesDate(rule['startDate'], rule['endDate'], now)) {
        return false;
      }
      if (!_matchesTime(rule['startTime'], rule['endTime'], now)) {
        return false;
      }
      if (!_matchesDay(rule['daysOfWeek'], now)) return false;
      return true;
    }).toList();

    if (candidates.isEmpty) return rules.first;
    candidates.sort((a, b) {
      final priorityA = int.tryParse(a['priority']?.toString() ?? '') ?? 0;
      final priorityB = int.tryParse(b['priority']?.toString() ?? '') ?? 0;
      return priorityB.compareTo(priorityA);
    });
    return candidates.first;
  }

  Future<List<Map<String, dynamic>>> getHolidays() async {
    final data = await get('/admin/pricing/holidays');
    return _asMapList(data);
  }

  Future<List<Map<String, dynamic>>> getSubscriptionPlans() async {
    final data = await get('/admin/subscriptions/plans');
    return _asMapList(data);
  }

  Future<List<Map<String, dynamic>>> getAdminTrips() async {
    final data = await get('/admin/trips');
    return _asMapList(data);
  }

  Future<Map<String, dynamic>> cancelAdminTrip(Object id) async {
    final data = await put('/admin/trips/$id/cancel', {});
    return _asMap(data);
  }

  Future<List<Map<String, dynamic>>> getAdminFailureReports() async {
    final data = await get('/admin/support/failure-reports');
    return _asMapList(data);
  }

  Future<Map<String, dynamic>> createMaintenanceFromFailureReport({
    required Object reportId,
    Object? assignedToUserId,
    required String priority,
    required String type,
    int? estimatedMinutes,
    String? currentLocation,
  }) async {
    final body = <String, dynamic>{'priority': priority, 'type': type};
    if (assignedToUserId != null) {
      body['assignedToUserId'] =
          int.tryParse(assignedToUserId.toString()) ?? assignedToUserId;
    }
    if (estimatedMinutes != null) body['estimatedMinutes'] = estimatedMinutes;
    if (currentLocation != null && currentLocation.trim().isNotEmpty) {
      body['currentLocation'] = currentLocation.trim();
    }
    final data = await post(
      '/admin/support/failure-reports/$reportId/maintenance',
      body,
    );
    return _asMap(data);
  }

  Future<List<Map<String, dynamic>>> getAuditLogs({
    String? eventType,
    String? entityType,
  }) async {
    final params = <String, String>{
      if (eventType != null && eventType.isNotEmpty) 'eventType': eventType,
      if (entityType != null && entityType.isNotEmpty) 'entityType': entityType,
    };
    final query = params.isEmpty
        ? ''
        : '?${Uri(queryParameters: params).query}';
    final data = await get('/admin/audit$query');
    return _asMapList(data);
  }

  Future<Map<String, dynamic>> getBicycleAnalytics({
    int days = 30,
    String period = 'DAY',
  }) async {
    final data = await get(
      '/admin/analytics/bicycles?days=$days&period=$period',
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> getUserAnalytics({
    int days = 30,
    String period = 'DAY',
  }) async {
    final data = await get('/admin/analytics/users?days=$days&period=$period');
    return _asMap(data);
  }

  Future<Map<String, dynamic>> getStationAnalytics({
    int days = 30,
    String period = 'DAY',
  }) async {
    final data = await get(
      '/admin/analytics/stations?days=$days&period=$period',
    );
    return _asMap(data);
  }

  Future<List<Map<String, dynamic>>> getZones() async {
    final data = await get('/admin/zones');
    return _asMapList(data);
  }

  Future<Map<String, dynamic>> createZone({
    required String name,
    String? description,
    required double centerLatitude,
    required double centerLongitude,
    required int radiusMeters,
    bool active = true,
  }) async {
    final data = await post('/admin/zones', {
      'name': name,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      'centerLatitude': centerLatitude,
      'centerLongitude': centerLongitude,
      'radiusMeters': radiusMeters,
      'active': active,
    });
    return _asMap(data);
  }

  Future<Map<String, dynamic>> updateZoneStatus({
    required Object id,
    required bool active,
  }) async {
    final data = await patch('/admin/zones/$id/status', {'active': active});
    return _asMap(data);
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final data = await get('/get/user');
    return _asMapList(data);
  }

  Future<Map<String, dynamic>> assignUserRole({
    required Object userId,
    required String role,
  }) async {
    final data = await patch('/get/user/$userId/role', {'role': role});
    return _asMap(data);
  }

  Future<Map<String, dynamic>> createMaintenanceUser({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final registerData = await post('/auth/register', {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'password': password,
    });

    Object? userId;
    if (registerData is Map) {
      userId = registerData['userId'];
    }

    if (userId == null) {
      final normalizedEmail = email.trim().toLowerCase();
      final users = await getUsers();
      Map<String, dynamic>? created;
      for (final user in users) {
        if (user['email']?.toString().toLowerCase() == normalizedEmail) {
          created = user;
          break;
        }
      }
      userId = created?['id'];
    }

    if (userId == null) {
      throw const CyclixApiException(
        'El usuario fue registrado, pero no se pudo localizar su id para asignar mantenimiento.',
      );
    }

    return assignUserRole(userId: userId, role: 'MAINTENANCE');
  }

  Future<List<Map<String, dynamic>>> getMaintenanceUsers() async {
    final users = await getUsers();
    return users
        .where(
          (user) => user['role']?.toString().toUpperCase() == 'MAINTENANCE',
        )
        .toList();
  }

  Future<List<MaintenanceOrder>> getAdminMaintenanceOrders() async {
    final data = await get('/admin/maintenance/orders');
    return _asMapList(data).map(MaintenanceOrder.fromJson).toList();
  }

  Future<MaintenanceOrder> createAdminMaintenanceOrder({
    required Object bikeId,
    required String priority,
    required String type,
    required String reportedIssue,
    Object? assignedToUserId,
    int? estimatedMinutes,
    String? currentLocation,
  }) async {
    final body = <String, dynamic>{
      'bikeId': int.tryParse(bikeId.toString()) ?? bikeId,
      'priority': priority,
      'type': type,
      'reportedIssue': reportedIssue,
    };
    if (assignedToUserId != null) {
      body['assignedToUserId'] =
          int.tryParse(assignedToUserId.toString()) ?? assignedToUserId;
    }
    if (estimatedMinutes != null) body['estimatedMinutes'] = estimatedMinutes;
    if (currentLocation != null && currentLocation.trim().isNotEmpty) {
      body['currentLocation'] = currentLocation.trim();
    }

    final data = await post('/admin/maintenance/orders', body);
    return MaintenanceOrder.fromJson(_asMap(data));
  }

  Future<MaintenanceOrder> assignAdminMaintenanceOrder({
    required Object id,
    required Object assignedToUserId,
    int? estimatedMinutes,
  }) async {
    final body = <String, dynamic>{
      'assignedToUserId':
          int.tryParse(assignedToUserId.toString()) ?? assignedToUserId,
    };
    if (estimatedMinutes != null) body['estimatedMinutes'] = estimatedMinutes;
    final data = await put('/admin/maintenance/orders/$id/assign', body);
    return MaintenanceOrder.fromJson(_asMap(data));
  }

  Future<List<MaintenanceOrder>> getMyMaintenanceOrders() async {
    final data = await get('/maintenance/orders/my');
    return _asMapList(data).map(MaintenanceOrder.fromJson).toList();
  }

  Future<MaintenanceOrder> getMaintenanceOrder(Object id) async {
    final data = await get('/maintenance/orders/$id');
    return MaintenanceOrder.fromJson(_asMap(data));
  }

  Future<MaintenanceOrder> updateMaintenanceProgress({
    required Object id,
    String? status,
    String? diagnosis,
    String? resolutionNotes,
    String? currentLocation,
    int? estimatedMinutes,
    String? note,
  }) async {
    final body = <String, dynamic>{};
    if (status != null) body['status'] = status;
    if (diagnosis != null) body['diagnosis'] = diagnosis;
    if (resolutionNotes != null) body['resolutionNotes'] = resolutionNotes;
    if (currentLocation != null) body['currentLocation'] = currentLocation;
    if (estimatedMinutes != null) {
      body['estimatedMinutes'] = estimatedMinutes;
    }
    if (note != null) body['note'] = note;

    final data = await patch('/maintenance/orders/$id/progress', body);
    return MaintenanceOrder.fromJson(_asMap(data));
  }

  Future<MaintenanceOrder> resolveMaintenanceOrder({
    required Object id,
    required String resultStatus,
    required String resolutionNotes,
    String? outOfServiceReason,
    String? currentLocation,
  }) async {
    final body = <String, dynamic>{
      'resultStatus': resultStatus,
      'resolutionNotes': resolutionNotes,
    };
    if (outOfServiceReason != null) {
      body['outOfServiceReason'] = outOfServiceReason;
    }
    if (currentLocation != null) body['currentLocation'] = currentLocation;

    final data = await patch('/maintenance/orders/$id/resolve', body);
    return MaintenanceOrder.fromJson(_asMap(data));
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const CyclixApiException('La API devolvió un formato inesperado.');
  }

  List<Map<String, dynamic>> _asMapList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return const [];
  }

  bool _matchesDate(Object? startValue, Object? endValue, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime.tryParse(startValue?.toString() ?? '');
    final end = DateTime.tryParse(endValue?.toString() ?? '');
    if (start != null &&
        today.isBefore(DateTime(start.year, start.month, start.day))) {
      return false;
    }
    if (end != null && today.isAfter(DateTime(end.year, end.month, end.day))) {
      return false;
    }
    return true;
  }

  bool _matchesTime(Object? startValue, Object? endValue, DateTime now) {
    final start = _parseTimeOfDay(startValue);
    final end = _parseTimeOfDay(endValue);
    if (start == null || end == null) return true;
    if (start == end) return true;

    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (startMinutes < endMinutes) {
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    }
    return currentMinutes >= startMinutes || currentMinutes < endMinutes;
  }

  bool _matchesDay(Object? daysValue, DateTime now) {
    final raw = daysValue?.toString();
    if (raw == null || raw.trim().isEmpty) return true;
    const days = [
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
      'SUNDAY',
    ];
    final current = days[now.weekday - 1];
    final allowed = raw.split(',').map((item) => item.trim().toUpperCase());
    return allowed.contains(current);
  }

  _ClockTime? _parseTimeOfDay(Object? value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return _ClockTime(hour, minute);
  }
}

class _ClockTime {
  const _ClockTime(this.hour, this.minute);

  final int hour;
  final int minute;

  @override
  bool operator ==(Object other) {
    return other is _ClockTime && other.hour == hour && other.minute == minute;
  }

  @override
  int get hashCode => Object.hash(hour, minute);
}
