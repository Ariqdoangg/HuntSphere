import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:math' show cos, sqrt, asin;
import '../../shared/screens/chatbot_screen.dart';
import '../../../services/audio_service.dart';
import '../../../core/widgets/huntsphere_watermark.dart';

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
  Set<String> _arrivedCheckpoints = {};
  Map<String, dynamic>? _nearestCheckpoint;
  double? _distanceToNearest;
  Timer? _locationTimer;
  Timer? _countdownTimer;
  bool _isLoadingLocation = true;
  bool _hasError = false;
  String? _teamName;
  String? _teamEmoji;
  RealtimeChannel? _activityStatusChannel;
  RealtimeChannel? _announcementChannel;
  Duration _remainingTime = Duration.zero;
  Map<String, dynamic>? _activityData;
  List<Map<String, dynamic>> _announcements = [];

  static const double GEOFENCE_RADIUS = 50.0;

  @override
  void initState() {
    super.initState();
    _initializeAll();
  }

  /// Coordinate all async initialization
  Future<void> _initializeAll() async {
    try {
      // Load data concurrently
      await Future.wait([
        _loadTeamInfo(),
        _loadCheckpoints(),
        _loadArrivedCheckpoints(),
        _loadActivityData(),
      ]);
    } catch (e) {
      debugPrint('Initialization error: $e');
      if (mounted) {
        setState(() => _hasError = true);
      }
    }

    // Initialize location (depends on permissions, do separately)
    _initializeLocation();
    _subscribeToActivityStatus();
    _subscribeToAnnouncements();

    // Start countdown timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdown();
    });
  }

  Future<void> _loadActivityData() async {
    try {
      final response = await Supabase.instance.client
          .from('activities')
          .select()
          .eq('id', widget.activityId)
          .single();

      setState(() {
        _activityData = response;
      });
      _updateCountdown();
    } catch (e) {
      debugPrint('Error loading activity data: $e');
    }
  }

  void _updateCountdown() {
    if (_activityData == null) return;

    final gameStartedAt = _activityData!['game_started_at'];
    // Always use total_duration_minutes (set by facilitator at creation)
    // duration_minutes column is unreliable (has DEFAULT 60 in DB)
    final durationMinutes = _activityData!['total_duration_minutes'] ?? 60;

    if (gameStartedAt == null) return;

    final startTime = DateTime.parse(gameStartedAt);
    final endTime = startTime.add(Duration(minutes: durationMinutes));
    final now = DateTime.now();
    final remaining = endTime.difference(now);

    if (mounted) {
      setState(() {
        if (remaining.isNegative) {
          _remainingTime = Duration.zero;
        } else {
          _remainingTime = remaining;
        }
      });
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Parse arrival points safely from checkpoint data
  /// Handles multiple data types (int, double, string) and applies bounds checking
  int _parseArrivalPoints(Map<String, dynamic> checkpoint) {
    try {
      final points = checkpoint['arrival_points'];

      // Handle different types from database
      if (points == null) return 50;
      if (points is int) return points.clamp(0, 10000);  // Bounds check
      if (points is double) return points.round().clamp(0, 10000);
      if (points is String) {
        final parsed = int.tryParse(points);
        return (parsed ?? 50).clamp(0, 10000);
      }

      debugPrint('⚠️ Unknown arrival_points type: ${points.runtimeType}');
      return 50;  // Fallback
    } catch (e) {
      debugPrint('Error parsing arrival points: $e');
      return 50;
    }
  }

  /// Execute operation with retry logic and exponential backoff
  /// Returns true if operation succeeded, false if all retries failed
  Future<bool> _executeWithRetry({
    required Future<void> Function() operation,
    required String operationName,
    int maxRetries = 3,
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await operation();
        return true;  // Success
      } catch (e) {
        debugPrint('❌ $operationName failed (attempt $attempt/$maxRetries): $e');

        if (attempt == maxRetries) {
          // Final attempt failed
          _showMessage(
            'Failed to $operationName after $maxRetries attempts. Please check your connection.',
            isError: true,
          );
          return false;
        }

        // Wait before retry (exponential backoff: 2s, 4s, 6s)
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
    return false;
  }

  /// Subscribe to activity status changes (to detect game end)
  void _subscribeToActivityStatus() {
    _activityStatusChannel = Supabase.instance.client
        .channel('game_activity_status_${widget.activityId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'activities',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.activityId,
          ),
          callback: (payload) {
            debugPrint('📢 Activity status update: ${payload.newRecord}');
            final newRecord = payload.newRecord;

            // Reload full activity data including duration
            _reloadActivityData(newRecord);

            final status = newRecord['status'];

            // Check if game has ended
            if (status == 'completed' || status == 'ended') {
              _navigateToResults();
            }
          },
        )
        .subscribe();
  }

  /// Reload activity data when updates are received
  void _reloadActivityData(Map<String, dynamic> updatedData) {
    if (!mounted) return;

    setState(() {
      _activityData = updatedData;
    });

    debugPrint('⏱️ Activity data refreshed - Duration: ${updatedData['total_duration_minutes']} minutes');
  }

  /// Subscribe to announcements from facilitator
  void _subscribeToAnnouncements() {
    _announcementChannel = Supabase.instance.client
        .channel('announcements_${widget.activityId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'announcements',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'activity_id',
            value: widget.activityId,
          ),
          callback: (payload) {
            debugPrint('📢 New announcement: ${payload.newRecord}');
            _showAnnouncement(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// Show announcement dialog to participant
  void _showAnnouncement(Map<String, dynamic> announcement) {
    if (!mounted) return;

    final message = announcement['message'] as String;

    // Show as dialog with timer
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF00D9FF).withOpacity(0.9),
                const Color(0xFF7B2FFF).withOpacity(0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00D9FF).withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.campaign, color: Colors.white, size: 30),
                  SizedBox(width: 10),
                  Text(
                    'Announcement',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF00D9FF),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
                child: const Text('Got it!'),
              ),
            ],
          ),
        ),
      ),
    );

    // Auto-dismiss after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst || !route.willHandlePopInternally);
      }
    });
  }

  /// Navigate to results screen when game ends
  void _navigateToResults() {
    if (!mounted) return;

    // Show a snackbar notification
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.flag, color: Colors.white),
            SizedBox(width: 12),
            Text('Game Over! Showing results...'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );

    // Navigate to results after a short delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/results',
          (route) => route.isFirst,
          arguments: {'activityId': widget.activityId},
        );
      }
    });
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
      debugPrint('❌ Error loading team info: $e');
    }
  }

  Future<void> _loadCheckpoints() async {
    try {
      debugPrint('📍 Loading checkpoints for activity: ${widget.activityId}');
      
      final response = await Supabase.instance.client
          .from('checkpoints')
          .select()
          .eq('activity_id', widget.activityId)
          .order('sequence_order', ascending: true);

      debugPrint('📍 Found ${response.length} checkpoints');

      setState(() {
        _checkpoints = List<Map<String, dynamic>>.from(response);
      });

      _updateMarkers();
    } catch (e) {
      debugPrint('❌ Error loading checkpoints: $e');
    }
  }

  Future<void> _loadArrivedCheckpoints() async {
    try {
      final response = await Supabase.instance.client
          .from('team_progress')
          .select('checkpoint_id')
          .eq('team_id', widget.teamId);

      setState(() {
        _arrivedCheckpoints = Set<String>.from(
          response.map((r) => r['checkpoint_id'] as String),
        );
      });
      
      debugPrint('✅ Already arrived at ${_arrivedCheckpoints.length} checkpoints');
    } catch (e) {
      debugPrint('❌ Error loading arrived checkpoints: $e');
    }
  }

  void _updateMarkers() {
    final markers = <Marker>{};

    for (var checkpoint in _checkpoints) {
      // Skip checkpoints with missing required data
      if (checkpoint['id'] == null ||
          checkpoint['latitude'] == null ||
          checkpoint['longitude'] == null) {
        debugPrint('⚠️ Skipping checkpoint with missing data');
        continue;
      }

      final isArrived = _arrivedCheckpoints.contains(checkpoint['id']);

      markers.add(
        Marker(
          markerId: MarkerId(checkpoint['id'] as String),
          position: LatLng(
            checkpoint['latitude'] as double,
            checkpoint['longitude'] as double,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isArrived ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(
            title: checkpoint['name'] ?? 'Checkpoint',
            snippet: isArrived ? '✅ Completed' : '${checkpoint['arrival_points'] ?? checkpoint['points'] ?? 0} points',
          ),
          onTap: () => _onMarkerTap(checkpoint),
        ),
      );
    }

    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(
            title: '${_teamEmoji ?? ''} ${_teamName ?? 'My Team'}'.trim(),
            snippet: 'Your location',
          ),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  void _onMarkerTap(Map<String, dynamic> checkpoint) {
    final checkpointId = checkpoint['id'] as String?;
    final latitude = checkpoint['latitude'] as double?;
    final longitude = checkpoint['longitude'] as double?;

    if (checkpointId == null || latitude == null || longitude == null) {
      _showMessage('Invalid checkpoint data', isError: true);
      return;
    }

    final distance = _currentPosition != null
        ? _calculateDistance(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            latitude,
            longitude,
          )
        : null;

    final radius = (checkpoint['radius_meters'] ?? GEOFENCE_RADIUS).toDouble();
    final isInRange = distance != null && distance <= radius;
    final isArrived = _arrivedCheckpoints.contains(checkpointId);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A2332),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isArrived
                        ? Colors.green.withOpacity(0.2)
                        : const Color(0xFF00D9FF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isArrived ? Icons.check_circle : Icons.location_on,
                    color: isArrived ? Colors.green : const Color(0xFF00D9FF),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        checkpoint['name'] as String? ?? 'Checkpoint',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        distance != null
                            ? '${distance.toStringAsFixed(0)}m away'
                            : 'Distance unknown',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    isInRange ? Icons.check_circle : Icons.info_outline,
                    color: isInRange ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isInRange
                        ? 'You are within range!'
                        : 'Get within ${radius.toInt()}m to check in',
                    style: TextStyle(
                      color: isInRange ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            if (isArrived)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToTasks(checkpoint);
                  },
                  icon: const Icon(Icons.task),
                  label: const Text('View Tasks'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              )
            else if (isInRange)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _manualCheckIn(checkpoint);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Check In Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D9FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToCheckpoint(checkpoint);
                  },
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navigate Here'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D9FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _navigateToCheckpoint(Map<String, dynamic> checkpoint) {
    if (mounted && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(checkpoint['latitude'], checkpoint['longitude']),
          17.0,
        ),
      );
    }
  }

  Future<void> _manualCheckIn(Map<String, dynamic> checkpoint) async {
    try {
      final checkpointId = checkpoint['id'] as String?;
      final checkpointName = checkpoint['name'] as String? ?? 'Checkpoint';

      if (checkpointId == null) {
        _showMessage('Invalid checkpoint data', isError: true);
        return;
      }

      debugPrint('📍 Manual check-in for: $checkpointName');

      if (_arrivedCheckpoints.contains(checkpointId)) {
        _showMessage('Already checked in!', isError: false);
        _navigateToTasks(checkpoint);
        return;
      }

      // Use same team-together logic as automatic check-in
      await _onCheckpointArrived(checkpoint);

    } catch (e) {
      debugPrint('❌ Check-in error: $e');
      _showMessage('Check-in failed: $e', isError: true);
    }
  }

  Future<void> _initializeLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showMessage('Location permission denied', isError: true);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage('Location permission permanently denied', isError: true);
        return;
      }

      // Get initial position with platform-specific handling
      Position position;
      if (kIsWeb) {
        // Web: Use shorter timeout, browser handles permission
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw TimeoutException('Location request timed out on web');
          },
        );
      } else {
        // Mobile: Standard timeout
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      }

      debugPrint('📍 Current position: ${position.latitude}, ${position.longitude}');

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
        });

        _updateMarkers();
        _calculateNearestCheckpoint();
        _updateParticipantLocation(position);
        _checkGeofences();

        // Always try to move camera to current position
        if (mounted && _mapController != null) {
          await _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(position.latitude, position.longitude),
              16.0, // Slightly more zoomed in
            ),
          );
          debugPrint('📍 Camera moved to current position');
        } else {
          debugPrint('⚠️ Map controller not ready yet');
        }

        _startLocationTracking();
      }
      
    } catch (e) {
      debugPrint('❌ Location error: $e');
      if (mounted) {
        setState(() => _isLoadingLocation = false);

        // Show more helpful error message
        if (e.toString().contains('timeout')) {
          _showMessage('Location request timed out. Please enable location in your browser.', isError: true);
        } else {
          _showMessage('Unable to get location. Make sure location is enabled.', isError: true);
        }
      }
    }
  }

  void _startLocationTracking() {
    _locationTimer?.cancel();
    
    _locationTimer = Timer.periodic(
      const Duration(seconds: 5),
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
          _checkGeofences();
          
        } catch (e) {
          debugPrint('⚠️ Location update error: $e');
        }
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
      debugPrint('⚠️ Error updating location in DB: $e');
    }
  }

  void _calculateNearestCheckpoint() {
    if (_currentPosition == null || _checkpoints.isEmpty) return;

    double minDistance = double.infinity;
    Map<String, dynamic>? nearest;

    for (var checkpoint in _checkpoints) {
      final checkpointId = checkpoint['id'] as String?;
      final latitude = checkpoint['latitude'] as double?;
      final longitude = checkpoint['longitude'] as double?;

      // Skip if missing required data
      if (checkpointId == null || latitude == null || longitude == null) {
        continue;
      }

      if (_arrivedCheckpoints.contains(checkpointId)) continue;

      final distance = _calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        latitude,
        longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearest = checkpoint;
      }
    }

    setState(() {
      _nearestCheckpoint = nearest;
      _distanceToNearest = nearest != null ? minDistance : null;
    });
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000;
  }

  void _checkGeofences() {
    if (_currentPosition == null || _checkpoints.isEmpty) {
      debugPrint('⚠️ Cannot check geofences: position or checkpoints missing');
      return;
    }

    debugPrint('🔍 Checking geofences...');

    for (var checkpoint in _checkpoints) {
      final checkpointId = checkpoint['id'] as String?;
      final checkpointName = checkpoint['name'] as String? ?? 'Checkpoint';
      final latitude = checkpoint['latitude'] as double?;
      final longitude = checkpoint['longitude'] as double?;

      // Skip if missing required data
      if (checkpointId == null || latitude == null || longitude == null) {
        debugPrint('⚠️ Skipping checkpoint with incomplete data');
        continue;
      }

      if (_arrivedCheckpoints.contains(checkpointId)) continue;

      final distance = _calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        latitude,
        longitude,
      );

      final radius = (checkpoint['radius_meters'] ?? GEOFENCE_RADIUS).toDouble();

      debugPrint('📍 $checkpointName: ${distance.toStringAsFixed(1)}m (radius: ${radius}m)');

      if (distance <= radius) {
        debugPrint('✅ INSIDE GEOFENCE: $checkpointName');
        _onCheckpointArrived(checkpoint);
        break;
      }
    }
  }

  Future<void> _onCheckpointArrived(Map<String, dynamic> checkpoint) async {
    final checkpointId = checkpoint['id'] as String?;
    final checkpointName = checkpoint['name'] as String? ?? 'Checkpoint';

    if (checkpointId == null) {
      debugPrint('⚠️ Cannot process arrival: checkpoint ID is null');
      return;
    }

    if (_arrivedCheckpoints.contains(checkpointId)) {
      debugPrint('⚠️ Already processed arrival for $checkpointName');
      return;
    }

    try {
      debugPrint('🎯 Processing arrival at: $checkpointName');

      // Check if team has already completed this checkpoint
      final existing = await Supabase.instance.client
          .from('team_progress')
          .select()
          .eq('team_id', widget.teamId)
          .eq('checkpoint_id', checkpointId)
          .maybeSingle();

      if (existing != null) {
        debugPrint('⚠️ Team already completed this checkpoint');
        setState(() {
          _arrivedCheckpoints.add(checkpointId);
        });
        return;
      }

      // TEAM TOGETHER MODE: Record individual participant arrival
      final distance = _currentPosition != null
          ? _calculateDistance(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              checkpoint['latitude'] as double,
              checkpoint['longitude'] as double,
            )
          : null;

      // Check if this participant already recorded arrival
      final myArrival = await Supabase.instance.client
          .from('checkpoint_arrivals')
          .select()
          .eq('checkpoint_id', checkpointId)
          .eq('participant_id', widget.participantId)
          .maybeSingle();

      if (myArrival == null) {
        // Record this participant's arrival
        await Supabase.instance.client.from('checkpoint_arrivals').insert({
          'checkpoint_id': checkpointId,
          'participant_id': widget.participantId,
          'team_id': widget.teamId,
          'activity_id': widget.activityId,
          'latitude': _currentPosition?.latitude,
          'longitude': _currentPosition?.longitude,
          'distance_from_checkpoint': distance,
          'arrived_at': DateTime.now().toIso8601String(),
        });
        debugPrint('✅ Recorded my arrival at $checkpointName');
      }

      // Check if ALL team members have arrived
      final teamCheckResult = await Supabase.instance.client
          .rpc('check_all_team_members_present', params: {
        'p_checkpoint_id': checkpointId,
        'p_team_id': widget.teamId,
      }).select();

      if (teamCheckResult.isEmpty) {
        debugPrint('⚠️ Could not verify team presence');
        return;
      }

      final result = teamCheckResult.first;
      final allPresent = result['all_present'] as bool;
      final totalMembers = result['total_members'] as int;
      final arrivedMembers = result['arrived_members'] as int;
      final missingMembers = (result['missing_members'] as List?)?.cast<String>() ?? [];

      debugPrint('👥 Team status: $arrivedMembers/$totalMembers members present');

      if (!allPresent) {
        // Show waiting dialog
        _showWaitingForTeamDialog(
          checkpoint,
          arrivedMembers,
          totalMembers,
          missingMembers,
        );
        return;
      }

      // ALL MEMBERS PRESENT! Complete the checkpoint
      // Use atomic RPC function with retry logic to prevent points loss
      final arrivalPoints = _parseArrivalPoints(checkpoint);

      final success = await _executeWithRetry(
        operation: () async {
          await Supabase.instance.client.rpc('complete_checkpoint_and_award_points', params: {
            'p_team_id': widget.teamId,
            'p_checkpoint_id': checkpointId,
            'p_arrival_points': arrivalPoints,
          });
        },
        operationName: 'award checkpoint points',
      );

      if (success) {
        debugPrint('✅ All team members present! Checkpoint unlocked!');
        debugPrint('✅ +$arrivalPoints points awarded for checkpoint arrival!');

        // Play success sound and haptic feedback
        await AudioService().play('checkpoint_complete');
        HapticFeedback.heavyImpact();

        setState(() {
          _arrivedCheckpoints.add(checkpointId);
        });
        _updateMarkers();

        // Check if all checkpoints completed
        if (_arrivedCheckpoints.length >= _checkpoints.length && _checkpoints.isNotEmpty) {
          _showAllCheckpointsCompletedDialog();
        } else if (mounted) {
          _showCheckpointArrivalDialog(checkpoint);
        }
      }

    } catch (e) {
      debugPrint('❌ Error recording arrival: $e');
      _showMessage('Error: $e', isError: true);
    }
  }

  /// Show dialog when all checkpoints are completed
  void _showAllCheckpointsCompletedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Text('🎉', style: TextStyle(fontSize: 64)),
            SizedBox(height: 16),
            Text(
              'All Checkpoints Complete!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    '${_checkpoints.length}/${_checkpoints.length} Checkpoints',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Congratulations! You have completed all checkpoints. View the leaderboard to see your final ranking!',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  '/leaderboard',
                  arguments: {
                    'activityId': widget.activityId,
                    'currentTeamId': widget.teamId,
                  },
                );
              },
              icon: const Icon(Icons.leaderboard),
              label: const Text('View Leaderboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D9FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Continue Exploring',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  /// Show waiting dialog when not all team members are present
  void _showWaitingForTeamDialog(
    Map<String, dynamic> checkpoint,
    int arrivedMembers,
    int totalMembers,
    List<String> missingMembers,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.groups, color: Colors.orange, size: 32),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Waiting for Team',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
              checkpoint['name'] as String? ?? 'Checkpoint',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00D9FF),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people, color: Colors.orange, size: 32),
                      const SizedBox(width: 12),
                      Text(
                        '$arrivedMembers / $totalMembers',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'team members here',
                    style: TextStyle(
                      color: Colors.orange.shade200,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (missingMembers.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Waiting for:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...missingMembers.map((name) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          color: Colors.white54,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: 16),
            const Text(
              '💡 All team members must be within the checkpoint radius to unlock tasks.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check),
              label: const Text('Got it'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D9FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCheckpointArrivalDialog(Map<String, dynamic> checkpoint) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 32),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Checkpoint Reached!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
              checkpoint['name'] as String? ?? 'Checkpoint',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00D9FF),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${checkpoint['arrival_points'] ?? checkpoint['points'] ?? 0} points available',
                  style: const TextStyle(fontSize: 16, color: Colors.orange),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Complete tasks to earn more points!',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _navigateToTasks(checkpoint);
            },
            icon: const Icon(Icons.task),
            label: const Text('View Tasks'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D9FF),
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToTasks(Map<String, dynamic> checkpoint) {
    final checkpointId = checkpoint['id'] as String?;
    final checkpointName = checkpoint['name'] as String? ?? 'Checkpoint';

    if (checkpointId == null) {
      _showMessage('Invalid checkpoint data', isError: true);
      return;
    }

    Navigator.pushNamed(
      context,
      '/checkpoint-tasks',
      arguments: {
        'checkpointId': checkpointId,
        'checkpointName': checkpointName,
        'teamId': widget.teamId,
      },
    );
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _countdownTimer?.cancel();
    _activityStatusChannel?.unsubscribe();
    _announcementChannel?.unsubscribe();
    // Don't dispose map controller on web - it causes issues
    // The GoogleMap widget will handle its own cleanup
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTimeLow = _remainingTime.inMinutes < 5 && _remainingTime.inSeconds > 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),
        title: Row(
          children: [
            if (_teamEmoji != null)
              Text('$_teamEmoji ', style: const TextStyle(fontSize: 24)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _teamName ?? 'Loading...',
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Timer display
                  Row(
                    children: [
                      Icon(
                        Icons.timer,
                        size: 12,
                        color: isTimeLow ? Colors.red : const Color(0xFF00D9FF),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _remainingTime.inSeconds > 0
                            ? _formatDuration(_remainingTime)
                            : 'Time Up!',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isTimeLow ? Colors.red : const Color(0xFF00D9FF),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard),
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/leaderboard',
                arguments: {
                  'activityId': widget.activityId,
                  'currentTeamId': widget.teamId,
                },
              );
            },
            tooltip: 'Leaderboard',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadCheckpoints();
              _loadArrivedCheckpoints();
              _checkGeofences();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      const Text('Failed to load game data', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => _hasError = false);
                          _initializeAll();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _isLoadingLocation
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF00D9FF)),
                      SizedBox(height: 16),
                      Text('Getting your location...', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                )
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition != null
                        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                        : const LatLng(3.5890, 101.5080),
                    zoom: 15.0,
                  ),
                  markers: _markers,
                  myLocationEnabled: !kIsWeb,  // Location button doesn't work on web
                  myLocationButtonEnabled: !kIsWeb,  // Location button doesn't work on web
                  zoomControlsEnabled: true,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    if (kIsWeb) {
                      debugPrint('📍 Map initialized on web');
                    }
                    // Move camera to current position if available
                    if (_currentPosition != null) {
                      controller.animateCamera(
                        CameraUpdate.newLatLngZoom(
                          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                          15.0,
                        ),
                      );
                    }
                  },
                ),

          if (_nearestCheckpoint != null && _distanceToNearest != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => _onMarkerTap(_nearestCheckpoint!),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _distanceToNearest! <= GEOFENCE_RADIUS
                        ? Colors.green.withOpacity(0.95)
                        : const Color(0xFF1A2332).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _distanceToNearest! <= GEOFENCE_RADIUS
                          ? Colors.green
                          : const Color(0xFF00D9FF),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _distanceToNearest! <= GEOFENCE_RADIUS
                            ? Icons.check_circle
                            : Icons.navigation,
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
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              _distanceToNearest! <= GEOFENCE_RADIUS
                                  ? 'TAP TO CHECK IN!'
                                  : '${_distanceToNearest!.toStringAsFixed(0)}m away',
                              style: TextStyle(
                                fontSize: 14,
                                color: _distanceToNearest! <= GEOFENCE_RADIUS
                                    ? Colors.white
                                    : Colors.white70,
                                fontWeight: _distanceToNearest! <= GEOFENCE_RADIUS
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_distanceToNearest! <= GEOFENCE_RADIUS)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'CHECK IN',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          DraggableScrollableSheet(
            initialChildSize: 0.3,
            minChildSize: 0.1,
            maxChildSize: 0.7,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1A2332),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white38,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.flag, color: Color(0xFF00D9FF)),
                          const SizedBox(width: 8),
                          Text(
                            'Progress: ${_arrivedCheckpoints.length}/${_checkpoints.length} checkpoints',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _checkpoints.length,
                        itemBuilder: (context, index) {
                          final checkpoint = _checkpoints[index];
                          final checkpointId = checkpoint['id'] as String?;
                          final latitude = checkpoint['latitude'] as double?;
                          final longitude = checkpoint['longitude'] as double?;

                          // Skip if missing required data
                          if (checkpointId == null || latitude == null || longitude == null) {
                            return const SizedBox.shrink();
                          }

                          final isArrived = _arrivedCheckpoints.contains(checkpointId);
                          final distance = _currentPosition != null
                              ? _calculateDistance(
                                  _currentPosition!.latitude,
                                  _currentPosition!.longitude,
                                  latitude,
                                  longitude,
                                )
                              : null;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: isArrived
                                ? Colors.green.withOpacity(0.2)
                                : const Color(0xFF0A1628),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isArrived
                                    ? Colors.green
                                    : const Color(0xFF00D9FF).withOpacity(0.3),
                              ),
                            ),
                            child: ListTile(
                              onTap: () => _onMarkerTap(checkpoint),
                              leading: CircleAvatar(
                                backgroundColor: isArrived
                                    ? Colors.green
                                    : const Color(0xFF00D9FF),
                                child: isArrived
                                    ? const Icon(Icons.check, color: Colors.white)
                                    : Text(
                                        '${checkpoint['sequence_order'] ?? index + 1}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                              ),
                              title: Text(
                                checkpoint['name'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isArrived ? Colors.green : Colors.white,
                                ),
                              ),
                              subtitle: Text(
                                isArrived
                                    ? '✅ Completed'
                                    : distance != null
                                        ? '${distance.toStringAsFixed(0)}m away'
                                        : 'Calculating...',
                                style: TextStyle(
                                  color: isArrived ? Colors.green : Colors.white70,
                                ),
                              ),
                              trailing: Icon(
                                isArrived ? Icons.task_alt : Icons.arrow_forward_ios,
                                color: isArrived ? Colors.green : Colors.white54,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // HuntSphere watermark for screenshots
          const HuntSphereWatermark(
            alignment: Alignment.topRight,
            opacity: 0.6,
          ),
        ],
      ),
      // Chatbot FAB
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.25),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ChatbotScreen()),
            );
          },
          tooltip: 'Open Chatbot Assistant',
          backgroundColor: const Color(0xFF7B68EE),
          child: const Icon(Icons.smart_toy, semanticLabel: 'Chatbot'),
        ),
      ),
    );
  }
}
