import 'package:flutter/material.dart';

import '../theme/cyclix_colors.dart';

class CyclixSubscriptionCard extends StatelessWidget {
  const CyclixSubscriptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.actionLabel = 'Ver suscripciones',
    this.icon = Icons.workspace_premium_outlined,
    this.emphasized = true,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final IconData icon;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final gradient = emphasized
        ? const LinearGradient(
            colors: [Color(0xFF0F6ACF), Color(0xFF00A86B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null;
    final backgroundColor = emphasized
        ? null
        : CyclixColors.accentGreen.withValues(alpha: 0.08);
    final borderColor = emphasized
        ? Colors.white.withValues(alpha: 0.16)
        : CyclixColors.accentGreen.withValues(alpha: 0.24);
    final titleColor = emphasized ? Colors.white : CyclixColors.textDark;
    final subtitleColor = emphasized
        ? Colors.white.withValues(alpha: 0.82)
        : CyclixColors.instructionGray;
    final iconColor = emphasized ? Colors.white : CyclixColors.accentGreen;
    final buttonBackground = emphasized ? Colors.white : CyclixColors.textDark;
    final buttonForeground = emphasized
        ? CyclixColors.primaryBlue
        : Colors.white;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: CyclixColors.primaryBlue.withValues(
              alpha: emphasized ? 0.14 : 0.05,
            ),
            blurRadius: emphasized ? 22 : 10,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: emphasized
                    ? Colors.white.withValues(alpha: 0.16)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: textTheme.bodyMedium?.copyWith(color: subtitleColor),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: buttonBackground,
                foregroundColor: buttonForeground,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CyclixSubscriptionPill extends StatelessWidget {
  const CyclixSubscriptionPill({
    super.key,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: CyclixColors.accentGreen.withValues(alpha: 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: CyclixColors.accentGreen.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.workspace_premium_outlined,
                  color: CyclixColors.accentGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: CyclixColors.textDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: CyclixColors.instructionGray,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
