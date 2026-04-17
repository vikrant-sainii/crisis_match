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

class VictimMapScreen extends StatefulWidget {
  final HelpRequestModel request;

  const VictimMapScreen({super.key, required this.request});

  @override
  State<VictimMapScreen> createState() => _VictimMapScreenState();
}

class _VictimMapScreenState extends State<VictimMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  StreamSubscription<Position>? _positionStream;
  StreamSubscription? _requestStream;

  LatLng? _myLocation; // Victim's live location
  LatLng? _helperLocation; // Helper's live location
  double? _distanceMeters;
  bool _isFirstLocation = true;
  
  List<LatLng> _polylineCoordinates = [];

  @override
  void initState() {
    super.initState();
    // Set initial positions from request
    if (widget.request.victimCurrLat != 0.0 && widget.request.victimCurrLong != 0.0) {
      _myLocation = LatLng(widget.request.victimCurrLat, widget.request.victimCurrLong);
    }
    if (widget.request.helperLat != null && widget.request.helperLng != null) {
      _helperLocation = LatLng(
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

  /// Start streaming victim's own location via GPS
  void _startLocationTracking() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      ),
    ).listen((Position position) {
      setState(() {
        _myLocation = LatLng(position.latitude, position.longitude);
        _updateDistance();
      });
      if (_isFirstLocation) {
        _isFirstLocation = false;
        _fitBothMarkers();
      }
      
      // We only fetch the route occasionally when we move
      _fetchRoute();
    });
  }

  /// Subscribes to the Helper's mission-specific location in the request_table
  void _subscribeToRequestUpdates() {
    _requestStream = Supabase.instance.client
        .from('request_table')
        .stream(primaryKey: ['request_id'])
        .eq('request_id', widget.request.id)
        .listen((data) {
      if (data.isNotEmpty) {
        final row = data.first;
        final helperLat = (row['helper_curr_lat'] as num?)?.toDouble();
        final helperLng = (row['helper_curr_long'] as num?)?.toDouble();
        
        // If helper location physically changed
        if (helperLat != null && helperLng != null) {
          final newLocation = LatLng(helperLat, helperLng);
          if (_helperLocation == null ||
              _helperLocation!.latitude != newLocation.latitude ||
              _helperLocation!.longitude != newLocation.longitude) {
            setState(() {
              _helperLocation = newLocation;
              _updateDistance();
            });
            _fetchRoute(); // Recalculate route polyline
          }
        }
      }
    });
  }

  void _updateDistance() {
    if (_myLocation != null && _helperLocation != null) {
      _distanceMeters = Geolocator.distanceBetween(
        _myLocation!.latitude, _myLocation!.longitude,
        _helperLocation!.latitude, _helperLocation!.longitude
      );
    }
  }
  
  Future<void> _fetchRoute() async {
    if (_myLocation == null || _helperLocation == null) return;
    
    try {
      final url = 'https://maps.googleapis.com/maps/api/directions/json?origin=${_myLocation!.latitude},${_myLocation!.longitude}&destination=${_helperLocation!.latitude},${_helperLocation!.longitude}&key=${SupabaseConfig.googleMapsApiKey}';
      final response = await http.get(Uri.parse(url));
      final json = jsonDecode(response.body);
      
      if (json['routes'] != null && json['routes'].isNotEmpty) {
        final points = json['routes'][0]['overview_polyline']['points'];
        setState(() {
          _polylineCoordinates = _decodePoly(points);
        });
      }
    } catch (e) {
      developer.log('VictimMap: Failed to fetch route: $e');
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
    if (_myLocation == null || _helperLocation == null) return;
    try {
      final GoogleMapController controller = await _mapController.future;
      final meters = Geolocator.distanceBetween(
        _myLocation!.latitude, _myLocation!.longitude,
        _helperLocation!.latitude, _helperLocation!.longitude
      );
      
      if (meters < 50) {
        controller.animateCamera(CameraUpdate.newLatLngZoom(_myLocation!, 16));
        return;
      }
      
      double minLat = _myLocation!.latitude < _helperLocation!.latitude ? _myLocation!.latitude : _helperLocation!.latitude;
      double maxLat = _myLocation!.latitude > _helperLocation!.latitude ? _myLocation!.latitude : _helperLocation!.latitude;
      double minLng = _myLocation!.longitude < _helperLocation!.longitude ? _myLocation!.longitude : _helperLocation!.longitude;
      double maxLng = _myLocation!.longitude > _helperLocation!.longitude ? _myLocation!.longitude : _helperLocation!.longitude;
      
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
      
      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
    } catch (e) {
      developer.log('VictimMap: fitBounds error: $e');
      if (_myLocation != null) {
        final GoogleMapController controller = await _mapController.future;
        controller.animateCamera(CameraUpdate.newLatLngZoom(_myLocation!, 14));
      }
    }
  }

  String _formatDistance(double? meters) {
    if (meters == null) return 'Waiting for helper...';
    if (meters < 1000) return '${meters.round()} m away';
    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }

  @override
  Widget build(BuildContext context) {
    final Set<Marker> markers = {};
    if (_myLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('me'),
        position: _myLocation!,
        infoWindow: const InfoWindow(title: 'You'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }
    if (_helperLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('helper'),
        position: _helperLocation!,
        infoWindow: const InfoWindow(title: 'Helper'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }
    
    final Set<Polyline> polylines = {};
    if (_polylineCoordinates.isNotEmpty) {
      polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: _polylineCoordinates,
        color: Colors.blue.withValues(alpha: 0.7),
        width: 5,
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Helper Route'),
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
                // After 1 sec of drawing, auto-fit coordinates
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
                  const Icon(Icons.local_hospital, color: Colors.green, size: 24),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Helper approaching',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _helperLocation != null ? Colors.green[50] : Colors.orange[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formatDistance(_distanceMeters),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _helperLocation != null ? Colors.green[700] : Colors.orange[700],
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
                    color: _helperLocation != null ? Colors.green : Colors.orange
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _helperLocation != null
                        ? 'Helper is live on the map'
                        : 'Waiting for helper to open map...',
                    style: TextStyle(
                      fontSize: 12,
                      color: _helperLocation != null ? Colors.green[600] : Colors.orange[600],
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
