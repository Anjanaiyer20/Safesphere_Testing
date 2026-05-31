import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/api_service_impl.dart';
import '../../theme/app_theme.dart';

class CommunityIncidentsScreen extends StatefulWidget {
  const CommunityIncidentsScreen({super.key});

  @override
  State<CommunityIncidentsScreen> createState() =>
      _CommunityIncidentsScreenState();
}

class _CommunityIncidentsScreenState extends State<CommunityIncidentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _allIncidents = [];
  List<dynamic> _myIncidents = [];
  bool _isLoading = true;

  final List<String> _incidentTypes = [
    'Harassment',
    'Theft',
    'Assault',
    'Suspicious Activity',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadIncidents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadIncidents() async {
    setState(() => _isLoading = true);
    try {
      final allResponse = await ApiService.getAllIncidents();
      final myResponse = await ApiService.getMyIncidents();
      setState(() {
        _allIncidents = allResponse['incidents'] ?? [];
        _myIncidents = myResponse['incidents'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showReportDialog() {
    String selectedType = _incidentTypes[0];
    final descController = TextEditingController();
    final parentContext = context;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Report Incident',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                dropdownColor: AppTheme.cardLight,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Incident Type',
                  prefixIcon: Icon(Icons.warning_outlined),
                ),
                items: _incidentTypes
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => selectedType = value!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final position = await Geolocator.getCurrentPosition(
                    desiredAccuracy: LocationAccuracy.high,
                  );
                  final response = await ApiService.reportIncident(
                    selectedType,
                    descController.text,
                    position.latitude,
                    position.longitude,
                  );
                  if (!mounted) return;
                  // ignore: use_build_context_synchronously
                  Navigator.pop(parentContext);
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      content: Text(response['message'] ?? 'Reported'),
                      backgroundColor: AppTheme.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                  _loadIncidents();
                } catch (e) {
                  if (!mounted) return;
                  // ignore: use_build_context_synchronously
                  Navigator.pop(parentContext);
                }
              },
              child: const Text('Report'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getIncidentColor(String type) {
    switch (type) {
      case 'Harassment':
        return AppTheme.sosRed;
      case 'Theft':
        return AppTheme.warning;
      case 'Assault':
        return Colors.deepOrange;
      case 'Suspicious Activity':
        return Colors.orange;
      default:
        return AppTheme.primaryLight;
    }
  }

  Widget _buildIncidentList(List<dynamic> incidents, bool showDelete) {
    if (incidents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 60),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.card,
                border: Border.all(color: AppTheme.divider),
              ),
              child: const Icon(
                Icons.report_outlined,
                color: AppTheme.textMuted,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No incidents reported',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadIncidents,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: incidents.length,
        itemBuilder: (context, index) {
          final incident = incidents[index];
          final color = _getIncidentColor(incident['incident_type'] ?? '');
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withAlpha((0.3 * 255).round())),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withAlpha((0.2 * 255).round()),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        incident['incident_type'] ?? '',
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (showDelete)
                      IconButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final response = await ApiService.deleteIncident(
                            incident['id'],
                          );
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(response['message'] ?? 'Deleted'),
                              backgroundColor: AppTheme.success,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          _loadIncidents();
                        },
                        icon: const Icon(
                          Icons.delete_outlined,
                          color: AppTheme.sosRed,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  incident['description'] ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  incident['created_at']?.toString().substring(0, 16) ?? '',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: Duration(milliseconds: index * 100));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Community Incidents'),
        backgroundColor: AppTheme.surface,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryLight,
          labelColor: AppTheme.primaryLight,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: const [
            Tab(text: 'All Incidents'),
            Tab(text: 'My Incidents'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showReportDialog,
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildIncidentList(_allIncidents, false),
                _buildIncidentList(_myIncidents, true),
              ],
            ),
    );
  }
}
