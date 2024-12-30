import MapKit

// Used to darken map everywhere except visited regions.
class BlurredMapOverlay: NSObject, MKOverlay {
    var coordinate: CLLocationCoordinate2D
    var boundingMapRect: MKMapRect
    
    override init() {
        self.coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        self.boundingMapRect = MKMapRect.world
    }
}

class BlurredMapOverlayRenderer: MKOverlayRenderer {
    var excludedRegions: [MKPolygon]

    init(overlay: MKOverlay, excludedRegions: [MKPolygon]) {
        self.excludedRegions = excludedRegions
        super.init(overlay: overlay)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        context.setFillColor(UIColor.black.withAlphaComponent(0.75).cgColor)
        context.fill(self.rect(for: self.overlay.boundingMapRect))

        for polygon in excludedRegions {
            let path = CGMutablePath()
            
            for i in 0..<polygon.pointCount {
                let point = polygon.points()[i]
                let mapPoint = MKMapPoint(x: Double(point.x), y: Double(point.y))
                let cgPoint = self.point(for: mapPoint)

                if i == 0 {
                    path.move(to: cgPoint)
                } else {
                    path.addLine(to: cgPoint)
                }
            }
            path.closeSubpath()
            
            context.addPath(path)
            context.setBlendMode(.clear)
            context.fillPath()
        }

        context.setBlendMode(.normal)
    }
}
