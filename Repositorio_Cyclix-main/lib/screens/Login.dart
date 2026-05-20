import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import '../services/auth_service.dart';
import '../theme/cyclix_colors.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController userController = TextEditingController();
  final TextEditingController passController = TextEditingController();
  final AuthService _authService = AuthService();
  final LocalAuthentication auth = LocalAuthentication();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initBiometrics();
    });
  }

  Future<void> _initBiometrics() async {
    final hasLogin = await _authService.hasPreviousLogin();
    if (!mounted || !hasLogin) return;

    try {
      final isSupported = await auth.isDeviceSupported();
      final availableBiometrics = await auth.getAvailableBiometrics();
      final canAuthenticate = isSupported && availableBiometrics.isNotEmpty;
      if (!mounted) return;
      setState(() {
        _canCheckBiometrics = canAuthenticate;
      });
    } catch (e) {
      debugPrint('Error inicializando biometría: $e');
      if (!mounted) return;
      setState(() {
        _canCheckBiometrics = false;
      });
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    if (_isLoading) return;

    try {
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Inicia sesión con tu huella o rostro',
        options: const AuthenticationOptions(biometricOnly: true),
      );

      if (!mounted || !didAuthenticate) return;

      final token = await _authService.getSavedToken();
      final userData = await _authService.getUserData();

      if (!mounted) return;

      if (token != null && userData != null) {
        _showWelcomeAndNavigate(userData['firstName'] ?? 'Usuario');
      } else {
        await _authService.logout();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Tu sesión expiró. Inicia sesión de nuevo."),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error de biometría: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No se pudo iniciar sesión con biometría"),
        ),
      );
    }
  }

  void _showWelcomeAndNavigate(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "¡Bienvenido/a, $name!",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: CyclixColors.accentGreen,
      ),
    );
    Navigator.pushReplacementNamed(context, '/main');
  }

  void login() async {
    if (userController.text.isEmpty || passController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, completa todos los campos")),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.login(
      userController.text.trim(),
      passController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result != null) {
      _showWelcomeAndNavigate(result['firstName'] ?? 'Usuario');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Credenciales incorrectas o error de conexión"),
        ),
      );
    }
  }

  @override
  void dispose() {
    userController.dispose();
    passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CyclixColors.backgroundWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/logo_cyclix.png',
                  height: 180,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.directions_bike,
                      size: 100,
                      color: CyclixColors.primaryBlue,
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  "BIENVENIDO A CYCLIX",
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: CyclixColors.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "MUEVE TU MUNDO",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: userController,
                  style: GoogleFonts.poppins(color: CyclixColors.textDark),
                  decoration: InputDecoration(
                    labelText: "Email",
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: CyclixColors.primaryBlue,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: passController,
                  obscureText: _obscurePassword,
                  style: GoogleFonts.poppins(color: CyclixColors.textDark),
                  decoration: InputDecoration(
                    labelText: "Contraseña",
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: CyclixColors.primaryBlue,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                _isLoading
                    ? const CircularProgressIndicator(
                        color: CyclixColors.primaryBlue,
                      )
                    : Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: CyclixColors.accentGreen,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                "INGRESAR",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          if (_canCheckBiometrics) ...[
                            const SizedBox(height: 20),
                            IconButton(
                              icon: const Icon(
                                Icons.fingerprint,
                                size: 50,
                                color: CyclixColors.primaryBlue,
                              ),
                              onPressed: _authenticateWithBiometrics,
                            ),
                            Text(
                              "Ingresar con biometría",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ],
                      ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  ),
                  child: Text(
                    "¿No tienes cuenta? Regístrate aquí",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: CyclixColors.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
