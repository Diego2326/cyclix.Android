import '../services/cyclix_api_service.dart';
import 'package:flutter/material.dart';
import '../theme/cyclix_colors.dart';
import '../widgets/cyclix_header.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, this.embeddedInShell = false});

  final bool embeddedInShell;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final CyclixApiService _api = CyclixApiService();
  late Future<_WalletData> _future = _load();
  bool _recharging = false;

  Future<_WalletData> _load() async {
    final wallet = await _api.getWallet();
    final transactions = await _api.getWalletTransactions();
    return _WalletData(wallet, transactions);
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  String _money(Object? value, {String currency = 'GTQ'}) {
    final number = num.tryParse(value?.toString() ?? '');
    return '$currency ${((number ?? 0).toDouble()).toStringAsFixed(2)}';
  }

  Future<void> _showRechargeDialog(Map<String, dynamic> wallet) async {
    final controller = TextEditingController();
    String selectedMethod = 'TEST';
    String finalSelectedMethod = 'TEST';
    String? amountError;

    final cardNumberController = TextEditingController();
    final cardNameController = TextEditingController();
    final cardDateController = TextEditingController();
    final cardCvvController = TextEditingController();
    final paypalEmailController = TextEditingController();

    final amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
            final bottomSafe = MediaQuery.paddingOf(context).bottom;

            void submit() {
              final raw = controller.text.trim().replaceAll(',', '.');
              final parsed = double.tryParse(raw);
              if (raw.isEmpty || parsed == null || parsed <= 0) {
                setSheetState(() {
                  amountError = 'Debes colocar un monto para recargar.';
                });
                return;
              }
              finalSelectedMethod = selectedMethod;
              Navigator.pop(context, parsed);
            }

            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  20 + bottomSafe + bottomInset,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Recargar wallet',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Selecciona un método y escribe el monto a agregar.',
                      style: TextStyle(color: CyclixColors.instructionGray),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Monto',
                        prefixText: 'Q. ',
                        errorText: amountError,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        if (amountError != null) {
                          setSheetState(() => amountError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 18),
                    _RechargeMethodTile(
                      title: 'Visa',
                      subtitle: 'Tarjeta terminada en 4242',
                      icon: Icons.credit_card,
                      selected: selectedMethod == 'VISA',
                      onTap: () => setSheetState(() => selectedMethod = 'VISA'),
                    ),
                    _RechargeMethodTile(
                      title: 'MasterCard',
                      subtitle: 'Tarjeta terminada en 5555',
                      icon: Icons.credit_card_outlined,
                      selected: selectedMethod == 'MASTERCARD',
                      onTap: () =>
                          setSheetState(() => selectedMethod = 'MASTERCARD'),
                    ),
                    _RechargeMethodTile(
                      title: 'PayPal',
                      subtitle: 'Cuenta PayPal vinculada',
                      icon: Icons.paypal_outlined,
                      selected: selectedMethod == 'PAYPAL',
                      onTap: () =>
                          setSheetState(() => selectedMethod = 'PAYPAL'),
                    ),

                    _RechargeMethodTile(
                      title: 'Recarga de prueba',
                      subtitle: 'Usa el endpoint de pruebas del API',
                      icon: Icons.science_outlined,
                      selected: selectedMethod == 'TEST',
                      onTap: () => setSheetState(() => selectedMethod = 'TEST'),
                    ),

                    if (selectedMethod == 'VISA' ||
                        selectedMethod == 'MASTERCARD') ...[
                      const SizedBox(height: 14),

                      Text(
                        selectedMethod == 'VISA'
                            ? 'Datos de tarjeta Visa'
                            : 'Datos de tarjeta MasterCard',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextField(
                        controller: cardNumberController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Número de tarjeta',
                          hintText: '0000 0000 0000 0000',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextField(
                        controller: cardNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del titular',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: cardDateController,
                              decoration: const InputDecoration(
                                labelText: 'Fecha',
                                hintText: 'MM/AA',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: TextField(
                              controller: cardCvvController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'CVV',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (selectedMethod == 'PAYPAL') ...[
                      const SizedBox(height: 14),

                      const Text(
                        'Cuenta PayPal',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextField(
                        controller: paypalEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo PayPal',
                          hintText: 'correo@paypal.com',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    FilledButton.icon(
                      onPressed: submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: CyclixColors.accentGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.add_card_outlined),
                      label: const Text('Confirmar recarga'),
                    ),

                    const SizedBox(height: 8),

                    TextButton(
                      onPressed: () => Navigator.pop(context),
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

    if (amount == null || amount <= 0 || _recharging) return;

    setState(() => _recharging = true);

    try {
      await _api.topUpMyWallet(
        amount: amount,
        paymentMethod: _apiPaymentMethod(finalSelectedMethod),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saldo recargado correctamente.')),
      );

      setState(() => _future = _load());
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo recargar el wallet. $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _recharging = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      top: false,
      child: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<_WalletData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(32),
                children: [
                  const SizedBox(height: 80),
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 58,
                    color: CyclixColors.primaryBlue,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No se pudo cargar tu wallet',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(snapshot.error.toString(), textAlign: TextAlign.center),
                ],
              );
            }

            final data = snapshot.data!;
            final currency = data.wallet['currency']?.toString() ?? 'GTQ';

            return ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                20,
                16,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: CyclixColors.primaryBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 34,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Saldo disponible',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _money(data.wallet['balance'], currency: currency),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _recharging
                            ? null
                            : () => _showRechargeDialog(data.wallet),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: CyclixColors.primaryBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: _recharging
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_card_outlined),
                        label: const Text('Recargar saldo'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Movimientos',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (data.transactions.isEmpty)
                  const Text('Aún no hay movimientos en tu wallet.'),
                for (final tx in data.transactions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      tx['type'] == 'CREDIT'
                          ? Icons.add_circle_outline
                          : Icons.remove_circle_outline,
                      color: tx['type'] == 'CREDIT'
                          ? CyclixColors.accentGreen
                          : CyclixColors.primaryBlue,
                    ),
                    title: Text(
                      tx['description']?.toString() ?? tx['type'].toString(),
                    ),
                    subtitle: Text(tx['createdAt']?.toString() ?? ''),
                    trailing: Text(
                      _money(tx['amount'], currency: currency),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );

    if (widget.embeddedInShell) {
      return ColoredBox(color: CyclixColors.backgroundWhite, child: content);
    }

    return Scaffold(
      backgroundColor: CyclixColors.backgroundWhite,
      appBar: const CyclixHeader(showBack: true),
      body: content,
    );
  }
}

String _apiPaymentMethod(String selectedMethod) {
  return switch (selectedMethod) {
    'PAYPAL' => 'TRANSFER',
    'TEST' => 'CASH',
    _ => 'CARD',
  };
}

class _RechargeMethodTile extends StatelessWidget {
  const _RechargeMethodTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? CyclixColors.accentGreen.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? CyclixColors.accentGreen
                  : const Color(0xFFE6EAF0),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected
                    ? CyclixColors.accentGreen
                    : CyclixColors.primaryBlue,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: CyclixColors.instructionGray,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                color: selected ? CyclixColors.accentGreen : Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletData {
  const _WalletData(this.wallet, this.transactions);

  final Map<String, dynamic> wallet;
  final List<Map<String, dynamic>> transactions;
}
