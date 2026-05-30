import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/active_trip_controller.dart';
import '../theme/cyclix_colors.dart';

class CyclixHeader extends StatefulWidget implements PreferredSizeWidget {
  const CyclixHeader({
    super.key,
    this.showBack = false,
    this.showActiveTripShortcut = true,
  });

  final bool showBack;
  final bool showActiveTripShortcut;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  State<CyclixHeader> createState() => _CyclixHeaderState();
}

class _CyclixHeaderState extends State<CyclixHeader> {
  final ActiveTripController _activeTripController =
      ActiveTripController.instance;

  @override
  void initState() {
    super.initState();
    _activeTripController.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 64,
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: const Border(
        bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1),
      ),
      leadingWidth: 64,
      leading: Builder(
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: IconButton(
              tooltip: widget.showBack ? 'Volver' : 'Menú',
              icon: Icon(
                widget.showBack ? Icons.arrow_back : Icons.menu,
                color: CyclixColors.primaryBlue,
              ),
              onPressed: () {
                if (widget.showBack) {
                  Navigator.of(context).maybePop();
                } else {
                  Scaffold.maybeOf(context)?.openDrawer();
                }
              },
            ),
          );
        },
      ),
      title: Text(
        'Cyclix',
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          color: CyclixColors.primaryBlue,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: ValueListenableBuilder<ActiveTripSession?>(
            valueListenable: _activeTripController.sessionListenable,
            builder: (context, session, child) {
              if (!widget.showActiveTripShortcut || session == null) {
                return child!;
              }

              return TextButton.icon(
                onPressed: () {
                  Navigator.of(
                    context,
                  ).push(_activeTripController.buildRoute(session));
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: CyclixColors.accentGreen.withValues(
                    alpha: 0.14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: const Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: CyclixColors.accentGreen,
                ),
                label: Text(
                  'Viaje activo',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: CyclixColors.accentGreen,
                  ),
                ),
              );
            },
            child: const Icon(
              Icons.pedal_bike,
              color: CyclixColors.accentGreen,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }
}
