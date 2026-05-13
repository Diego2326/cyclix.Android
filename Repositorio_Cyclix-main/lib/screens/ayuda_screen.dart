import 'package:flutter/material.dart';

import '../theme/cyclix_colors.dart';
import '../widgets/cyclix_header.dart';
import '../widgets/cyclix_primary_button.dart';

class AyudaScreen extends StatelessWidget {
  const AyudaScreen({super.key});

  static const List<_PreguntaFrecuente> _faqs = [
    _PreguntaFrecuente(
      pregunta: '¿Cómo desbloqueo una bicicleta?',
      respuesta:
      'Escanea el código QR que está en el manillar de la bicicleta con la app y sigue las instrucciones en pantalla.',
    ),
    _PreguntaFrecuente(
      pregunta: '¿Cómo se calcula el costo del viaje?',
      respuesta:
      'El costo se calcula por minuto de uso desde que desbloqueas la bicicleta hasta que la devuelves a una estación.',
    ),
    _PreguntaFrecuente(
      pregunta: '¿Dónde puedo dejar la bicicleta?',
      respuesta:
      'Debes dejarla en cualquiera de las estaciones marcadas en el mapa de la app para que el viaje finalice correctamente.',
    ),
    _PreguntaFrecuente(
      pregunta: '¿Qué hago si la bicicleta tiene un problema?',
      respuesta:
      'Reporta el problema desde la sección Contacto o llama a nuestra línea de atención al cliente.',
    ),
  ];

  void _snack(BuildContext context, String mensaje) {
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Centro de Ayuda',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Preguntas frecuentes',
                style: TextStyle(
                  fontSize: 14,
                  color: CyclixColors.instructionGray,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: _faqs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _FaqTile(faq: _faqs[i]),
                ),
              ),
              const SizedBox(height: 20),
              CyclixPrimaryButton(
                label: 'Contactar soporte',
                onPressed: () =>
                    _snack(context, 'Contactar soporte — próximamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreguntaFrecuente {
  const _PreguntaFrecuente({
    required this.pregunta,
    required this.respuesta,
  });
  final String pregunta;
  final String respuesta;
}

class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.faq});
  final _PreguntaFrecuente faq;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _expanded ? CyclixColors.brandGreen : Colors.grey.shade200,
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        onExpansionChanged: (v) => setState(() => _expanded = v),
        iconColor: CyclixColors.brandGreen,
        collapsedIconColor: Colors.grey.shade400,
        title: Text(
          widget.faq.pregunta,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        children: [
          Text(
            widget.faq.respuesta,
            style: TextStyle(
              fontSize: 13,
              color: CyclixColors.instructionGray,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}