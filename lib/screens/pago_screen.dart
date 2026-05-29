import 'package:flutter/material.dart';

import '../theme/cyclix_colors.dart';
import '../widgets/cyclix_header.dart';
import '../widgets/cyclix_primary_button.dart';

class PagoScreen extends StatelessWidget {
  const PagoScreen({super.key, required this.trip});

  final Map<String, dynamic> trip;

  String _money(Object? value) {
    final number = num.tryParse(value?.toString() ?? '');
    return 'Q.${(number ?? 0).toStringAsFixed(2)}';
  }

  String _minutes(Object? value) => '${value ?? 0} min';

  String _duration(Object? secondsValue) {
    final seconds = int.tryParse(secondsValue?.toString() ?? '') ?? 0;
    final minutes = (seconds / 60).ceil();
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: CyclixColors.backgroundWhite,
      appBar: const CyclixHeader(showBack: true),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 32 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _ConfirmacionHeader(),
              const SizedBox(height: 32),
              const _SectionTitle(titulo: 'Resumen del viaje'),
              const SizedBox(height: 8),
              _ResumenViaje(
                rows: [
                  _SummaryRow('Duración', _duration(trip['durationSeconds'])),
                  _SummaryRow(
                    'Distancia',
                    '${num.tryParse(trip['distanceKm']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'} km',
                  ),
                  _SummaryRow(
                    'Tarifa aplicada',
                    trip['pricingRuleName']?.toString() ?? 'Tarifa estándar',
                  ),
                  _SummaryRow(
                    'Minutos cubiertos por plan',
                    _minutes(trip['subscriptionMinutesCovered']),
                  ),
                  _SummaryRow(
                    'Minutos cobrados',
                    _minutes(trip['billableMinutes']),
                  ),
                  _SummaryRow('Subtotal base', _money(trip['baseFareApplied'])),
                  _SummaryRow('Extras', _money(trip['extraAmount'])),
                  _SummaryRow(
                    'Cobrado a la billetera',
                    _money(trip['walletChargedAmount'] ?? trip['totalAmount']),
                    highlighted: true,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'El pago se descontó del saldo de tu billetera.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: CyclixColors.instructionGray,
                ),
              ),
              const SizedBox(height: 32),
              CyclixPrimaryButton(
                label: 'Volver al inicio',
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/main',
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmacionHeader extends StatelessWidget {
  const _ConfirmacionHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: CyclixColors.accentGreen.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_outline_rounded,
            color: CyclixColors.accentGreen,
            size: 44,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Viaje finalizado',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: CyclixColors.textDark,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.titulo});
  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Text(
      titulo,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: CyclixColors.textDark,
      ),
    );
  }
}

class _SummaryRow {
  const _SummaryRow(this.label, this.value, {this.highlighted = false});

  final String label;
  final String value;
  final bool highlighted;
}

class _ResumenViaje extends StatelessWidget {
  const _ResumenViaje({required this.rows});

  final List<_SummaryRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CyclixColors.cardGrey,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _FilaResumen(row: rows[i]),
            if (i != rows.length - 1)
              Divider(height: 1, color: Colors.grey.shade100),
          ],
        ],
      ),
    );
  }
}

class _FilaResumen extends StatelessWidget {
  const _FilaResumen({required this.row});
  final _SummaryRow row;

  @override
  Widget build(BuildContext context) {
    final style = row.highlighted
        ? const TextStyle(
            fontWeight: FontWeight.bold,
            color: CyclixColors.accentGreen,
            fontSize: 15,
          )
        : const TextStyle(color: CyclixColors.textDark, fontSize: 14);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(child: Text(row.label, style: style)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              row.value,
              textAlign: TextAlign.end,
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
