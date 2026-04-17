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
            BitmapDescriptor.hueGreen,
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
          color: Colors.blue.withValues(alpha: 0.7),
          width: 5,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Route to Victim'),
        actions: [
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            tooltip: 'Fit both markers',
            onPressed: _fitBothMarkers,
          ),
        ],
      ),
      body: _myLocation == null
          ? const Center(child: CircularProgressIndicator())
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.person_pin_circle,
                    color: Colors.red,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Navigate to victim',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _victimLocation != null
                          ? Colors.red[50]
                          : Colors.orange[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formatDistance(_distanceMeters),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _victimLocation != null
                            ? Colors.red[700]
                            : Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: _victimLocation != null
                        ? Colors.green
                        : Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _victimLocation != null
                        ? 'Victim location acquired'
                        : 'Waiting for victim location...',
                    style: TextStyle(
                      fontSize: 12,
                      color: _victimLocation != null
                          ? Colors.green[600]
                          : Colors.orange[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
