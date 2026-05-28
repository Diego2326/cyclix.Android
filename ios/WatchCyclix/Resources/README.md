# WatchCyclix

Codigo nativo para portar la app de `wear/cyclix_wear` a watchOS con SwiftUI, reutilizando la API de Cyclix y replicando el flujo principal de la app:

- login y persistencia de sesion
- dashboard con wallet, puesto cercano y viaje activo
- desbloqueo manual de bicicleta por ID/codigo/URL de QR
- validacion de zona al iniciar y finalizar viajes
- wallet y recarga
- historial de viajes
- puestos activos y bicicletas disponibles
- soporte y creacion de tickets
- perfil y cierre de sesion

## Lo que cambia frente a WearOS

- No se implementa NFC.
- El inicio de viaje se hace con un flujo manual desde el reloj.
- No se agregan assets, signing ni provisioning en este commit.

## Integracion sugerida en Xcode

1. En `Runner.xcodeproj`, agrega un nuevo target `watchOS App`.
2. Usa `ios/WatchCyclix/App/CyclixWatchApp.swift` como entrypoint.
3. Agrega todos los archivos `.swift` de `ios/WatchCyclix`.
4. Define un deployment target de watchOS 10 o superior.
5. Agrega permisos de ubicacion en el `Info.plist` del target watch:
   - `NSLocationWhenInUseUsageDescription`
6. Si compartiras sesion con iPhone luego, puedes mover `CyclixWatchSessionStore` a un app group o usar `WatchConnectivity`.

## Nota

La carpeta se dejo separada del target Flutter/iOS existente para no romper la configuracion actual del proyecto mientras se implementa el port.
