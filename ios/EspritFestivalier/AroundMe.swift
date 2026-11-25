import CoreLocation
import EFDomain
import Observation

/// "Autour de moi" (STORY-013): the position is read on the device only, to about a kilometer.
@MainActor @Observable
final class AroundMe: NSObject, CLLocationManagerDelegate {
    private(set) var status: CLAuthorizationStatus
    private(set) var coordinate: Coordinate?
    /// E14: the explanation sheet, shown before the iOS permission prompt.
    var showExplanation = false
    var showDenied = false
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var onLocated: ((Coordinate) -> Void)?

    var isAuthorized: Bool { status == .authorizedWhenInUse || status == .authorizedAlways }
    var isDenied: Bool { status == .denied || status == .restricted }

    override init() {
        status = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Calls `apply` with the position, asking first when the permission is not decided yet.
    func activate(then apply: @escaping (Coordinate) -> Void) {
        onLocated = apply
        if isDenied {
            onLocated = nil
            showDenied = true
        } else if status == .notDetermined {
            showExplanation = true
        } else if let coordinate {
            onLocated = nil
            apply(coordinate)
        } else {
            manager.requestLocation()
        }
    }

    func confirmExplanation() {
        showExplanation = false
        manager.requestWhenInUseAuthorization()
    }

    func declineExplanation() {
        showExplanation = false
        onLocated = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.authorizationChanged(status) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        let coordinate = Coordinate(latitude: last.coordinate.latitude, longitude: last.coordinate.longitude)
        Task { @MainActor in self.located(coordinate) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        // No position: the filter stays off and the region picker remains available.
    }

    private func authorizationChanged(_ status: CLAuthorizationStatus) {
        self.status = status
        if isAuthorized {
            manager.requestLocation()
        } else if isDenied, onLocated != nil {
            onLocated = nil
            showDenied = true
        }
    }

    private func located(_ coordinate: Coordinate) {
        self.coordinate = coordinate
        let apply = onLocated
        onLocated = nil
        apply?(coordinate)
    }
}
