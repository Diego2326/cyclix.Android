import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const CyclixWearApp());
}

class CyclixWearApp extends StatelessWidget {
  const CyclixWearApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cyclix Watch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF25B84B),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF050B12),
        useMaterial3: true,
      ),
      home: const StartupScreen(),
    );
  }
}

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  final _api = CyclixWearApi();
  late Future<bool> _hasSession;

  @override
  void initState() {
    super.initState();
    _hasSession = _api.hasToken();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasSession,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingScaffold();
        }
        return snapshot.data == true
            ? WearHomeScreen(api: _api)
            : LoginScreen(api: _api);
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.api});

  final CyclixWearApi api;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty || _loading) {
      setState(() => _error = 'Correo y contrasena requeridos.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.api.login(email: email, password: password);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => WearHomeScreen(api: widget.api),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          children: [
            const _BrandMark(),
            const SizedBox(height: 18),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Clave',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFFF7070), fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _login,
              child: _loading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Entrar'),
            ),
          ],
        ),
      ),
    );
  }
}

class WearHomeScreen extends StatefulWidget {
  const WearHomeScreen({super.key, required this.api});

  final CyclixWearApi api;

  @override
  State<WearHomeScreen> createState() => _WearHomeScreenState();
}

class _WearHomeScreenState extends State<WearHomeScreen> {
  late Future<WearSummary> _summary = _load();
  bool _busy = false;

  Future<WearSummary> _load() async {
    final wallet = await _safeMap(
      widget.api.getWallet,
      fallback: const {'balance': 0, 'currency': 'GTQ'},
    );
    final trips = await _safeList(widget.api.getMyTrips);
    final stations = await _safeList(widget.api.getStations);
    final activeTrip = _findActiveTrip(trips);
    final nearestStation = _firstStation(stations);

    return WearSummary(
      wallet: wallet,
      activeTrip: activeTrip,
      nearestStation: nearestStation,
      nfcEnabled: Platform.isAndroid,
    );
  }

  void _refresh() {
    setState(() {
      _summary = _load();
    });
  }

