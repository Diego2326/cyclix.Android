# Cyclix WatchOS

App nativa para Apple Watch en SwiftUI basada en las capacidades de `wear/cyclix_wear` y en el mismo API de Cyclix.

Incluye:

- login directo contra `https://api.cyclix.site/api/v1`
- wallet y movimientos recientes
- estaciones activas ordenadas por cercanía
- viaje activo y cierre de viaje
- soporte rápido desde el reloj
- desbloqueo y bloqueo de bicicletas por BLE

## BLE

La capa BLE ya está implementada, pero usa una configuración placeholder en `Sources/Models.swift`:

- `serviceUUID = FFF0`
- `commandCharacteristicUUID = FFF1`
- comandos `UNLOCK` y `LOCK`

Antes de producción hay que sustituirlos por los UUIDs y payloads reales del firmware de la bicicleta.

## Generar el proyecto

El `.xcodeproj` se genera desde un script para que sea fácil de reconstruir:

```bash
cd watchos/CyclixWatch
gem install xcodeproj
ruby scripts/generate_project.rb
```

## Abrir en Xcode

```bash
open watchos/CyclixWatch/CyclixWatch.xcodeproj
```

## Limitaciones actuales

- No reutiliza Flutter ni la sesión del iPhone; inicia sesión directo desde el reloj.
- El flujo BLE necesita credenciales reales del hardware para probar el desbloqueo físico.
- QR, cámara y captura de foto de cierre no se migraron porque no encajan bien en watchOS.
