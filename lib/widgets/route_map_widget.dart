import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';

/// An open-source OpenStreetMap-powered route widget for SafeSphere's Safe Route Prediction.
class RouteMapWidget extends StatefulWidget {
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;
  final String? startLabel;
  final String? endLabel;
  final Map<String, dynamic>? routeData;
  final bool startNavigation;
  final void Function(Map<String, dynamic>)? onNavigationUpdate;
  final VoidCallback? onDestinationReached;

  const RouteMapWidget({
    super.key,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
    this.startLabel,
    this.endLabel,
    this.routeData,
    this.startNavigation = false,
    this.onNavigationUpdate,
    this.onDestinationReached,
  });

  @override
  State<RouteMapWidget> createState() => _RouteMapWidgetState();
}

class _RouteMapWidgetState extends State<RouteMapWidget> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionSub;
  Timer? _simTimer;
  int _simIndex = 0;
  LatLng? _userPosition;
  List<LatLng> _routePoints = [];
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _routePoints = _decodeGeometry();
    if (widget.startNavigation) {
      _startNavigation();
    }
  }

  @override
  void didUpdateWidget(covariant RouteMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.routeData != oldWidget.routeData) {
      setState(() {
        _routePoints = _decodeGeometry();
      });
      _fitRoute();
    }

    if (widget.startNavigation && !oldWidget.startNavigation) {
      _startNavigation();
    } else if (!widget.startNavigation && oldWidget.startNavigation) {
      _stopNavigation();
      _fitRoute();
    }
  }

  @override
  void dispose() {
    _stopNavigation();
    super.dispose();
  }

  // ── Polyline Geometry Decoding ────────────────────────────────────────────

  List<LatLng> _decodeGeometry() {
    final route = widget.routeData?['route'];
    final geometry = route?['geometry'] ?? widget.routeData?['geometry'];
    if (geometry == null) return [];

    List<LatLng> points = [];

    if (geometry is String) {
      if (geometry.isEmpty) return [];
      final decoded = _decodePolyline(geometry);
      if (decoded.isEmpty) return [];

      final p0 = decoded.first;
      final dLatAsLat = (p0.latitude - widget.startLat).abs();
      final dLngAsLat = (p0.longitude - widget.startLat).abs();

      if (dLatAsLat < dLngAsLat) {
        points = decoded;
      } else {
        points = decoded.map((p) => LatLng(p.longitude, p.latitude)).toList();
      }
    } else if (geometry is List) {
      for (final item in geometry) {
        if (item is List && item.length >= 2) {
          final val1 = (item[0] as num).toDouble();
          final val2 = (item[1] as num).toDouble();
          final d1 = (val1 - widget.startLat).abs();
          final d2 = (val2 - widget.startLat).abs();
          if (d1 < d2) {
            points.add(LatLng(val1, val2));
          } else {
            points.add(LatLng(val2, val1));
          }
        }
      }
    }

    return points;
  }

  List<LatLng> _decodePolyline(String encoded) {
    final pts = <LatLng>[];
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

      pts.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return pts;
  }

  // ── Map Helpers ───────────────────────────────────────────────────────────

  void _fitRoute() {
    if (!_mapReady) return;
    final points = _getNavPoints();
    if (points.isEmpty) return;

    final allPoints = <LatLng>[
      LatLng(widget.startLat, widget.startLng),
      LatLng(widget.endLat, widget.endLng),
      ...points,
    ];

    try {
      final bounds = LatLngBounds.fromPoints(allPoints);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
      );
    } catch (_) {}
  }

  // ── Navigation & GPS Simulation ──────────────────────────────────────────

  void _startNavigation() {
    _startGps();
    _startSimulation();
  }

  void _stopNavigation() {
    _positionSub?.cancel();
    _positionSub = null;
    _simTimer?.cancel();
    _simTimer = null;
  }

  void _startSimulation() {
    _simTimer?.cancel();
    final points = _getNavPoints();
    if (points.isEmpty) return;

    _simIndex = 0;
    _userPosition = points[0];

    final int stepMs = (points.length > 1)
        ? (12000 / points.length).clamp(500, 1200).round()
        : 1000;

    _simTimer = Timer.periodic(Duration(milliseconds: stepMs), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_simIndex < points.length - 1) {
        _simIndex++;
        final currentPoint = points[_simIndex];
        final rem = _remainingMeters(currentPoint);
        final eta = _etaSeconds(rem);

        setState(() {
          _userPosition = currentPoint;
        });

        widget.onNavigationUpdate?.call({'remaining_m': rem, 'eta_s': eta});

        try {
          _mapController.move(currentPoint, 16.0);
        } catch (_) {}

        if (_simIndex >= points.length - 1 || rem < 25) {
          _stopNavigation();
          widget.onDestinationReached?.call();
        }
      } else {
        _stopNavigation();
        widget.onDestinationReached?.call();
      }
    });
  }

  List<LatLng> _getNavPoints() {
    if (_routePoints.isNotEmpty) return _routePoints;
    final start = LatLng(widget.startLat, widget.startLng);
    final end = LatLng(widget.endLat, widget.endLng);
    return [
      start,
      LatLng((start.latitude * 2 + end.latitude) / 3, (start.longitude * 2 + end.longitude) / 3),
      LatLng((start.latitude + end.latitude * 2) / 3, (start.longitude + end.longitude * 2) / 3),
      end,
    ];
  }

  Future<void> _startGps() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        return;
      }

      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((pos) {
        final p = LatLng(pos.latitude, pos.longitude);
        if (widget.startNavigation && _simTimer == null) {
          setState(() => _userPosition = p);
          final rem = _remainingMeters(p);
          final eta = _etaSeconds(rem);
          widget.onNavigationUpdate?.call({'remaining_m': rem, 'eta_s': eta});
          try {
            _mapController.move(p, 16.0);
          } catch (_) {}

          if (rem < 30) {
            _stopNavigation();
            widget.onDestinationReached?.call();
          }
        }
      });
    } catch (_) {}
  }

  double _remainingMeters(LatLng current) {
    final points = _getNavPoints();
    if (points.isEmpty) return 0;
    const d = Distance();
    double minD = double.infinity;
    int nearest = 0;
    for (int i = 0; i < points.length; i++) {
      final dist = d.as(LengthUnit.Meter, current, points[i]);
      if (dist < minD) {
        minD = dist;
        nearest = i;
      }
    }
    double total = minD;
    for (int i = nearest; i < points.length - 1; i++) {
      total += d.as(LengthUnit.Meter, points[i], points[i + 1]);
    }
    return total;
  }

  int _etaSeconds(double remainingM) {
    final route = widget.routeData?['route'];
    if (route != null) {
      final distKm = (route['distance_km'] as num?)?.toDouble();
      final durMin = (route['duration_min'] as num?)?.toDouble();
      if (distKm != null && durMin != null && distKm > 0) {
        final mps = (distKm * 1000) / (durMin * 60);
        if (mps > 0) return (remainingM / mps).round();
      }
    }
    return (remainingM / 8.3).round();
  }

  // ── Build Map Widget ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final start = LatLng(widget.startLat, widget.startLng);
    final end = LatLng(widget.endLat, widget.endLng);
    final points = _getNavPoints();

    final center = _userPosition ??
        (_routePoints.isNotEmpty
            ? _routePoints[_routePoints.length ~/ 2]
            : LatLng((widget.startLat + widget.endLat) / 2, (widget.startLng + widget.endLng) / 2));

    List<LatLng> traveledPoints = [];
    List<LatLng> remainingPoints = [];

    if (widget.startNavigation && points.isNotEmpty && _simIndex < points.length) {
      traveledPoints = points.sublist(0, (_simIndex + 1).clamp(1, points.length));
      remainingPoints = points.sublist(_simIndex.clamp(0, points.length - 1));
    } else {
      remainingPoints = _routePoints.isNotEmpty ? _routePoints : [start, end];
    }

    return Container(
      height: 360,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: widget.startNavigation ? 16 : 13,
                onMapReady: () {
                  _mapReady = true;
                  if (!widget.startNavigation) {
                    _fitRoute();
                  }
                },
              ),
              children: [
                // OpenStreetMap Tile Layer
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.safesphere.app',
                  maxZoom: 19,
                ),

                // Traveled Polyline
                if (traveledPoints.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: traveledPoints,
                        strokeWidth: 4,
                        color: Colors.grey.withValues(alpha: 0.6),
                      ),
                    ],
                  ),

                // Safe Route Polyline
                if (remainingPoints.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: remainingPoints,
                        strokeWidth: 6,
                        color: AppTheme.primaryLight,
                      ),
                    ],
                  ),

                // Markers Layer
                MarkerLayer(
                  markers: [
                    ..._buildDangerMarkers(),
                    _buildPinMarker(start, Colors.green, Icons.play_arrow, widget.startLabel ?? 'Start'),
                    _buildPinMarker(end, AppTheme.sosRed, Icons.location_on, widget.endLabel ?? 'Destination'),
                    if (_userPosition != null)
                      _buildPinMarker(_userPosition!, AppTheme.primaryLight, Icons.navigation, 'Current Position'),
                  ],
                ),
              ],
            ),

            // Recenter Button
            Positioned(
              right: 12,
              bottom: 12,
              child: FloatingActionButton.small(
                heroTag: 'recenter_osm_map',
                backgroundColor: AppTheme.card,
                foregroundColor: AppTheme.primaryLight,
                onPressed: () {
                  if (widget.startNavigation && _userPosition != null) {
                    _mapController.move(_userPosition!, 16.0);
                  } else {
                    _fitRoute();
                  }
                },
                child: const Icon(Icons.my_location),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Marker _buildPinMarker(LatLng point, Color color, IconData icon, String tooltip) {
    return Marker(
      point: point,
      width: 44,
      height: 44,
      child: Tooltip(
        message: tooltip,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  List<Marker> _buildDangerMarkers() {
    final dangerZones = widget.routeData?['safety']?['danger_zones'] as List<dynamic>? ?? [];
    final List<Marker> list = [];

    for (int i = 0; i < dangerZones.length; i++) {
      final dz = dangerZones[i];
      if (dz is Map<String, dynamic>) {
        final lat = (dz['lat'] as num?)?.toDouble();
        final lng = (dz['lng'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          list.add(
            Marker(
              point: LatLng(lat, lng),
              width: 36,
              height: 36,
              child: Tooltip(
                message: '${dz['risk_level']?.toString().toUpperCase() ?? 'HIGH RISK'}: ${dz['reason'] ?? 'Incident hotspot'}',
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.warning,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.warning.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Colors.black, size: 20),
                ),
              ),
            ),
          );
        }
      }
    }

    return list;
  }
}
