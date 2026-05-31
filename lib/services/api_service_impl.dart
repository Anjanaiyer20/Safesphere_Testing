import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mock_api_service.dart';

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

    print(
      'Getting token (length: ${cleanToken?.length}): ${cleanToken != null ? "${cleanToken.substring(0, 20)}..." : "NULL"}',
    );
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
      if (res.statusCode >= 200 && res.statusCode < 300)
        return _decodeMap(res.body);
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
      if (res.statusCode >= 200 && res.statusCode < 300)
        return _decodeMap(res.body);
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
      if (res.statusCode >= 200 && res.statusCode < 300)
        return _decodeMap(res.body);
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
      if (res.statusCode >= 200 && res.statusCode < 300)
        return _decodeMap(res.body);
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
      if (res.statusCode >= 200 && res.statusCode < 300)
        return _decodeMap(res.body);
      debugPrint('triggerSOS failed: ${res.statusCode} ${res.body}');
      return {
        'error': 'Server error',
        'status': res.statusCode,
        'body': res.body,
      };
    } catch (e) {
      debugPrint('triggerSOS exception: $e');
      return {'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getSOSHistory() async {
    final uri = Uri.parse('$baseUrl/api/sos/history');
    try {
      final res = await http
          .get(uri, headers: await _authHeaders)
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300)
        return _decodeMap(res.body);
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
      if (res.statusCode >= 200 && res.statusCode < 300)
        return _decodeMap(res.body);
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
      if (res.statusCode >= 200 && res.statusCode < 300)
        return _decodeMap(res.body);
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
      if (res.statusCode >= 200 && res.statusCode < 300)
        return _decodeMap(res.body);
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
      if (res.statusCode >= 200 && res.statusCode < 300)
        return _decodeMap(res.body);
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
      if (res.statusCode >= 200 && res.statusCode < 300)
        return _decodeMap(res.body);
      debugPrint('getContacts failed: ${res.statusCode} ${res.body}');
      return {
        'error': 'Server error',
        'status': res.statusCode,
        'body': res.body,
      };
    } catch (e) {
      debugPrint('getContacts exception: $e');
      return {'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteContact(int id) async {
    final uri = Uri.parse('$baseUrl/api/emergency/delete/$id');
    try {
      final res = await http
          .delete(uri, headers: await _authHeaders)
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300)
        return _decodeMap(res.body);
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
      if (res.statusCode >= 200 && res.statusCode < 300)
        return _decodeMap(res.body);
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
      if (res.statusCode >= 200 && res.statusCode < 300)
        return _decodeMap(res.body);
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
      if (res.statusCode >= 200 && res.statusCode < 300)
        return _decodeMap(res.body);
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
      if (res.statusCode >= 200 && res.statusCode < 300)
        return _decodeMap(res.body);
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
    double endLng,
  ) async {
    final uri = Uri.parse('$baseUrl/api/route/safe');
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return {'error': 'Token missing', 'auth_required': true};
    }
    try {
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
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300)
        return _decodeMap(res.body);
      debugPrint('getSafeRoute failed: ${res.statusCode} ${res.body}');
      return {
        'error': 'Server error',
        'status': res.statusCode,
        'body': res.body,
      };
    } catch (e) {
      debugPrint('getSafeRoute exception: $e');
      return {'error': 'Network error: $e'};
    }
  }

  static Future<List<Map<String, dynamic>>> geocode(
    String query, {
    int limit = 5,
  }) async {
    final uri = Uri.parse('https://nominatim.openstreetmap.org/search').replace(
      queryParameters: {
        'q': query,
        'format': 'json',
        'limit': limit.toString(),
        'addressdetails': '0',
      },
    );
    try {
      final res = await http
          .get(
            uri,
            headers: {'User-Agent': 'SafeSphereApp/1.0 (you@example.com)'},
          )
          .timeout(_timeout);
      final data = jsonDecode(res.body) as List<dynamic>;
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('geocode exception: $e');
      return [];
    }
  }
}
