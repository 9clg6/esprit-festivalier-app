import EFDesign
import EFDomain
import MapKit
import SwiftUI

/// E4: festivals as clustered pins. Touching a cluster zooms in, touching a pin selects its festival.
struct FestivalMapView: UIViewRepresentable {
    let festivals: [Festival]
    @Binding var selection: Festival.ID?
    let userCoordinate: Coordinate?
    /// Incremented by the "recentrer sur moi" button.
    let recenter: Int

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "pin")
        map.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "cluster")
        map.tintColor = UIColor(EFColorToken.accentFill.color)
        map.pointOfInterestFilter = .excludingAll
        map.setRegion(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 46.6, longitude: 2.4),
                span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
            ),
            animated: false
        )
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        map.showsUserLocation = userCoordinate != nil
        context.coordinator.sync(map, festivals: festivals)
        if recenter != context.coordinator.lastRecenter {
            context.coordinator.lastRecenter = recenter
            if let userCoordinate {
                map.setRegion(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(
                        latitude: userCoordinate.latitude, longitude: userCoordinate.longitude
                    ),
                    span: MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
                ), animated: true)
            }
        }
    }

    final class Pin: NSObject, MKAnnotation {
        let festival: Festival
        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: festival.latitude, longitude: festival.longitude)
        }
        var title: String? { festival.name }

        init(_ festival: Festival) { self.festival = festival }
    }

    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: FestivalMapView
        var lastRecenter: Int
        private var shown: [Festival.ID] = []

        init(_ parent: FestivalMapView) {
            self.parent = parent
            lastRecenter = parent.recenter
        }

        /// Replaces the pins when the filtered festivals change, then fits them on screen.
        func sync(_ map: MKMapView, festivals: [Festival]) {
            let ids = festivals.map(\.id)
            guard ids != shown else { return }
            shown = ids
            map.removeAnnotations(map.annotations.filter { $0 is Pin })
            let pins = festivals.map(Pin.init)
            map.addAnnotations(pins)
            guard !pins.isEmpty else { return }
            let rect = pins.reduce(MKMapRect.null) {
                $0.union(MKMapRect(origin: MKMapPoint($1.coordinate), size: MKMapSize(width: 0, height: 0)))
            }
            // ponytail: a single festival would zoom to street level, so keep a 150 km minimum span.
            let minSize = 150_000 * MKMapPointsPerMeterAtLatitude(46)
            let padded = rect.insetBy(
                dx: -max(rect.width * 0.2, (minSize - rect.width) / 2),
                dy: -max(rect.height * 0.2, (minSize - rect.height) / 2)
            )
            map.setVisibleMapRect(padded, edgePadding: .init(top: 24, left: 24, bottom: 24, right: 24), animated: true)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
            if let cluster = annotation as? MKClusterAnnotation {
                let view = marker(mapView, id: "cluster", annotation: cluster)
                view.glyphText = "\(cluster.memberAnnotations.count)"
                view.accessibilityLabel = "\(cluster.memberAnnotations.count) festivals, touche pour zoomer"
                return view
            }
            guard let pin = annotation as? Pin else { return nil }
            let view = marker(mapView, id: "pin", annotation: pin)
            view.clusteringIdentifier = "festival"
            view.glyphImage = UIImage(systemName: "music.note")
            view.canShowCallout = false
            let dates = FestivalDates.text(from: pin.festival.startDate, to: pin.festival.endDate)
            view.accessibilityLabel = "\(pin.festival.name), \(dates)"
            return view
        }

        private func marker(_ map: MKMapView, id: String, annotation: any MKAnnotation) -> MKMarkerAnnotationView {
            let reused = map.dequeueReusableAnnotationView(withIdentifier: id, for: annotation)
            let view = reused as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation = annotation
            view.markerTintColor = UIColor(EFColorToken.accentFill.color)
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let cluster = view.annotation as? MKClusterAnnotation {
                mapView.deselectAnnotation(cluster, animated: false)
                mapView.showAnnotations(cluster.memberAnnotations, animated: true)
            } else if let pin = view.annotation as? Pin {
                parent.selection = pin.festival.id
            }
        }

        func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
            if view.annotation is Pin { parent.selection = nil }
        }
    }
}
