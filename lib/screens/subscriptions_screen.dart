import 'package:flutter/material.dart';

import '../services/cyclix_api_service.dart';
import '../theme/cyclix_colors.dart';
import '../widgets/cyclix_header.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final CyclixApiService _api = CyclixApiService();
  late Future<_SubscriptionsViewData> _future = _load();
  bool _processing = false;

  Future<_SubscriptionsViewData> _load() async {
    final plans = await _loadPlans();
    final active = await _loadActiveSubscription();
    final history = await _loadHistory();
    final wallet = await _loadWallet();

    plans.sort((a, b) {
      if (a.active != b.active) return a.active ? -1 : 1;
      return a.includedHours.compareTo(b.includedHours);
    });
    history.sort((a, b) => b.startsAt.compareTo(a.startsAt));

    return _SubscriptionsViewData(
      plans: plans,
      activeSubscription: active,
      history: history,
      wallet: wallet,
    );
  }

  Future<List<_SubscriptionPlan>> _loadPlans() async {
    final data = await _api.getAvailableSubscriptionPlans();
    return data.map(_SubscriptionPlan.fromJson).toList();
  }

  Future<_UserSubscription?> _loadActiveSubscription() async {
    try {
      final data = await _api.getMyActiveSubscription();
      if (data == null) return null;
      return _UserSubscription.fromJson(data);
    } on CyclixApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<_UserSubscription>> _loadHistory() async {
    try {
      final data = await _api.getMySubscriptions();
      return data.map(_UserSubscription.fromJson).toList();
    } on CyclixApiException catch (e) {
      if (e.statusCode == 404) return const [];
      rethrow;
    }
  }

  Future<_WalletSummary?> _loadWallet() async {
    try {
      final data = await _api.getWallet();
      return _WalletSummary.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  String _money(num? value, {String currency = 'GTQ'}) {
    return '$currency ${(value ?? 0).toDouble().toStringAsFixed(2)}';
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} $hour:$minute';
  }

  String _statusLabel(String status) {
    return switch (status) {
      'ACTIVE' => 'Activa',
      'EXPIRED' => 'Expirada',
      'CANCELLED' => 'Cancelada',
      _ => status,
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      'ACTIVE' => CyclixColors.accentGreen,
      'EXPIRED' => CyclixColors.primaryBlue,
      'CANCELLED' => Colors.redAccent,
      _ => CyclixColors.instructionGray,
    };
  }

  Future<void> _showPurchaseSheet(
    _SubscriptionsViewData data,
    _SubscriptionPlan plan,
  ) async {
    if (_processing) return;
    var autoRenew = false;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) {
        final wallet = data.wallet;
        final enoughBalance =
            wallet == null || wallet.balance >= plan.monthlyPrice;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Confirmar compra',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Se cobrará al wallet y la suscripción se activará inmediatamente.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: CyclixColors.instructionGray,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SummaryPanel(
                      rows: [
                        _SummaryRow('Plan', plan.name),
                        _SummaryRow(
                          'Precio mensual',
                          _money(plan.monthlyPrice),
                        ),
                        _SummaryRow(
                          'Cobertura',
                          '${plan.includedHours} horas (${plan.includedHours * 60} min)',
                        ),
                        if (wallet != null)
                          _SummaryRow(
                            'Saldo actual',
                            _money(wallet.balance, currency: wallet.currency),
                            highlighted: !enoughBalance,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      value: autoRenew,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) {
                        setModalState(() => autoRenew = value);
                      },
                      title: const Text('Renovar automáticamente'),
                      subtitle: const Text(
                        'Si la API ya lo soporta, quedará guardado en tu suscripción.',
                      ),
                    ),
                    if (!enoughBalance) ...[
                      const SizedBox(height: 10),
                      const _InlineNotice(
                        message:
                            'Tu wallet no tiene saldo suficiente para este plan.',
                        tone: _NoticeTone.warning,
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: enoughBalance
                          ? () => Navigator.pop(context, true)
                          : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: CyclixColors.accentGreen,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.account_balance_wallet_outlined),
                      label: const Text('Comprar ahora'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true) return;
    await _purchasePlan(plan: plan, autoRenew: autoRenew);
  }

  Future<void> _purchasePlan({
    required _SubscriptionPlan plan,
    required bool autoRenew,
  }) async {
    setState(() => _processing = true);
    try {
      await _api.purchaseSubscription(planId: plan.id, autoRenew: autoRenew);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Suscripción ${plan.name} activada y cobrada al wallet.',
          ),
        ),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _cancelSubscription(_UserSubscription subscription) async {
    if (_processing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancelar suscripción'),
          content: Text(
            'Se cancelará ${subscription.planName}. Esta acción no podrá deshacerse desde la app.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cancelar plan'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    setState(() => _processing = true);
    try {
      await _api.cancelMySubscription(subscription.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Suscripción cancelada.')));
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _toggleAutoRenew(
    _UserSubscription subscription,
    bool value,
  ) async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      await _api.updateMySubscriptionAutoRenew(
        id: subscription.id,
        autoRenew: value,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Renovación automática activada.'
                : 'Renovación automática desactivada.',
          ),
        ),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyclixColors.backgroundWhite,
      appBar: const CyclixHeader(showBack: true),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _reload,
          child: FutureBuilder<_SubscriptionsViewData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 80),
                    const Icon(
                      Icons.workspace_premium_outlined,
                      size: 64,
                      color: CyclixColors.primaryBlue,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No se pudo cargar suscripciones',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: CyclixColors.instructionGray,
                      ),
                    ),
                  ],
                );
              }

              final data = snapshot.data!;
              final active = data.activeSubscription;

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16,
                  20,
                  16,
                  24 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  _HeroSubscriptionCard(
                    wallet: data.wallet,
                    activeSubscription: active,
                    processing: _processing,
                  ),
                  const SizedBox(height: 18),
                  if (active != null)
                    _ActiveSubscriptionCard(
                      subscription: active,
                      moneyFormatter: _money,
                      dateFormatter: _formatDateTime,
                      onCancel: _processing
                          ? null
                          : () => _cancelSubscription(active),
                      onAutoRenewChanged: _processing
                          ? null
                          : (value) => _toggleAutoRenew(active, value),
                    )
                  else
                    const _InlineNotice(
                      message:
                          'No tienes una suscripción activa. Puedes comprar un plan desde esta pantalla.',
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Planes disponibles',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (data.plans.isEmpty)
                    const _InlineNotice(
                      message: 'La API no devolvió planes disponibles.',
                      tone: _NoticeTone.warning,
                    ),
                  for (final plan in data.plans) ...[
                    _PlanCard(
                      plan: plan,
                      moneyFormatter: _money,
                      wallet: data.wallet,
                      disabledByActiveSubscription: active != null,
                      onPurchase:
                          (!plan.active || active != null || _processing)
                          ? null
                          : () => _showPurchaseSheet(data, plan),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    'Historial',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (data.history.isEmpty)
                    const _InlineNotice(
                      message:
                          'Aún no hay suscripciones registradas para esta cuenta.',
                    ),
                  for (final subscription in data.history) ...[
                    _HistoryCard(
                      subscription: subscription,
                      dateFormatter: _formatDateTime,
                      moneyFormatter: _money,
                      statusLabel: _statusLabel(subscription.status),
                      statusColor: _statusColor(subscription.status),
                    ),
                    const SizedBox(height: 10),
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

class _HeroSubscriptionCard extends StatelessWidget {
  const _HeroSubscriptionCard({
    required this.wallet,
    required this.activeSubscription,
    required this.processing,
  });

  final _WalletSummary? wallet;
  final _UserSubscription? activeSubscription;
  final bool processing;

  @override
  Widget build(BuildContext context) {
    final walletBalance = wallet == null
        ? 'Wallet no disponible'
        : '${wallet!.currency} ${wallet!.balance.toStringAsFixed(2)}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B63C7), Color(0xFF00B36C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'SUSCRIPCIONES CYCLIX',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            activeSubscription == null
                ? 'Activa un plan y reduce minutos facturables.'
                : 'Tu plan actual cubre parte de cada viaje.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            activeSubscription == null
                ? 'La compra se cobra directamente al wallet y la cobertura empieza de inmediato.'
                : 'Tus minutos se descuentan antes de que el backend calcule el monto final del viaje.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroBadge(
                icon: Icons.account_balance_wallet_outlined,
                label: walletBalance,
              ),
              _HeroBadge(
                icon: Icons.sync_outlined,
                label: processing
                    ? 'Procesando...'
                    : activeSubscription?.autoRenew == true
                    ? 'Auto-renew activo'
                    : 'Sin auto-renew',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveSubscriptionCard extends StatelessWidget {
  const _ActiveSubscriptionCard({
    required this.subscription,
    required this.moneyFormatter,
    required this.dateFormatter,
    required this.onCancel,
    required this.onAutoRenewChanged,
  });

  final _UserSubscription subscription;
  final String Function(num?, {String currency}) moneyFormatter;
  final String Function(DateTime) dateFormatter;
  final VoidCallback? onCancel;
  final ValueChanged<bool>? onAutoRenewChanged;

  @override
  Widget build(BuildContext context) {
    final consumedPercent = subscription.includedMinutes <= 0
        ? 0.0
        : (subscription.consumedMinutes / subscription.includedMinutes).clamp(
            0.0,
            1.0,
          );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: CyclixColors.accentGreen.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subscription.planName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Chip(
                label: const Text('Activa'),
                backgroundColor: CyclixColors.accentGreen.withValues(
                  alpha: 0.12,
                ),
                labelStyle: const TextStyle(
                  color: CyclixColors.accentGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            moneyFormatter(subscription.monthlyPrice),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: CyclixColors.primaryBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: consumedPercent,
            minHeight: 10,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: CyclixColors.cardGrey,
            color: CyclixColors.accentGreen,
          ),
          const SizedBox(height: 12),
          _SummaryPanel(
            rows: [
              _SummaryRow(
                'Minutos restantes',
                '${subscription.remainingMinutes}',
              ),
              _SummaryRow(
                'Minutos consumidos',
                '${subscription.consumedMinutes}',
              ),
              _SummaryRow('Vence el', dateFormatter(subscription.expiresAt)),
            ],
          ),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            value: subscription.autoRenew,
            contentPadding: EdgeInsets.zero,
            onChanged: onAutoRenewChanged,
            title: const Text('Renovación automática'),
            subtitle: const Text('Activa o desactiva la preferencia del plan.'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancelar suscripción'),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.moneyFormatter,
    required this.wallet,
    required this.disabledByActiveSubscription,
    required this.onPurchase,
  });

  final _SubscriptionPlan plan;
  final String Function(num?, {String currency}) moneyFormatter;
  final _WalletSummary? wallet;
  final bool disabledByActiveSubscription;
  final VoidCallback? onPurchase;

  @override
  Widget build(BuildContext context) {
    final enoughBalance =
        wallet == null || wallet!.balance >= plan.monthlyPrice;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: plan.active
              ? CyclixColors.primaryBlue.withValues(alpha: 0.14)
              : const Color(0xFFE4EAF3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Chip(
                label: Text(plan.active ? 'Activo' : 'Inactivo'),
                backgroundColor: plan.active
                    ? CyclixColors.primaryBlue.withValues(alpha: 0.10)
                    : const Color(0xFFF2F4F7),
                labelStyle: TextStyle(
                  color: plan.active
                      ? CyclixColors.primaryBlue
                      : CyclixColors.instructionGray,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            moneyFormatter(plan.monthlyPrice),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: CyclixColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PlanTag(label: '${plan.includedHours} horas'),
              _PlanTag(label: '${plan.includedHours * 60} min'),
            ],
          ),
          const SizedBox(height: 14),
          if (disabledByActiveSubscription)
            const _InlineNotice(
              message:
                  'Ya tienes una suscripción activa. Debes esperar a que termine o cancelarla antes de comprar otra.',
            )
          else if (!enoughBalance)
            _InlineNotice(
              message:
                  'Saldo insuficiente en wallet para comprar este plan ahora mismo.',
              tone: _NoticeTone.warning,
            )
          else
            const Text(
              'La compra crea la suscripción inmediatamente y descuenta el precio desde tu wallet.',
              style: TextStyle(
                color: CyclixColors.instructionGray,
                height: 1.35,
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onPurchase,
            style: FilledButton.styleFrom(
              backgroundColor: plan.active
                  ? CyclixColors.primaryBlue
                  : Colors.grey.shade300,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.shopping_bag_outlined),
            label: Text(
              !plan.active
                  ? 'No disponible'
                  : disabledByActiveSubscription
                  ? 'Ya tienes un plan activo'
                  : 'Comprar plan',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.subscription,
    required this.dateFormatter,
    required this.moneyFormatter,
    required this.statusLabel,
    required this.statusColor,
  });

  final _UserSubscription subscription;
  final String Function(DateTime) dateFormatter;
  final String Function(num?, {String currency}) moneyFormatter;
  final String statusLabel;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CyclixColors.cardGrey,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subscription.planName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Chip(
                label: Text(statusLabel),
                backgroundColor: statusColor.withValues(alpha: 0.12),
                labelStyle: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SummaryPanel(
            rows: [
              _SummaryRow('Precio', moneyFormatter(subscription.monthlyPrice)),
              _SummaryRow('Inicio', dateFormatter(subscription.startsAt)),
              _SummaryRow('Fin', dateFormatter(subscription.expiresAt)),
              _SummaryRow(
                'Uso',
                '${subscription.consumedMinutes}/${subscription.includedMinutes} min',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.rows});

  final List<_SummaryRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  rows[i].label,
                  style: const TextStyle(color: CyclixColors.instructionGray),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  rows[i].value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: rows[i].highlighted
                        ? Colors.redAccent
                        : CyclixColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          if (i != rows.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SummaryRow {
  const _SummaryRow(this.label, this.value, {this.highlighted = false});

  final String label;
  final String value;
  final bool highlighted;
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message, this.tone = _NoticeTone.soft});

  final String message;
  final _NoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final isWarning = tone == _NoticeTone.warning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isWarning
            ? const Color(0xFFFFF7E8)
            : CyclixColors.primaryBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWarning ? const Color(0xFFFFD98C) : const Color(0xFFD4E4F7),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isWarning ? Icons.warning_amber_rounded : Icons.info_outline,
            color: isWarning
                ? const Color(0xFFB7791F)
                : CyclixColors.primaryBlue,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(height: 1.35))),
        ],
      ),
    );
  }
}

class _PlanTag extends StatelessWidget {
  const _PlanTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: CyclixColors.cardGrey,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: CyclixColors.textDark,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

enum _NoticeTone { soft, warning }

class _SubscriptionsViewData {
  const _SubscriptionsViewData({
    required this.plans,
    required this.activeSubscription,
    required this.history,
    required this.wallet,
  });

  final List<_SubscriptionPlan> plans;
  final _UserSubscription? activeSubscription;
  final List<_UserSubscription> history;
  final _WalletSummary? wallet;
}

class _SubscriptionPlan {
  const _SubscriptionPlan({
    required this.id,
    required this.name,
    required this.monthlyPrice,
    required this.includedHours,
    required this.active,
  });

  factory _SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return _SubscriptionPlan(
      id: json['id'] as Object? ?? 0,
      name: json['name']?.toString() ?? 'Plan Cyclix',
      monthlyPrice:
          num.tryParse(json['monthlyPrice']?.toString() ?? '')?.toDouble() ?? 0,
      includedHours: int.tryParse(json['includedHours']?.toString() ?? '') ?? 0,
      active: json['active'] != false,
    );
  }

  final Object id;
  final String name;
  final double monthlyPrice;
  final int includedHours;
  final bool active;
}

class _UserSubscription {
  const _UserSubscription({
    required this.id,
    required this.planName,
    required this.status,
    required this.startsAt,
    required this.expiresAt,
    required this.includedMinutes,
    required this.consumedMinutes,
    required this.remainingMinutes,
    required this.autoRenew,
    required this.monthlyPrice,
  });

  factory _UserSubscription.fromJson(Map<String, dynamic> json) {
    return _UserSubscription(
      id: json['id'] as Object? ?? 0,
      planName: json['planName']?.toString() ?? 'Plan Cyclix',
      status: json['status']?.toString() ?? 'ACTIVE',
      startsAt:
          DateTime.tryParse(json['startsAt']?.toString() ?? '') ??
          DateTime.now(),
      expiresAt:
          DateTime.tryParse(json['expiresAt']?.toString() ?? '') ??
          DateTime.now(),
      includedMinutes:
          int.tryParse(json['includedMinutes']?.toString() ?? '') ?? 0,
      consumedMinutes:
          int.tryParse(json['consumedMinutes']?.toString() ?? '') ?? 0,
      remainingMinutes:
          int.tryParse(json['remainingMinutes']?.toString() ?? '') ?? 0,
      autoRenew: json['autoRenew'] == true,
      monthlyPrice:
          num.tryParse(json['monthlyPrice']?.toString() ?? '')?.toDouble() ?? 0,
    );
  }

  final Object id;
  final String planName;
  final String status;
  final DateTime startsAt;
  final DateTime expiresAt;
  final int includedMinutes;
  final int consumedMinutes;
  final int remainingMinutes;
  final bool autoRenew;
  final double monthlyPrice;
}

class _WalletSummary {
  const _WalletSummary({required this.balance, required this.currency});

  factory _WalletSummary.fromJson(Map<String, dynamic> json) {
    return _WalletSummary(
      balance: num.tryParse(json['balance']?.toString() ?? '')?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? 'GTQ',
    );
  }

  final double balance;
  final String currency;
}
