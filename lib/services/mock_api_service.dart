import 'dart:async';

/// Mock API Service for development/testing when backend is unavailable.
/// Toggle USE_MOCK_API in ApiService to enable.
class MockApiService {
  static const _delay = Duration(milliseconds: 800);

  // Mock user for testing
  static const _mockUser = {
    'id': 1,
    'name': 'Test User',
    'email': 'test@example.com',
    'phone': '+91 9876543210',
    'created_at': '2025-01-15T10:30:00Z',
  };

  static const _mockToken = 'mock_jwt_token_12345_dev';

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    await Future.delayed(_delay);
    if (email.isEmpty || password.isEmpty) {
      return {'error': 'Email and password required'};
    }
    return {'token': _mockToken, 'user': _mockUser};
  }

  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String phone,
    String password,
    String confirmPassword,
  ) async {
    await Future.delayed(_delay);
    if (password != confirmPassword) {
      return {'error': 'Passwords do not match'};
    }
    return {
      'message': 'Registration successful',
      'token': _mockToken,
      'user': {..._mockUser, 'name': name, 'email': email, 'phone': phone},
    };
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    await Future.delayed(_delay);
    return {'message': 'Password reset link sent to $email'};
  }

  static Future<Map<String, dynamic>> getProfile() async {
    await Future.delayed(_delay);
    return _mockUser;
  }

  static Future<Map<String, dynamic>> updateProfile(
    String name,
    String phone,
  ) async {
    await Future.delayed(_delay);
    return {
      'message': 'Profile updated',
      'user': {..._mockUser, 'name': name, 'phone': phone},
    };
  }

  static Future<Map<String, dynamic>> changePassword(
    String oldPassword,
    String newPassword,
  ) async {
    await Future.delayed(_delay);
    return {'message': 'Password changed successfully'};
  }

  static Future<Map<String, dynamic>> triggerSOS(
    double latitude,
    double longitude,
  ) async {
    await Future.delayed(_delay);
    return {
      'message': 'SOS triggered',
      'sos_id': 'sos_${DateTime.now().millisecondsSinceEpoch}',
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  static Future<Map<String, dynamic>> getSOSHistory() async {
    await Future.delayed(_delay);
    return {
      'sos_history': [
        {
          'id': 1,
          'status': 'RESOLVED',
          'place_name': 'Gandhipuram, Coimbatore',
          'created_at': '2025-01-10T15:30:00Z',
        },
      ],
    };
  }

  static Future<Map<String, dynamic>> updateLocation(
    double latitude,
    double longitude,
  ) async {
    await Future.delayed(_delay);
    return {
      'message': 'Location updated',
      'location': {
        'latitude': latitude,
        'longitude': longitude,
        'place_name': 'Test Location',
      },
    };
  }

  static Future<Map<String, dynamic>> getLocationHistory() async {
    await Future.delayed(_delay);
    return {
      'locations': [
        {
          'place_name': 'Home',
          'latitude': 11.0168,
          'longitude': 76.9558,
          'timestamp': DateTime.now().toIso8601String(),
        },
        {
          'place_name': 'Work',
          'latitude': 11.0048,
          'longitude': 76.9603,
          'timestamp': DateTime.now()
              .subtract(const Duration(hours: 2))
              .toIso8601String(),
        },
      ],
    };
  }

  static Future<Map<String, dynamic>> getLatestLocation() async {
    await Future.delayed(_delay);
    return {
      'location': {
        'latitude': 11.0168,
        'longitude': 76.9558,
        'place_name': 'Current Location',
      },
    };
  }

  static Future<Map<String, dynamic>> addContact(
    String name,
    String phone,
  ) async {
    await Future.delayed(_delay);
    return {
      'message': 'Contact added',
      'contact': {'id': 1, 'name': name, 'phone': phone},
    };
  }

  static Future<Map<String, dynamic>> getContacts() async {
    await Future.delayed(_delay);
    return {
      'contacts': [
        {'id': 1, 'name': 'Mom', 'phone': '+91 9123456789'},
        {'id': 2, 'name': 'Sister', 'phone': '+91 9987654321'},
      ],
    };
  }

  static Future<Map<String, dynamic>> deleteContact(int id) async {
    await Future.delayed(_delay);
    return {'message': 'Contact deleted'};
  }

  static Future<Map<String, dynamic>> reportIncident(
    String incidentType,
    String description,
    double latitude,
    double longitude,
  ) async {
    await Future.delayed(_delay);
    return {
      'message': 'Incident reported',
      'incident': {
        'id': DateTime.now().millisecondsSinceEpoch,
        'incident_type': incidentType,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'created_at': DateTime.now().toIso8601String(),
      },
    };
  }

  static Future<Map<String, dynamic>> getAllIncidents() async {
    await Future.delayed(_delay);
    return {
      'incidents': [
        {
          'id': 1,
          'incident_type': 'Harassment',
          'description': 'Unwanted verbal harassment',
          'latitude': 11.0168,
          'longitude': 76.9558,
          'created_at': '2025-01-10T14:20:00Z',
        },
        {
          'id': 2,
          'incident_type': 'Theft',
          'description': 'Theft attempt near main road',
          'latitude': 11.0200,
          'longitude': 76.9600,
          'created_at': '2025-01-09T10:15:00Z',
        },
      ],
    };
  }

  static Future<Map<String, dynamic>> getMyIncidents() async {
    await Future.delayed(_delay);
    return {'incidents': []};
  }

  static Future<Map<String, dynamic>> deleteIncident(int id) async {
    await Future.delayed(_delay);
    return {'message': 'Incident deleted'};
  }

  static Future<Map<String, dynamic>> getSafeRoute(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    await Future.delayed(_delay);
    return {
      'safety': {
        'level': 'Safe',
        'score': 85,
        'total_incidents': 1,
        'danger_zones': [],
      },
      'route': {
        'distance_km': 5.2,
        'duration_min': 12,
        // Provide a simple geometry (list of [lat, lng]) so the map can draw real route points
        'geometry': [
          [11.0168, 76.9558],
          [11.0185, 76.9585],
          [11.0205, 76.9610],
          [11.0240, 76.9660],
          [11.0280, 76.9730],
          [11.0300, 76.9800],
        ],
        // Keep polyline key for compatibility (optional)
        'polyline': '',
      },
    };
  }
}