  Future<void> _logout() async {
    await widget.api.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => LoginScreen(api: widget.api)),
    );
  }

  Future<void> _scanNfc() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await widget.api.scanAndStartTrip();
      _showSnack(result);
      _refresh();
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finishTrip(Object tripId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.api.finishTrip(tripId);
      _showSnack('Viaje finalizado.');
      _refresh();
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: FutureBuilder<WearSummary>(
            future: _summary,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _LoadingScaffold(compact: true);
              }
              if (snapshot.hasError || snapshot.data == null) {
                return ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    const _BrandMark(),
                    const SizedBox(height: 18),
                    const Text(
                      'No se pudo cargar Cyclix.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _refresh,
                      child: const Text('Reintentar'),
                    ),
                    TextButton(onPressed: _logout, child: const Text('Salir')),
                  ],
                );
              }

              final summary = snapshot.data!;
              final activeTrip = summary.activeTrip;

              return ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                children: [
                  Row(
                    children: [
                      const Expanded(child: _BrandMark(compact: true)),
                      IconButton(
                        tooltip: 'Salir',
                        onPressed: _logout,
                        icon: const Icon(Icons.logout, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _InfoTile(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Wallet',
                    value: _money(summary.wallet['balance']),
                  ),
                  const SizedBox(height: 8),
                  _InfoTile(
                    icon: Icons.location_on_outlined,
                    label: 'Estacion disponible',
                    value: summary.nearestStation?.name ?? 'No disponible',
                    subtitle: summary.nearestStation?.distanceText,
                  ),
                  const SizedBox(height: 8),
                  if (activeTrip == null)
                    _ActionTile(
                      icon: Icons.nfc,
                      label: 'Desbloquear con NFC',
                      busy: _busy,
                      onTap: summary.nfcEnabled ? _scanNfc : null,
                    )
                  else
                    _ActiveTripTile(
                      trip: activeTrip,
                      busy: _busy,
                      onFinish: () => _finishTrip(activeTrip['id'] ?? ''),
                    ),
                  const SizedBox(height: 8),
                  _ActionTile(
                    icon: Icons.support_agent_outlined,
                    label: 'Soporte rapido',
                    onTap: () => _showSnack(
                      'Para la demo: reporte rapido desde reloj preparado.',
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

Future<Map<String, dynamic>> _safeMap(
  Future<Map<String, dynamic>> Function() loader, {
  required Map<String, dynamic> fallback,
}) async {
  try {
    return await loader();
  } catch (_) {
    return fallback;
  }
}

Future<List<Map<String, dynamic>>> _safeList(
  Future<List<Map<String, dynamic>>> Function() loader,
) async {
  try {
    return await loader();
  } catch (_) {
    return const [];
  }
}

class CyclixWearApi {
  static const baseUrl = 'https://api.cyclix.site/api/v1';
  static const _tokenKey = 'cyclix_token';
  static const _emailKey = 'cyclix_email';
  static const _requestTimeout = Duration(seconds: 15);

  Future<bool> hasToken() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_tokenKey) ?? '').isNotEmpty;
  }

  Future<void> login({required String email, required String password}) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(_requestTimeout);
    final data = _decode(response);
    if (data is! Map || data['token'] == null) {
      throw Exception('Respuesta de login invalida.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, data['token'].toString());
    await prefs.setString(_emailKey, email);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_emailKey);
  }

  Future<Map<String, dynamic>> getWallet() async {
    return Map<String, dynamic>.from(await _get('/wallet/my') as Map);
  }

  Future<List<Map<String, dynamic>>> getMyTrips() async {
    final data = await _get('/trips/my');
    return _asMapList(data);
  }

  Future<List<Map<String, dynamic>>> getStations() async {
    final data = await _get('/puestos/activos');
    return _asMapList(data);
  }

  Future<bool> checkNfcAvailability() async {
    if (!Platform.isAndroid) return false;
    final availability = await NfcManager.instance.checkAvailability();
    return availability == NfcAvailability.enabled;
  }

  Future<String> scanAndStartTrip() async {
    if (!await checkNfcAvailability()) {
      throw Exception('Este reloj no tiene NFC disponible para la app.');
    }

    final completer = _OneShotCompleter<String>();
    await NfcManager.instance.startSession(
      pollingOptions: const {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
      },
      onDiscovered: (tag) async {
        try {
          final payload = await _readNdefPayload(tag);
          final identifier = _readTagIdentifier(tag);
          final raw = payload?.trim().isNotEmpty == true
              ? payload!.trim()
              : identifier;

          await NfcManager.instance.stopSession(
            alertMessageIos: 'Bicicleta leida.',
          );
          if (raw == null || raw.isEmpty) {
            completer.completeError('Tag NFC sin identificador.');
            return;
          }

          final bike = await _bikeFromTag(raw);
          final position = await _currentPositionOrDefault();
          await _ensureZoneAllowed(position, start: true);
          await _post('/trips', {
            'bikeId': _asInt(bike['id']),
            'startLatitude': position.latitude,
            'startLongitude': position.longitude,
          });
          completer.complete('Bicicleta desbloqueada.');
        } catch (e) {
          await NfcManager.instance.stopSession(errorMessageIos: e.toString());
          completer.completeError(e.toString());
        }
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () async {
        await NfcManager.instance.stopSession();
        throw Exception('Tiempo agotado leyendo NFC.');
      },
    );
  }

  Future<void> finishTrip(Object tripId) async {
    final position = await _currentPositionOrDefault();
    await _ensureZoneAllowed(position, start: false);
    await _put('/trips/$tripId/finish', {
      'endLatitude': position.latitude,
      'endLongitude': position.longitude,
    });
  }

  Future<dynamic> _get(String path) async {
    final response = await http
        .get(Uri.parse('$baseUrl$path'), headers: await _headers())
        .timeout(_requestTimeout);
    return _decode(response);
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: await _headers(),
          body: jsonEncode(body),
        )
        .timeout(_requestTimeout);
    return _decode(response);
  }

  Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl$path'),
          headers: await _headers(),
          body: jsonEncode(body),
        )
        .timeout(_requestTimeout);
    return _decode(response);
  }

  Future<void> _ensureZoneAllowed(GeoPoint point, {required bool start}) async {
    final data = await _post('/zones/validate', {
      'latitude': point.latitude,
      'longitude': point.longitude,
    });
    if (data is Map && data['allowed'] == false) {
      throw Exception(
        data['message']?.toString() ??
            (start
                ? 'No puedes iniciar fuera de una zona habilitada.'
                : 'Debes finalizar dentro de una zona habilitada.'),
      );
    }
  }

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  dynamic _decode(http.Response response) {
    final text = utf8.decode(response.bodyBytes);
    final dynamic decoded = text.isEmpty ? null : _tryDecodeJson(text);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    if (decoded is Map) {
      throw Exception(
        decoded['message']?.toString() ??
            decoded['error']?.toString() ??
            'Error ${response.statusCode}',
      );
    }
    if (text.trim().isNotEmpty) {
      throw Exception('Error ${response.statusCode}: ${text.trim()}');
    }
    throw Exception('Error ${response.statusCode}');
  }

  dynamic _tryDecodeJson(String text) {
    try {
      return jsonDecode(text);
    } catch (_) {
      return text;
    }
  }

  Future<Map<String, dynamic>> _bikeFromTag(String raw) async {
    final bikeId = _bikeIdFromPayload(raw);
    final path = bikeId.startsWith('CYCLIX-BICI-')
        ? '/bicicletas/qr/${Uri.encodeComponent(bikeId)}'
        : '/bicicletas/$bikeId';
    return Map<String, dynamic>.from(await _get(path) as Map);
  }

  String _bikeIdFromPayload(String raw) {
    final trimmed = raw.trim();
    final uri = Uri.tryParse(trimmed);
    final fromQuery =
        uri?.queryParameters['bikeId'] ??
        uri?.queryParameters['bike'] ??
        uri?.queryParameters['id'];
    if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;
    final segments = uri?.pathSegments ?? const <String>[];
    if (segments.isNotEmpty) return segments.last;
    return trimmed;
  }

  Future<GeoPoint> _currentPositionOrDefault() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (enabled) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 8),
            ),
          );
          return GeoPoint(position.latitude, position.longitude);
        }
      }
    } catch (_) {
      // Fallback for demo devices without granted location.
    }
    return const GeoPoint(14.6349, -90.5069);
  }

  Future<String?> _readNdefPayload(NfcTag tag) async {
    NdefMessage? message;
    if (Platform.isAndroid) {
      final ndef = NdefAndroid.from(tag);
      message = ndef?.cachedNdefMessage;
      if (message == null && ndef != null) {
        message = await ndef.getNdefMessage();
      }
    }
    if (message == null) return null;
    for (final record in message.records) {
      final value = _decodeNdefRecord(record);
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  String? _decodeNdefRecord(NdefRecord record) {
    final type = ascii.decode(record.type, allowInvalid: true);
    if (record.typeNameFormat == TypeNameFormat.wellKnown && type == 'T') {
      return _decodeTextRecord(record.payload);
    }
    if (record.typeNameFormat == TypeNameFormat.wellKnown && type == 'U') {
      return _decodeUriRecord(record.payload);
    }
    return utf8.decode(record.payload, allowMalformed: true);
  }

  String _decodeTextRecord(Uint8List payload) {
    if (payload.isEmpty) return '';
    final languageCodeLength = payload.first & 0x3F;
    if (payload.length <= languageCodeLength + 1) return '';
    return utf8.decode(
      payload.sublist(languageCodeLength + 1),
      allowMalformed: true,
    );
  }

  String _decodeUriRecord(Uint8List payload) {
    if (payload.isEmpty) return '';
    const prefixes = <int, String>{
      0x00: '',
      0x01: 'http://www.',
      0x02: 'https://www.',
      0x03: 'http://',
      0x04: 'https://',
    };
    final prefix = prefixes[payload.first] ?? '';
    return prefix + utf8.decode(payload.sublist(1), allowMalformed: true);
  }

  String? _readTagIdentifier(NfcTag tag) {
    Uint8List? identifier;
    if (Platform.isAndroid) {
      identifier = NfcTagAndroid.from(tag)?.id;
    }
    return identifier
        ?.map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}

class WearSummary {
  const WearSummary({
    required this.wallet,
    required this.nfcEnabled,
    this.activeTrip,
    this.nearestStation,
  });

  final Map<String, dynamic> wallet;
  final Map<String, dynamic>? activeTrip;
  final NearestStation? nearestStation;
  final bool nfcEnabled;
}

class NearestStation {
  const NearestStation({required this.name, required this.distanceMeters});

  final String name;
  final double distanceMeters;

  String get distanceText {
    if (distanceMeters < 1000) return '${distanceMeters.round()} m';
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }
}

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

class _OneShotCompleter<T> {
  bool _completed = false;
  final _inner = Completer<T>();

  Future<T> get future => _inner.future;

  void complete(T value) {
    if (_completed) return;
    _completed = true;
    _inner.complete(value);
  }

  void completeError(Object error) {
    if (_completed) return;
    _completed = true;
    _inner.completeError(error);
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.directions_bike,
          color: const Color(0xFF25B84B),
          size: compact ? 24 : 42,
        ),
        const SizedBox(height: 4),
        Text(
          'CYCLIX',
          style: TextStyle(
            fontSize: compact ? 15 : 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF101A24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF223243)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF25B84B), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: busy ? null : onTap,
      icon: busy
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}

class _ActiveTripTile extends StatelessWidget {
  const _ActiveTripTile({
    required this.trip,
    required this.onFinish,
    required this.busy,
  });

  final Map<String, dynamic> trip;
  final VoidCallback onFinish;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E2A18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF25B84B)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: Color(0xFF25B84B)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Viaje #${trip['id'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy ? null : onFinish,
              child: const Text('Finalizar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final spinner = const CircularProgressIndicator(strokeWidth: 2);
    if (compact) return Center(child: spinner);
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

Map<String, dynamic>? _findActiveTrip(List<Map<String, dynamic>> trips) {
  for (final trip in trips) {
    final status = trip['status']?.toString().toUpperCase() ?? '';
    if (status == 'ACTIVE' || status == 'IN_PROGRESS' || status == 'STARTED') {
      return trip;
    }
    if (trip['endTime'] == null && trip['finishedAt'] == null) return trip;
  }
  return null;
}

NearestStation? _firstStation(List<Map<String, dynamic>> stations) {
  if (stations.isEmpty) return null;
  final first = stations.first;
  return NearestStation(
    name: first['nombre']?.toString() ?? 'Estacion',
    distanceMeters: 0,
  );
}

List<Map<String, dynamic>> _asMapList(dynamic data) {
  if (data is List) {
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  return const [];
}

int _asInt(Object? value) => int.tryParse(value?.toString() ?? '') ?? 0;

String _money(Object? value) {
  final number = num.tryParse(value?.toString() ?? '') ?? 0;
  return 'Q${number.toStringAsFixed(2)}';
}
