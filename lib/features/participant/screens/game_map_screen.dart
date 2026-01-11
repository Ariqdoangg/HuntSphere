import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:math' show cos, sqrt, asin, pi;

class GameMapScreen extends StatefulWidget {
  final String participantId;
  final String teamId;
  final String activityId;

  const GameMapScreen({
    super.key,
    required this.participantId,
    required this.teamId,
    required this.activityId,
  });

  @override
  State<GameMapScreen> createState() => _GameMapScreenState();
}

class _GameMapScreenState extends State<GameMapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  List<Map<String, dynamic>> _checkpoints = [];
  Map<String, dynamic>? _nearestCheckpoint;
  double? _distanceToNearest;
  Timer? _locationTimer;
  Timer? _geofenceTimer;
  bool _isLoadingLocation = true;
  String? _teamName;
  String? _teamEmoji;

  // Geofencing radius in meters
  static const double GEOFENCE_RADIUS = 50.0;

  @override
  void initState() {
    super.initState();
    _loadTeamInfo();
    _loadCheckpoints();
    _initializeLocation();
    _startLocationTracking();
    _startGeofenceChecking();
  }

  Future<void> _loadTeamInfo() async {
    try {
      final teamData = await Supabase.instance.client
          .from('teams')
          .select('team_name, emoji')
          .eq('id', widget.teamId)
          .single();

      setState(() {
        _teamName = teamData['team_name'];
        _teamEmoji = teamData['emoji'];
      });
    } catch (e) {
      debugPrint('Error loading team info: $e');
    }
  }

  Future<void> _loadCheckpoints() async {
    try {
      final response = await Supabase.instance.client
          .from('checkpoints')
          .select('''
            id,
            name,
            latitude,
            longitude,
            radius_meters,
            sequence_order,
            points
          ''')
          .eq('activity_id', widget.activityId)
          .order('sequence_order', ascending: true);

      setState(() {
        _checkpoints = List<Map<String, dynamic>>.from(response);
      });

      _updateMarkers();
    } catch (e) {
      debugPrint('Error loading checkpoints: $e');
    }
  }

  void _updateMarkers() {
    final markers = <Marker>{};

    // Add checkpoint markers
    for (var checkpoint in _checkpoints) {
      markers.add(
        Marker(
          markerId: MarkerId(checkpoint['id']),
          position: LatLng(
            checkpoint['latitude'],
            checkpoint['longitude'],
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(
            title: checkpoint['name'],
            snippet: '${checkpoint['points']} points',
          ),
        ),
      );
    }

    // Add current position marker
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(
            title: '$_teamEmoji $_teamName',
            snippet: 'Your team location',
          ),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  Future<void> _initializeLocation() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError('Location permission permanently denied');
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });

      _updateMarkers();
      _calculateNearestCheckpoint();
      _updateParticipantLocation(position);

      // Move camera to current location
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            15.0,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      _showError('Error getting location: $e');
    }
  }

  void _startLocationTracking() {
    _locationTimer = Timer.periodic(
      const Duration(seconds: 10),
      (timer) async {
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );

          setState(() {
            _currentPosition = position;
          });

          _updateMarkers();
          _calculateNearestCheckpoint();
          _updateParticipantLocation(position);
        } catch (e) {
          debugPrint('Location update error: $e');
        }
      },
    );
  }

  void _startGeofenceChecking() {
    _geofenceTimer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) {
        _checkGeofences();
      },
    );
  }

  Future<void> _updateParticipantLocation(Position position) async {
    try {
      await Supabase.instance.client.from('participants').update({
        'current_latitude': position.latitude,
        'current_longitude': position.longitude,
        'last_location_update': DateTime.now().toIso8601String(),
      }).eq('id', widget.participantId);
    } catch (e) {
      debugPrint('Error updating location: $e');
    }
  }

  void _calculateNearestCheckpoint() {
    if (_currentPosition == null || _checkpoints.isEmpty) return;

    double minDistance = double.infinity;
    Map<String, dynamic>? nearest;

    for (var checkpoint in _checkpoints) {
      final distance = _calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        checkpoint['latitude'],
        checkpoint['longitude'],
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearest = checkpoint;
      }
    }

    setState(() {
      _nearestCheckpoint = nearest;
      _distanceToNearest = minDistance;
    });
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;

    return 12742 * asin(sqrt(a)) * 1000; // Distance in meters
  }

  void _checkGeofences() async {
    if (_currentPosition == null) return;

    for (var checkpoint in _checkpoints) {
      final distance = _calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        checkpoint['latitude'],
        checkpoint['longitude'],
      );

      final radius = checkpoint['radius_meters'] ?? GEOFENCE_RADIUS;

      if (distance <= radius) {
        // Inside geofence!
        await _onCheckpointArrived(checkpoint);
      }
    }
  }

  Future<void> _onCheckpointArrived(Map<String, dynamic> checkpoint) async {
    // Check if already arrived
    try {
      final existing = await Supabase.instance.client
          .from('team_progress')
          .select()
          .eq('team_id', widget.teamId)
          .eq('checkpoint_id', checkpoint['id'])
          .maybeSingle();

      if (existing != null) {
        // Already arrived, don't show again
        return;
      }

      // Record arrival
      await Supabase.instance.client.from('team_progress').insert({
        'team_id': widget.teamId,
        'checkpoint_id': checkpoint['id'],
        'arrived_at': DateTime.now().toIso8601String(),
        'status': 'in_progress',
      });

      // Show arrival dialog
      if (mounted) {
        _showCheckpointArrivalDialog(checkpoint);
      }
    } catch (e) {
      debugPrint('Error recording checkpoint arrival: $e');
    }
  }

  void _showCheckpointArrivalDialog(Map<String, dynamic> checkpoint) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Checkpoint Reached!',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              checkpoint['name'],
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00D9FF),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '⭐ ${checkpoint['points']} points available',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Complete tasks to earn points!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Continue Exploring',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                '/checkpoint-tasks',
                arguments: {
                  'checkpointId': checkpoint['id'],
                  'checkpointName': checkpoint['name'],
                  'teamId': widget.teamId,
                },
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D9FF),
              foregroundColor: Colors.black,
            ),
            child: const Text('View Tasks'),
          ),
        ],
      ),
    );
  }

  void _navigateToTasks(Map<String, dynamic> checkpoint) {
    // TODO: Navigate to task list screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening tasks for ${checkpoint['name']}...'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _geofenceTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$_teamEmoji $_teamName'),
        backgroundColor: const Color(0xFF0A1628),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _initializeLocation();
              _loadCheckpoints();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          _isLoadingLocation
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF00D9FF)),
                      SizedBox(height: 16),
                      Text('Getting your location...'),
                    ],
                  ),
                )
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition != null
                        ? LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          )
                        : const LatLng(3.5890, 101.5080), // Default: KL
                    zoom: 15.0,
                  ),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                ),

          // Distance indicator at top
          if (_nearestCheckpoint != null && _distanceToNearest != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF00D9FF).withValues(alpha: 0.9),
                      const Color(0xFF0A1628).withValues(alpha: 0.9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF00D9FF),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.navigation,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nearestCheckpoint!['name'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${_distanceToNearest!.toStringAsFixed(0)}m away',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_distanceToNearest! <= GEOFENCE_RADIUS)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'ARRIVED',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Checkpoint list at bottom
          DraggableScrollableSheet(
            initialChildSize: 0.35, // Start larger!
            minChildSize: 0.15,
            maxChildSize: 0.7,
            snap: true,
            snapSizes: [0.15, 0.35, 0.7],
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1A2332),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Enhanced drag handle
                    GestureDetector(
                      onTap: () {
                        // Tapping handle toggles between min and max
                        // This helps on web where dragging is harder
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          children: [
                            Container(
                              width: 50,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.white38,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '↕️ Drag to expand/collapse',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Checkpoints title
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: Color(0xFF00D9FF)),
                          SizedBox(width: 8),
                          Text(
                            'Checkpoints',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Checkpoint list
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _checkpoints.length,
                        itemBuilder: (context, index) {
                          final checkpoint = _checkpoints[index];
                          final distance = _currentPosition != null
                              ? _calculateDistance(
                                  _currentPosition!.latitude,
                                  _currentPosition!.longitude,
                                  checkpoint['latitude'],
                                  checkpoint['longitude'],
                                )
                              : null;

                          return _CheckpointCard(
                            checkpoint: checkpoint,
                            distance: distance,
                            onTap: () {
                              if (_mapController != null) {
                                _mapController!.animateCamera(
                                  CameraUpdate.newLatLngZoom(
                                    LatLng(
                                      checkpoint['latitude'],
                                      checkpoint['longitude'],
                                    ),
                                    16.0,
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CheckpointCard extends StatelessWidget {
  final Map<String, dynamic> checkpoint;
  final double? distance;
  final VoidCallback onTap;

  const _CheckpointCard({
    required this.checkpoint,
    required this.distance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF0A1628),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF00D9FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Text(
                    '${checkpoint['sequence_order']}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00D9FF),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      checkpoint['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '⭐ ${checkpoint['points']} points',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              if (distance != null)
                Text(
                  '${distance!.toStringAsFixed(0)}m',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.white54,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
