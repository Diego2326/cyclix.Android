import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

import '../models/bike_info.dart';
import '../theme/cyclix_colors.dart';
import '../widgets/cyclix_header.dart';
import '../widgets/cyclix_primary_button.dart';
import 'bike_detail_screen.dart';

/// Pantalla de lectura NFC. Conserva el nombre de clase para no tocar el shell.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({
    super.key,
    this.stationName,
    this.embeddedInShell = false,
  });

  final String? stationName;
  final bool embeddedInShell;

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _handled = false;
  bool _isScanning = false;
  String _message = 'Acerca tu teléfono al tag NFC de la bicicleta.';

  static const BikeInfo _exampleBike = BikeInfo(
    id: '1234',
    costPerMinuteDisplay: 'Costo Q.1.00 / min',
  );

  @override
  void dispose() {
    _stopNfcSession();
    _scanner.dispose();
    super.dispose();
  }

  bool get _usesNfc => Platform.isAndroid;

  Future<void> _startNfcSession() async {
    if (_isScanning || _handled) return;

    final availability = await NfcManager.instance.checkAvailability();
    if (!mounted) return;

    if (availability != NfcAvailability.enabled) {
      setState(() {
        _message =
            'NFC no está disponible o está desactivado en este dispositivo.';
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _message = 'Buscando tag NFC...';
    });

    await NfcManager.instance.startSession(
      pollingOptions: const {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
      },
      onDiscovered: (tag) async {
        await _handleTag(tag);
      },
    );
  }

  Future<void> _stopNfcSession() async {
    if (!_isScanning) return;
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {
      // La sesión puede no existir si el sistema la cerró antes.
    }
  }

  Future<void> _handleTag(NfcTag tag) async {
    if (_handled) return;
    _handled = true;

    final payload = await _readNdefPayload(tag);
    final tagId = _readTagIdentifier(tag);
    final raw = payload?.trim().isNotEmpty == true ? payload!.trim() : tagId;

    await NfcManager.instance.stopSession(
      alertMessageIos: 'Tag NFC leído correctamente.',
    );

    if (!mounted) return;
    setState(() {
      _isScanning = false;
      _message = 'Tag leído.';
    });
    _openDetailFromPayload(raw ?? _exampleBike.id);
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

    return identifier == null ? null : _bytesToHex(identifier);
  }

  String _bytesToHex(Uint8List bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  void _openDetailFromPayload(String raw) {
    final bikeId = _bikeIdFromPayload(raw);
    final bike = BikeInfo(
      id: bikeId,
      costPerMinuteDisplay: _exampleBike.costPerMinuteDisplay,
    );

    Navigator.of(context)
        .push<void>(
          MaterialPageRoute<void>(builder: (_) => BikeDetailScreen(bike: bike)),
        )
        .then((_) {
          if (mounted) {
            setState(() {
              _handled = false;
              _message = _usesNfc
                  ? 'Acerca tu teléfono al tag NFC de la bicicleta.'
                  : 'Apunta la cámara al código QR de la bicicleta.';
            });
          }
        });
  }

  String _bikeIdFromPayload(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return _exampleBike.id;

    final uri = Uri.tryParse(value);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }

    return value;
  }

  void _simulateScan() {
    if (_handled) return;
    _handled = true;
    _openDetailFromPayload(_exampleBike.id);
  }

  Widget _buildScannerArea(BuildContext context) {
    if (!_usesNfc) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _scanner,
              onDetect: (capture) {
                final codes = capture.barcodes;
                if (codes.isEmpty || _handled) return;
                final raw = codes.first.rawValue;
                if (raw != null) {
                  _handled = true;
                  _openDetailFromPayload(raw);
                }
              },
            ),
            CustomPaint(
              painter: ScannerFramePainter(),
              child: const Center(
                child: Text(
                  'Escanea el QR',
                  style: TextStyle(
                    color: CyclixColors.instructionGray,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: CyclixColors.cardGrey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.nfc,
                size: 96,
                color: _isScanning
                    ? CyclixColors.brandGreen
                    : CyclixColors.primaryBlue,
              ),
              const SizedBox(height: 18),
              Text(
                _isScanning ? 'Escaneando NFC' : 'Escanear tag NFC',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: CyclixColors.textDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: CyclixColors.instructionGray,
                ),
              ),
              if (_isScanning) ...[
                const SizedBox(height: 24),
                const CircularProgressIndicator(
                  color: CyclixColors.primaryBlue,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      children: [
        if (widget.stationName != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Estación: ${widget.stationName}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: CyclixColors.instructionGray,
              ),
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _buildScannerArea(context),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            widget.embeddedInShell ? 16 : 24,
          ),
          child: Column(
            children: [
              CyclixPrimaryButton(
                label: _usesNfc
                    ? (_isScanning ? 'Cancelar lectura NFC' : 'Leer tag NFC')
                    : 'Escanear QR',
                onPressed: _usesNfc
                    ? (_isScanning
                          ? () async {
                              await _stopNfcSession();
                              if (!mounted) return;
                              setState(() {
                                _isScanning = false;
                                _message =
                                    'Acerca tu teléfono al tag NFC de la bicicleta.';
                              });
                            }
                          : _startNfcSession)
                    : null,
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _simulateScan,
                child: const Text('Simular lectura (demo)'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embeddedInShell) {
      return ColoredBox(color: Colors.white, child: _buildBody(context));
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CyclixHeader(showBack: true),
      body: _buildBody(context),
    );
  }
}

class ScannerFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const bracket = 40.0;
    const stroke = 4.0;
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    final left = w * 0.12;
    final top = h * 0.18;
    final right = w * 0.88;
    final bottom = h * 0.72;

    canvas.drawPath(
      Path()
        ..moveTo(left, top + bracket)
        ..lineTo(left, top)
        ..lineTo(left + bracket, top),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(right - bracket, top)
        ..lineTo(right, top)
        ..lineTo(right, top + bracket),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(left, bottom - bracket)
        ..lineTo(left, bottom)
        ..lineTo(left + bracket, bottom),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(right - bracket, bottom)
        ..lineTo(right, bottom)
        ..lineTo(right, bottom - bracket),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
