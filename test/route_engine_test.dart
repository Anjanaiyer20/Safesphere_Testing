import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safesphere/services/api_service_impl.dart';

class _AllowHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  HttpOverrides.global = _AllowHttpOverrides();

  const startLat = 11.0168; // Gandhipuram, Coimbatore
  const startLng = 76.9558;
  const endLat = 11.0048;   // RS Puram, Coimbatore
  const endLng = 76.9603;

  test('Route detection with OSRM engine', () async {
    final result = await ApiService.getSafeRoute(
      startLat, startLng, endLat, endLng,
      engine: RoutingEngine.osrm,
    );

    expect(result, isNotNull);
    expect(result.containsKey('route'), isTrue);
    final route = result['route'] as Map<String, dynamic>;
    expect(route['geometry'], isNotNull);
    expect(route['distance_km'], greaterThan(0));
    print('OSRM Route Success: Engine=${result['engine']}, Dist=${route['distance_km']}km, Dur=${route['duration_min']}min');
  });

  test('Route detection with OpenRouteService engine', () async {
    final result = await ApiService.getSafeRoute(
      startLat, startLng, endLat, endLng,
      engine: RoutingEngine.openrouteservice,
    );

    expect(result, isNotNull);
    expect(result.containsKey('route'), isTrue);
    final route = result['route'] as Map<String, dynamic>;
    expect(route['geometry'], isNotNull);
    expect(route['distance_km'], greaterThan(0));
    print('ORS Route Success: Engine=${result['engine']}, Dist=${route['distance_km']}km, Dur=${route['duration_min']}min');
  });

  test('Route detection with Valhalla engine', () async {
    final result = await ApiService.getSafeRoute(
      startLat, startLng, endLat, endLng,
      engine: RoutingEngine.valhalla,
    );

    expect(result, isNotNull);
    expect(result.containsKey('route'), isTrue);
    final route = result['route'] as Map<String, dynamic>;
    expect(route['geometry'], isNotNull);
    expect(route['distance_km'], greaterThan(0));
    print('Valhalla Route Success: Engine=${result['engine']}, Dist=${route['distance_km']}km, Dur=${route['duration_min']}min');
  });

  test('Route detection with Auto cascade engine', () async {
    final result = await ApiService.getSafeRoute(
      startLat, startLng, endLat, endLng,
      engine: RoutingEngine.auto,
    );

    expect(result, isNotNull);
    expect(result.containsKey('route'), isTrue);
    final route = result['route'] as Map<String, dynamic>;
    expect(route['geometry'], isNotNull);
    expect(route['distance_km'], greaterThan(0));
    print('Auto Cascade Route Success: Engine=${result['engine']}, Dist=${route['distance_km']}km, Dur=${route['duration_min']}min');
  });

  test('Geocoding search detection test', () async {
    final results = await ApiService.geocode('Coimbatore');
    expect(results, isNotEmpty);
    final top = results.first;
    expect(top['lat'], isNotNull);
    expect(top['lon'], isNotNull);
    print('Geocoding Success: Query=Coimbatore -> Name=${top['display_name']} (${top['lat']}, ${top['lon']})');
  });
}
