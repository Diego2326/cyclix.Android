# Cyclix Smartwatch

Este directorio contiene proyectos companion para relojes inteligentes.

## Wear OS

`cyclix_wear/` es una app Flutter independiente para relojes Android/Wear OS.

Funciones incluidas:

- login con el mismo API de Cyclix
- saldo de wallet
- estacion disponible sin bloquear el inicio si el reloj no entrega ubicacion
- viaje activo
- finalizar viaje
- desbloqueo por NFC si el reloj tiene NFC disponible para apps
- soporte rapido preparado para demo

Comandos:

```bash
cd wear/cyclix_wear
flutter pub get
flutter run
flutter build apk --debug
```

El APK debug queda en:

```text
wear/cyclix_wear/build/app/outputs/flutter-apk/app-debug.apk
```

## Apple Watch

Apple Watch no ejecuta Flutter como una app watchOS completa. Para soportarlo bien se debe crear un target watchOS en Xcode usando SwiftUI y conectarlo al mismo API o a la app iOS companion.

Pantallas recomendadas para Apple Watch:

- wallet y saldo
- viaje activo
- estacion cercana
- finalizar viaje
- soporte rapido
- notificaciones de viaje y saldo

## NFC en smartwatch

El flujo NFC esta preparado para Wear OS, pero depende del hardware y de que Android permita a apps de terceros leer tags NFC en ese reloj. Algunos relojes tienen NFC solo para pagos y no lo exponen a apps normales.
