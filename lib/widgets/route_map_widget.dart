import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';

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
  });

  @override
  State<RouteMapWidget> createState() => _RouteMapWidgetState();
}

class _RouteMapWidgetState extends State<RouteMapWidget> {
  final MapController _mapCtrl = MapController();
  StreamSubscription<Position>? _positionSub;
  LatLng? _userPosition;
  List<LatLng> _routePoints = [];
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _routePoints = _decodeGeometry();
    if (widget.startNavigation) _startGps();
  }

  @override
  void didUpdateWidget(covariant RouteMapWidget old) {
    super.didUpdateWidget(old);
    // Re-decode if route data changed
    if (widget.routeData != old.routeData) {
      setState(() => _routePoints = _decodeGeometry());
      _fitRoute();
    }
    if (widget.startNavigation && !old.startNavigation) {
      _startGps();
    } else if (!widget.startNavigation && old.startNavigation) {
      _stopGps();
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  // ── Route decoding ────────────────────────────────────────────────────────

  List<LatLng> _decodeGeometry() {
    final geometry = widget.routeData?['route']?['geometry'];
    if (geometry is! String || geometry.isEmpty) return [];

    final pts = _decodePolyline(geometry);
    if (pts.isEmpty) return [];

    // ORS encodes [lng, lat] in some versions — auto-detect and fix
    // Valid lat range: -90 to 90. If first "lat" is outside that, coords are flipped.
    final first = pts.first;
    if (first.latitude.abs() > 90) {
      return pts.map((p) => LatLng(p.longitude, p.latitude)).toList();
    }
    return pts;
  }

  /// Standard Google/ORS encoded polyline decoder (1e5 precision)
  List<LatLng> _decodePolyline(String encoded) {
    final pts = <LatLng>[];
    int i = 0, lat = 0, lng = 0;

    while (i < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(i++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(i++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      pts.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return pts;
  }

  // ── Map helpers ───────────────────────────────────────────────────────────

  void _fitRoute() {
    if (!_mapReady || _routePoints.length < 2) return;
    try {
      final bounds = LatLngBounds.fromPoints(_routePoints);
      _mapCtrl.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
      );
    } catch (_) {}
  }

  // ── GPS navigation ────────────────────────────────────────────────────────

  Future<void> _startGps() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied)
      return;

    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((pos) {
          final p = LatLng(pos.latitude, pos.longitude);
          setState(() => _userPosition = p);

          // Notify parent with remaining distance + ETA
          if (_routePoints.isNotEmpty) {
            final rem = _remainingMeters(p);
            final eta = _etaSeconds(rem);
            widget.onNavigationUpdate?.call({'remaining_m': rem, 'eta_s': eta});
          }

          // Re-center map
          try {
            _mapCtrl.move(p, _mapCtrl.camera.zoom);
          } catch (_) {}
        });
  }

  void _stopGps() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  double _remainingMeters(LatLng current) {
    if (_routePoints.isEmpty) return 0;
    const d = Distance();
    // Find nearest point on route
    double minD = double.infinity;
    int nearest = 0;
    for (int i = 0; i < _routePoints.length; i++) {
      final dist = d.as(LengthUnit.Meter, current, _routePoints[i]);
      if (dist < minD) {
        minD = dist;
        nearest = i;
      }
    }
    // Sum remaining segments
    double total = minD;
    for (int i = nearest; i < _routePoints.length - 1; i++) {
      total += d.as(LengthUnit.Meter, _routePoints[i], _routePoints[i + 1]);
    }
    return total;
  }

  int _etaSeconds(double remainingM) {
    final route = widget.routeData?['route'];
    if (route != null) {
      final distM = (route['distance_km'] as num?)?.toDouble();
      final durS = (route['duration_min'] as num?)?.toDouble();
      if (distM != null && durS != null && distM > 0) {
        final mps = (distM * 1000) / (durS * 60);
        if (mps > 0) return (remainingM / mps).round();
      }
    }
    return (remainingM / 8.3).round(); // ~30 km/h city default
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final start = LatLng(widget.startLat, widget.startLng);
    final end = LatLng(widget.endLat, widget.endLng);

    final center = _routePoints.isNotEmpty
        ? _routePoints[_routePoints.length ~/ 2]
        : LatLng(
            (widget.startLat + widget.endLat) / 2,
            (widget.startLng + widget.endLng) / 2,
          );

    return Container(
      height: 320,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13,
            onMapReady: () {
              _mapReady = true;
              _fitRoute();
            },
          ),
          children: [
            // ── Tiles ──────────────────────────────────────────────────────
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.safesphere.app',
              maxZoom: 19,
            ),

            // ── Route polyline ─────────────────────────────────────────────
            if (_routePoints.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 5,
                    color: AppTheme.primaryLight,
                  ),
                ],
              )
            else
              // Dotted straight line when no route decoded yet
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [start, end],
                    strokeWidth: 3,
                    isDotted: true,
                    color: AppTheme.primaryLight.withAlpha(120),
                  ),
                ],
              ),

            // ── Danger zone markers ────────────────────────────────────────
            MarkerLayer(
              markers: [
                ..._dangerMarkers(),
                _marker(start, _startPin()),
                _marker(end, _endPin()),
                if (_userPosition != null) _marker(_userPosition!, _navPin()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Marker> _dangerMarkers() {
    final zones =
        widget.routeData?['safety']?['danger_zones'] as List<dynamic>? ?? [];
    return zones.map((z) {
      final lat = (z['latitude'] as num?)?.toDouble() ?? 0;
      final lng = (z['longitude'] as num?)?.toDouble() ?? 0;
      return _marker(
        LatLng(lat, lng),
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.sosRed.withAlpha(200),
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: 16,
          ),
        ),
      );
    }).toList();
  }

  Marker _marker(LatLng point, Widget child) =>
      Marker(point: point, width: 40, height: 40, child: child);

  Widget _startPin() => _pin(AppTheme.success, Icons.my_location);
  Widget _endPin() => _pin(AppTheme.sosRed, Icons.flag);
  Widget _navPin() => _pin(AppTheme.primary, Icons.navigation, size: 28);

  Widget _pin(Color color, IconData icon, {double size = 40}) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: [
        BoxShadow(color: color.withAlpha(100), blurRadius: 8, spreadRadius: 2),
      ],
    ),
    child: Icon(icon, color: Colors.white, size: size * 0.5),
  );
}
