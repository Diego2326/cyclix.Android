import 'package:flutter/material.dart';

import '../services/cyclix_api_service.dart';
import '../theme/cyclix_colors.dart';
import '../widgets/cyclix_header.dart';

class PlanesScreen extends StatefulWidget {
  const PlanesScreen({super.key});

  @override
  State<PlanesScreen> createState() => _PlanesScreenState();
}

class _PlanesScreenState extends State<PlanesScreen> {
  final CyclixApiService _api = CyclixApiService();
  late Future<List<Map<String, dynamic>>> _future = _api
      .getSubscriptionPlansForUser();
  bool _requesting = false;

  Future<void> _reload() async {
    setState(() => _future = _api.getSubscriptionPlansForUser());
    await _future;
  }

  Future<void> _requestPlan(Map<String, dynamic> plan) async {
    if (_requesting) return;
    var autoRenew = true;

    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottom = MediaQuery.paddingOf(context).bottom;
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Contratar ${plan['name']}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'El plan se aplica automaticamente al finalizar viajes: primero consume tus minutos incluidos y luego cobra extras a la billetera.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: CyclixColors.instructionGray,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: autoRenew,
                      activeThumbColor: CyclixColors.accentGreen,
                      title: const Text('Auto renovacion mensual'),
                      onChanged: (value) =>
                          setSheetState(() => autoRenew = value),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.workspace_premium_outlined),
                      label: const Text('Confirmar solicitud'),
                      style: FilledButton.styleFrom(
                        backgroundColor: CyclixColors.accentGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (accepted != true) return;

    setState(() => _requesting = true);
    try {
      await _api.requestSubscriptionPlan(plan: plan, autoRenew: autoRenew);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Solicitud enviada. Un admin puede activar el plan desde Administracion API.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo solicitar el plan. $e')),
      );
    } finally {
      if (mounted) setState(() => _requesting = false);
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
        child: RefreshIndicator(
          onRefresh: _reload,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(
                  padding: EdgeInsets.fromLTRB(24, 80, 24, 24 + bottom),
                  children: [
                    const Icon(
                      Icons.workspace_premium_outlined,
                      size: 60,
                      color: CyclixColors.primaryBlue,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No se pudieron cargar los planes',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              }

              final plans = (snapshot.data ?? const <Map<String, dynamic>>[])
                  .where((plan) => plan['active'] != false)
                  .toList();

              return ListView(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottom),
                children: [
                  Text(
                    'Planes Cyclix',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: CyclixColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Contrata minutos mensuales para que tus viajes usen primero el plan y cobren a la billetera solo el excedente.',
                    style: TextStyle(color: CyclixColors.instructionGray),
                  ),
                  const SizedBox(height: 18),
                  if (plans.isEmpty)
                    const Text('No hay planes activos por el momento.'),
                  for (final plan in plans) ...[
                    _PlanCard(
                      plan: plan,
                      requesting: _requesting,
                      onRequest: () => _requestPlan(plan),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.requesting,
    required this.onRequest,
  });

  final Map<String, dynamic> plan;
  final bool requesting;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final hours = int.tryParse(plan['includedHours']?.toString() ?? '') ?? 0;
    final minutes = hours * 60;
    final price = num.tryParse(plan['monthlyPrice']?.toString() ?? '') ?? 0;

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
          Row(
            children: [
              const Icon(
                Icons.workspace_premium_outlined,
                color: CyclixColors.accentGreen,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  plan['name']?.toString() ?? 'Plan Cyclix',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'GTQ ${price.toStringAsFixed(2)} / mes',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: CyclixColors.primaryBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          _BenefitRow(
            icon: Icons.timer_outlined,
            label: '$hours horas incluidas ($minutes minutos)',
          ),
          const _BenefitRow(
            icon: Icons.payments_outlined,
            label: 'Minutos incluidos antes de cobrar extras',
          ),
          const _BenefitRow(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Excedentes calculados por el API al finalizar',
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: requesting ? null : onRequest,
              style: FilledButton.styleFrom(
                backgroundColor: CyclixColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Contratar plan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: CyclixColors.primaryBlue),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
