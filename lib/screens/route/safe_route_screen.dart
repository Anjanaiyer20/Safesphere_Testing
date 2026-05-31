import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../services/api_service_impl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/route_map_widget.dart';

class SafeRouteScreen extends StatefulWidget {
  const SafeRouteScreen({super.key});

  @override
  State<SafeRouteScreen> createState() => _SafeRouteScreenState();
}

class _SafeRouteScreenState extends State<SafeRouteScreen> {
  final _destinationController = TextEditingController();
  bool _isLoading = false;
  bool _isLocationLoading = true;
  Map<String, dynamic>? _routeResult;
  bool _navigating = false;
  double? _remainingMeters;
  int? _etaSeconds;
  double? _currentLat;
  double? _currentLng;
  String _currentPlaceName = 'Detecting your location...';
  double? _selectedDestLat;
  double? _selectedDestLng;
  List<Map<String, dynamic>> _remoteSuggestions = [];
  bool _isSearching = false;
  Timer? _searchDebounce;

  final List<Map<String, dynamic>> _suggestions = [
    {'name': 'Gandhipuram', 'lat': 11.0168, 'lng': 76.9558},
    {'name': 'RS Puram', 'lat': 11.0048, 'lng': 76.9603},
    {'name': 'Peelamedu', 'lat': 11.0247, 'lng': 77.0229},
    {'name': 'Saibaba Colony', 'lat': 11.0209, 'lng': 76.9629},
    {'name': 'Singanallur', 'lat': 10.9930, 'lng': 77.0156},
    {'name': 'Ukkadam', 'lat': 10.9905, 'lng': 76.9695},
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ── Location ──────────────────────────────────────────────────────────────

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocationLoading = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        _setDefaultLocation();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final locResponse = await ApiService.updateLocation(
        position.latitude,
        position.longitude,
      );

      setState(() {
        _currentLat = position.latitude;
        _currentLng = position.longitude;
        _currentPlaceName =
            locResponse['location']?['place_name'] ?? 'Your current location';
        _isLocationLoading = false;
      });
    } catch (_) {
      _setDefaultLocation();
    }
  }

  void _setDefaultLocation() {
    setState(() {
      _currentLat = 11.0168;
      _currentLng = 76.9558;
      _currentPlaceName = 'Coimbatore (default)';
      _isLocationLoading = false;
    });
  }

  // ── Route ─────────────────────────────────────────────────────────────────

  Future<void> _getSafeRoute() async {
    if (_currentLat == null) {
      _showSnackBar('Getting your location...', isError: true);
      return;
    }
    if (_selectedDestLat == null) {
      _showSnackBar('Please select a destination', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _routeResult = null;
    });

    try {
      final response = await ApiService.getSafeRoute(
        _currentLat!,
        _currentLng!,
        _selectedDestLat!,
        _selectedDestLng!,
      );

      if (response.containsKey('error')) {
        _showSnackBar(
          response['error'] ?? 'Failed to get route',
          isError: true,
        );
      } else {
        setState(() => _routeResult = response);
      }
    } catch (_) {
      _showSnackBar('Network error. Please try again.', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Search ────────────────────────────────────────────────────────────────

  void _onSearchChanged(String value) {
    if (_selectedDestLat != null) {
      setState(() {
        _selectedDestLat = null;
        _selectedDestLng = null;
      });
    }

    _searchDebounce?.cancel();

    if (value.trim().length < 3) {
      setState(() {
        _remoteSuggestions = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final results = await ApiService.geocode(value.trim());
        if (mounted) {
          setState(() {
            _remoteSuggestions = results.cast<Map<String, dynamic>>();
            _isSearching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  void _selectDestination(double lat, double lng, String name) {
    setState(() {
      _selectedDestLat = lat;
      _selectedDestLng = lng;
      _destinationController.text = name;
      _remoteSuggestions = [];
      _isSearching = false;
    });
    _getSafeRoute();
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.sosRed : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Color _safetyColor(String level) {
    switch (level) {
      case 'Safe':
        return AppTheme.success;
      case 'Moderate':
        return AppTheme.warning;
      case 'Dangerous':
        return AppTheme.sosRed;
      default:
        return AppTheme.primaryLight;
    }
  }

  IconData _safetyIcon(String level) {
    switch (level) {
      case 'Safe':
        return Icons.check_circle;
      case 'Moderate':
        return Icons.warning_amber_rounded;
      case 'Dangerous':
        return Icons.dangerous;
      default:
        return Icons.help_outline;
    }
  }

  String _formatEta(int seconds) {
    final d = Duration(seconds: seconds);
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60).toString().padLeft(2, '0')}m';
    }
    return '${d.inMinutes} min';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Safe Route'),
        backgroundColor: AppTheme.surface,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLocationCard(),
            const SizedBox(height: 8),
            const Center(
              child: Icon(
                Icons.arrow_downward,
                color: AppTheme.primaryLight,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            _buildSearchField(),
            const SizedBox(height: 8),
            _buildSuggestionsList(),
            const SizedBox(height: 16),
            _buildPopularDestinations(),
            const SizedBox(height: 24),
            _buildGetRouteButton(),
            const SizedBox(height: 24),
            if (_routeResult != null) _buildRouteResult(),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primary.withAlpha((0.4 * 255).round()),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary.withAlpha((0.2 * 255).round()),
            ),
            child: const Icon(
              Icons.my_location,
              color: AppTheme.primaryLight,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Location',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                _isLocationLoading
                    ? const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryLight,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _currentPlaceName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
              ],
            ),
          ),
          IconButton(
            onPressed: _getCurrentLocation,
            icon: const Icon(
              Icons.refresh,
              color: AppTheme.primaryLight,
              size: 20,
            ),
            tooltip: 'Refresh location',
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: TextField(
        controller: _destinationController,
        style: const TextStyle(color: Colors.white),
        onChanged: _onSearchChanged,
        decoration: const InputDecoration(
          labelText: 'Where do you want to go?',
          prefixIcon: Icon(Icons.location_searching, color: AppTheme.sosRed),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildSuggestionsList() {
    final localMatches = _suggestions
        .where(
          (p) => p['name'].toString().toLowerCase().contains(
            _destinationController.text.toLowerCase(),
          ),
        )
        .toList();

    if (_destinationController.text.isEmpty &&
        !_isSearching &&
        _remoteSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          ...localMatches.map(
            (place) => ListTile(
              dense: true,
              leading: const Icon(
                Icons.location_on_outlined,
                color: AppTheme.primaryLight,
              ),
              title: Text(
                place['name'],
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () => _selectDestination(
                place['lat'] as double,
                place['lng'] as double,
                place['name'] as String,
              ),
            ),
          ),
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  color: AppTheme.primary,
                  strokeWidth: 2,
                ),
              ),
            ),
          ..._remoteSuggestions.map((r) {
            final label = r['display_name'] ?? r['name'] ?? '';
            final lat = double.tryParse(r['lat']?.toString() ?? '') ?? 0.0;
            final lon = double.tryParse(r['lon']?.toString() ?? '') ?? 0.0;
            return ListTile(
              dense: true,
              leading: const Icon(Icons.place, color: AppTheme.primaryLight),
              title: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _selectDestination(lat, lon, label),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPopularDestinations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Popular Destinations',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestions.map((place) {
            final isSelected =
                _selectedDestLat == place['lat'] &&
                _selectedDestLng == place['lng'];
            return GestureDetector(
              onTap: () => _selectDestination(
                place['lat'] as double,
                place['lng'] as double,
                place['name'] as String,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : AppTheme.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : AppTheme.divider,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.location_on_outlined,
                      color: isSelected ? Colors.white : AppTheme.primaryLight,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      place['name'],
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildGetRouteButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _getSafeRoute,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: _isLoading
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Checking Safety...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  'Check Route Safety',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildRouteResult() {
    final safety = _routeResult!['safety'] as Map<String, dynamic>? ?? {};
    final route = _routeResult!['route'] as Map<String, dynamic>? ?? {};
    final level = safety['level'] as String? ?? '';
    final score = safety['score'] as int? ?? 0;
    final dangerZones = safety['danger_zones'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: AppTheme.divider),
        const SizedBox(height: 16),

        // Map
        RouteMapWidget(
          startLat: _currentLat!,
          startLng: _currentLng!,
          endLat: _selectedDestLat!,
          endLng: _selectedDestLng!,
          startLabel: _currentPlaceName,
          endLabel: _destinationController.text,
          routeData: _routeResult,
          startNavigation: _navigating,
          onNavigationUpdate: (m) {
            setState(() {
              _remainingMeters = (m['remaining_m'] as num?)?.toDouble();
              _etaSeconds = (m['eta_s'] as num?)?.toInt();
            });
          },
        ).animate().fadeIn(delay: 50.ms),
        const SizedBox(height: 12),

        // Navigation controls
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _navigating = !_navigating),
                icon: Icon(_navigating ? Icons.stop : Icons.navigation),
                label: Text(
                  _navigating ? 'Stop Navigation' : 'Start Navigation',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navigating
                      ? AppTheme.sosRed
                      : AppTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Remaining / ETA
        if (_remainingMeters != null && _etaSeconds != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Remaining: ${(_remainingMeters! / 1000).toStringAsFixed(2)} km',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              Text(
                'ETA: ${_formatEta(_etaSeconds!)}',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ).animate().fadeIn(),
        const SizedBox(height: 16),

        // Safety score card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _safetyColor(level).withAlpha((0.6 * 255).round()),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(_safetyIcon(level), color: _safetyColor(level), size: 48),
              const SizedBox(height: 12),
              Text(
                level,
                style: TextStyle(
                  color: _safetyColor(level),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Safety Score: $score / 100',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: score / 100,
                  backgroundColor: AppTheme.divider,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _safetyColor(level),
                  ),
                  minHeight: 12,
                ),
              ),
            ],
          ),
        ).animate().fadeIn().scale(),
        const SizedBox(height: 16),

        // Stats row
        Row(
          children: [
            Expanded(
              child: _statCard(
                Icons.straighten,
                '${route['distance_km'] ?? 0} km',
                'Distance',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                Icons.timer_outlined,
                '${(route['duration_min'] ?? 0).toStringAsFixed(0)} min',
                'Duration',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                Icons.warning_amber_rounded,
                '${safety['total_incidents'] ?? 0}',
                'Incidents',
                color: AppTheme.warning,
              ),
            ),
          ],
        ).animate().fadeIn(delay: 100.ms),
        const SizedBox(height: 16),

        // Danger zones or safe message
        if (dangerZones.isNotEmpty) ...[
          const Text(
            'Danger Zones',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...dangerZones.map(
            (zone) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.sosRed.withAlpha((0.3 * 255).round()),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.sosRed,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zone['incident_type'] ?? '',
                          style: const TextStyle(
                            color: AppTheme.sosRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          zone['description'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.success.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.success.withAlpha((0.3 * 255).round()),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.success),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This route is safe! No incidents reported nearby.',
                    style: TextStyle(color: AppTheme.success, fontSize: 14),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _statCard(
    IconData icon,
    String value,
    String label, {
    Color color = AppTheme.primaryLight,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
