# Cyclix Wear

Companion app para relojes Android/Wear OS.

## Ejecutar

```bash
flutter pub get
flutter run
```

## Compilar APK debug

```bash
flutter build apk --debug
```

Salida:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## NFC

El desbloqueo por NFC queda disponible solo si el reloj reporta NFC activo para apps. Si el dispositivo reserva NFC solo para pagos, la app mostrara que NFC no esta disponible.
