import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../services/api_service_impl.dart';
import '../../theme/app_theme.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  bool _isLoading = false;
  String _placeName = 'Detecting location...';
  double? _latitude;
  double? _longitude;
  List<dynamic> _history = [];
  bool _historyLoading = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadHistory();
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission().catchError((_) => LocationPermission.denied);
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission().catchError((_) => LocationPermission.denied);
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 4),
        ).catchError((_) => null);

        if (position != null) {
          final reverseName = await ApiService.reverseGeocode(
            position.latitude,
            position.longitude,
          );
          if (mounted) {
            setState(() {
              _latitude = position.latitude;
              _longitude = position.longitude;
              _placeName = reverseName;
              _isLoading = false;
            });
          }
          _loadHistory();
          return;
        }
      }
    } catch (_) {}

    await _fetchIpLocation();
  }

  Future<void> _fetchIpLocation() async {
    // 1. Try ipwho.is (HTTPS, fast, unthrottled)
    try {
      final res = await http
          .get(Uri.parse('https://ipwho.is/'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final lat = (data['latitude'] as num?)?.toDouble();
          final lng = (data['longitude'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            final reverseName = await ApiService.reverseGeocode(lat, lng);
            if (mounted) {
              setState(() {
                _latitude = lat;
                _longitude = lng;
                _placeName = reverseName;
                _isLoading = false;
              });
            }
            _loadHistory();
            return;
          }
        }
      }
    } catch (_) {}

    // 2. Fallback to ipinfo.io (HTTPS)
    try {
      final res = await http
          .get(Uri.parse('https://ipinfo.io/json'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final loc = data['loc']?.toString();
        if (loc != null && loc.contains(',')) {
          final parts = loc.split(',');
          final lat = double.tryParse(parts[0].trim());
          final lng = double.tryParse(parts[1].trim());
          if (lat != null && lng != null) {
            final reverseName = await ApiService.reverseGeocode(lat, lng);
            if (mounted) {
              setState(() {
                _latitude = lat;
                _longitude = lng;
                _placeName = reverseName;
                _isLoading = false;
              });
            }
            _loadHistory();
            return;
          }
        }
      }
    } catch (_) {}

    _setDefaultLocation();
  }

  void _setDefaultLocation() async {
    if (!mounted) return;
    const defaultLat = 13.0827; // Chennai
    const defaultLng = 80.2707;
    final reverseName = await ApiService.reverseGeocode(defaultLat, defaultLng);
    if (mounted) {
      setState(() {
        _latitude = defaultLat;
        _longitude = defaultLng;
        _placeName = reverseName;
        _isLoading = false;
      });
    }
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    setState(() => _historyLoading = true);
    try {
      final response = await ApiService.getLocationHistory();
      if (!mounted) return;
      setState(() {
        _history = response['locations'] ?? [];
        _historyLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _historyLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Live Location'),
        backgroundColor: AppTheme.surface,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _getCurrentLocation,
            icon: const Icon(Icons.refresh, color: AppTheme.primaryLight),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Location Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withAlpha((0.4 * 255).round()),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.location_on, color: Colors.white, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Current Location',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _placeName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                  if (_latitude != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Lat: ${_latitude!.toStringAsFixed(4)}, Lng: ${_longitude!.toStringAsFixed(4)}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ).animate().fadeIn().scale(),
            const SizedBox(height: 24),

            // Update Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _getCurrentLocation,
              icon: const Icon(Icons.my_location),
              label: const Text('Update My Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 32),

            // Location History
            const Text(
              'Location History',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 16),

            _historyLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : _history.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: const Center(
                      child: Text(
                        'No location history yet',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final loc = _history[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.primary.withAlpha(
                                  (0.2 * 255).round(),
                                ),
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: AppTheme.primaryLight,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loc['place_name'] ?? 'Unknown location',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    loc['timestamp']?.toString().substring(
                                          0,
                                          16,
                                        ) ??
                                        '',
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(
                        delay: Duration(milliseconds: index * 100),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
