import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/Login.dart';
import 'screens/main_shell.dart';
import 'theme/cyclix_colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CyclixApp());
}

class CyclixApp extends StatelessWidget {
  const CyclixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cyclix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: CyclixColors.primaryBlue,
          primary: CyclixColors.primaryBlue,
          secondary: CyclixColors.accentGreen,
          surface: CyclixColors.backgroundWhite,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme().copyWith(
          displayLarge: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: CyclixColors.textDark,
          ),
          displayMedium: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: CyclixColors.textDark,
          ),
          displaySmall: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: CyclixColors.textDark,
          ),
          headlineLarge: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: CyclixColors.textDark,
          ),
          headlineMedium: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: CyclixColors.textDark,
          ),
          headlineSmall: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: CyclixColors.textDark,
          ),
          titleLarge: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: CyclixColors.textDark,
          ),
          titleMedium: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: CyclixColors.textDark,
          ),
          titleSmall: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: CyclixColors.textDark,
          ),
          bodyLarge: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            color: CyclixColors.textDark,
          ),
          bodyMedium: GoogleFonts.poppins(
            fontWeight: FontWeight.w400,
            color: CyclixColors.textDark,
          ),
        ),
        scaffoldBackgroundColor: CyclixColors.backgroundWhite,
        cardTheme: const CardThemeData(color: CyclixColors.cardGrey),
        appBarTheme: const AppBarTheme(
          backgroundColor: CyclixColors.backgroundWhite,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: CyclixColors.textDark),
        ),
      ),

      // Primero se abre el login
      home: const LoginScreen(),

      // Ruta para ir a la pantalla principal después del login
      routes: {'/main': (context) => const MainShell()},
    );
  }
}
