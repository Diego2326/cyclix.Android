import 'package:flutter/material.dart';

import '../services/cyclix_api_service.dart';
import '../theme/cyclix_colors.dart';
import '../widgets/cyclix_header.dart';

class SoporteScreen extends StatefulWidget {
  const SoporteScreen({
    super.key,
    this.initialCategory = 'APP',
    this.initialPriority = 'MEDIUM',
    this.bikeId,
    this.tripId,
  });

  final String initialCategory;
  final String initialPriority;
  final Object? bikeId;
  final Object? tripId;

  @override
  State<SoporteScreen> createState() => _SoporteScreenState();
}

class _SoporteScreenState extends State<SoporteScreen> {
  final CyclixApiService _api = CyclixApiService();
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();

  late String _category;
  late String _priority = widget.initialPriority;
  late Future<List<Map<String, dynamic>>> _tickets = _api.getMyTickets();
  bool _saving = false;

  static const _categories = [
    'BIKE',
    'APP',
    'PAYMENT',
    'ACCOUNT',
    'TRIP',
    'EMERGENCY',
    'OTHER',
  ];

  static const _priorities = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];

  static const _categoryLabels = {
    'BIKE': 'Bicicleta',
    'APP': 'Aplicación',
    'PAYMENT': 'Pago',
    'ACCOUNT': 'Cuenta',
    'TRIP': 'Viaje',
    'EMERGENCY': 'Emergencia',
    'OTHER': 'Otro',
  };

  static const _priorityLabels = {
    'LOW': 'Baja',
    'MEDIUM': 'Media',
    'HIGH': 'Alta',
    'CRITICAL': 'Crítica',
  };

  static const _statusLabels = {
    'OPEN': 'Abierto',
    'PENDING': 'Pendiente',
    'IN_PROGRESS': 'En progreso',
    'WAITING_USER': 'Esperando respuesta',
    'RESOLVED': 'Resuelto',
    'CLOSED': 'Cerrado',
  };

  String _categoryLabel(Object? value) {
    final key = value?.toString();
    return _categoryLabels[key] ?? key ?? '';
  }

  String _priorityLabel(Object? value) {
    final key = value?.toString();
    return _priorityLabels[key] ?? key ?? '';
  }

  String _statusLabel(Object? value) {
    final key = value?.toString();
    return _statusLabels[key] ?? key ?? '';
  }

  List<String> get _availableCategories {
    if (widget.bikeId != null) return _categories;
    return _categories.where((category) => category != 'BIKE').toList();
  }

  String _errorMessage(Object error) {
    if (error is CyclixApiException) {
      return error.message;
    }
    final text = error.toString();
    if (text.contains('SocketException') ||
        text.contains('Connection refused') ||
        text.contains('Failed host lookup')) {
      return 'No se pudo conectar con la API. Revisa tu conexión.';
    }
    if (text.contains('FormatException')) {
      return 'La API devolvió una respuesta inesperada. Inténtalo de nuevo.';
    }
    return 'No se pudo crear el reporte. Inténtalo de nuevo.';
  }

  @override
  void initState() {
    super.initState();
    final categories = _availableCategories;
    _category = categories.contains(widget.initialCategory)
        ? widget.initialCategory
        : 'APP';
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _createTicket() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    if (_category == 'BIKE' && widget.bikeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Para reportar una bicicleta, primero debes seleccionar una bicicleta.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (_category == 'BIKE' && widget.bikeId != null) {
        await _api.createFailureReport(
          bikeId: widget.bikeId!,
          tripId: widget.tripId,
          priority: _priority,
          title: _title.text.trim(),
          description: _description.text.trim(),
        );
      } else {
        await _api.createTicket(
          category: _category,
          priority: _priority,
          title: _title.text.trim(),
          description: _description.text.trim(),
          bikeId: widget.bikeId,
          tripId: widget.tripId,
        );
      }
      _title.clear();
      _description.clear();
      setState(() => _tickets = _api.getMyTickets());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reporte creado correctamente.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: CyclixColors.backgroundWhite,
      appBar: const CyclixHeader(showBack: true),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 24 + bottom),
          children: [
            Text(
              'Centro de soporte',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    items: _availableCategories
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_categoryLabel(value)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _category = value!),
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _priority,
                    items: _priorities
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_priorityLabel(value)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _priority = value!),
                    decoration: const InputDecoration(
                      labelText: 'Prioridad',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: 'Título',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Escribe un título'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Describe el problema'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _saving ? null : _createTicket,
                    style: FilledButton.styleFrom(
                      backgroundColor: CyclixColors.accentGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_outlined),
                    label: const Text('Crear reporte'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Mis reportes',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _tickets,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Text(
                    _errorMessage(snapshot.error!),
                    style: const TextStyle(color: CyclixColors.instructionGray),
                  );
                }

                final tickets = snapshot.data ?? [];
                if (tickets.isEmpty) {
                  return const Text('No tienes reportes aún.');
                }

                return Column(
                  children: tickets
                      .map(
                        (ticket) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.confirmation_number_outlined,
                            color: CyclixColors.primaryBlue,
                          ),
                          title: Text(ticket['title']?.toString() ?? ''),
                          subtitle: Text(
                            '${_categoryLabel(ticket['category'])} · ${_priorityLabel(ticket['priority'])} · ${_statusLabel(ticket['status'])}',
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
