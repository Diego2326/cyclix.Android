import CoreLocation
import Foundation

final class CyclixWatchLocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var pendingContinuation: CheckedContinuation<CLLocationCoordinate2D, Error>?
    private var awaitingAuthorization = false

    static let fallbackCoordinate = CLLocationCoordinate2D(latitude: 14.6349, longitude: -90.5069)

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func currentCoordinateOrFallback() async -> CLLocationCoordinate2D {
        do {
            return try await currentCoordinate()
        } catch {
            return Self.fallbackCoordinate
        }
    }

    func currentCoordinate() async throws -> CLLocationCoordinate2D {
        if let coordinate = manager.location?.coordinate {
            return coordinate
        }

        let status = manager.authorizationStatus
        if status == .denied || status == .restricted {
            throw CyclixWatchError.message("Permite la ubicacion para usar la app desde el reloj.")
        }

        return try await withCheckedThrowingContinuation { continuation in
            pendingContinuation = continuation

            if status == .notDetermined {
                awaitingAuthorization = true
                manager.requestWhenInUseAuthorization()
            } else {
                manager.requestLocation()
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard awaitingAuthorization else { return }
        awaitingAuthorization = false

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            pendingContinuation?.resume(throwing: CyclixWatchError.message("Sin permiso de ubicacion."))
            pendingContinuation = nil
        case .notDetermined:
            break
        @unknown default:
            pendingContinuation?.resume(throwing: CyclixWatchError.message("No se pudo obtener permiso de ubicacion."))
            pendingContinuation = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else {
            pendingContinuation?.resume(throwing: CyclixWatchError.message("No se pudo leer la ubicacion actual."))
            pendingContinuation = nil
            return
        }
        pendingContinuation?.resume(returning: coordinate)
        pendingContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        pendingContinuation?.resume(throwing: error)
        pendingContinuation = nil
    }
}
