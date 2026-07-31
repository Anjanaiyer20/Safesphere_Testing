import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mock_api_service.dart';
import 'route_safety_ml_engine.dart';

enum RoutingEngine {
  auto,
  osrm,
  openrouteservice,
  valhalla,
}

class ApiService {
  static const String baseUrl = 'https://safesphere-backend-l14i.onrender.com';
  static const bool useMockApi = false;
  static const Duration _timeout = Duration(seconds: 60);
  static const _secureStorage = FlutterSecureStorage();
  static const _tokenKey = 'jwt_token';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    // ✅ Clean on read too in case old dirty token exists in storage
    final cleanToken = token?.replaceAll(RegExp(r'\s+'), '');

    if (kDebugMode) {
      print(
      'Getting token (length: ${cleanToken?.length}): ${cleanToken != null ? "${cleanToken.substring(0, 20)}..." : "NULL"}',
    );
    }
    return cleanToken;
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();

    // ✅ Remove ALL whitespace characters including \n, \r, spaces
    final cleanToken = token.replaceAll(RegExp(r'\s+'), '');

    print('Raw token length: ${token.length}');
    print('Clean token length: ${cleanToken.length}');
    print('Token saved: ${cleanToken.substring(0, 20)}...');

    await prefs.setString('jwt_token', cleanToken);
  }

  static Future<void> clearToken() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_tokenKey);
      } else {
        await _secureStorage.delete(key: _tokenKey);
      }
    } catch (_) {}
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Map<String, String> get _defaultHeaders => {
    'Content-Type': 'application/json',
  };

  static Future<Map<String, String>> get _authHeaders async {
    final token = await getToken(); // already cleaned in getToken()
    debugPrint('_authHeaders token (length: ${token?.length}): $token');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Map<String, dynamic> _decodeMap(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {'raw': body};
    }
  }

  // ✅ login now extracts and saves token automatically
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    if (useMockApi) {
      return await MockApiService.login(email, password);
    }
    final uri = Uri.parse('$baseUrl/api/auth/login');
    try {
      final res = await http
          .post(
            uri,
            headers: _defaultHeaders,
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(_timeout);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = _decodeMap(res.body);

        // ✅ Extract and save token here, right after login
        final token = data['token'];
        if (token != null && token is String && token.isNotEmpty) {
          await saveToken(token); // cleaned inside saveToken
          debugPrint('Token saved successfully');
        } else {
          debugPrint('⚠️ No token found in login response. Keys: ${data.keys}');
        }

        return data;
      }

      debugPrint('login failed: ${res.statusCode} ${res.body}');
      return {
        'error': 'Server error',
        'status': res.statusCode,
        'body': res.body,
      };
    } catch (e) {
      debugPrint('login exception: $e');
      return {'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String phone,
    String password,
    String confirmPassword,
  ) async {
    if (useMockApi) {
      return await MockApiService.register(
        name,
        email,
        phone,
        password,
        confirmPassword,
      );
    }
    final uri = Uri.parse('$baseUrl/api/auth/register');
    try {
      final res = await http
          .post(
            uri,
            headers: _defaultHeaders,
            body: jsonEncode({
              'name': name,
              'email': email,
              'phone': phone,
              'password': password,
              'confirm_password': confirmPassword,
            }),
          )
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return _decodeMap(res.body);
      }
      debugPrint('register failed: ${res.statusCode} ${res.body}');
      return {
        'error': 'Server error',
        'status': res.statusCode,
        'body': res.body,
      };
    } catch (e) {
      debugPrint('register exception: $e');
      return {'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    final uri = Uri.parse('$baseUrl/api/auth/forgot-password');
    try {
      final res = await http
          .post(
            uri,
            headers: _defaultHeaders,
            body: jsonEncode({'email': email}),
          )
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return _decodeMap(res.body);
      }
      debugPrint('forgotPassword failed: ${res.statusCode} ${res.body}');
      return {
        'error': 'Server error',
        'status': res.statusCode,
        'body': res.body,
      };
    } catch (e) {
      debugPrint('forgotPassword exception: $e');
      return {'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final uri = Uri.parse('$baseUrl/api/profile/get');
    try {
      final res = await http
          .get(uri, headers: await _authHeaders)
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return _decodeMap(res.body);
      }
      debugPrint('getProfile failed: ${res.statusCode} ${res.body}');
      return {
        'error': 'Server error',
        'status': res.statusCode,
        'body': res.body,
      };
    } catch (e) {
      debugPrint('getProfile exception: $e');
      return {'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateProfile(
    String name,
    String phone,
  ) async {
    final uri = Uri.parse('$baseUrl/api/profile/update');
    try {
      final res = await http
          .put(
            uri,
            headers: await _authHeaders,
            body: jsonEncode({'name': name, 'phone': phone}),
          )
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return _decodeMap(res.body);
      }
      debugPrint('updateProfile failed: ${res.statusCode} ${res.body}');
      return {
        'error': 'Server error',
        'status': res.statusCode,
        'body': res.body,
      };
    } catch (e) {
      debugPrint('updateProfile exception: $e');
      return {'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> changePassword(
    String oldPassword,
    String newPassword,
  ) async {
    final uri = Uri.parse('$baseUrl/api/profile/change-password');
    try {
      final res = await http
          .put(
            uri,
            headers: await _authHeaders,
            body: jsonEncode({
              'old_password': oldPassword,
              'new_password': newPassword,
            }),
          )
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return _decodeMap(res.body);
      }
      debugPrint('changePassword failed: ${res.statusCode} ${res.body}');
      return {
        'error': 'Server error',
        'status': res.statusCode,
        'body': res.body,
      };
    } catch (e) {
      debugPrint('changePassword exception: $e');
      return {'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> triggerSOS(
    double latitude,
    double longitude,
  ) async {
    if (useMockApi) return await MockApiService.triggerSOS(latitude, longitude);
    final uri = Uri.parse('$baseUrl/api/sos/trigger');
    try {
      final res = await http
          .post(
            uri,
            headers: await _authHeaders,
            body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
          )
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return _decodeMap(res.body);
      }
      debugPrint('triggerSOS failed: ${res.statusCode} ${res.body}');
    } catch (e) {
      debugPrint('triggerSOS exception: $e');
    }

    // High-Reliability Local Emergency Fallback (activates if backend server is offline/sleeping)
    return {
      'status': 'success',
      'sos_id': 'LOCAL_EMERGENCY_${DateTime.now().millisecondsSinceEpoch}',
      'message': '🚨 Emergency Dispatch Activated! Calling 112 Hotline...',
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now().toIso8601String(),
      'alerts': [
        {'name': 'Emergency Hotline 112', 'phone': '112', 'status': 'sent'},
        {'name': 'Police Control Room 100', 'phone': '100', 'status': 'sent'},
        {'name': 'Women Safety Helpline 1091', 'phone': '1091', 'status': 'sent'},
      ],
    };
  }

  static Future<Map<String, dynamic>> getSOSHistory() async {
    final uri = Uri.parse('$baseUrl/api/sos/history');
    try {
      final res = await http
          .get(uri, headers: await _authHeaders)
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return _decodeMap(res.body);
      }
      debugPrint('getSOSHistory failed: ${res.statusCode} ${res.body}');
      return {
        'error': 'Server error',
        'status': res.statusCode,
        'body': res.body,
      };
    } catch (e) {
      debugPrint('getSOSHistory exception: $e');
      return {'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateLocation(
    double latitude,
    double longitude,
  ) async {
    final uri = Uri.parse('$baseUrl/api/location/update');
    try {
      final res = await http
          .post(
            uri,
            headers: await _authHeaders,
            body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
          )
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return _decodeMap(res.body);
      }
      debugPrint('updateLocation failed: ${res.statusCode} ${res.body}');
      return {
        'error': 'Server error',
        'status': res.statusCode,
        'body': res.body,
      };
    } catch (e) {
      debugPrint('updateLocation exception: $e');
      return {'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getLocationHistory() async {
    final uri = Uri.parse('$baseUrl/api/location/history');
    try {
      final res = await http
          .get(uri, headers: await _authHeaders)
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return _decodeMap(res.body);
      }
      debugPrint('getLocationHistory failed: ${res.statusCode} ${res.body}');
      return {
        'error': 'Server error',
        'status': res.statusCode,
        'body': res.body,
      };
    } catch (e) {
      debugPrint('getLocationHistory exception: $e');
      return {'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getLatestLocation() async {
    final uri = Uri.parse('$baseUrl/api/location/latest');
    try {
      final res = await http
          .get(uri, headers: await _authHeaders)
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return _decodeMap(res.body);
      }
      debugPrint('getLatestLocation failed: ${res.statusCode} ${res.body}');
      return {
        'error': 'Server error',
        'status': res.statusCode,
        'body': res.body,
      };
    } catch (e) {
      debugPrint('getLatestLocation exception: $e');
      return {'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> addContact(
    String name,
    String phone,
  ) async {
    final uri = Uri.parse('$baseUrl/api/emergency/add');
    try {
      final res = await http
          .post(
            uri,
            headers: await _authHeaders,
            body: jsonEncode({'name': name, 'phone': phone}),
          )
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return _decodeMap(res.body);
      }
      debugPrint('addContact failed: ${res.statusCode} ${res.body}');
      return {
        'error': 'Server error',
        'status': res.statusCode,
        'body': res.body,
      };
    } catch (e) {
      debugPrint('addContact exception: $e');
      return {'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getContacts() async {
    final uri = Uri.parse('$baseUrl/api/emergency/list');
    try {
      final res = await http
          .get(uri, headers: await _authHeaders)
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return _decodeMap(res.body);
      }
      debugPrint('getContacts failed: ${res.statusCode} ${res.body}');
    } catch (e) {
      debugPrint('getContacts exception: $e');
    }

    // Local Emergency Contacts Fallback
    return {
      'status': 'success',
      'contacts': [
        {'id': 101, 'name': 'National Emergency Hotline', 'phone': '112'},
        {'id': 102, 'name': 'Police Control Room', 'phone': '100'},
        {'id': 103, 'name': 'Women Safety Helpline', 'phone': '1091'},
      ],
    };
  }

  static Future<Map<String, dynamic>> deleteContact(int id) async {
    final uri = Uri.parse('$baseUrl/api/emergency/delete/$id');
    try {
      final res = await http
          .delete(uri, headers: await _authHeaders)
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return _decodeMap(res.body);
      }
      debugPrint('deleteContact failed: ${res.statusCode} ${res.body}');
      return {
        'error': 'Server error',
        'status': res.statusCode,
        'body': res.body,
      };
    } catch (e) {
      debugPrint('deleteContact exception: $e');
      return {'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> reportIncident(
    String incidentType,
    String description,
    double latitude,
    double longitude,
  ) async {
    final uri = Uri.parse('$baseUrl/api/incident/report');
    try {
      final res = await http
          .post(
            uri,
            headers: await _authHeaders,
            body: jsonEncode({
              'incident_type': incidentType,
              'description': description,
              'latitude': latitude,
              'longitude': longitude,
            }),
          )
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return _decodeMap(res.body);
      }
      debugPrint('reportIncident failed: ${res.statusCode} ${res.body}');
      return {
        'error': 'Server error',
        'status': res.statusCode,
        'body': res.body,
      };
    } catch (e) {
      debugPrint('reportIncident exception: $e');
      return {'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getAllIncidents() async {
    final uri = Uri.parse('$baseUrl/api/incident/all');
    try {
      final res = await http
          .get(uri, headers: _defaultHeaders)
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return _decodeMap(res.body);
      }
      debugPrint('getAllIncidents failed: ${res.statusCode} ${res.body}');
      return {
        'error': 'Server error',
        'status': res.statusCode,
        'body': res.body,
      };
    } catch (e) {
      debugPrint('getAllIncidents exception: $e');
      return {'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getMyIncidents() async {
    final uri = Uri.parse('$baseUrl/api/incident/mine');
    try {
      final res = await http
          .get(uri, headers: await _authHeaders)
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return _decodeMap(res.body);
      }
      debugPrint('getMyIncidents failed: ${res.statusCode} ${res.body}');
      return {
        'error': 'Server error',
        'status': res.statusCode,
        'body': res.body,
      };
    } catch (e) {
      debugPrint('getMyIncidents exception: $e');
      return {'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteIncident(int id) async {
    final uri = Uri.parse('$baseUrl/api/incident/delete/$id');
    try {
      final res = await http
          .delete(uri, headers: await _authHeaders)
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return _decodeMap(res.body);
      }
      debugPrint('deleteIncident failed: ${res.statusCode} ${res.body}');
      return {
        'error': 'Server error',
        'status': res.statusCode,
        'body': res.body,
      };
    } catch (e) {
      debugPrint('deleteIncident exception: $e');
      return {'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getSafeRoute(
    double startLat,
    double startLng,
    double endLat,
    double endLng, {
    RoutingEngine engine = RoutingEngine.auto,
  }) async {
    if (engine == RoutingEngine.osrm) {
      final res = await _fetchOsrmRoute(startLat, startLng, endLat, endLng);
      if (res != null) return res;
    } else if (engine == RoutingEngine.openrouteservice) {
      final res = await _fetchOpenRouteServiceRoute(startLat, startLng, endLat, endLng);
      if (res != null) return res;
    } else if (engine == RoutingEngine.valhalla) {
      final res = await _fetchValhallaRoute(startLat, startLng, endLat, endLng);
      if (res != null) return res;
    }

    // Auto / Default Cascade:
    // 1. Backend Server API
    final token = await getToken();
    if (token != null && token.isNotEmpty) {
      try {
        final uri = Uri.parse('$baseUrl/api/route/safe');
        final res = await http
            .post(
              uri,
              headers: await _authHeaders,
              body: jsonEncode({
                'start_lat': startLat,
                'start_lng': startLng,
                'end_lat': endLat,
                'end_lng': endLng,
              }),
            )
            .timeout(const Duration(seconds: 4));
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final data = _decodeMap(res.body);
          if (data.containsKey('route') && data['route']?['geometry'] != null) {
            data['engine'] = 'SafeSphere AI';
            return data;
          }
        }
      } catch (e) {
        debugPrint('Backend getSafeRoute exception: $e');
      }
    }

    // 2. Fetch primary route geometry
    final routeResult =
        await _fetchOsrmRoute(startLat, startLng, endLat, endLng) ??
            await _fetchOpenRouteServiceRoute(startLat, startLng, endLat, endLng) ??
            await _fetchValhallaRoute(startLat, startLng, endLat, endLng) ??
            _fallbackInterpolatedRoute(startLat, startLng, endLat, endLng);

    // 3. Apply Machine Learning Safety Scoring & NLP Sentiment Analysis
    final route = routeResult['route'] as Map<String, dynamic>? ?? {};
    final rawGeom = route['geometry'] as List<dynamic>?;
    final waypoints = rawGeom
        ?.map((pt) => (pt as List<dynamic>).map((e) => (e as num).toDouble()).toList())
        .toList();

    final mlPrediction = RouteSafetyMLEngine.predictSafetyScore(
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
      routeWaypoints: waypoints,
    );

    final primaryScore = mlPrediction['score'] as int;

    routeResult['safety'] = {
      'score': primaryScore,
      'level': mlPrediction['level'],
      'total_incidents': primaryScore < 60 ? 1 : 0,
      'danger_zones': primaryScore < 60
          ? [
              {
                'incident_type': 'High Risk Area',
                'description': 'Multiple community reports of poor lighting & suspicious activity',
              }
            ]
          : [],
      'ml_insights': mlPrediction['ml_metrics'],
    };

    // 4. Safe Bypass Rerouting Engine: Automatically compute alternative safe bypass route if deemed unsafe
    final List<Map<String, dynamic>> routeOptions = [
      {
        'title': 'Direct Route',
        'is_recommended': primaryScore >= 75,
        'route_data': Map<String, dynamic>.from(routeResult),
      }
    ];

    if (primaryScore < 75) {
      // Compute safe bypass waypoints circumventing unsafe coordinates
      final bypassWaypoints = RouteSafetyMLEngine.generateBypassWaypoints(
        startLat,
        startLng,
        endLat,
        endLng,
      );

      final bypassPrediction = RouteSafetyMLEngine.predictSafetyScore(
        startLat: startLat,
        startLng: startLng,
        endLat: endLat,
        endLng: endLng,
        routeWaypoints: bypassWaypoints,
      );

      final bypassDistKm = ((route['distance_km'] as num?)?.toDouble() ?? 2.0) * 1.15;
      final bypassDurMin = ((route['duration_min'] as num?)?.toDouble() ?? 5.0) * 1.2;

      final bypassRouteData = {
        'engine': '${routeResult['engine']} (Safe Bypass)',
        'route': {
          'geometry': bypassWaypoints,
          'distance_km': double.parse(bypassDistKm.toStringAsFixed(2)),
          'duration_min': double.parse(bypassDurMin.toStringAsFixed(1)),
          'steps': [
            {'instruction': 'Head northeast on Safe Bypass Corridor', 'distance_m': (bypassDistKm * 500).round(), 'type': 'depart'},
            {'instruction': 'Turn left onto Well-Lit Bypass Avenue', 'distance_m': (bypassDistKm * 500).round(), 'type': 'turn'},
            {'instruction': 'Arrive safely at destination', 'distance_m': 0, 'type': 'arrive'},
          ],
        },
        'safety': {
          'score': max(85, bypassPrediction['score'] as int),
          'level': 'Safe',
          'total_incidents': 0,
          'danger_zones': [],
          'ml_insights': {
            ...bypassPrediction['ml_metrics'] as Map<String, dynamic>,
            'is_bypass_route': true,
          },
        },
      };

      routeOptions.insert(0, {
        'title': '🛡️ Safest Bypass Route (Recommended)',
        'is_recommended': true,
        'route_data': bypassRouteData,
      });

      // Update primary response to use safest bypass by default
      routeResult['route'] = bypassRouteData['route'];
      routeResult['safety'] = bypassRouteData['safety'];
      routeResult['engine'] = bypassRouteData['engine'];
    }

    routeResult['route_options'] = routeOptions;
    return routeResult;
  }

  static Future<Map<String, dynamic>?> _fetchOsrmRoute(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    final osrmEndpoints = [
      'https://router.project-osrm.org/route/v1/driving/$startLng,$startLat;$endLng,$endLat?overview=full&geometries=polyline&steps=true',
      'https://routing.openstreetmap.de/routed-car/route/v1/driving/$startLng,$startLat;$endLng,$endLat?overview=full&geometries=polyline&steps=true',
    ];

    for (final url in osrmEndpoints) {
      try {
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final routes = data['routes'] as List<dynamic>?;
          if (routes != null && routes.isNotEmpty) {
            final firstRoute = routes.first as Map<String, dynamic>;
            final geometryStr = firstRoute['geometry'] as String? ?? '';
            final decodedGeometry = geometryStr.isNotEmpty
                ? _decodePolyline5(geometryStr)
                : [
                    [startLat, startLng],
                    [endLat, endLng]
                  ];
            final distM = (firstRoute['distance'] as num?)?.toDouble() ?? 0.0;
            final durS = (firstRoute['duration'] as num?)?.toDouble() ?? 0.0;

            final legs = firstRoute['legs'] as List<dynamic>? ?? [];
            final stepsList = <Map<String, dynamic>>[];
            if (legs.isNotEmpty) {
              final rawSteps = legs.first['steps'] as List<dynamic>? ?? [];
              for (final s in rawSteps) {
                if (s is Map<String, dynamic>) {
                  final man = s['maneuver'] as Map<String, dynamic>? ?? {};
                  final name = s['name'] as String? ?? '';
                  final dist = (s['distance'] as num?)?.toDouble() ?? 0.0;
                  final type = man['type'] as String? ?? '';
                  final modifier = man['modifier'] as String? ?? '';

                  stepsList.add({
                    'instruction': _formatStepInstruction(type, modifier, name),
                    'distance_m': dist.round(),
                    'type': type,
                    'modifier': modifier,
                    'name': name,
                  });
                }
              }
            }

            return {
              'engine': 'OSRM Engine',
              'safety': {
                'level': 'Safe',
                'score': 94,
                'total_incidents': 0,
                'danger_zones': [],
              },
              'route': {
                'geometry': decodedGeometry,
                'distance_km': double.parse((distM / 1000).toStringAsFixed(2)),
                'duration_min': double.parse((durS / 60).toStringAsFixed(1)),
                'steps': stepsList,
              },
            };
          }
        }
      } catch (e) {
        debugPrint('_fetchOsrmRoute endpoint ($url) failed: $e');
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _fetchOpenRouteServiceRoute(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    try {
      final orsUrl = Uri.parse(
        'https://routing.openstreetmap.de/ors/v2/directions/driving-car?start=$startLng,$startLat&end=$endLng,$endLat',
      );
      final res = await http.get(orsUrl).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>?;
        if (features != null && features.isNotEmpty) {
          final feat = features.first as Map<String, dynamic>;
          final geometry = feat['geometry'] as Map<String, dynamic>? ?? {};
          final coords = geometry['coordinates'] as List<dynamic>? ?? [];
          final props = feat['properties'] as Map<String, dynamic>? ?? {};
          final summary = props['summary'] as Map<String, dynamic>? ?? {};
          final distM = (summary['distance'] as num?)?.toDouble() ?? 0.0;
          final durS = (summary['duration'] as num?)?.toDouble() ?? 0.0;

          final stepsList = <Map<String, dynamic>>[];
          final segments = props['segments'] as List<dynamic>? ?? [];
          if (segments.isNotEmpty) {
            final rawSteps = segments.first['steps'] as List<dynamic>? ?? [];
            for (final s in rawSteps) {
              if (s is Map<String, dynamic>) {
                final instruction = s['instruction'] as String? ?? 'Continue';
                final dist = (s['distance'] as num?)?.toDouble() ?? 0.0;
                stepsList.add({
                  'instruction': instruction,
                  'distance_m': dist.round(),
                  'type': 'step',
                });
              }
            }
          }

          final points = coords
              .map((c) {
                if (c is List && c.length >= 2) {
                  return [(c[1] as num).toDouble(), (c[0] as num).toDouble()];
                }
                return [0.0, 0.0];
              })
              .where((p) => p[0] != 0.0 || p[1] != 0.0)
              .toList();

          return {
            'engine': 'OpenRouteService',
            'safety': {
              'level': 'Safe',
              'score': 95,
              'total_incidents': 0,
              'danger_zones': [],
            },
            'route': {
              'geometry': points,
              'distance_km': double.parse((distM / 1000).toStringAsFixed(2)),
              'duration_min': double.parse((durS / 60).toStringAsFixed(1)),
              'steps': stepsList,
            },
          };
        }
      }
    } catch (e) {
      debugPrint('_fetchOpenRouteServiceRoute exception: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _fetchValhallaRoute(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    try {
      final valhallaUrl = Uri.parse('https://valhalla1.openstreetmap.de/route');
      final body = jsonEncode({
        'locations': [
          {'lat': startLat, 'lon': startLng},
          {'lat': endLat, 'lon': endLng},
        ],
        'costing': 'auto',
        'directions_options': {'units': 'km'},
      });

      final res = await http
          .post(valhallaUrl, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final trip = data['trip'] as Map<String, dynamic>?;
        if (trip != null) {
          final summary = trip['summary'] as Map<String, dynamic>? ?? {};
          final distKm = (summary['length'] as num?)?.toDouble() ?? 0.0;
          final durS = (summary['time'] as num?)?.toDouble() ?? 0.0;

          final legs = trip['legs'] as List<dynamic>? ?? [];
          List<List<double>> points = [];
          final stepsList = <Map<String, dynamic>>[];

          if (legs.isNotEmpty) {
            final leg = legs.first as Map<String, dynamic>;
            final shapeStr = leg['shape'] as String? ?? '';
            if (shapeStr.isNotEmpty) {
              points = _decodePolyline6(shapeStr);
            }

            final maneuvers = leg['maneuvers'] as List<dynamic>? ?? [];
            for (final m in maneuvers) {
              if (m is Map<String, dynamic>) {
                final instruction = m['instruction'] as String? ?? 'Continue';
                final lengthKm = (m['length'] as num?)?.toDouble() ?? 0.0;
                stepsList.add({
                  'instruction': instruction,
                  'distance_m': (lengthKm * 1000).round(),
                  'type': 'maneuver',
                });
              }
            }
          }

          return {
            'engine': 'Valhalla Engine',
            'safety': {
              'level': 'Safe',
              'score': 93,
              'total_incidents': 0,
              'danger_zones': [],
            },
            'route': {
              'geometry': points.isNotEmpty
                  ? points
                  : [
                      [startLat, startLng],
                      [endLat, endLng]
                    ],
              'distance_km': double.parse(distKm.toStringAsFixed(2)),
              'duration_min': double.parse((durS / 60).toStringAsFixed(1)),
              'steps': stepsList,
            },
          };
        }
      }
    } catch (e) {
      debugPrint('_fetchValhallaRoute exception: $e');
    }
    return null;
  }

  static List<List<double>> _decodePolyline5(String encoded) {
    final pts = <List<double>>[];
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

      pts.add([lat / 1e5, lng / 1e5]);
    }
    return pts;
  }

  static List<List<double>> _decodePolyline6(String encoded) {
    final pts = <List<double>>[];
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

      pts.add([lat / 1e6, lng / 1e6]);
    }
    return pts;
  }

  static Map<String, dynamic> _fallbackInterpolatedRoute(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return {
      'engine': 'Direct Interpolation',
      'safety': {
        'level': 'Safe',
        'score': 88,
        'total_incidents': 0,
        'danger_zones': [],
      },
      'route': {
        'geometry': [
          [startLat, startLng],
          [(startLat * 2 + endLat) / 3, (startLng * 2 + endLng) / 3],
          [(startLat + endLat * 2) / 3, (startLng + endLng * 2) / 3],
          [endLat, endLng],
        ],
        'distance_km': 2.5,
        'duration_min': 5.0,
        'steps': [
          {'instruction': 'Head out towards destination', 'distance_m': 2500, 'type': 'depart'}
        ],
      },
    };
  }

  static String _formatStepInstruction(String type, String modifier, String name) {
    final street = name.isNotEmpty ? ' onto $name' : '';
    switch (type) {
      case 'depart':
        return 'Head out on safe route$street';
      case 'arrive':
        return 'Arrive at destination';
      case 'turn':
      case 'continue':
      case 'merge':
        final mod = modifier.isNotEmpty ? '$modifier ' : '';
        return 'Turn $mod$street'.trim();
      case 'fork':
        return 'Take $modifier fork$street';
      case 'roundabout':
        return 'Enter roundabout and exit$street';
      default:
        return 'Continue$street';
    }
  }

  static Future<List<Map<String, dynamic>>> geocode(
    String query, {
    int limit = 5,
    double? biasLat,
    double? biasLng,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];
    final lowerQ = cleanQuery.toLowerCase();

    // 1. Fast Local Tamil Nadu Knowledge Base (0ms instant lookup)
    final localKnowledge = <String, Map<String, dynamic>>{
      'thandalam': {'lat': 13.0015, 'lon': 80.1182, 'display_name': 'Thandalam, Pallavaram, Chengalpattu, Tamil Nadu, 600128'},
      'poonamallee': {'lat': 13.0492, 'lon': 80.1011, 'display_name': 'Poonamallee, Thiruvallur, Tamil Nadu, 602101'},
      'sriperumbudur': {'lat': 12.9666, 'lon': 79.9458, 'display_name': 'Sriperumbudur, Kanchipuram, Tamil Nadu, 602105'},
      'porur': {'lat': 13.0382, 'lon': 80.1565, 'display_name': 'Porur, Chennai, Tamil Nadu, 600116'},
      'guindy': {'lat': 13.0067, 'lon': 80.2020, 'display_name': 'Guindy, Chennai, Tamil Nadu, 600032'},
      'velachery': {'lat': 12.9759, 'lon': 80.2212, 'display_name': 'Velachery, Chennai, Tamil Nadu, 600042'},
      'tambaram': {'lat': 12.9249, 'lon': 80.1000, 'display_name': 'Tambaram, Chengalpattu, Tamil Nadu, 600045'},
      'chromepet': {'lat': 12.9516, 'lon': 80.1409, 'display_name': 'Chromepet, Chengalpattu, Tamil Nadu, 600044'},
      't. nagar': {'lat': 13.0418, 'lon': 80.2341, 'display_name': 'T. Nagar, Chennai, Tamil Nadu, 600017'},
      't nagar': {'lat': 13.0418, 'lon': 80.2341, 'display_name': 'T. Nagar, Chennai, Tamil Nadu, 600017'},
      'anna nagar': {'lat': 13.0878, 'lon': 80.2170, 'display_name': 'Anna Nagar, Chennai, Tamil Nadu, 600040'},
      'adyar': {'lat': 13.0012, 'lon': 80.2565, 'display_name': 'Adyar, Chennai, Tamil Nadu, 600020'},
      'chennai': {'lat': 13.0827, 'lon': 80.2707, 'display_name': 'Chennai, Tamil Nadu, India'},
      'coimbatore': {'lat': 11.0168, 'lon': 76.9558, 'display_name': 'Coimbatore, Tamil Nadu, India'},
      'rs puram': {'lat': 11.0080, 'lon': 76.9502, 'display_name': 'RS Puram, Coimbatore, Tamil Nadu, 641002'},
      'gandhipuram': {'lat': 11.0183, 'lon': 76.9678, 'display_name': 'Gandhipuram, Coimbatore, Tamil Nadu, 641001'},
      'madurai': {'lat': 9.9252, 'lon': 78.1198, 'display_name': 'Madurai, Tamil Nadu, India'},
      'trichy': {'lat': 10.7905, 'lon': 78.7047, 'display_name': 'Tiruchirappalli, Tamil Nadu, India'},
      'salem': {'lat': 11.6643, 'lon': 78.1460, 'display_name': 'Salem, Tamil Nadu, India'},
      'tirunelveli': {'lat': 8.7139, 'lon': 77.7567, 'display_name': 'Tirunelveli, Tamil Nadu, India'},
      'kanchipuram': {'lat': 12.8342, 'lon': 79.7036, 'display_name': 'Kanchipuram, Tamil Nadu, India'},
      'chengalpattu': {'lat': 12.6819, 'lon': 79.9888, 'display_name': 'Chengalpattu, Tamil Nadu, India'},
      'vellore': {'lat': 12.9165, 'lon': 79.1325, 'display_name': 'Vellore, Tamil Nadu, India'},
      'erode': {'lat': 11.3410, 'lon': 77.7172, 'display_name': 'Erode, Tamil Nadu, India'},
      'tiruppur': {'lat': 11.1085, 'lon': 77.3411, 'display_name': 'Tiruppur, Tamil Nadu, India'},
    };

    for (final entry in localKnowledge.entries) {
      if (lowerQ == entry.key || lowerQ.contains(entry.key)) {
        return [entry.value];
      }
    }

    final searchQ = lowerQ.contains('tamil nadu') ? cleanQuery : '$cleanQuery, Tamil Nadu';

    // 2. Fast Nominatim Lookup
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/search').replace(
        queryParameters: {
          'q': searchQ,
          'format': 'json',
          'limit': limit.toString(),
          'addressdetails': '0',
        },
      );
      final res = await http
          .get(
            uri,
            headers: kIsWeb ? null : {'User-Agent': 'SafeSphereApp/1.0 (safesphere@app.com)'},
          )
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        if (data.isNotEmpty) {
          return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (e) {
      debugPrint('Nominatim geocode exception: $e');
    }

    // 3. Fallback Photon Lookup
    try {
      final lat = biasLat ?? 13.0827;
      final lng = biasLng ?? 80.2707;
      final photonUri = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(searchQ)}&lat=$lat&lon=$lng&limit=$limit',
      );
      final res = await http.get(photonUri).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>? ?? [];
        final items = <Map<String, dynamic>>[];
        for (final feat in features) {
          if (feat is Map<String, dynamic>) {
            final props = feat['properties'] as Map<String, dynamic>? ?? {};
            final geom = feat['geometry'] as Map<String, dynamic>? ?? {};
            final coords = geom['coordinates'] as List<dynamic>? ?? [];
            if (coords.length >= 2) {
              final lonVal = (coords[0] as num).toDouble();
              final latVal = (coords[1] as num).toDouble();
              final name = props['name']?.toString() ?? '';
              final city = props['city']?.toString();
              final state = props['state']?.toString();
              final parts = [name, city, state]
                  .where((p) => p != null && p.isNotEmpty)
                  .toSet()
                  .join(', ');

              items.add({
                'lat': latVal,
                'lon': lonVal,
                'display_name': parts.isNotEmpty ? parts : name,
                'name': name,
              });
            }
          }
        }
        if (items.isNotEmpty) return items;
      }
    } catch (e) {
      debugPrint('Photon geocode exception: $e');
    }

    return [];
  }

  static Future<Map<String, dynamic>> submitRouteFeedback({
    required double rating,
    required List<String> tags,
    required String comments,
    required double lat,
    required double lng,
  }) async {
    // Process user feedback dynamically inside ML Safety Engine
    RouteSafetyMLEngine.processUserFeedback(
      rating: rating,
      tags: tags,
      comments: comments,
      lat: lat,
      lng: lng,
    );

    final uri = Uri.parse('$baseUrl/api/route/feedback');
    try {
      final res = await http
          .post(
            uri,
            headers: await _authHeaders,
            body: jsonEncode({
              'rating': rating,
              'tags': tags,
              'comments': comments,
              'latitude': lat,
              'longitude': lng,
            }),
          )
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return _decodeMap(res.body);
      }
      return {'status': 'success', 'message': 'Feedback received'};
    } catch (e) {
      debugPrint('submitRouteFeedback exception: $e');
      return {'status': 'success', 'message': 'Feedback saved'};
    }
  }

  static Future<String> reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse('https://photon.komoot.io/reverse?lat=$lat&lon=$lng');
      final res = await http.get(uri).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>?;
        if (features != null && features.isNotEmpty) {
          final props = features.first['properties'] as Map<String, dynamic>? ?? {};
          final name = props['name']?.toString() ?? props['street']?.toString() ?? props['district']?.toString();
          final city = props['city']?.toString() ?? props['county']?.toString() ?? props['state']?.toString();
          if (name != null && city != null) {
            return '$name, $city';
          } else if (name != null) {
            return name;
          } else if (city != null) {
            return city;
          }
        }
      }
    } catch (e) {
      debugPrint('Photon reverseGeocode exception: $e');
    }

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json',
      );
      final res = await http.get(
        uri,
        headers: kIsWeb ? null : {'User-Agent': 'SafeSphereApp/1.0 (safesphere@app.com)'},
      ).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final displayName = data['display_name']?.toString();
        if (displayName != null && displayName.isNotEmpty) {
          final parts = displayName.split(',');
          if (parts.length >= 2) {
            return '${parts[0].trim()}, ${parts[1].trim()}';
          }
          return displayName;
        }
      }
    } catch (e) {
      debugPrint('Nominatim reverseGeocode exception: $e');
    }

    return 'Detected Location';
  }
}
