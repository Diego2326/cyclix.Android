import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import 'screens/login.dart';
import 'screens/main_shell.dart';
import 'theme/cyclix_colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // En varios dispositivos Android el modo TLHC no entrega bien los toques al mapa;
  // la composición híbrida corrige el arrastre y el zoom.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    final GoogleMapsFlutterPlatform impl = GoogleMapsFlutterPlatform.instance;
    if (impl is GoogleMapsFlutterAndroid) {
      impl.useAndroidViewSurface = true;
    }
  }

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
          seedColor: CyclixColors.brandGreen,
          primary: CyclixColors.brandGreen,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: CyclixColors.scaffoldBackground,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),

      // Primero se abre el login
      home: const LoginScreen(),

      // Ruta para ir a la pantalla principal después del login
      routes: {
        '/main': (context) => const MainShell(),
      },
    );
  }
}