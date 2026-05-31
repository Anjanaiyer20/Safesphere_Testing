import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://safesphere-backend-l14i.onrender.com';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final cleanToken = token?.trim().replaceAll('\n', '').replaceAll('\r', '');
    print(
      'Getting token: ${cleanToken != null ? "${cleanToken.substring(0, 20)}..." : "NULL"}',
    );
    return cleanToken;
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanToken = token.trim().replaceAll('\n', '').replaceAll('\r', '');
    await prefs.setString('jwt_token', cleanToken);
    print('Token saved: ${cleanToken.substring(0, 20)}...');
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    print('Token cleared');
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
  };

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      print('WARNING: No token found for authenticated request!');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token ?? ''}',
    };
  }

  static Future<Map<String, dynamic>> _handleResponse(
    http.Response response,
  ) async {
    print('Response ${response.statusCode}: ${response.body}');
    if (response.body.isEmpty) {
      return {'error': 'Empty response from server'};
    }
    try {
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': 'Invalid response: ${response.body}'};
    }
  }

  // AUTH
  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String phone,
    String password,
    String confirmPassword,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/auth/register'),
            headers: _headers,
            body: jsonEncode({
              'name': name,
              'email': email,
              'phone': phone,
              'password': password,
              'confirm_password': confirmPassword,
            }),
          )
          .timeout(const Duration(seconds: 60));
      return _handleResponse(response);
    } catch (e) {
      print('register failed: $e');
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/auth/login'),
            headers: _headers,
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 60));
      final data = await _handleResponse(response);

      // ✅ Extract token from all possible keys
      final token =
          data['token'] ??
          data['access_token'] ??
          data['data']?['token'] ??
          data['data']?['access_token'];

      if (token != null && token is String && token.isNotEmpty) {
        await saveToken(token); // cleaned inside saveToken
        print('Token saved after login!');
      } else {
        print(
          'WARNING: No token found in login response. Keys: ${data.keys.toList()}',
        );
      }

      return data;
    } catch (e) {
      print('login failed: $e');
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/auth/forgot-password'),
            headers: _headers,
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 60));
      return _handleResponse(response);
    } catch (e) {
      print('forgotPassword failed: $e');
      return {'error': e.toString()};
    }
  }

  // PROFILE
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/api/profile/get'), headers: headers)
          .timeout(const Duration(seconds: 60));
      return _handleResponse(response);
    } catch (e) {
      print('getProfile failed: $e');
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateProfile(
    String name,
    String phone,
  ) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .put(
            Uri.parse('$baseUrl/api/profile/update'),
            headers: headers,
            body: jsonEncode({'name': name, 'phone': phone}),
          )
          .timeout(const Duration(seconds: 60));
      return _handleResponse(response);
    } catch (e) {
      print('updateProfile failed: $e');
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> changePassword(
    String oldPassword,
    String newPassword,
  ) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .put(
            Uri.parse('$baseUrl/api/profile/change-password'),
            headers: headers,
            body: jsonEncode({
              'old_password': oldPassword,
              'new_password': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 60));
      return _handleResponse(response);
    } catch (e) {
      print('changePassword failed: $e');
      return {'error': e.toString()};
    }
  }

  // SOS
  static Future<Map<String, dynamic>> triggerSOS(
    double latitude,
    double longitude,
  ) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/sos/trigger'),
            headers: headers,
            body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
          )
          .timeout(const Duration(seconds: 60));
      return _handleResponse(response);
    } catch (e) {
      print('triggerSOS failed: $e');
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getSOSHistory() async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/api/sos/history'), headers: headers)
          .timeout(const Duration(seconds: 60));
      return _handleResponse(response);
    } catch (e) {
      print('getSOSHistory failed: $e');
      return {'error': e.toString()};
    }
  }

  // LOCATION
  static Future<Map<String, dynamic>> updateLocation(
    double latitude,
    double longitude,
  ) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/location/update'),
            headers: headers,
            body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
          )
          .timeout(const Duration(seconds: 60));
      return _handleResponse(response);
    } catch (e) {
      print('updateLocation failed: $e');
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getLocationHistory() async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/api/location/history'), headers: headers)
          .timeout(const Duration(seconds: 60));
      return _handleResponse(response);
    } catch (e) {
      print('getLocationHistory failed: $e');
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getLatestLocation() async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/api/location/latest'), headers: headers)
          .timeout(const Duration(seconds: 60));
      return _handleResponse(response);
    } catch (e) {
      print('getLatestLocation failed: $e');
      return {'error': e.toString()};
    }
  }

  // EMERGENCY CONTACTS
  static Future<Map<String, dynamic>> addContact(
    String name,
    String phone,
  ) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/emergency/add'),
            headers: headers,
            body: jsonEncode({'name': name, 'phone': phone}),
          )
          .timeout(const Duration(seconds: 60));
      return _handleResponse(response);
    } catch (e) {
      print('addContact failed: $e');
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getContacts() async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/api/emergency/list'), headers: headers)
          .timeout(const Duration(seconds: 60));
      return _handleResponse(response);
    } catch (e) {
      print('getContacts failed: $e');
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteContact(int id) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .delete(
            Uri.parse('$baseUrl/api/emergency/delete/$id'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 60));
      return _handleResponse(response);
    } catch (e) {
      print('deleteContact failed: $e');
      return {'error': e.toString()};
    }
  }

  // INCIDENTS
  static Future<Map<String, dynamic>> reportIncident(
    String incidentType,
    String description,
    double latitude,
    double longitude,
  ) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/incident/report'),
            headers: headers,
            body: jsonEncode({
              'incident_type': incidentType,
              'description': description,
              'latitude': latitude,
              'longitude': longitude,
            }),
          )
          .timeout(const Duration(seconds: 60));
      return _handleResponse(response);
    } catch (e) {
      print('reportIncident failed: $e');
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getAllIncidents() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/incident/all'), headers: _headers)
          .timeout(const Duration(seconds: 60));
      return _handleResponse(response);
    } catch (e) {
      print('getAllIncidents failed: $e');
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getMyIncidents() async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/api/incident/mine'), headers: headers)
          .timeout(const Duration(seconds: 60));
      return _handleResponse(response);
    } catch (e) {
      print('getMyIncidents failed: $e');
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteIncident(int id) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .delete(
            Uri.parse('$baseUrl/api/incident/delete/$id'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 60));
      return _handleResponse(response);
    } catch (e) {
      print('deleteIncident failed: $e');
      return {'error': e.toString()};
    }
  }

  // SAFE ROUTE
  static Future<Map<String, dynamic>> getSafeRoute(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/route/safe'),
            headers: headers,
            body: jsonEncode({
              'start_lat': startLat,
              'start_lng': startLng,
              'end_lat': endLat,
              'end_lng': endLng,
            }),
          )
          .timeout(const Duration(seconds: 60));
      return _handleResponse(response);
    } catch (e) {
      print('getSafeRoute failed: $e');
      return {'error': e.toString()};
    }
  }
}
