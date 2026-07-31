import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safesphere/services/api_service_impl.dart';

class _AllowHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  HttpOverrides.global = _AllowHttpOverrides();

  group('Full Route Prediction & Geocoding End-to-End Tests', () {
    test('1. Geocode start location string to coordinates', () async {
      final startResults = await ApiService.geocode('Gandhipuram, Coimbatore');
      expect(startResults, isNotEmpty, reason: 'Geocoding start location should return results');
      final top = startResults.first;
      expect(top['lat'], isNotNull);
      expect(top['lon'], isNotNull);
      print('✓ Start location geocoded: ${top['display_name']} -> (${top['lat']}, ${top['lon']})');
    });

    test('2. Geocode destination location string to coordinates', () async {
      final destResults = await ApiService.geocode('RS Puram, Coimbatore');
      expect(destResults, isNotEmpty, reason: 'Geocoding destination should return results');
      final top = destResults.first;
      expect(top['lat'], isNotNull);
      expect(top['lon'], isNotNull);
      print('✓ Destination geocoded: ${top['display_name']} -> (${top['lat']}, ${top['lon']})');
    });

    test('3. Full route prediction pipeline (Auto engine)', () async {
      const startLat = 11.0168;
      const startLng = 76.9558;
      const endLat = 11.0048;
      const endLng = 76.9603;

      final result = await ApiService.getSafeRoute(
        startLat,
        startLng,
        endLat,
        endLng,
        engine: RoutingEngine.auto,
      );

      expect(result, isNotNull);
      expect(result['route'], isNotNull);
      final route = result['route'] as Map<String, dynamic>;
      final safety = result['safety'] as Map<String, dynamic>? ?? {};

      expect(route['geometry'], isA<List>());
      final geometry = route['geometry'] as List;
      expect(geometry.length, greaterThan(1), reason: 'Route geometry must contain multiple waypoints');

      expect(route['distance_km'], greaterThan(0));
      expect(route['duration_min'], greaterThan(0));
      expect(safety['score'], isNotNull);

      print('✓ Auto Engine Route Predicted successfully:');
      print('  - Selected Engine: ${result['engine']}');
      print('  - Distance: ${route['distance_km']} km');
      print('  - Duration: ${route['duration_min']} min');
      print('  - Waypoints count: ${geometry.length}');
      print('  - Safety Score: ${safety['score']}% (${safety['level']})');
    });

    test('4. Route prediction with OSRM engine', () async {
      const startLat = 11.0168;
      const startLng = 76.9558;
      const endLat = 11.0048;
      const endLng = 76.9603;

      final result = await ApiService.getSafeRoute(
        startLat,
        startLng,
        endLat,
        endLng,
        engine: RoutingEngine.osrm,
      );

      expect(result['route'], isNotNull);
      final route = result['route'] as Map<String, dynamic>;
      expect((route['geometry'] as List).length, greaterThan(1));
      print('✓ OSRM Route Predicted: ${route['distance_km']} km, ${route['duration_min']} min');
    });

    test('5. Route prediction with Valhalla engine', () async {
      const startLat = 11.0168;
      const startLng = 76.9558;
      const endLat = 11.0048;
      const endLng = 76.9603;

      final result = await ApiService.getSafeRoute(
        startLat,
        startLng,
        endLat,
        endLng,
        engine: RoutingEngine.valhalla,
      );

      expect(result['route'], isNotNull);
      final route = result['route'] as Map<String, dynamic>;
      expect((route['geometry'] as List).length, greaterThan(1));
      print('✓ Valhalla Route Predicted: ${route['distance_km']} km, ${route['duration_min']} min');
    });

    test('6. Geocoding Tamil Nadu destination places', () async {
      final places = [
        'Gandhipuram',
        'RS Puram',
        'Peelamedu',
        'Saravanampatti',
        'Saibaba Colony',
        'Madurai',
        'Chennai',
        'Tiruppur',
        'Salem',
        'T. Nagar',
      ];

      for (final place in places) {
        final results = await ApiService.geocode(place, biasLat: 11.0168, biasLng: 76.9558);
        expect(results, isNotEmpty, reason: 'Destination "$place" in Tamil Nadu must be detected');
        final top = results.first;
        expect(top['lat'], isNotNull);
        expect(top['lon'], isNotNull);
        print('  ✓ TN Destination Detected: "$place" -> ${top['display_name']} (${top['lat']}, ${top['lon']})');
      }
    });

    test('7. Geocoding Chennai & Thandalam area places', () async {
      final chennaiPlaces = [
        'Thandalam',
        'Poonamallee',
        'Sriperumbudur',
        'Porur',
        'Guindy',
        'Velachery',
        'Chromepet',
        'Tambaram',
        'Sholinganallur',
        'Koyambedu',
      ];

      for (final place in chennaiPlaces) {
        final results = await ApiService.geocode(place, biasLat: 13.0827, biasLng: 80.2707);
        expect(results, isNotEmpty, reason: 'Chennai area destination "$place" must be detected');
        final top = results.first;
        expect(top['lat'], isNotNull);
        expect(top['lon'], isNotNull);
        print('  ✓ Chennai Destination Detected: "$place" -> ${top['display_name']} (${top['lat']}, ${top['lon']})');
      }
    });
  });
}
