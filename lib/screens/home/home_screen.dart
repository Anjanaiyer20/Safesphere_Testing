import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/api_service_impl.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../sos/sos_history_screen.dart';
import '../location/location_screen.dart';
import '../contacts/emergency_contacts_screen.dart';
import '../profile/profile_screen.dart';
import '../incidents/community_incidents_screen.dart';
import '../route/safe_route_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isSosLoading = false;
  String _userName = 'User';
  late AnimationController _sosAnimationController;

  @override
  void initState() {
    super.initState();
    _sosAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _loadProfile();
  }

  @override
  void dispose() {
    _sosAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final response = await ApiService.getProfile();
      if (response.containsKey('name')) {
        setState(() => _userName = response['name']);
      }
    } catch (e) {
      // ignore
    }
  }

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Location services are disabled', isError: true);
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Location permission denied', isError: true);
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Location permission permanently denied', isError: true);
      return null;
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> _triggerSOS() async {
    setState(() => _isSosLoading = true);

    try {
      final position = await _getCurrentLocation();
      if (position == null) {
        setState(() => _isSosLoading = false);
        return;
      }

      final response = await ApiService.triggerSOS(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        _showSOSDialog(response);
      }
    } catch (e) {
      _showSnackBar('SOS failed. Please try again.', isError: true);
    }

    setState(() => _isSosLoading = false);
  }

  void _showSOSDialog(Map<String, dynamic> response) {
    final location = response['location'] as Map<String, dynamic>?;
    final alerts = response['alerts'] as List<dynamic>?;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.success,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 16),
              const Text(
                'SOS Triggered!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (location != null)
                Text(
                  location['place_name'] ?? 'Location detected',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 16),
              if (alerts != null && alerts.isNotEmpty) ...[
                const Text(
                  'Contacts Notified:',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...alerts.map(
                  (alert) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person,
                          color: AppTheme.primaryLight,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${alert['name']} — ${alert['phone']}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }

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

  Future<void> _logout() async {
    await ApiService.clearToken();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return const LocationScreen();
      case 2:
        return const EmergencyContactsScreen();
      case 3:
        return const ProfileScreen();
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: AppTheme.surface,
        selectedItemColor: AppTheme.primaryLight,
        unselectedItemColor: AppTheme.textMuted,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on_outlined),
            activeIcon: Icon(Icons.location_on),
            label: 'Location',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts_outlined),
            activeIcon: Icon(Icons.contacts),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, $_userName 👋',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Stay safe today',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: AppTheme.textSecondary),
                ),
              ],
            ).animate().fadeIn().slideY(begin: -0.3),
            const SizedBox(height: 40),
            Center(
              child: GestureDetector(
                onTap: _isSosLoading ? null : _triggerSOS,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _sosAnimationController,
                      builder: (context, child) {
                        return Container(
                          width: 180 + (_sosAnimationController.value * 20),
                          height: 180 + (_sosAnimationController.value * 20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.sosRed.withAlpha(
                              (0.1 * (1 - _sosAnimationController.value) * 255)
                                  .round(),
                            ),
                          ),
                        );
                      },
                    ),
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [AppTheme.sosRed, AppTheme.sosRedDark],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.sosRed.withAlpha(
                              (0.5 * 255).round(),
                            ),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: _isSosLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.white,
                                  size: 40,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'SOS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 4,
                                  ),
                                ),
                                Text(
                                  'Tap for Help',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 300.ms).scale(),
            const SizedBox(height: 48),
            const Text(
              'Quick Actions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.3,
              children: [
                _buildQuickAction(
                  icon: Icons.history,
                  label: 'SOS History',
                  color: AppTheme.sosRed,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SOSHistoryScreen()),
                  ),
                ),
                _buildQuickAction(
                  icon: Icons.route,
                  label: 'Safe Route',
                  color: AppTheme.success,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SafeRouteScreen()),
                  ),
                ),
                _buildQuickAction(
                  icon: Icons.report_problem_outlined,
                  label: 'Incidents',
                  color: AppTheme.warning,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CommunityIncidentsScreen(),
                    ),
                  ),
                ),
                _buildQuickAction(
                  icon: Icons.location_history,
                  label: 'Location History',
                  color: AppTheme.primaryLight,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
              ],
            ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.3),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha((0.3 * 255).round())),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withAlpha((0.2 * 255).round()),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
