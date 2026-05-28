import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/maintenance_order.dart';
import '../services/cyclix_api_service.dart';
import '../services/auth_service.dart';
import '../theme/cyclix_colors.dart';
import '../widgets/cyclix_drawer.dart';

class MaintenanceShell extends StatefulWidget {
  const MaintenanceShell({super.key});

  @override
  State<MaintenanceShell> createState() => _MaintenanceShellState();
}

class _MaintenanceShellState extends State<MaintenanceShell> {
  final CyclixApiService _api = CyclixApiService();
  late Future<List<MaintenanceOrder>> _ordersFuture;
  String _technicianName = '';
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _api.getMyMaintenanceOrders();
    _loadTechnicianName();
  }

  Future<void> _loadTechnicianName() async {
    final user = await AuthService().getUserData();
    if (!mounted) return;
    setState(() {
      _technicianName = _displayNameFromUser(user);
    });
  }

  void _refresh() {
    setState(() {
      _ordersFuture = _api.getMyMaintenanceOrders();
    });
  }

  Future<void> _openDetail(MaintenanceOrder order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaintenanceDetailScreen(orderId: order.id),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyclixColors.backgroundWhite,
      drawer: const CyclixDrawer(),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Builder(
          builder: (context) => _MaintenanceHeader(
            showMenu: true,
            onMenu: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
      ),
      body: FutureBuilder<List<MaintenanceOrder>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: CyclixColors.primaryBlue),
            );
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: 'No se pudieron cargar tus órdenes.',
              onRetry: _refresh,
            );
          }
          final orders = snapshot.data ?? const [];
          return IndexedStack(
            index: _index,
            children: [
              MaintenanceHomeScreen(
                orders: orders,
                technicianName: _technicianName,
                onOpenList: () => setState(() => _index = 1),
                onOpenOrder: _openDetail,
                onRefresh: _refresh,
              ),
              MaintenanceBikeListScreen(
                orders: orders,
                onOpenOrder: _openDetail,
                onRefresh: _refresh,
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        height: 64,
        selectedIndex: _index,
        backgroundColor: Colors.white,
        indicatorColor: CyclixColors.accentGreen.withValues(alpha: 0.12),
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: CyclixColors.accentGreen),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.pedal_bike_outlined),
            selectedIcon: Icon(
              Icons.pedal_bike,
              color: CyclixColors.accentGreen,
            ),
            label: 'Bicicletas',
          ),
        ],
      ),
    );
  }
}

class MaintenanceHomeScreen extends StatelessWidget {
  const MaintenanceHomeScreen({
    super.key,
    required this.orders,
    required this.technicianName,
    required this.onOpenList,
    required this.onOpenOrder,
    required this.onRefresh,
  });

  final List<MaintenanceOrder> orders;
  final String technicianName;
  final VoidCallback onOpenList;
  final ValueChanged<MaintenanceOrder> onOpenOrder;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final active = orders.where((order) => !order.isFinalized).toList();
    final newOrders = active
        .where(
          (order) => order.status == 'PENDING' || order.status == 'ASSIGNED',
        )
        .toList();
    final inMaintenance = active
        .where(
          (order) => order.status != 'PENDING' && order.status != 'ASSIGNED',
        )
        .length;
    final outOfService = orders
        .where((order) => order.resultStatus == 'OUT_OF_SERVICE')
        .length;
    final problemStations = active
        .map((order) => order.bike.puesto?.id)
        .whereType<int>()
        .toSet()
        .length;

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: CyclixColors.accentGreen,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
        children: [
          Text(
            technicianName.isEmpty
                ? 'Bienvenido'
                : 'Bienvenido, $technicianName',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: CyclixColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Aquí tienes el estado general del sistema.',
            style: GoogleFonts.poppins(
              color: const Color(0xFF16305C),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '◷ Última actualización: ${_formatTime(DateTime.now())}',
            style: GoogleFonts.poppins(
              color: CyclixColors.instructionGray,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 22),
          const _MaintenanceInstructionsCard(),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.42,
            children: [
              _MetricCard(
                label: 'Bicicletas dañadas',
                value: active.length.toString(),
                icon: Icons.pedal_bike,
                color: const Color(0xFFE9003A),
              ),
              _MetricCard(
                label: 'En mantenimiento',
                value: inMaintenance.toString(),
                icon: Icons.build_outlined,
                color: const Color(0xFFD89200),
              ),
              _MetricCard(
                label: 'Fuera de servicio',
                value: outOfService.toString(),
                icon: Icons.schedule,
                color: CyclixColors.textDark,
              ),
              _MetricCard(
                label: 'Estaciones con problemas',
                value: problemStations.toString(),
                icon: Icons.location_on_outlined,
                color: CyclixColors.primaryBlue,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Reportes nuevos',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(onPressed: onOpenList, child: const Text('Ver todos')),
            ],
          ),
          const SizedBox(height: 8),
          if (newOrders.isEmpty)
            const _EmptyState(message: 'No tienes reportes nuevos.')
          else
            ...newOrders
                .take(4)
                .map(
                  (order) => _ReportTile(
                    order: order,
                    onTap: () => onOpenOrder(order),
                  ),
                ),
        ],
      ),
    );
  }
}

