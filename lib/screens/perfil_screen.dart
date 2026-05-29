import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'subscriptions_screen.dart';
import '../services/auth_service.dart';
import '../theme/cyclix_colors.dart';
import '../widgets/cyclix_subscription_cta.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? userData;
  String? _profilePhotoPath;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final data = await _authService.getUserData();
    final photoPath = await _authService.getProfilePhotoPath();
    if (!mounted) return;
    setState(() {
      userData = data;
      _profilePhotoPath = photoPath;
    });
  }

  Future<void> _openSubscriptions() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SubscriptionsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyclixColors.backgroundWhite,
      body: userData == null
          ? const Center(
              child: CircularProgressIndicator(color: CyclixColors.primaryBlue),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                40,
                24,
                32 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: CyclixColors.primaryBlue,
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 55,
                            backgroundColor: CyclixColors.cardGrey,
                            backgroundImage:
                                _profilePhotoPath != null &&
                                    File(_profilePhotoPath!).existsSync()
                                ? FileImage(File(_profilePhotoPath!))
                                : null,
                            child:
                                _profilePhotoPath == null ||
                                    !File(_profilePhotoPath!).existsSync()
                                ? const Icon(
                                    Icons.person,
                                    size: 70,
                                    color: CyclixColors.primaryBlue,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "${userData!['firstName'] ?? 'Usuario'} ${userData!['lastName'] ?? ''}",
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: CyclixColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: CyclixColors.accentGreen.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "MI CUENTA",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: CyclixColors.accentGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    "Información Personal",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: CyclixColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildInfoCard([
                    _buildInfoTile(
                      Icons.person_outline,
                      "Nombre Completo",
                      "${userData!['firstName'] ?? ''} ${userData!['lastName'] ?? ''}",
                    ),
                    _buildDivider(),
                    _buildInfoTile(
                      Icons.email_outlined,
                      "Correo Electrónico",
                      userData!['email'] ?? 'No disponible',
                    ),
                    _buildDivider(),
                    _buildInfoTile(
                      Icons.phone_android_outlined,
                      "Teléfono",
                      userData!['phone'] ?? 'No disponible',
                    ),
                  ]),
                  const SizedBox(height: 30),
                  Text(
                    "Estado de Cuenta",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: CyclixColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildInfoCard([
                    _buildInfoTile(
                      Icons.verified_user_outlined,
                      "Estado del Usuario",
                      "ACTIVO",
                    ),
                  ]),
                  const SizedBox(height: 20),
                  CyclixSubscriptionCard(
                    title: 'Suscripciones para tus viajes',
                    subtitle:
                        'Descubre planes que descuentan minutos antes del pricing y del cobro al wallet.',
                    actionLabel: 'Abrir suscripciones',
                    icon: Icons.workspace_premium_outlined,
                    emphasized: false,
                    onTap: _openSubscriptions,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CyclixColors.cardGrey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(color: Colors.grey.withValues(alpha: 0.2), height: 20);
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: CyclixColors.primaryBlue, size: 20),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: CyclixColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
