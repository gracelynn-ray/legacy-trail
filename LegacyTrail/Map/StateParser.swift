import MapKit

// Used to highlight regions on map.
class GeoJSONParser {
    
    // Parses JSON file to get array of polygons for map.
    static func parseStates(from fileName: String) -> [MKPolygon] {
        var polygons = [MKPolygon]()
        
        guard let path = Bundle.main.path(forResource: fileName, ofType: "json"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return polygons
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            
            guard let features = json?["features"] as? [[String: Any]] else {
                return polygons
            }
            
            for feature in features {
                guard let geometry = feature["geometry"] as? [String: Any],
                      let type = geometry["type"] as? String else {
                    continue
                }
                
                if type == "Polygon",
                   let coordinates = geometry["coordinates"] as? [[[Double]]] {
                    let newPolygons = createPolygons(from: coordinates)
                    polygons.append(contentsOf: newPolygons)
                }
                
                if type == "MultiPolygon",
                   let multiCoordinates = geometry["coordinates"] as? [[[[Double]]]] {
                    for coordinates in multiCoordinates {
                        let newPolygons = createPolygons(from: coordinates)
                        polygons.append(contentsOf: newPolygons)
                    }
                }
            }
        } catch {
            print("Failed to parse: \(error)")
        }
        
        return polygons
    }
    
    private static func createPolygons(from coordinates: [[[Double]]]) -> [MKPolygon] {
        var polygons = [MKPolygon]()
        
        for ring in coordinates {
            var points: [CLLocationCoordinate2D] = []
            
            for coordinate in ring {
                let longitude = coordinate[0]
                let latitude = coordinate[1]
                points.append(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
            }
            
            let polygon = MKPolygon(coordinates: points, count: points.count)
            polygons.append(polygon)
        }
        
        return polygons
    }
    
}
