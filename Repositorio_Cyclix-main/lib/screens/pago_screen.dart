import 'package:flutter/material.dart';

import '../theme/cyclix_colors.dart';
import '../widgets/cyclix_header.dart';
import '../widgets/cyclix_primary_button.dart';

class PagoScreen extends StatefulWidget {
  const PagoScreen({super.key});

  @override
  State<PagoScreen> createState() => _PagoScreenState();
}

class _PagoScreenState extends State<PagoScreen> {
  String _metodoPagoSeleccionado = 'Visa';

  void _snack(String mensaje) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: CyclixColors.brandGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyclixColors.scaffoldBackground,
      appBar: const CyclixHeader(showBack: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _ConfirmacionHeader(),
              const SizedBox(height: 32),
              const _SectionTitle(titulo: 'Resumen del viaje'),
              const SizedBox(height: 8),
              const _ResumenViaje(),
              const SizedBox(height: 28),
              const _SectionTitle(titulo: 'Método de pago'),
              const SizedBox(height: 8),
              _MetodoPagoTile(
                titulo: 'Visa',
                icono: Icons.credit_card,
                seleccionado: _metodoPagoSeleccionado == 'Visa',
                onTap: () => setState(() => _metodoPagoSeleccionado = 'Visa'),
              ),
              const SizedBox(height: 8),
              _MetodoPagoTile(
                titulo: 'MasterCard',
                icono: Icons.credit_card_outlined,
                seleccionado: _metodoPagoSeleccionado == 'MasterCard',
                onTap: () =>
                    setState(() => _metodoPagoSeleccionado = 'MasterCard'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _snack('Agregar tarjeta — próximamente'),
                icon: Icon(Icons.add, color: CyclixColors.brandGreen),
                label: Text(
                  'Agregar nueva tarjeta',
                  style: TextStyle(color: CyclixColors.brandGreen),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: CyclixColors.brandGreen),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              CyclixPrimaryButton(
                label: 'Pagar Q.90.00',
                onPressed: () => _snack('Procesando pago — próximamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widgets privados ─────────────────────────────────────────────────────────

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
            color: CyclixColors.brandGreen.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle_outline_rounded,
            color: CyclixColors.brandGreen,
            size: 44,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Gracias por utilizar\nnuestro servicio',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tu viaje ha finalizado',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: CyclixColors.instructionGray,
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
        color: Colors.black87,
      ),
    );
  }
}

class _ResumenViaje extends StatelessWidget {
  const _ResumenViaje();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const _FilaResumen(label: 'Duración', valor: '45 min'),
          Divider(height: 1, color: Colors.grey.shade100),
          const _FilaResumen(label: 'Distancia', valor: '3.2 km'),
          Divider(height: 1, color: Colors.grey.shade100),
          const _FilaResumen(
            label: 'Total a pagar',
            valor: 'Q.90.00',
            destacado: true,
          ),
        ],
      ),
    );
  }
}

class _FilaResumen extends StatelessWidget {
  const _FilaResumen({
    required this.label,
    required this.valor,
    this.destacado = false,
  });
  final String label;
  final String valor;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final style = destacado
        ? TextStyle(
      fontWeight: FontWeight.bold,
      color: CyclixColors.brandGreen,
      fontSize: 15,
    )
        : const TextStyle(color: Colors.black87, fontSize: 14);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(valor, style: style),
        ],
      ),
    );
  }
}

class _MetodoPagoTile extends StatelessWidget {
  const _MetodoPagoTile({
    required this.titulo,
    required this.icono,
    required this.seleccionado,
    required this.onTap,
  });
  final String titulo;
  final IconData icono;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
            seleccionado ? CyclixColors.brandGreen : Colors.grey.shade200,
            width: seleccionado ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icono,
              color: seleccionado
                  ? CyclixColors.brandGreen
                  : CyclixColors.instructionGray,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                titulo,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: seleccionado ? Colors.black87 : Colors.black54,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: seleccionado
                  ? Icon(Icons.check_circle_rounded,
                  key: const ValueKey('check'),
                  color: CyclixColors.brandGreen)
                  : Icon(Icons.circle_outlined,
                  key: const ValueKey('empty'),
                  color: Colors.grey.shade300),
            ),
          ],
        ),
      ),
    );
  }
}