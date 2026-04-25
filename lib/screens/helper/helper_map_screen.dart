import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../../models/help_request_model.dart';
import '../../config/supabase_config.dart';
import '../../repositories/help_request_repository.dart';

class HelperMapScreen extends StatefulWidget {
  final HelpRequestModel request;

  const HelperMapScreen({super.key, required this.request});

  @override
  State<HelperMapScreen> createState() => _HelperMapScreenState();
}

class _HelperMapScreenState extends State<HelperMapScreen> {
  final Completer<GoogleMapController> _mapController =
      Completer<GoogleMapController>();
  StreamSubscription<Position>? _positionStream;
  StreamSubscription? _requestStream;

  LatLng? _myLocation; // Helper's live location
  LatLng? _victimLocation; // Victim's live location
  double? _distanceMeters;
  bool _isFirstLocation = true;

  List<LatLng> _polylineCoordinates = [];

  @override
  void initState() {
    super.initState();
    // Set initial custom victim position from request
    if (widget.request.victimCurrLat != 0.0 &&
        widget.request.victimCurrLong != 0.0) {
      _victimLocation = LatLng(
        widget.request.victimCurrLat,
        widget.request.victimCurrLong,
      );
    }
    if (widget.request.helperLat != null && widget.request.helperLng != null) {
      _myLocation = LatLng(
        widget.request.helperLat!,
        widget.request.helperLng!,
      );
    }
    _startLocationTracking();
    _subscribeToRequestUpdates();
    _fetchRoute();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _requestStream?.cancel();
    super.dispose();
  }

  /// Start streaming helper's own location via GPS
  void _startLocationTracking() {
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5, // Update every 5 meters
          ),
        ).listen((Position position) {
          setState(() {
            _myLocation = LatLng(position.latitude, position.longitude);
            _updateDistance();
          });

          // PUSH TO MISSION LOG (request_table) instead of global helpers table
          HelpRequestRepository()
              .updateHelperLocation(
                widget.request.id,
                position.latitude,
                position.longitude,
              )
              .catchError(
                (e) => developer.log(
                  'HelperMap: Failed to push mission location: $e',
                ),
              );

          if (_isFirstLocation) {
            _isFirstLocation = false;
            _fitBothMarkers();
          }

          _fetchRoute();
        });
  }

  /// Listen for if the victim changes their location (in case they move)
  void _subscribeToRequestUpdates() {
    _requestStream = Supabase.instance.client
        .from('request_table')
        .stream(primaryKey: ['request_id'])
        .eq('request_id', widget.request.id)
        .listen((data) {
          if (data.isNotEmpty) {
            final row = data.first;
            final victimLat = (row['victim_curr_lat'] as num?)?.toDouble();
            final victimLng = (row['victim_curr_long'] as num?)?.toDouble();
            if (victimLat != null && victimLng != null) {
              final newLocation = LatLng(victimLat, victimLng);
              if (_victimLocation == null ||
                  _victimLocation!.latitude != newLocation.latitude ||
                  _victimLocation!.longitude != newLocation.longitude) {
                setState(() {
                  _victimLocation = newLocation;
                  _updateDistance();
                });
                _fetchRoute();
              }
            }
          }
        });
  }

  void _updateDistance() {
    if (_myLocation != null && _victimLocation != null) {
      _distanceMeters = Geolocator.distanceBetween(
        _myLocation!.latitude,
        _myLocation!.longitude,
        _victimLocation!.latitude,
        _victimLocation!.longitude,
      );
    }
  }

  Future<void> _fetchRoute() async {
    if (_myLocation == null || _victimLocation == null) return;

    try {
      final url =
          'https://maps.googleapis.com/maps/api/directions/json?origin=${_myLocation!.latitude},${_myLocation!.longitude}&destination=${_victimLocation!.latitude},${_victimLocation!.longitude}&key=${SupabaseConfig.googleMapsApiKey}';
      final response = await http.get(Uri.parse(url));
      final json = jsonDecode(response.body);

      if (json['routes'] != null && json['routes'].isNotEmpty) {
        final points = json['routes'][0]['overview_polyline']['points'];
        setState(() {
          _polylineCoordinates = _decodePoly(points);
        });
      }
    } catch (e) {
      developer.log('HelperMap: Failed to fetch route: $e');
    }
  }

  List<LatLng> _decodePoly(String poly) {
    var list = <LatLng>[];
    int index = 0, len = poly.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = poly.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = poly.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      list.add(LatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble()));
    }
    return list;
  }

  Future<void> _fitBothMarkers() async {
    if (_myLocation == null || _victimLocation == null) return;
    try {
      final GoogleMapController controller = await _mapController.future;
      final meters = Geolocator.distanceBetween(
        _myLocation!.latitude,
        _myLocation!.longitude,
        _victimLocation!.latitude,
        _victimLocation!.longitude,
      );

      if (meters < 50) {
        controller.animateCamera(CameraUpdate.newLatLngZoom(_myLocation!, 16));
        return;
      }

      double minLat = _myLocation!.latitude < _victimLocation!.latitude
          ? _myLocation!.latitude
          : _victimLocation!.latitude;
      double maxLat = _myLocation!.latitude > _victimLocation!.latitude
          ? _myLocation!.latitude
          : _victimLocation!.latitude;
      double minLng = _myLocation!.longitude < _victimLocation!.longitude
          ? _myLocation!.longitude
          : _victimLocation!.longitude;
      double maxLng = _myLocation!.longitude > _victimLocation!.longitude
          ? _myLocation!.longitude
          : _victimLocation!.longitude;

      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );

      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
    } catch (e) {
      developer.log('HelperMap: fitBounds error: $e');
      if (_myLocation != null) {
        final GoogleMapController controller = await _mapController.future;
        controller.animateCamera(CameraUpdate.newLatLngZoom(_myLocation!, 14));
      }
    }
  }

  String _formatDistance(double? meters) {
    if (meters == null) return 'Calculating distance...';
    if (meters < 1000) return '${meters.round()} m away';
    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }

  @override
  Widget build(BuildContext context) {
    final Set<Marker> markers = {};
    if (_myLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('me'),
          position: _myLocation!,
          infoWindow: const InfoWindow(title: 'You (Helper)'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }
    if (_victimLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('victim'),
          position: _victimLocation!,
          infoWindow: const InfoWindow(title: 'Victim'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    final Set<Polyline> polylines = {};
    if (_polylineCoordinates.isNotEmpty) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: _polylineCoordinates,
          color: const Color(0xFF2563EB).withValues(alpha: 0.7),
          width: 5,
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'MISSION TRACKING',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.center_focus_strong, color: Color(0xFF2563EB)),
            tooltip: 'Fit both markers',
            onPressed: _fitBothMarkers,
          ),
        ],
      ),
      body: _myLocation == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: CameraPosition(
                target: _myLocation ?? const LatLng(0, 0),
                zoom: 14,
              ),
              markers: markers,
              polylines: polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              onMapCreated: (GoogleMapController controller) {
                _mapController.complete(controller);
                Future.delayed(const Duration(seconds: 1), _fitBothMarkers);
              },
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFFEF4444),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TARGET ACQUIRED',
                        style: TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        _formatDistance(_distanceMeters),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {}, // Optional: Open system maps
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: const Text('NAVIGATE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 10,
                  color: _victimLocation != null
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 8),
                Text(
                  _victimLocation != null
                      ? 'Live victim signal connected'
                      : 'Acquiring victim coordinates...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _victimLocation != null
                        ? const Color(0xFF059669)
                        : const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
