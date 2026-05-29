import 'package:flutter/material.dart';

import '../models/maintenance_order.dart';
import '../services/cyclix_api_service.dart';
import '../theme/cyclix_colors.dart';
import '../widgets/cyclix_header.dart';

class AdminApiScreen extends StatefulWidget {
  const AdminApiScreen({super.key});

  @override
  State<AdminApiScreen> createState() => _AdminApiScreenState();
}

class _AdminApiScreenState extends State<AdminApiScreen> {
  final CyclixApiService _api = CyclixApiService();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return DefaultTabController(
      length: 13,
      child: Scaffold(
        backgroundColor: CyclixColors.backgroundWhite,
        appBar: const CyclixHeader(showBack: true),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Usuarios'),
                  Tab(text: 'Técnicos'),
                  Tab(text: 'Órdenes'),
                  Tab(text: 'Zonas'),
                  Tab(text: 'Soporte'),
                  Tab(text: 'Reportes'),
                  Tab(text: 'Viajes'),
                  Tab(text: 'Analítica'),
                  Tab(text: 'Auditoría'),
                  Tab(text: 'Bicicletas'),
                  Tab(text: 'Tarifas'),
                  Tab(text: 'Festivos'),
                  Tab(text: 'Planes'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _ApiList(
                      future: _api.getUsers(),
                      titleBuilder: (item) =>
                          '${item['firstName'] ?? ''} ${item['lastName'] ?? ''}'
                              .trim(),
                      subtitleBuilder: (item) =>
                          '${item['email']} · ${item['role']} · ${item['status']}',
                      bottomPadding: bottom,
                    ),
                    _MaintenanceUsersTab(api: _api, bottomPadding: bottom),
                    _MaintenanceOrdersTab(api: _api, bottomPadding: bottom),
                    _ZonesTab(api: _api, bottomPadding: bottom),
                    _SupportTicketsTab(api: _api, bottomPadding: bottom),
                    _FailureReportsTab(api: _api, bottomPadding: bottom),
                    _AdminTripsTab(api: _api, bottomPadding: bottom),
                    _AnalyticsTab(api: _api, bottomPadding: bottom),
                    _AuditTab(api: _api, bottomPadding: bottom),
                    _ApiList(
                      future: _api.getBikes(),
                      titleBuilder: (item) =>
                          '${item['marca'] ?? ''} ${item['modelo'] ?? ''}'
                              .trim(),
                      subtitleBuilder: (item) =>
                          '#${item['id']} · ${item['codigo']} · ${item['estado']}',
                      bottomPadding: bottom,
                    ),
                    _ApiList(
                      future: _api.getPricingRules(),
                      titleBuilder: (item) => item['name']?.toString() ?? '',
                      subtitleBuilder: (item) =>
                          'Q.${item['baseFare']} incluye ${item['includedMinutes']} min · Extra Q.${item['extraFarePerBlock']}/${item['extraBlockMinutes']} min',
                      bottomPadding: bottom,
                    ),
                    _ApiList(
                      future: _api.getHolidays(),
                      titleBuilder: (item) => item['name']?.toString() ?? '',
                      subtitleBuilder: (item) =>
                          '${item['holidayDate']} · ${item['active'] == true ? 'Activo' : 'Inactivo'}',
                      bottomPadding: bottom,
                    ),
                    _SubscriptionPlansTab(api: _api, bottomPadding: bottom),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaintenanceUsersTab extends StatefulWidget {
  const _MaintenanceUsersTab({required this.api, required this.bottomPadding});

  final CyclixApiService api;
  final double bottomPadding;

  @override
  State<_MaintenanceUsersTab> createState() => _MaintenanceUsersTabState();
}

class _MaintenanceUsersTabState extends State<_MaintenanceUsersTab> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = widget.api.getUsers();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = widget.api.getUsers();
    });
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.api.createMaintenanceUser(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
      );
      _firstNameController.clear();
      _lastNameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _passwordController.clear();
      _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tecnico de mantenimiento creado.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo crear. $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        final users = snapshot.data ?? const <Map<String, dynamic>>[];
        final technicians = users
            .where(
              (user) => user['role']?.toString().toUpperCase() == 'MAINTENANCE',
            )
            .toList();

        return ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + widget.bottomPadding),
          children: [
            _SectionPanel(
              title: 'Registrar tecnico',
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _TextInput(
                      controller: _firstNameController,
                      label: 'Nombre',
                      validator: _required,
                    ),
                    _TextInput(
                      controller: _lastNameController,
                      label: 'Apellido',
                    ),
                    _TextInput(
                      controller: _emailController,
                      label: 'Correo',
                      keyboardType: TextInputType.emailAddress,
                      validator: _emailValidator,
                    ),
                    _TextInput(
                      controller: _phoneController,
                      label: 'Telefono',
                      keyboardType: TextInputType.phone,
                    ),
                    _TextInput(
                      controller: _passwordController,
                      label: 'Contrasena',
                      obscureText: true,
                      validator: _passwordValidator,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _createUser,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.engineering_outlined),
                        label: const Text('Crear tecnico'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            _SectionPanel(
              title: 'Técnicos activos',
              child: snapshot.connectionState != ConnectionState.done
                  ? const Center(child: CircularProgressIndicator())
                  : technicians.isEmpty
                  ? const Text('Aun no hay usuarios de mantenimiento.')
                  : Column(
                      children: [
                        for (final user in technicians)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.build_circle_outlined),
                            title: Text(
                              '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
                                  .trim(),
                            ),
                            subtitle: Text(user['email']?.toString() ?? ''),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _MaintenanceOrdersTab extends StatefulWidget {
  const _MaintenanceOrdersTab({required this.api, required this.bottomPadding});

  final CyclixApiService api;
  final double bottomPadding;

  @override
  State<_MaintenanceOrdersTab> createState() => _MaintenanceOrdersTabState();
}

class _MaintenanceOrdersTabState extends State<_MaintenanceOrdersTab> {
  final _formKey = GlobalKey<FormState>();
  final _issueController = TextEditingController();
  final _locationController = TextEditingController();
  final _minutesController = TextEditingController(text: '30');
  late Future<_MaintenanceAdminData> _future;
  Object? _selectedBikeId;
  Object? _selectedTechnicianId;
  String _priority = 'MEDIUM';
  String _type = 'GENERAL';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _issueController.dispose();
    _locationController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  Future<_MaintenanceAdminData> _load() async {
    final users = await widget.api.getUsers();
    final bikes = await widget.api.getBikes();
    final orders = await widget.api.getAdminMaintenanceOrders();
    return _MaintenanceAdminData(users: users, bikes: bikes, orders: orders);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _createOrder() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    if (_selectedBikeId == null) {
      _showSnack('Selecciona una bicicleta.');
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.api.createAdminMaintenanceOrder(
        bikeId: _selectedBikeId!,
        assignedToUserId: _selectedTechnicianId,
        priority: _priority,
        type: _type,
        reportedIssue: _issueController.text.trim(),
        estimatedMinutes: int.tryParse(_minutesController.text.trim()),
        currentLocation: _locationController.text,
      );
      _issueController.clear();
      _locationController.clear();
      _minutesController.text = '30';
      _reload();
      _showSnack('Orden de mantenimiento creada.');
    } catch (e) {
      _showSnack('No se pudo crear la orden. $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MaintenanceAdminData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            snapshot.data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ListView(
            padding: EdgeInsets.fromLTRB(32, 56, 32, 24 + widget.bottomPadding),
            children: [
              const Icon(
                Icons.admin_panel_settings_outlined,
                size: 58,
                color: CyclixColors.primaryBlue,
              ),
              const SizedBox(height: 16),
              Text(
                'Modulo no disponible',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(snapshot.error.toString(), textAlign: TextAlign.center),
            ],
          );
        }

        final data = snapshot.data!;
        final technicians = data.users
            .where(
              (user) => user['role']?.toString().toUpperCase() == 'MAINTENANCE',
            )
            .toList();
        final availableBikes = data.bikes.where((bike) {
          final status = bike['estado']?.toString().toUpperCase();
          return status != 'EN_USO' && status != 'RESERVADA';
        }).toList();
        final bikeIds = availableBikes.map((bike) => bike['id']).toSet();
        final technicianIds = technicians.map((user) => user['id']).toSet();

        if (!bikeIds.contains(_selectedBikeId)) {
          _selectedBikeId = null;
        }
        if (!technicianIds.contains(_selectedTechnicianId)) {
          _selectedTechnicianId = null;
        }
        if (_selectedBikeId == null && availableBikes.isNotEmpty) {
          _selectedBikeId = availableBikes.first['id'];
        }

        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + widget.bottomPadding),
            children: [
              _SectionPanel(
                title: 'Nueva orden',
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      DropdownButtonFormField<Object>(
                        initialValue: _selectedBikeId,
                        isExpanded: true,
                        decoration: _inputDecoration('Bicicleta'),
                        items: [
                          for (final bike in availableBikes)
                            DropdownMenuItem<Object>(
                              value: bike['id'],
                              child: Text(
                                '${bike['codigo']} · ${bike['estado']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _selectedBikeId = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<Object?>(
                        initialValue: _selectedTechnicianId,
                        isExpanded: true,
                        decoration: _inputDecoration('Asignar tecnico'),
                        items: [
                          const DropdownMenuItem<Object?>(
                            value: null,
                            child: Text('Sin asignar por ahora'),
                          ),
                          for (final user in technicians)
                            DropdownMenuItem<Object?>(
                              value: user['id'],
                              child: Text(
                                '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
                                    .trim(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _selectedTechnicianId = value),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final priorityField = DropdownButtonFormField<String>(
                            initialValue: _priority,
                            isExpanded: true,
                            decoration: _inputDecoration('Prioridad'),
                            items: const [
                              DropdownMenuItem(
                                value: 'LOW',
                                child: Text('Baja'),
                              ),
                              DropdownMenuItem(
                                value: 'MEDIUM',
                                child: Text('Media'),
                              ),
                              DropdownMenuItem(
                                value: 'HIGH',
                                child: Text('Alta'),
                              ),
                              DropdownMenuItem(
                                value: 'CRITICAL',
                                child: Text('Crítica'),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _priority = value ?? 'MEDIUM'),
                          );
                          final typeField = DropdownButtonFormField<String>(
                            initialValue: _type,
                            isExpanded: true,
                            decoration: _inputDecoration('Tipo'),
                            items: const [
                              DropdownMenuItem(
                                value: 'GENERAL',
                                child: Text('General'),
                              ),
                              DropdownMenuItem(
                                value: 'BRAKES',
                                child: Text('Frenos'),
                              ),
                              DropdownMenuItem(
                                value: 'TIRES',
                                child: Text('Llantas'),
                              ),
                              DropdownMenuItem(
                                value: 'CHAIN',
                                child: Text('Cadena'),
                              ),
                              DropdownMenuItem(
                                value: 'PREVENTIVE',
                                child: Text('Preventivo'),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _type = value ?? 'GENERAL'),
                          );

                          if (constraints.maxWidth < 360) {
                            return Column(
                              children: [
                                priorityField,
                                const SizedBox(height: 12),
                                typeField,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: priorityField),
                              const SizedBox(width: 12),
                              Expanded(child: typeField),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _TextInput(
                        controller: _issueController,
                        label: 'Problema reportado',
                        maxLines: 3,
                        validator: _required,
                      ),
                      _TextInput(
                        controller: _locationController,
                        label: 'Ubicacion actual',
                      ),
                      _TextInput(
                        controller: _minutesController,
                        label: 'Minutos estimados',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _createOrder,
                          icon: const Icon(Icons.add_task_outlined),
                          label: const Text('Crear orden'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _SectionPanel(
                title: 'Órdenes recientes',
                child: data.orders.isEmpty
                    ? const Text('Aún no hay órdenes de mantenimiento.')
                    : Column(
                        children: [
                          for (final order in data.orders)
                            _MaintenanceOrderTile(order: order),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MaintenanceOrderTile extends StatelessWidget {
  const _MaintenanceOrderTile({required this.order});

  final MaintenanceOrder order;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.pedal_bike_outlined),
      title: Text('Orden #${order.id} · ${order.bike.codigo}'),
      subtitle: Text(
        '${_statusLabel(order.status)} · ${order.assignedTo?.fullName ?? 'Sin tecnico'}',
      ),
      trailing: Text(_priorityLabel(order.priority)),
    );
  }
}

class _ZonesTab extends StatefulWidget {
  const _ZonesTab({required this.api, required this.bottomPadding});

  final CyclixApiService api;
  final double bottomPadding;

  @override
  State<_ZonesTab> createState() => _ZonesTabState();
}

class _ZonesTabState extends State<_ZonesTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _latController = TextEditingController(text: '14.9722');
  final _lngController = TextEditingController(text: '-89.5305');
  final _radiusController = TextEditingController(text: '1500');
  late Future<List<Map<String, dynamic>>> _future;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = widget.api.getZones();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = widget.api.getZones();
    });
  }

  Future<void> _createZone() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    final radius = int.tryParse(_radiusController.text.trim());
    if (lat == null || lng == null || radius == null || radius <= 0) {
      _showSnack('Revisa latitud, longitud y radio.');
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.api.createZone(
        name: _nameController.text.trim(),
        description: _descriptionController.text,
        centerLatitude: lat,
        centerLongitude: lng,
        radiusMeters: radius,
      );
      _nameController.clear();
      _descriptionController.clear();
      _reload();
      _showSnack('Zona creada correctamente.');
    } catch (e) {
      _showSnack('No se pudo crear la zona. $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleZone(Map<String, dynamic> zone) async {
    try {
      await widget.api.updateZoneStatus(
        id: zone['id'],
        active: zone['active'] != true,
      );
      _reload();
    } catch (e) {
      _showSnack('No se pudo actualizar la zona. $e');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        final zones = snapshot.data ?? const <Map<String, dynamic>>[];
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + widget.bottomPadding),
          children: [
            _SectionPanel(
              title: 'Nueva zona permitida',
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _TextInput(
                      controller: _nameController,
                      label: 'Nombre',
                      validator: _required,
                    ),
                    _TextInput(
                      controller: _descriptionController,
                      label: 'Descripcion',
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _TextInput(
                            controller: _latController,
                            label: 'Latitud',
                            keyboardType: const TextInputType.numberWithOptions(
                              signed: true,
                              decimal: true,
                            ),
                            validator: _required,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TextInput(
                            controller: _lngController,
                            label: 'Longitud',
                            keyboardType: const TextInputType.numberWithOptions(
                              signed: true,
                              decimal: true,
                            ),
                            validator: _required,
                          ),
                        ),
                      ],
                    ),
                    _TextInput(
                      controller: _radiusController,
                      label: 'Radio en metros',
                      keyboardType: TextInputType.number,
                      validator: _required,
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _createZone,
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: const Text('Crear zona'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            _SectionPanel(
              title: 'Zonas registradas',
              child: snapshot.connectionState != ConnectionState.done
                  ? const Center(child: CircularProgressIndicator())
                  : zones.isEmpty
                  ? const Text('Aun no hay zonas.')
                  : Column(
                      children: [
                        for (final zone in zones)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: zone['active'] == true,
                            onChanged: (_) => _toggleZone(zone),
                            title: Text(zone['name']?.toString() ?? ''),
                            subtitle: Text(
                              '${zone['radiusMeters']} m · ${zone['centerLatitude']}, ${zone['centerLongitude']}',
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _FailureReportsTab extends StatefulWidget {
  const _FailureReportsTab({required this.api, required this.bottomPadding});

  final CyclixApiService api;
  final double bottomPadding;

  @override
  State<_FailureReportsTab> createState() => _FailureReportsTabState();
}

class _FailureReportsTabState extends State<_FailureReportsTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.getAdminFailureReports();
  }

  void _reload() {
    setState(() {
      _future = widget.api.getAdminFailureReports();
    });
  }

  Future<void> _sendToMaintenance(Map<String, dynamic> report) async {
    if (report['bikeId'] == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este reporte no tiene bicicleta asociada. Revísalo en Soporte.',
          ),
        ),
      );
      return;
    }

    try {
      await widget.api.createMaintenanceFromFailureReport(
        reportId: report['id'],
        priority: report['priority']?.toString() ?? 'MEDIUM',
        type: 'GENERAL',
      );
      _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Orden de mantenimiento creada.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo crear orden. $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _AdminError(message: snapshot.error.toString());
        }
        final reports = snapshot.data ?? const <Map<String, dynamic>>[];
        if (reports.isEmpty) return const Center(child: Text('Sin reportes.'));
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + widget.bottomPadding),
          itemCount: reports.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final report = reports[index];
            final bikeId = report['bikeId'];
            final canCreateMaintenance = bikeId != null;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.report_problem_outlined),
              title: Text(report['title']?.toString() ?? ''),
              subtitle: Text(
                '${canCreateMaintenance ? 'Bici $bikeId' : 'Sin bicicleta'} · ${_priorityLabel(report['priority']?.toString() ?? '')} · ${_statusLabel(report['status']?.toString() ?? '')}',
              ),
              trailing: IconButton(
                tooltip: canCreateMaintenance
                    ? 'Crear mantenimiento'
                    : 'Sin bicicleta asociada',
                onPressed: canCreateMaintenance
                    ? () => _sendToMaintenance(report)
                    : null,
                icon: Icon(
                  Icons.build_outlined,
                  color: canCreateMaintenance ? null : Colors.grey,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SupportTicketsTab extends StatefulWidget {
  const _SupportTicketsTab({required this.api, required this.bottomPadding});

  final CyclixApiService api;
  final double bottomPadding;

  @override
  State<_SupportTicketsTab> createState() => _SupportTicketsTabState();
}

class _SupportTicketsTabState extends State<_SupportTicketsTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.getAdminTickets();
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget.api.getAdminTickets();
    });
    await _future;
  }

  Future<void> _updateStatus(Map<String, dynamic> ticket, String status) async {
    try {
      await widget.api.updateAdminTicketStatus(
        id: ticket['id'],
        status: status,
      );
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Estado actualizado.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo actualizar. $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _AdminError(message: snapshot.error.toString());
        }

        final tickets = snapshot.data ?? const <Map<String, dynamic>>[];
        if (tickets.isEmpty) {
          return const Center(child: Text('Sin reportes de soporte.'));
        }

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + widget.bottomPadding),
            itemCount: tickets.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              final status = ticket['status']?.toString() ?? 'OPEN';
              final priority = ticket['priority']?.toString() ?? 'MEDIUM';
              final category = ticket['category']?.toString() ?? '';
              final createdAt = ticket['createdAt']?.toString() ?? '';

              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE6EAF0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ExpansionTile(
                  leading: const Icon(
                    Icons.support_agent_outlined,
                    color: CyclixColors.primaryBlue,
                  ),
                  title: Text(
                    ticket['title']?.toString() ?? 'Reporte sin título',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Usuario #${ticket['userId']} · ${_categoryLabel(category)} · ${_priorityLabel(priority)} · ${_statusLabel(status)}',
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        ticket['description']?.toString() ?? 'Sin descripción.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _KeyValueRow(
                      label: 'Fecha',
                      value: createdAt.isEmpty ? 'Sin fecha' : createdAt,
                    ),
                    if (ticket['bikeId'] != null)
                      _KeyValueRow(
                        label: 'Bicicleta',
                        value: '#${ticket['bikeId']}',
                      ),
                    if (ticket['tripId'] != null)
                      _KeyValueRow(
                        label: 'Viaje',
                        value: '#${ticket['tripId']}',
                      ),
                    if (ticket['paymentId'] != null)
                      _KeyValueRow(
                        label: 'Pago',
                        value: '#${ticket['paymentId']}',
                      ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: _inputDecoration('Estado'),
                      items: const [
                        DropdownMenuItem(value: 'OPEN', child: Text('Abierto')),
                        DropdownMenuItem(
                          value: 'IN_PROGRESS',
                          child: Text('En progreso'),
                        ),
                        DropdownMenuItem(
                          value: 'WAITING_USER',
                          child: Text('Esperando respuesta'),
                        ),
                        DropdownMenuItem(
                          value: 'RESOLVED',
                          child: Text('Resuelto'),
                        ),
                        DropdownMenuItem(
                          value: 'CLOSED',
                          child: Text('Cerrado'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null || value == status) return;
                        _updateStatus(ticket, value);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _AdminTripsTab extends StatefulWidget {
  const _AdminTripsTab({required this.api, required this.bottomPadding});

  final CyclixApiService api;
  final double bottomPadding;

  @override
  State<_AdminTripsTab> createState() => _AdminTripsTabState();
}

class _AdminTripsTabState extends State<_AdminTripsTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.getAdminTrips();
  }

  void _reload() {
    setState(() {
      _future = widget.api.getAdminTrips();
    });
  }

  Future<void> _cancel(Map<String, dynamic> trip) async {
    try {
      await widget.api.cancelAdminTrip(trip['id']);
      _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Viaje cancelado.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo cancelar. $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ApiList(
      future: _future,
      titleBuilder: (item) => 'Viaje #${item['id']} · Bici ${item['bikeId']}',
      subtitleBuilder: (item) =>
          '${item['status']} · ${item['startedAt'] ?? ''} · Q.${item['totalAmount'] ?? '0.00'}',
      bottomPadding: widget.bottomPadding,
      trailingBuilder: (item) =>
          item['status']?.toString().toUpperCase() == 'ACTIVE'
          ? IconButton(
              tooltip: 'Cancelar viaje',
              onPressed: () => _cancel(item),
              icon: const Icon(Icons.cancel_outlined),
            )
          : null,
    );
  }
}

class _AnalyticsTab extends StatefulWidget {
  const _AnalyticsTab({required this.api, required this.bottomPadding});

  final CyclixApiService api;
  final double bottomPadding;

  @override
  State<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<_AnalyticsTab> {
  late Future<List<_MetricGroup>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_MetricGroup>> _load() async {
    final results = await Future.wait([
      widget.api.getBicycleAnalytics(),
      widget.api.getUserAnalytics(),
      widget.api.getStationAnalytics(),
    ]);
    return [
      _MetricGroup('Bicicletas', results[0]),
      _MetricGroup('Usuarios', results[1]),
      _MetricGroup('Estaciones', results[2]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_MetricGroup>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _AdminError(message: snapshot.error.toString());
        }
        final groups = snapshot.data ?? const <_MetricGroup>[];
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + widget.bottomPadding),
          children: [
            for (final group in groups) ...[
              _SectionPanel(
                title: group.title,
                child: Column(
                  children: group.data.entries
                      .where(
                        (entry) => entry.value is num || entry.value is String,
                      )
                      .take(8)
                      .map(
                        (entry) => _KeyValueRow(
                          label: entry.key,
                          value: entry.value.toString(),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 14),
            ],
          ],
        );
      },
    );
  }
}

class _AuditTab extends StatelessWidget {
  const _AuditTab({required this.api, required this.bottomPadding});

  final CyclixApiService api;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return _ApiList(
      future: api.getAuditLogs(),
      titleBuilder: (item) => item['eventType']?.toString() ?? '',
      subtitleBuilder: (item) =>
          '${item['entityType'] ?? ''} #${item['entityId'] ?? ''} · ${item['createdAt'] ?? ''}',
      bottomPadding: bottomPadding,
    );
  }
}

class _MetricGroup {
  const _MetricGroup(this.title, this.data);

  final String title;
  final Map<String, dynamic> data;
}

class _SubscriptionPlansTab extends StatefulWidget {
  const _SubscriptionPlansTab({required this.api, required this.bottomPadding});

  final CyclixApiService api;
  final double bottomPadding;

  @override
  State<_SubscriptionPlansTab> createState() => _SubscriptionPlansTabState();
}

class _SubscriptionPlansTabState extends State<_SubscriptionPlansTab> {
  final _planFormKey = GlobalKey<FormState>();
  final _assignFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _hoursController = TextEditingController();
  late Future<_SubscriptionAdminData> _future;
  Map<String, dynamic>? _editingPlan;
  Object? _selectedUserId;
  Object? _selectedPlanId;
  bool _planActive = true;
  bool _autoRenew = false;
  bool _savingPlan = false;
  bool _assigning = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  Future<_SubscriptionAdminData> _load() async {
    final users = await widget.api.getUsers();
    final plans = await widget.api.getSubscriptionPlans();
    return _SubscriptionAdminData(users: users, plans: plans);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  void _editPlan(Map<String, dynamic> plan) {
    setState(() {
      _editingPlan = plan;
      _nameController.text = plan['name']?.toString() ?? '';
      _priceController.text = plan['monthlyPrice']?.toString() ?? '';
      _hoursController.text = plan['includedHours']?.toString() ?? '';
      _planActive = plan['active'] != false;
    });
  }

  void _clearPlanForm() {
    setState(() {
      _editingPlan = null;
      _nameController.clear();
      _priceController.clear();
      _hoursController.clear();
      _planActive = true;
    });
  }

  Future<void> _savePlan() async {
    if (!_planFormKey.currentState!.validate() || _savingPlan) return;
    final price = double.parse(
      _priceController.text.trim().replaceAll(',', '.'),
    );
    final hours = int.parse(_hoursController.text.trim());
    setState(() => _savingPlan = true);
    try {
      final editing = _editingPlan;
      if (editing == null) {
        await widget.api.createSubscriptionPlan(
          name: _nameController.text.trim(),
          monthlyPrice: price,
          includedHours: hours,
          active: _planActive,
        );
      } else {
        await widget.api.updateSubscriptionPlan(
          id: editing['id'],
          name: _nameController.text.trim(),
          monthlyPrice: price,
          includedHours: hours,
          active: _planActive,
        );
      }
      _clearPlanForm();
      _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan guardado correctamente.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo guardar. $e')));
    } finally {
      if (mounted) setState(() => _savingPlan = false);
    }
  }

  Future<void> _assignPlan() async {
    if (!_assignFormKey.currentState!.validate() || _assigning) return;
    final userId = _selectedUserId;
    final planId = _selectedPlanId;
    if (userId == null || planId == null) return;

    final now = DateTime.now();
    final startsAt = DateTime(now.year, now.month, now.day);
    final expiresAt = startsAt
        .add(const Duration(days: 30))
        .subtract(const Duration(seconds: 1));

    setState(() => _assigning = true);
    try {
      await widget.api.assignSubscriptionPlan(
        userId: userId,
        planId: planId,
        startsAt: startsAt,
        expiresAt: expiresAt,
        autoRenew: _autoRenew,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan asignado al usuario.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo asignar. $e')));
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SubscriptionAdminData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _AdminError(message: snapshot.error.toString());
        }

        final data = snapshot.data!;
        final users = data.users
            .where((user) => user['role']?.toString().toUpperCase() == 'USER')
            .toList();

        return ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + widget.bottomPadding),
          children: [
            _SectionPanel(
              title: _editingPlan == null ? 'Crear plan' : 'Editar plan',
              child: Form(
                key: _planFormKey,
                child: Column(
                  children: [
                    _TextInput(
                      controller: _nameController,
                      label: 'Nombre del plan',
                      validator: _required,
                    ),
                    _TextInput(
                      controller: _priceController,
                      label: 'Precio mensual',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _positiveDecimal,
                    ),
                    _TextInput(
                      controller: _hoursController,
                      label: 'Horas incluidas',
                      keyboardType: TextInputType.number,
                      validator: _positiveInt,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _planActive,
                      activeThumbColor: CyclixColors.accentGreen,
                      title: const Text('Plan activo'),
                      onChanged: (value) => setState(() => _planActive = value),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _savingPlan ? null : _savePlan,
                            icon: _savingPlan
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              _editingPlan == null
                                  ? 'Crear plan'
                                  : 'Guardar cambios',
                            ),
                          ),
                        ),
                        if (_editingPlan != null) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _clearPlanForm,
                            child: const Text('Cancelar'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SectionPanel(
              title: 'Asignar plan a usuario',
              child: Form(
                key: _assignFormKey,
                child: Column(
                  children: [
                    DropdownButtonFormField<Object>(
                      initialValue: _selectedUserId,
                      decoration: _inputDecoration('Usuario'),
                      items: users
                          .map(
                            (user) => DropdownMenuItem<Object>(
                              value: user['id'],
                              child: Text(
                                '${user['firstName'] ?? ''} ${user['lastName'] ?? ''} · ${user['email']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedUserId = value),
                      validator: (value) =>
                          value == null ? 'Selecciona usuario' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Object>(
                      initialValue: _selectedPlanId,
                      decoration: _inputDecoration('Plan'),
                      items: data.plans
                          .where((plan) => plan['active'] != false)
                          .map(
                            (plan) => DropdownMenuItem<Object>(
                              value: plan['id'],
                              child: Text(
                                '${plan['name']} · ${plan['includedHours']}h',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedPlanId = value),
                      validator: (value) =>
                          value == null ? 'Selecciona plan' : null,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _autoRenew,
                      activeThumbColor: CyclixColors.accentGreen,
                      title: const Text('Auto renovacion'),
                      subtitle: const Text('Vigencia inicial de 30 dias'),
                      onChanged: (value) => setState(() => _autoRenew = value),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _assigning ? null : _assignPlan,
                        icon: _assigning
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.person_add_alt_1_outlined),
                        label: const Text('Activar plan'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SectionPanel(
              title: 'Planes existentes',
              child: Column(
                children: [
                  if (data.plans.isEmpty)
                    const Text('No hay planes configurados.'),
                  for (final plan in data.plans)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        plan['active'] == true
                            ? Icons.check_circle_outline
                            : Icons.pause_circle_outline,
                        color: plan['active'] == true
                            ? CyclixColors.accentGreen
                            : CyclixColors.instructionGray,
                      ),
                      title: Text(plan['name']?.toString() ?? ''),
                      subtitle: Text(
                        'Q.${plan['monthlyPrice']} · ${plan['includedHours']} horas',
                      ),
                      trailing: IconButton(
                        tooltip: 'Editar',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editPlan(plan),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ApiList extends StatelessWidget {
  const _ApiList({
    required this.future,
    required this.titleBuilder,
    required this.subtitleBuilder,
    required this.bottomPadding,
    this.trailingBuilder,
  });

  final Future<List<Map<String, dynamic>>> future;
  final String Function(Map<String, dynamic>) titleBuilder;
  final String Function(Map<String, dynamic>) subtitleBuilder;
  final double bottomPadding;
  final Widget? Function(Map<String, dynamic>)? trailingBuilder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.all(32),
            children: [
              const SizedBox(height: 60),
              const Icon(
                Icons.admin_panel_settings_outlined,
                size: 58,
                color: CyclixColors.primaryBlue,
              ),
              const SizedBox(height: 16),
              Text(
                'No disponible con tu usuario',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                snapshot.error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: CyclixColors.instructionGray),
              ),
            ],
          );
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) return const Center(child: Text('Sin registros.'));

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomPadding),
          itemCount: items.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(titleBuilder(item)),
              subtitle: Text(subtitleBuilder(item)),
              trailing: trailingBuilder?.call(item),
            );
          },
        );
      },
    );
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE6EAF0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: CyclixColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: CyclixColors.instructionGray),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _AdminError extends StatelessWidget {
  const _AdminError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        const Icon(
          Icons.admin_panel_settings_outlined,
          size: 58,
          color: CyclixColors.primaryBlue,
        ),
        const SizedBox(height: 16),
        Text(
          'No disponible con tu usuario',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: CyclixColors.instructionGray),
        ),
      ],
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.validator,
    this.obscureText = false,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool obscureText;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        maxLines: obscureText ? 1 : maxLines,
        validator: validator,
        decoration: _inputDecoration(label),
      ),
    );
  }
}

class _MaintenanceAdminData {
  const _MaintenanceAdminData({
    required this.users,
    required this.bikes,
    required this.orders,
  });

  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> bikes;
  final List<MaintenanceOrder> orders;
}

class _SubscriptionAdminData {
  const _SubscriptionAdminData({required this.users, required this.plans});

  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> plans;
}

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFE6EAF0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: CyclixColors.primaryBlue),
    ),
  );
}

String? _required(String? value) {
  if (value == null || value.trim().isEmpty) return 'Campo obligatorio';
  return null;
}

String? _emailValidator(String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return 'Campo obligatorio';
  if (!raw.contains('@') || !raw.contains('.')) return 'Correo invalido';
  return null;
}

String? _passwordValidator(String? value) {
  final raw = value ?? '';
  if (raw.length < 8) return 'Minimo 8 caracteres';
  return null;
}

String? _positiveDecimal(String? value) {
  final raw = value?.trim().replaceAll(',', '.') ?? '';
  final parsed = double.tryParse(raw);
  if (parsed == null || parsed < 0) return 'Ingresa un monto valido';
  return null;
}

String? _positiveInt(String? value) {
  final raw = value?.trim() ?? '';
  final parsed = int.tryParse(raw);
  if (parsed == null || parsed <= 0) return 'Ingresa un numero mayor que 0';
  return null;
}

String _statusLabel(String value) {
  return switch (value) {
    'OPEN' => 'Abierto',
    'IN_PROGRESS' => 'En progreso',
    'WAITING_USER' => 'Esperando respuesta',
    'RESOLVED' => 'Resuelto',
    'CLOSED' => 'Cerrado',
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

String _categoryLabel(String value) {
  return switch (value) {
    'BIKE' => 'Bicicleta',
    'APP' => 'Aplicación',
    'PAYMENT' => 'Pago',
    'ACCOUNT' => 'Cuenta',
    'TRIP' => 'Viaje',
    'EMERGENCY' => 'Emergencia',
    'OTHER' => 'Otro',
    _ => value,
  };
}

String _priorityLabel(String value) {
  return switch (value) {
    'LOW' => 'Baja',
    'MEDIUM' => 'Media',
    'HIGH' => 'Alta',
    'CRITICAL' => 'Crítica',
    _ => value,
  };
}
