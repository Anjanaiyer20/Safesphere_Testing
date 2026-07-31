import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

// Helper matching logic in RouteMapWidget
List<LatLng> decodePolyline(String encoded) {
  final pts = <LatLng>[];
  int i = 0, lat = 0, lng = 0;

  while (i < encoded.length) {
    int b, shift = 0, result = 0;
    do {
      if (i >= encoded.length) break;
      b = encoded.codeUnitAt(i++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

    shift = 0;
    result = 0;
    do {
      if (i >= encoded.length) break;
      b = encoded.codeUnitAt(i++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

    pts.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return pts;
}

List<LatLng> decodeORSGeometry(String geometry) {
  final decoded = decodePolyline(geometry);
  // Swapping lat and lng because ORS encodes as [lng, lat]
  return decoded.map((p) => LatLng(p.longitude, p.latitude)).toList();
}

String encodePolyline(List<List<double>> coords) {
  final str = StringBuffer();
  int lastLat = 0;
  int lastLng = 0;

  for (final coord in coords) {
    int lat = (coord[0] * 1e5).round();
    int lng = (coord[1] * 1e5).round();

    int dLat = lat - lastLat;
    int dLng = lng - lastLng;

    lastLat = lat;
    lastLng = lng;

    for (final val in [dLat, dLng]) {
      int num = val < 0 ? ~(val << 1) : (val << 1);
      while (num >= 0x20) {
        str.writeCharCode(((num & 0x1f) | 0x20) + 63);
        num >>= 5;
      }
      str.writeCharCode(num + 63);
    }
  }
  return str.toString();
}

void main() {
  test('ORS polyline decoding correctly swaps longitude and latitude', () {
    // Encoded polyline representing ORS route [lng, lat] around Coimbatore (11.0168 N, 76.9558 E)
    final polylineString = encodePolyline([
      [76.9558, 11.0168],
      [76.9603, 11.0048],
    ]);

    final points = decodeORSGeometry(polylineString);

    expect(points.length, equals(2));

    // Verify decoded points are correctly swapped into LatLng(lat, lng)
    expect(points[0].latitude, closeTo(11.0168, 0.0001));
    expect(points[0].longitude, closeTo(76.9558, 0.0001));

    expect(points[1].latitude, closeTo(11.0048, 0.0001));
    expect(points[1].longitude, closeTo(76.9603, 0.0001));
  });
}