class MaintenanceBikeListScreen extends StatefulWidget {
  const MaintenanceBikeListScreen({
    super.key,
    required this.orders,
    required this.onOpenOrder,
    required this.onRefresh,
  });

  final List<MaintenanceOrder> orders;
  final ValueChanged<MaintenanceOrder> onOpenOrder;
  final VoidCallback onRefresh;

  @override
  State<MaintenanceBikeListScreen> createState() =>
      _MaintenanceBikeListScreenState();
}

class _MaintenanceBikeListScreenState extends State<MaintenanceBikeListScreen> {
  String _filter = 'Todas';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final orders = widget.orders.where((order) {
      final matchesFilter = switch (_filter) {
        'En revisión' => order.status == 'IN_REVIEW',
        'Fuera de servicio' => order.resultStatus == 'OUT_OF_SERVICE',
        _ => true,
      };
      final text = [
        order.bike.codigo,
        order.bike.puesto?.nombre,
        order.reportedIssue,
      ].join(' ').toLowerCase();
      return matchesFilter && text.contains(_query.toLowerCase());
    }).toList();

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      color: CyclixColors.accentGreen,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        children: [
          Text(
            'Bicicletas reportadas',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Buscar bicicleta o estación',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: CyclixColors.cardGrey,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _FilterChipButton('Todas', _filter, _setFilter)),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterChipButton('En revisión', _filter, _setFilter),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterChipButton(
                  'Fuera de servicio',
                  _filter,
                  _setFilter,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (orders.isEmpty)
            const _EmptyState(message: 'No hay bicicletas para este filtro.')
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFEDEFF5)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  for (final order in orders)
                    _BikeRow(
                      order: order,
                      onTap: () => widget.onOpenOrder(order),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _setFilter(String value) => setState(() => _filter = value);
}

class _MaintenanceInstructionsCard extends StatelessWidget {
  const _MaintenanceInstructionsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CyclixColors.primaryBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CyclixColors.primaryBlue.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: CyclixColors.primaryBlue),
              const SizedBox(width: 10),
              Text(
                'Indicaciones del flujo',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: CyclixColors.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _InstructionStep(
            text:
                'Abre una orden asignada y revisa bicicleta, estación y prioridad.',
          ),
          const _InstructionStep(
            text: 'Registra diagnóstico, estado, ubicación y tiempo estimado.',
          ),
          const _InstructionStep(
            text:
                'Finaliza indicando si la bicicleta queda disponible o fuera de servicio.',
          ),
        ],
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  const _InstructionStep({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: CyclixColors.accentGreen),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                color: CyclixColors.textDark,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MaintenanceDetailScreen extends StatefulWidget {
  const MaintenanceDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<MaintenanceDetailScreen> createState() =>
      _MaintenanceDetailScreenState();
}

class _MaintenanceDetailScreenState extends State<MaintenanceDetailScreen> {
  final CyclixApiService _api = CyclixApiService();
  late Future<MaintenanceOrder> _orderFuture;

  @override
  void initState() {
    super.initState();
    _orderFuture = _api.getMaintenanceOrder(widget.orderId);
  }

  void _reload() {
    setState(() {
      _orderFuture = _api.getMaintenanceOrder(widget.orderId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const _MaintenanceHeader(showBack: true, title: 'Cyclix'),
      body: FutureBuilder<MaintenanceOrder>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: CyclixColors.primaryBlue),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _ErrorState(
              message: 'No se pudo cargar el detalle.',
              onRetry: _reload,
            );
          }
          final order = snapshot.data!;
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                child: Text(
                  'Detalle de bicicleta',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 20),
              const _BikeIllustration(),
              const Divider(height: 32),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.bike.codigo,
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                order.bike.puesto?.nombre ?? 'Sin estación',
                                style: GoogleFonts.poppins(
                                  color: CyclixColors.instructionGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _StatusPill(label: _statusLabel(order.status)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _DataPanel(
                      rows: [
                        ('Modelo', '${order.bike.marca} ${order.bike.modelo}'),
                        ('Tipo', _typeLabel(order.bike.tipo)),
                        ('Estado', _bikeStatusLabel(order.bike.estado)),
                        ('Problema', order.reportedIssue),
                        ('Ubicación', order.currentLocation ?? 'Sin ubicación'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _HistoryButton(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MaintenanceHistoryScreen(order: order),
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: order.isFinalized
                            ? null
                            : () async {
                                final updated =
                                    await Navigator.push<MaintenanceOrder>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            MaintenanceDiagnosisScreen(
                                              order: order,
                                            ),
                                      ),
                                    );
                                if (updated != null) _reload();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CyclixColors.accentGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        child: const Text('Iniciar revisión'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class MaintenanceHistoryScreen extends StatelessWidget {
  const MaintenanceHistoryScreen({super.key, required this.order});

  final MaintenanceOrder order;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const _MaintenanceHeader(showBack: true, title: 'Historial'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
        children: [
          Text(
            'Historial',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            'Cambios registrados para la orden #${order.id}.',
            style: GoogleFonts.poppins(color: CyclixColors.instructionGray),
          ),
          const SizedBox(height: 16),
          _DataPanel(
            rows: [
              ('Bicicleta', order.bike.codigo),
              ('Estado actual', _statusLabel(order.status)),
              ('Técnico', order.assignedTo?.fullName ?? 'Sin asignar'),
            ],
          ),
          const SizedBox(height: 18),
          if (order.history.isEmpty)
            const _EmptyState(message: 'Esta orden aún no tiene historial.')
          else
            ...order.history.map((event) => _HistoryEvent(event: event)),
        ],
      ),
    );
  }
}

class MaintenanceDiagnosisScreen extends StatefulWidget {
  const MaintenanceDiagnosisScreen({super.key, required this.order});

  final MaintenanceOrder order;

  @override
  State<MaintenanceDiagnosisScreen> createState() =>
      _MaintenanceDiagnosisScreenState();
}

class _MaintenanceDiagnosisScreenState
    extends State<MaintenanceDiagnosisScreen> {
  final CyclixApiService _api = CyclixApiService();
  late final TextEditingController _locationController;
  late final TextEditingController _minutesController;
  late final TextEditingController _diagnosisController;
  late final TextEditingController _noteController;
  String _status = 'IN_REVIEW';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final order = widget.order;
    _status = order.status == 'PENDING' || order.status == 'ASSIGNED'
        ? 'IN_REVIEW'
        : order.status;
    _locationController = TextEditingController(
      text: order.currentLocation ?? order.bike.puesto?.nombre ?? '',
    );
    _minutesController = TextEditingController(
      text: order.estimatedMinutes?.toString() ?? '',
    );
    _diagnosisController = TextEditingController(text: order.diagnosis ?? '');
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _locationController.dispose();
    _minutesController.dispose();
    _diagnosisController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveProgress() async {
    setState(() => _saving = true);
    try {
      final updated = await _api.updateMaintenanceProgress(
        id: widget.order.id,
        status: _status,
        diagnosis: _diagnosisController.text.trim(),
        currentLocation: _locationController.text.trim(),
        estimatedMinutes: int.tryParse(_minutesController.text.trim()),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      if (!mounted) return;
      final resolved = await Navigator.push<MaintenanceOrder>(
        context,
        MaterialPageRoute(
          builder: (_) => MaintenanceResolveScreen(order: updated),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, resolved ?? updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const _MaintenanceHeader(showBack: true, title: 'Diagnóstico'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 24),
        children: [
          Text(
            'Diagnóstico',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            'Registra el avance de la orden asignada.',
            style: GoogleFonts.poppins(color: CyclixColors.instructionGray),
          ),
          const SizedBox(height: 18),
          _FormPanel(
            title: 'Orden #${widget.order.id} · ${widget.order.bike.codigo}',
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: _inputDecoration('Estado'),
                      items: const [
                        DropdownMenuItem(
                          value: 'IN_REVIEW',
                          child: Text('En revisión'),
                        ),
                        DropdownMenuItem(
                          value: 'IN_REPAIR',
                          child: Text('En reparación'),
                        ),
                        DropdownMenuItem(
                          value: 'WAITING_PARTS',
                          child: Text('Esperando repuestos'),
                        ),
                        DropdownMenuItem(
                          value: 'PAUSED',
                          child: Text('Pausada'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _status = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _minutesController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('Tiempo en minutos'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationController,
                decoration: _inputDecoration('Ubicación actual'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _diagnosisController,
                maxLines: 4,
                decoration: _inputDecoration('Diagnóstico'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: _inputDecoration('Nota de avance'),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveProgress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CyclixColors.accentGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Guardar progreso'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MaintenanceResolveScreen extends StatefulWidget {
  const MaintenanceResolveScreen({super.key, required this.order});

  final MaintenanceOrder order;

  @override
  State<MaintenanceResolveScreen> createState() =>
      _MaintenanceResolveScreenState();
}

class _MaintenanceResolveScreenState extends State<MaintenanceResolveScreen> {
  final CyclixApiService _api = CyclixApiService();
  late final TextEditingController _notesController;
  late final TextEditingController _locationController;
  late final TextEditingController _outReasonController;
  String _result = 'AVAILABLE';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(
      text: widget.order.resolutionNotes ?? '',
    );
    _locationController = TextEditingController(
      text: widget.order.currentLocation ?? '',
    );
    _outReasonController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _locationController.dispose();
    _outReasonController.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    if (_notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Las notas de resolución son obligatorias.'),
        ),
      );
      return;
    }
    if (_result == 'OUT_OF_SERVICE' &&
        _outReasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Indica el motivo para dejarla fuera de servicio.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final resolved = await _api.resolveMaintenanceOrder(
        id: widget.order.id,
        resultStatus: _result,
        resolutionNotes: _notesController.text.trim(),
        currentLocation: _locationController.text.trim(),
        outOfServiceReason: _result == 'OUT_OF_SERVICE'
            ? _outReasonController.text.trim()
            : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Orden finalizada correctamente.')),
      );
      Navigator.pop(context, resolved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultLabel = switch (_result) {
      'STAYS_IN_MAINTENANCE' => 'Sigue en taller',
      'OUT_OF_SERVICE' => 'Fuera de servicio',
      _ => 'Disponible',
    };
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const _MaintenanceHeader(showBack: true, title: 'Resolver'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
        children: [
          Text(
            'Cierre de orden',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            'Define cómo quedará la bicicleta después del trabajo.',
            style: GoogleFonts.poppins(color: CyclixColors.instructionGray),
          ),
          const SizedBox(height: 18),
          _FormPanel(
            title: 'Resultado',
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'AVAILABLE', label: Text('Disponible')),
                  ButtonSegment(
                    value: 'STAYS_IN_MAINTENANCE',
                    label: Text('Sigue en taller'),
                  ),
                  ButtonSegment(
                    value: 'OUT_OF_SERVICE',
                    label: Text('Fuera servicio'),
                  ),
                ],
                selected: {_result},
                onSelectionChanged: (value) =>
                    setState(() => _result = value.first),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _notesController,
                maxLines: 5,
                decoration: _inputDecoration('Notas de resolución'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationController,
                decoration: _inputDecoration('Ubicación final'),
              ),
              if (_result == 'OUT_OF_SERVICE') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _outReasonController,
                  maxLines: 3,
                  decoration: _inputDecoration('Motivo fuera de servicio'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _FormPanel(
            title: 'Validación',
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE0E6EF)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.order.bike.codigo,
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        _StatusPill(label: resultLabel),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _validationText(_result),
                      style: GoogleFonts.poppins(
                        color: CyclixColors.instructionGray,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _saving ? null : _resolve,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CyclixColors.accentGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Finalizar orden'),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 56,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, widget.order),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CyclixColors.primaryBlue,
                    side: const BorderSide(color: Color(0xFFB8D5FF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: const Text('Guardar sin finalizar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MaintenanceHeader extends StatelessWidget
    implements PreferredSizeWidget {
  const _MaintenanceHeader({
    this.title = 'Cyclix',
    this.showBack = false,
    this.showMenu = false,
    this.onMenu,
  });

  final String title;
  final bool showBack;
  final bool showMenu;
  final VoidCallback? onMenu;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFFEAF7EB),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          showBack ? Icons.chevron_left : Icons.menu,
          color: showBack ? CyclixColors.primaryBlue : CyclixColors.accentGreen,
          size: showBack ? 32 : 28,
        ),
        onPressed: showBack ? () => Navigator.maybePop(context) : onMenu,
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: CyclixColors.primaryBlue,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
      centerTitle: true,
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 14),
          child: Icon(Icons.pedal_bike, color: CyclixColors.textDark),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CyclixColors.cardGrey,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF16305C),
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: GoogleFonts.poppins(
                  color: color,
                  fontSize: 32,
                  height: 1,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: CyclixColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.order, required this.onTap});

  final MaintenanceOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Material(
        color: CyclixColors.cardGrey,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const _BikeIconBox(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bicicleta #${order.bike.codigo}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        order.bike.puesto?.nombre ?? 'Sin estación',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF16305C),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusPill(label: 'Nuevo', color: const Color(0xFFE9003A)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BikeRow extends StatelessWidget {
  const _BikeRow({required this.order, required this.onTap});

  final MaintenanceOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFEDEFF5))),
        ),
        child: Row(
          children: [
            const _BikeIconBox(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Text(
                        order.bike.codigo,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      _StatusPill(label: _statusLabel(order.status)),
                    ],
                  ),
                  Text(
                    order.bike.puesto?.nombre ?? 'Sin estación',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  Text(
                    'Problema: ${_shortText(order.reportedIssue)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: CyclixColors.instructionGray,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _relativeDate(order.createdAt),
              style: GoogleFonts.poppins(
                color: const Color(0xFF8C93AA),
                fontSize: 11,
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFC1C7D2)),
          ],
        ),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton(this.label, this.selected, this.onSelected);

  final String label;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final isSelected = label == selected;
    return FilledButton(
      onPressed: () => onSelected(label),
      style: FilledButton.styleFrom(
        backgroundColor: isSelected
            ? CyclixColors.accentGreen
            : CyclixColors.cardGrey,
        foregroundColor: isSelected ? Colors.white : const Color(0xFF5C6374),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: FittedBox(child: Text(label)),
    );
  }
}

class _BikeIconBox extends StatelessWidget {
  const _BikeIconBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.pedal_bike, color: Color(0xFF16305C)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? _pillColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: resolvedColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: resolvedColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BikeIllustration extends StatelessWidget {
  const _BikeIllustration();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 210,
      child: Center(
        child: Icon(Icons.pedal_bike, size: 180, color: CyclixColors.textDark),
      ),
    );
  }
}

class _DataPanel extends StatelessWidget {
  const _DataPanel({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CyclixColors.cardGrey,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          for (final row in rows)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE3E5EA))),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 112,
                    child: Text(
                      row.$1,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF687087),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.$2,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryButton extends StatelessWidget {
  const _HistoryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CyclixColors.cardGrey,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.schedule, color: Color(0xFF687087)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ver historial',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF9AA3B8)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryEvent extends StatelessWidget {
  const _HistoryEvent({required this.event});

  final MaintenanceHistory event;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7EB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.check,
              color: CyclixColors.accentGreen,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFEDEFF5)),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _historyActionLabel(event.action),
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
                  ),
                  if (event.note != null && event.note!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      event.note!,
                      style: GoogleFonts.poppins(
                        color: CyclixColors.instructionGray,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${_relativeDate(event.createdAt)} · ${event.changedBy.fullName}',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF16305C),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormPanel extends StatelessWidget {
  const _FormPanel({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFDFE5EE)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.poppins(
              color: CyclixColors.primaryBlue,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 42, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CyclixColors.cardGrey,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(color: CyclixColors.instructionGray),
      ),
    );
  }
}

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFDFE5EE)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: CyclixColors.primaryBlue),
    ),
  );
}

String _displayNameFromUser(Map<String, dynamic>? user) {
  if (user == null) return '';
  final fullName = user['fullName']?.toString().trim();
  if (fullName != null && fullName.isNotEmpty) return fullName;

  final firstName = user['firstName']?.toString().trim() ?? '';
  final lastName = user['lastName']?.toString().trim() ?? '';
  final combined = '$firstName $lastName'.trim();
  if (combined.isNotEmpty) return combined;

  final email = user['email']?.toString().trim() ?? '';
  if (email.isEmpty) return '';
  return email.split('@').first;
}

String _statusLabel(String value) {
  return switch (value) {
    'PENDING' => 'Nuevo',
    'ASSIGNED' => 'Asignada',
    'IN_REVIEW' => 'En revisión',
    'IN_REPAIR' => 'En reparación',
    'WAITING_PARTS' => 'Esperando repuestos',
    'PAUSED' => 'Pausada',
    'FINALIZED' => 'Finalizada',
    _ => value,
  };
}

String _typeLabel(String value) {
  return switch (value) {
    'CORRECTIVE' => 'Correctivo',
    'PREVENTIVE' => 'Preventivo',
    'INSPECTION' => 'Inspección',
    'BRAKES' => 'Frenos',
    'TIRES' => 'Llantas',
    'CHAIN' => 'Cadena',
    'ELECTRICAL' => 'Eléctrico',
    'BATTERY' => 'Batería',
    'FRAME' => 'Marco',
    'GENERAL' => 'General',
    _ => value,
  };
}

String _bikeStatusLabel(String value) {
  return switch (value) {
    'DISPONIBLE' => 'Disponible',
    'EN_USO' => 'En uso',
    'RESERVADA' => 'Reservada',
    'MANTENIMIENTO' => 'En mantenimiento',
    'FUERA_DE_SERVICIO' => 'Fuera de servicio',
    _ => value,
  };
}

String _historyActionLabel(String value) {
  return switch (value) {
    'CREATED' => 'Orden creada',
    'ASSIGNED' => 'Orden asignada',
    'PROGRESS_UPDATED' => 'Progreso actualizado',
    'RESOLVED' => 'Orden resuelta',
    _ => value,
  };
}

String _validationText(String value) {
  return switch (value) {
    'STAYS_IN_MAINTENANCE' =>
      'Al confirmar, la orden se guarda y la bicicleta sigue en mantenimiento.',
    'OUT_OF_SERVICE' =>
      'Al confirmar, la orden pasa a finalizada y la bicicleta queda fuera de servicio.',
    _ =>
      'Al confirmar, la orden pasa a finalizada y la bicicleta vuelve a disponible.',
  };
}

Color _pillColor(String label) {
  if (label.contains('Fuera')) return const Color(0xFF657084);
  if (label.contains('reparación')) return const Color(0xFFFB6A00);
  if (label.contains('revisión')) return CyclixColors.primaryBlue;
  if (label.contains('Disponible')) return const Color(0xFF159447);
  if (label.contains('Nuevo')) return const Color(0xFFE9003A);
  return CyclixColors.primaryBlue;
}

String _shortText(String value) {
  final trimmed = value.trim();
  if (trimmed.length <= 28) return trimmed;
  return '${trimmed.substring(0, 28)}...';
}

String _formatTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final suffix = value.hour >= 12 ? 'p. m.' : 'a. m.';
  return '$hour:$minute $suffix';
}

String _relativeDate(DateTime value) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(value.year, value.month, value.day);
  if (date == today) return 'Hoy, ${_formatTime(value)}';
  if (date == today.subtract(const Duration(days: 1))) {
    return 'Ayer, ${_formatTime(value)}';
  }
  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}
