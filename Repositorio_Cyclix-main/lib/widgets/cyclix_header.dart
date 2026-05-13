import 'package:flutter/material.dart';

import '../theme/cyclix_colors.dart';

class CyclixHeader extends StatelessWidget implements PreferredSizeWidget {
  const CyclixHeader({super.key, this.showBack = false});

  /// Si es true, muestra flecha atrás en lugar del menú hamburguesa.
  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: CyclixColors.headerBorder, width: 2),
          bottom: BorderSide(color: CyclixColors.headerBorder, width: 2),
        ),
        color: Colors.white,
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              if (showBack)
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: CyclixColors.brandGreen),
                  onPressed: () => Navigator.of(context).maybePop(),
                )
              else
                IconButton(
                  icon: const Icon(Icons.menu, color: CyclixColors.brandGreen),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Menú (pendiente de integración)')),
                    );
                  },
                ),
              Expanded(
                child: Text(
                  'Cyclix',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: CyclixColors.brandBlue,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.pedal_bike,
                  color: CyclixColors.brandGreen,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
