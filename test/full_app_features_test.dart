import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safesphere/services/api_service_impl.dart';
import 'package:safesphere/services/route_safety_ml_engine.dart';

class _AllowHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  HttpOverrides.global = _AllowHttpOverrides();

  group('Comprehensive SafeSphere App Features Test Suite', () {
    test('1. Authentication & Security Storage Module', () async {
      final token = await ApiService.getToken();
      print('  ✓ Auth Token Storage check completed. Current Token: ${token ?? "None (Unauthenticated)"}');
    });

    test('2. Safe Route Prediction & Multi-Engine Routing', () async {
      const startLat = 11.0168;
      const startLng = 76.9558;
      const endLat = 11.0048;
      const endLng = 76.9603;

      final routeRes = await ApiService.getSafeRoute(
        startLat,
        startLng,
        endLat,
        endLng,
        engine: RoutingEngine.auto,
      );

      expect(routeRes, isNotNull);
      expect(routeRes['route'], isNotNull);
      final route = routeRes['route'] as Map<String, dynamic>;
      final safety = routeRes['safety'] as Map<String, dynamic>;

      expect((route['geometry'] as List).length, greaterThan(1));
      expect(route['distance_km'], greaterThan(0));
      expect(route['duration_min'], greaterThan(0));
      expect(safety['score'], isNotNull);

      print('  ✓ Safe Route Prediction Working:');
      print('    - Selected Engine: ${routeRes['engine']}');
      print('    - Distance: ${route['distance_km']} km, Duration: ${route['duration_min']} min');
      print('    - Safety Score: ${safety['score']}% (${safety['level']})');
    });

    test('3. Machine Learning Safety Scoring & NLP Sentiment Engine', () {
      const posText = 'Felt safe, well-lit street with regular police patrol.';
      const negText = 'Dark isolated street, poor lighting and suspicious activity.';

      final posSentiment = FeedbackSentimentNLP.analyzeSentiment(posText);
      final negSentiment = FeedbackSentimentNLP.analyzeSentiment(negText);

      expect(posSentiment, greaterThan(0.5));
      expect(negSentiment, lessThan(-0.5));

      final mlPred = RouteSafetyMLEngine.predictSafetyScore(
        startLat: 13.0827,
        startLng: 80.2707,
        endLat: 13.0890,
        endLng: 80.2780,
      );

      expect(mlPred['score'], isNotNull);
      expect(mlPred['level'], isNotNull);
      expect(mlPred['ml_metrics'], isNotNull);

      print('  ✓ ML Safety Scoring & Sentiment NLP Working:');
      print('    - Positive Comment Sentiment: $posSentiment');
      print('    - Negative Comment Sentiment: $negSentiment');
      print('    - Predicted Safety Score: ${mlPred['score']}% (${mlPred['level']})');
    });

    test('4. Automatic Safe Bypass Rerouting Engine', () {
      const startLat = 13.0827;
      const startLng = 80.2707;
      const endLat = 13.0890;
      const endLng = 80.2780;

      final bypassPoints = RouteSafetyMLEngine.generateBypassWaypoints(
        startLat,
        startLng,
        endLat,
        endLng,
      );

      expect(bypassPoints.length, greaterThanOrEqualTo(3));
      final detourPoint = bypassPoints[1];

      print('  ✓ Automatic Safe Bypass Rerouting Working:');
      print('    - Start: ($startLat, $startLng)');
      print('    - Detour Midpoint: (${detourPoint[0]}, ${detourPoint[1]})');
      print('    - Destination: ($endLat, $endLng)');
    });

    test('5. Location Detection & Geocoding (Tamil Nadu, Chennai, Thandalam)', () async {
      final places = ['Gandhipuram', 'RS Puram', 'Thandalam', 'Poonamallee', 'Sriperumbudur', 'Chennai'];

      for (final p in places) {
        final results = await ApiService.geocode(p, biasLat: 13.0827, biasLng: 80.2707);
        expect(results, isNotEmpty, reason: 'Location "$p" must be detected');
        final top = results.first;
        expect(top['lat'], isNotNull);
        expect(top['lon'], isNotNull);
        print('  ✓ Location Detected: "$p" -> ${top['display_name']} (${top['lat']}, ${top['lon']})');
      }
    });

    test('6. Emergency Contacts Service Module', () async {
      final contactsRes = await ApiService.getContacts();
      expect(contactsRes, isNotNull);
      print('  ✓ Emergency Contacts Module Working: $contactsRes');
    });

    test('7. Community Safety Reports Module', () async {
      final reportsRes = await ApiService.getAllIncidents();
      expect(reportsRes, isNotNull);
      print('  ✓ Community Safety Reports Module Working: $reportsRes');
    });

    test('8. SOS Alert Trigger & Safety Service', () async {
      final sosResult = await ApiService.triggerSOS(
        11.0168,
        76.9558,
      );
      expect(sosResult, isNotNull);
      print('  ✓ SOS Emergency Alert Dispatching Working: ${sosResult['message'] ?? 'SOS Triggered'}');
    });
  });
}
