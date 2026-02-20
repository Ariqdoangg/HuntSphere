import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

/// Service for monitoring network connectivity
class ConnectivityService {
  // Singleton pattern
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  // Stream controller for connectivity changes
  final _connectivityController = StreamController<bool>.broadcast();

  /// Stream of connectivity status (true = online, false = offline)
  Stream<bool> get onConnectivityChanged => _connectivityController.stream;

  bool _isOnline = true;

  /// Current connectivity status
  bool get isOnline => _isOnline;

  /// Initialize the connectivity service
  Future<void> initialize() async {
    // Check initial connectivity
    await checkConnectivity();

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _handleConnectivityChange(results);
    });
  }

  /// Check current connectivity status
  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _handleConnectivityChange(results);
      return _isOnline;
    } catch (e) {
      debugPrint('ConnectivityService.checkConnectivity error: $e');
      return false;
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;

    // Check if any connection type is available
    _isOnline = results.any((result) =>
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet);

    // Only emit if status changed
    if (wasOnline != _isOnline) {
      debugPrint('Connectivity changed: ${_isOnline ? "Online" : "Offline"}');
      _connectivityController.add(_isOnline);
    }
  }

  /// Get a human-readable connection type description
  Future<String> getConnectionType() async {
    try {
      final results = await _connectivity.checkConnectivity();

      if (results.contains(ConnectivityResult.wifi)) {
        return 'WiFi';
      } else if (results.contains(ConnectivityResult.mobile)) {
        return 'Mobile Data';
      } else if (results.contains(ConnectivityResult.ethernet)) {
        return 'Ethernet';
      } else if (results.contains(ConnectivityResult.vpn)) {
        return 'VPN';
      } else {
        return 'No Connection';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    _connectivityController.close();
  }
}

/// Mixin to add connectivity awareness to StatefulWidgets
mixin ConnectivityAware<T extends StatefulWidget> on State<T> {
  final ConnectivityService _connectivityService = ConnectivityService();
  StreamSubscription<bool>? _connectivitySubscription;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  @override
  void initState() {
    super.initState();
    _isOnline = _connectivityService.isOnline;
    _connectivitySubscription =
        _connectivityService.onConnectivityChanged.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
        });
        onConnectivityChanged(isOnline);
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  /// Override this method to handle connectivity changes
  void onConnectivityChanged(bool isOnline) {
    // Override in subclass to handle connectivity changes
  }
}
