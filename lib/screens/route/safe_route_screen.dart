import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../../services/api_service_impl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/route_map_widget.dart';
import '../../widgets/route_feedback_dialog.dart';

class SafeRouteScreen extends StatefulWidget {
  const SafeRouteScreen({super.key});

  @override
  State<SafeRouteScreen> createState() => _SafeRouteScreenState();
}

class _SafeRouteScreenState extends State<SafeRouteScreen> {
  final _startController = TextEditingController();
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
  final RoutingEngine _selectedEngine = RoutingEngine.osrm;
  int _selectedRouteOptionIndex = 0;

  final List<Map<String, dynamic>> _suggestions = [
    {'name': 'Thandalam', 'lat': 13.0169, 'lng': 80.0054},
    {'name': 'Poonamallee', 'lat': 13.0492, 'lng': 80.1011},
    {'name': 'Sriperumbudur', 'lat': 12.9675, 'lng': 79.9419},
    {'name': 'Porur', 'lat': 13.0382, 'lng': 80.1565},
    {'name': 'Guindy', 'lat': 13.0067, 'lng': 80.2206},
    {'name': 'Velachery', 'lat': 12.9759, 'lng': 80.2212},
    {'name': 'Chromepet', 'lat': 12.9516, 'lng': 80.1462},
    {'name': 'Tambaram', 'lat': 12.9249, 'lng': 80.1000},
    {'name': 'T. Nagar', 'lat': 13.0418, 'lng': 80.2341},
    {'name': 'Gandhipuram', 'lat': 11.0168, 'lng': 76.9558},
    {'name': 'RS Puram', 'lat': 11.0048, 'lng': 76.9603},
    {'name': 'Peelamedu', 'lat': 11.0247, 'lng': 77.0229},
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _startController.dispose();
    _destinationController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ── Location ──────────────────────────────────────────────────────────────

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    setState(() => _isLocationLoading = true);

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
              _currentLat = position.latitude;
              _currentLng = position.longitude;
              _currentPlaceName = reverseName;
              _startController.text = reverseName;
              _isLocationLoading = false;
            });
          }
          return;
        }
      }
    } catch (_) {}

    // Fast IP Geolocation Cascade if native GPS permission denied or unavailable
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
                _currentLat = lat;
                _currentLng = lng;
                _currentPlaceName = reverseName;
                _startController.text = reverseName;
                _isLocationLoading = false;
              });
            }
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
                _currentLat = lat;
                _currentLng = lng;
                _currentPlaceName = reverseName;
                _startController.text = reverseName;
                _isLocationLoading = false;
              });
            }
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
        _currentLat = defaultLat;
        _currentLng = defaultLng;
        _currentPlaceName = reverseName;
        _startController.text = reverseName;
        _isLocationLoading = false;
      });
    }
  }

  void _showChangeStartDialog() {
    final startCtrl = TextEditingController(text: _startController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Change Starting Point', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: startCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter start city or address...',
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final query = startCtrl.text.trim();
              if (query.isNotEmpty) {
                Navigator.pop(ctx);
                setState(() => _isLocationLoading = true);
                try {
                  final results = await ApiService.geocode(query);
                  if (results.isNotEmpty) {
                    final top = results.first;
                    final lat = double.tryParse(top['lat'].toString());
                    final lon = double.tryParse(top['lon'].toString());
                    if (lat != null && lon != null) {
                      setState(() {
                        _currentLat = lat;
                        _currentLng = lon;
                        _currentPlaceName = top['display_name'] ?? query;
                        _startController.text = _currentPlaceName;
                        _isLocationLoading = false;
                      });
                      return;
                    }
                  }
                } catch (_) {}
                setState(() {
                  _startController.text = query;
                  _isLocationLoading = false;
                });
              }
            },
            child: const Text('Set Start'),
          ),
        ],
      ),
    );
  }

  // ── Route Prediction (Geocodes letters to Lat/Lng) ─────────────────────────

  Future<void> _getSafeRoute() async {
    FocusScope.of(context).unfocus();

    final startText = _startController.text.trim().isNotEmpty
        ? _startController.text.trim()
        : _currentPlaceName;
    final destText = _destinationController.text.trim();

    if (destText.isEmpty && _selectedDestLat == null) {
      _showSnackBar('Please enter a destination', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _routeResult = null;
    });

    try {
      // 1. Geocode starting point text/letters into (lat, lng)
      if (startText.isNotEmpty && (startText != _currentPlaceName || _currentLat == null)) {
        try {
          final startResults = await ApiService.geocode(
            startText,
            biasLat: _currentLat,
            biasLng: _currentLng,
          );
          if (startResults.isNotEmpty) {
            final topStart = startResults.first;
            final lat = double.tryParse(topStart['lat'].toString());
            final lon = double.tryParse(topStart['lon'].toString());
            if (lat != null && lon != null) {
              _currentLat = lat;
              _currentLng = lon;
              _currentPlaceName = topStart['display_name'] ?? startText;
            }
          }
        } catch (_) {}
      }

      // 2. Geocode destination point text/letters into (lat, lng)
      if (destText.isNotEmpty && _selectedDestLat == null) {
        try {
          final destResults = await ApiService.geocode(
            destText,
            biasLat: _currentLat,
            biasLng: _currentLng,
          );
          if (destResults.isNotEmpty) {
            final topDest = destResults.first;
            final lat = double.tryParse(topDest['lat'].toString());
            final lon = double.tryParse(topDest['lon'].toString());
            if (lat != null && lon != null) {
              _selectedDestLat = lat;
              _selectedDestLng = lon;
              _destinationController.text = topDest['display_name'] ?? destText;
            }
          }
        } catch (_) {}
      }

      // Fallbacks if coordinates still null
      final startLat = _currentLat ?? 11.0168;
      final startLng = _currentLng ?? 76.9558;
      final endLat = _selectedDestLat ?? (startLat + 0.012);
      final endLng = _selectedDestLng ?? (startLng + 0.008);

      final response = await ApiService.getSafeRoute(
        startLat,
        startLng,
        endLat,
        endLng,
        engine: _selectedEngine,
      );

      if (response.containsKey('error') && response['route'] == null) {
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onDestinationReached() {
    if (!mounted) return;
    setState(() => _navigating = false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RouteFeedbackDialog(
        destinationName: _destinationController.text.isNotEmpty
            ? _destinationController.text
            : 'Destination',
        endLat: _selectedDestLat ?? 0.0,
        endLng: _selectedDestLng ?? 0.0,
        onSubmitted: () {
          setState(() {
            _remainingMeters = null;
            _etaSeconds = null;
          });
        },
      ),
    );
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

    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await ApiService.geocode(
          value.trim(),
          biasLat: _currentLat,
          biasLng: _currentLng,
        );
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
            const SizedBox(height: 16),
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
            onPressed: _showChangeStartDialog,
            icon: const Icon(
              Icons.edit_location_alt,
              color: AppTheme.primaryLight,
              size: 20,
            ),
            tooltip: 'Change starting location',
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
    if (_routeResult == null) return const SizedBox.shrink();
    final safety = _routeResult!['safety'] as Map<String, dynamic>? ?? {};
    final route = _routeResult!['route'] as Map<String, dynamic>? ?? {};
    final level = safety['level'] as String? ?? 'Safe';
    final score = safety['score'] as int? ?? 90;
    final dangerZones = safety['danger_zones'] as List<dynamic>? ?? [];

    final engineName = _routeResult!['engine'] as String? ?? 'Auto Routing';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: AppTheme.divider),
        const SizedBox(height: 12),
        // Route Options Selector if multiple routes exist
        if (_routeResult!.containsKey('route_options')) ...[
          const Text(
            'Route Selection:',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: (_routeResult!['route_options'] as List<dynamic>).asMap().entries.map((entry) {
                final idx = entry.key;
                final opt = entry.value as Map<String, dynamic>;
                final title = opt['title'] as String;
                final isSelected = idx == _selectedRouteOptionIndex;
                final routeData = opt['route_data'] as Map<String, dynamic>;
                final routeSafety = routeData['safety'] as Map<String, dynamic>? ?? {};
                final routeScore = routeSafety['score'] ?? 0;

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(
                      '$title ($routeScore% Safe)',
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: (opt['is_recommended'] == true)
                        ? AppTheme.success.withAlpha((0.75 * 255).round())
                        : AppTheme.primary,
                    backgroundColor: AppTheme.card,
                    side: BorderSide(
                      color: isSelected
                          ? (opt['is_recommended'] == true ? AppTheme.success : AppTheme.primaryLight)
                          : AppTheme.divider,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedRouteOptionIndex = idx;
                          _routeResult!['route'] = routeData['route'];
                          _routeResult!['safety'] = routeData['safety'];
                          _routeResult!['engine'] = routeData['engine'];
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Engine badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primary.withAlpha((0.15 * 255).round()),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryLight.withAlpha((0.3 * 255).round()),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.alt_route, size: 14, color: AppTheme.primaryLight),
              const SizedBox(width: 6),
              Text(
                'Engine: $engineName',
                style: const TextStyle(
                  color: AppTheme.primaryLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Map
        RouteMapWidget(
          startLat: _currentLat ?? 11.0168,
          startLng: _currentLng ?? 76.9558,
          endLat: _selectedDestLat ?? ((_currentLat ?? 11.0168) + 0.012),
          endLng: _selectedDestLng ?? ((_currentLng ?? 76.9558) + 0.008),
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
          onDestinationReached: _onDestinationReached,
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

        // ML Model Safety Insights Card
        if (safety.containsKey('ml_insights')) _buildMLInsightsCard(safety['ml_insights'] as Map<String, dynamic>),
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

        const SizedBox(height: 20),

        // Turn-by-Turn Directions (Google Maps Style)
        if (route['steps'] is List && (route['steps'] as List).isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.alt_route, color: AppTheme.primaryLight, size: 20),
              SizedBox(width: 8),
              Text(
                'Turn-by-Turn Directions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.divider),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: (route['steps'] as List).length,
              separatorBuilder: (_, __) => const Divider(color: AppTheme.divider, height: 1),
              itemBuilder: (context, index) {
                final step = (route['steps'] as List)[index] as Map<String, dynamic>;
                final instruction = step['instruction'] as String? ?? '';
                final distM = (step['distance_m'] as num?)?.toInt() ?? 0;
                final type = step['type'] as String? ?? '';

                IconData stepIcon = Icons.navigation;
                if (type == 'arrive') {
                  stepIcon = Icons.flag;
                } else if (type == 'turn') {
                  stepIcon = Icons.call_made;
                } else if (type == 'depart') {
                  stepIcon = Icons.my_location;
                }

                return ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: type == 'arrive'
                          ? AppTheme.sosRed.withAlpha(50)
                          : AppTheme.primary.withAlpha(40),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      stepIcon,
                      color: type == 'arrive' ? AppTheme.sosRed : AppTheme.primaryLight,
                      size: 16,
                    ),
                  ),
                  title: Text(
                    instruction,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  trailing: Text(
                    distM > 0
                        ? (distM >= 1000 ? '${(distM / 1000).toStringAsFixed(1)} km' : '$distM m')
                        : '',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                );
              },
            ),
          ),
        ],
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

  Widget _buildMLInsightsCard(Map<String, dynamic> ml) {
    final modelName = ml['model_name'] ?? 'Ensemble XGBoost & Naive Bayes NLP';
    final feedbackCount = ml['feedback_count'] ?? 0;
    final totalFeedbacks = ml['total_store_feedbacks'] ?? 0;
    final sentiment = ml['sentiment_score'] ?? '0.00';
    final confidence = ml['confidence_score'] ?? '0.80';
    final nightPenalty = ml['night_penalty_applied'] == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryLight.withAlpha((0.3 * 255).round())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: AppTheme.primaryLight, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ML Prediction: $modelName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.success.withAlpha((0.2 * 255).round()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Conf: ${(double.parse(confidence.toString()) * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: AppTheme.success,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _mlMetricChip(
                Icons.people_alt_outlined,
                '$feedbackCount nearby ($totalFeedbacks total)',
                'User Feedback',
              ),
              _mlMetricChip(
                Icons.sentiment_satisfied_alt_outlined,
                sentiment.toString(),
                'NLP Sentiment',
              ),
              if (nightPenalty)
                _mlMetricChip(
                  Icons.nightlight_round,
                  '-8% Night penalty',
                  'Time of Day',
                  color: AppTheme.warning,
                ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _mlMetricChip(IconData icon, String val, String label, {Color color = AppTheme.primaryLight}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        Text(
          val,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
