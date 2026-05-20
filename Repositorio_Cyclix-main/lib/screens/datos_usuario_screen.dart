import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../theme/cyclix_colors.dart';

class DatosUsuarioScreen extends StatefulWidget {
  const DatosUsuarioScreen({super.key});

  @override
  State<DatosUsuarioScreen> createState() => _DatosUsuarioScreenState();
}

class _DatosUsuarioScreenState extends State<DatosUsuarioScreen> {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final data = await _authService.getUserData();
    setState(() {
      userData = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyclixColors.backgroundWhite,
      appBar: AppBar(
        title: Text(
          "MI CUENTA",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: CyclixColors.primaryBlue,
          ),
        ),
        iconTheme: const IconThemeData(color: CyclixColors.primaryBlue),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: userData == null
          ? const Center(
              child: CircularProgressIndicator(color: CyclixColors.primaryBlue),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20.0,
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
                          child: const CircleAvatar(
                            radius: 55,
                            backgroundColor: CyclixColors.cardGrey,
                            child: Icon(
                              Icons.person,
                              size: 70,
                              color: CyclixColors.primaryBlue,
                            ),
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
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await _authService.logout();
                        if (!context.mounted) return;
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/',
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: Text(
                        "CERRAR SESIÓN",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1.2,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
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
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(color: Colors.grey.withOpacity(0.2), height: 20);
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
