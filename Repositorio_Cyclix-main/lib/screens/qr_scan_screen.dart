import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/bike_info.dart';
import '../theme/cyclix_colors.dart';
import '../widgets/cyclix_header.dart';
import '../widgets/cyclix_primary_button.dart';
import 'bike_detail_screen.dart';

/// Pantalla de escaneo QR. Usa [embeddedInShell] en la pestaña Buscar (sin AppBar propia).
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

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  /// Bicicleta de ejemplo para demo / hasta que el backend defina el formato del QR.
  static const BikeInfo _exampleBike = BikeInfo(
    id: '1234',
    costPerMinuteDisplay: 'Costo Q.1.00 / min',
  );

  void _openDetailFromPayload(String raw) {
    if (_handled) return;
    _handled = true;
    final bikeId = raw.trim().isEmpty ? _exampleBike.id : raw.trim();
    final bike = BikeInfo(
      id: bikeId,
      costPerMinuteDisplay: _exampleBike.costPerMinuteDisplay,
    );
    if (!mounted) return;
    Navigator.of(context)
        .push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BikeDetailScreen(bike: bike),
      ),
    )
        .then((_) {
      if (mounted) setState(() => _handled = false);
    });
  }

  void _simulateScan() {
    _openDetailFromPayload(_exampleBike.id);
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _scanner,
                    onDetect: (capture) {
                      final codes = capture.barcodes;
                      if (codes.isEmpty) return;
                      final raw = codes.first.rawValue;
                      if (raw != null) _openDetailFromPayload(raw);
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
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            widget.embeddedInShell ? 16 : 24,
          ),
          child: CyclixPrimaryButton(
            label: 'Escanear',
            onPressed: _simulateScan,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embeddedInShell) {
      return ColoredBox(
        color: Colors.white,
        child: _buildBody(context),
      );
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
