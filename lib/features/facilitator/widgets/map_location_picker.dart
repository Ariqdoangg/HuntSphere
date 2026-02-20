import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/theme/app_theme.dart';

/// A full-screen map picker for selecting checkpoint locations
/// Allows tapping on map or searching by address to set location
class MapLocationPicker extends StatefulWidget {
  /// Initial latitude (optional)
  final double? initialLatitude;

  /// Initial longitude (optional)
  final double? initialLongitude;

  /// Initial radius for the geofence circle preview
  final double radiusMeters;

  const MapLocationPicker({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.radiusMeters = 20,
  });

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  String? _addressText;
  bool _isLoading = true;
  bool _isSearching = false;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  // Default to UPSI Malaysia if no location provided
  static const LatLng _defaultLocation = LatLng(3.6891, 101.5088);

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    // Don't dispose map controller on web - it causes issues
    // The GoogleMap widget will handle its own cleanup
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    LatLng initialPosition;

    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      // Use provided coordinates
      initialPosition = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      _selectedLocation = initialPosition;
    } else {
      // Try to get current location
      try {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          await Geolocator.requestPermission();
        }

        final currentPermission = await Geolocator.checkPermission();
        if (currentPermission == LocationPermission.always ||
            currentPermission == LocationPermission.whileInUse) {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10), // Add timeout for web
          );
          initialPosition = LatLng(position.latitude, position.longitude);
        } else {
          initialPosition = _defaultLocation;
        }
      } catch (e) {
        initialPosition = _defaultLocation;
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      // Get address for initial/selected location
      if (_selectedLocation != null) {
        _getAddressFromLatLng(_selectedLocation!);
      }
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final parts = <String>[];

        if (place.name != null && place.name!.isNotEmpty) {
          parts.add(place.name!);
        }
        if (place.street != null && place.street!.isNotEmpty && place.street != place.name) {
          parts.add(place.street!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          parts.add(place.locality!);
        }
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          parts.add(place.administrativeArea!);
        }

        setState(() {
          _addressText = parts.take(3).join(', ');
        });
      }
    } catch (e) {
      // Geocoding failed, just show coordinates
      setState(() {
        _addressText = null;
      });
    }
  }

  Future<void> _searchAddress(String query) async {
    if (query.trim().isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final locations = await locationFromAddress(query);

      if (locations.isNotEmpty) {
        final location = locations.first;
        final newPosition = LatLng(location.latitude, location.longitude);

        setState(() {
          _selectedLocation = newPosition;
        });

        if (mounted && _mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(newPosition, 17),
          );
        }

        _getAddressFromLatLng(newPosition);
        _searchFocusNode.unfocus();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location not found'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: ${e.toString().split(':').last.trim()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _selectedLocation = position;
    });
    _getAddressFromLatLng(position);
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final newPermission = await Geolocator.requestPermission();
        if (newPermission == LocationPermission.denied ||
            newPermission == LocationPermission.deniedForever) {
          throw Exception('Location permission denied');
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10), // Add timeout for web
      );

      final newPosition = LatLng(position.latitude, position.longitude);

      setState(() {
        _selectedLocation = newPosition;
      });

      if (mounted && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(newPosition, 17),
        );
      }

      _getAddressFromLatLng(newPosition);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not get current location: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _confirmLocation() {
    if (_selectedLocation != null) {
      Navigator.pop(context, {
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'address': _addressText,
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please tap on the map to select a location'),
          backgroundColor: AppTheme.warning,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          // Map
          if (!_isLoading)
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _selectedLocation ?? _defaultLocation,
                zoom: 15,
              ),
              style: _darkMapStyle,
              onMapCreated: (controller) {
                _mapController = controller;
                // Move camera to selected location or current position
                final targetPosition = _selectedLocation ??
                    (widget.initialLatitude != null && widget.initialLongitude != null
                        ? LatLng(widget.initialLatitude!, widget.initialLongitude!)
                        : null);

                if (targetPosition != null) {
                  Future.delayed(const Duration(milliseconds: 300), () {
                    controller.animateCamera(
                      CameraUpdate.newLatLngZoom(targetPosition, 17),
                    );
                  });
                }
              },
              onTap: _onMapTap,
              markers: _selectedLocation != null
                  ? {
                      Marker(
                        markerId: const MarkerId('selected'),
                        position: _selectedLocation!,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueAzure,
                        ),
                      ),
                    }
                  : {},
              circles: _selectedLocation != null
                  ? {
                      Circle(
                        circleId: const CircleId('radius'),
                        center: _selectedLocation!,
                        radius: widget.radiusMeters,
                        fillColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
                        strokeColor: AppTheme.primaryBlue,
                        strokeWidth: 2,
                      ),
                    }
                  : {},
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),

          // Loading overlay
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryBlue,
              ),
            ),

          // Top bar with search
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Column(
                children: [
                  // Search bar and back button
                  Row(
                    children: [
                      // Back button
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundCard,
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                          color: AppTheme.textPrimary,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingS),

                      // Search bar
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundCard,
                            borderRadius: BorderRadius.circular(AppTheme.radiusM),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            style: AppTheme.bodyLarge,
                            decoration: InputDecoration(
                              hintText: 'Search address or place...',
                              hintStyle: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.textMuted,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: AppTheme.primaryBlue,
                              ),
                              suffixIcon: _isSearching
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppTheme.primaryBlue,
                                        ),
                                      ),
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.search),
                                      color: AppTheme.primaryBlue,
                                      onPressed: () => _searchAddress(_searchController.text),
                                    ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spacingM,
                                vertical: AppTheme.spacingM,
                              ),
                            ),
                            onSubmitted: _searchAddress,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Instruction text
                  if (_selectedLocation == null)
                    Container(
                      margin: const EdgeInsets.only(top: AppTheme.spacingM),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingM,
                        vertical: AppTheme.spacingS,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundCard.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.touch_app,
                            color: AppTheme.primaryBlue,
                            size: 18,
                          ),
                          const SizedBox(width: AppTheme.spacingS),
                          Text(
                            'Tap on map to select location',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Bottom panel with location info and confirm button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundCard,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusXL),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle bar
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
                        decoration: BoxDecoration(
                          color: AppTheme.textMuted.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Location info
                      if (_selectedLocation != null) ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(AppTheme.radiusS),
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: AppTheme.primaryBlue,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingM),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_addressText != null)
                                    Text(
                                      _addressText!,
                                      style: AppTheme.bodyLarge.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                                    style: AppTheme.bodySmall.copyWith(
                                      color: AppTheme.textMuted,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                      ] else
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
                          child: Text(
                            'No location selected',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ),

                      // Action buttons
                      Row(
                        children: [
                          // Current location button
                          Container(
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundElevated,
                              borderRadius: BorderRadius.circular(AppTheme.radiusM),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.my_location),
                              color: AppTheme.primaryBlue,
                              onPressed: _goToCurrentLocation,
                              tooltip: 'Use current location',
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingM),

                          // Confirm button
                          Expanded(
                            child: EliteButton(
                              label: 'Confirm Location',
                              icon: Icons.check,
                              onPressed: _selectedLocation != null ? _confirmLocation : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Dark map style JSON
  static const String _darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#1d2c4d"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#8ec3b9"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#1a3646"}]},
  {"featureType": "administrative.country", "elementType": "geometry.stroke", "stylers": [{"color": "#4b6878"}]},
  {"featureType": "administrative.land_parcel", "elementType": "labels.text.fill", "stylers": [{"color": "#64779e"}]},
  {"featureType": "administrative.province", "elementType": "geometry.stroke", "stylers": [{"color": "#4b6878"}]},
  {"featureType": "landscape.man_made", "elementType": "geometry.stroke", "stylers": [{"color": "#334e87"}]},
  {"featureType": "landscape.natural", "elementType": "geometry", "stylers": [{"color": "#023e58"}]},
  {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#283d6a"}]},
  {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#6f9ba5"}]},
  {"featureType": "poi", "elementType": "labels.text.stroke", "stylers": [{"color": "#1d2c4d"}]},
  {"featureType": "poi.park", "elementType": "geometry.fill", "stylers": [{"color": "#023e58"}]},
  {"featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [{"color": "#3C7680"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#304a7d"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#98a5be"}]},
  {"featureType": "road", "elementType": "labels.text.stroke", "stylers": [{"color": "#1d2c4d"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#2c6675"}]},
  {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#255763"}]},
  {"featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [{"color": "#b0d5ce"}]},
  {"featureType": "road.highway", "elementType": "labels.text.stroke", "stylers": [{"color": "#023e58"}]},
  {"featureType": "transit", "elementType": "labels.text.fill", "stylers": [{"color": "#98a5be"}]},
  {"featureType": "transit", "elementType": "labels.text.stroke", "stylers": [{"color": "#1d2c4d"}]},
  {"featureType": "transit.line", "elementType": "geometry.fill", "stylers": [{"color": "#283d6a"}]},
  {"featureType": "transit.station", "elementType": "geometry", "stylers": [{"color": "#3a4762"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0e1626"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#4e6d70"}]}
]
''';
}
