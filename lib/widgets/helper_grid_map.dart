import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../blocs/admin/admin_bloc.dart';
import '../blocs/admin/admin_event.dart';
import '../blocs/admin/admin_state.dart';
import '../blocs/location/location_bloc.dart';
import '../blocs/location/location_state.dart';

class HelperGridMap extends StatefulWidget {
  const HelperGridMap({super.key});

  @override
  State<HelperGridMap> createState() => _HelperGridMapState();
}

class _HelperGridMapState extends State<HelperGridMap> {
  final Map<String, BitmapDescriptor> _markerCache = {};

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocationBloc, LocationState>(
      builder: (context, locState) {
        return BlocBuilder<AdminBloc, AdminState>(
          builder: (context, state) {
            if (state is AdminLoading) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF22D3EE)),
              );
            }
            if (state is AdminDataLoaded) {
              final helpers = state.helpers;
              _preLoadMarkers(helpers);

              final filteredHelpers = state.selectedOccupation == null
                  ? helpers
                  : helpers
                        .where(
                          (h) => h['occupation'] == state.selectedOccupation,
                        )
                        .toList();

              LatLng? victimPos;
              if (locState is LocationLoaded) {
                victimPos = LatLng(locState.lat, locState.lng);
              }

              final Set<Marker> markers = filteredHelpers.map((h) {
                final name = h['profiles']['full_name'] as String;
                final occupation = h['occupation'] as String;
                
                String distText = '';
                if (victimPos != null) {
                  final dist = Geolocator.distanceBetween(
                    victimPos.latitude, victimPos.longitude, h['lat'], h['lng']);
                  distText = ' (${(dist / 1000).toStringAsFixed(1)} KM)';
                }

                return Marker(
                  markerId: MarkerId(h['id']),
                  position: LatLng(h['lat'] ?? 0, h['lng'] ?? 0),
                  icon:
                      _markerCache['$name-$occupation'] ??
                      BitmapDescriptor.defaultMarker,
                  infoWindow: InfoWindow(
                    title: name,
                    snippet: '${occupation.toUpperCase()}$distText',
                  ),
                );
              }).toSet();

              if (victimPos != null) {
                markers.add(
                  Marker(
                    markerId: const MarkerId('victim_me'),
                    position: victimPos,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueCyan,
                    ),
                    infoWindow: const InfoWindow(title: 'YOU'),
                  ),
                );
              }

              return Column(
                children: [
                  _buildMapFilter(state.occupations),
                  Expanded(
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target:
                            victimPos ??
                            const LatLng(
                              19.0760,
                              72.8777,
                            ), // Victim or default Mumbai
                        zoom: 12,
                      ),
                      myLocationEnabled: true,
                      gestureRecognizers:
                          <Factory<OneSequenceGestureRecognizer>>{
                            Factory<OneSequenceGestureRecognizer>(
                              () => EagerGestureRecognizer(),
                            ),
                          },
                      markers: markers,
                    ),
                  ),
                ],
              );
            }
            return const Center(
              child: Text(
                'UPLINK ERROR: GRID DATA UNAVAILABLE',
                style: TextStyle(
                  color: Colors.blueGrey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMapFilter(List<String> occupations) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFF1E293B),
      child: Row(
        children: [
          const Text(
            'TACTICAL FILTER: ',
            style: TextStyle(
              color: Colors.blueGrey,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(null, 'ALL'),
                  ...occupations.map(
                    (o) => _buildFilterChip(
                      o,
                      o.toUpperCase().replaceAll('_', ' '),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String? value, String label) {
    return BlocBuilder<AdminBloc, AdminState>(
      builder: (context, state) {
        final isSelected =
            state is AdminDataLoaded && state.selectedOccupation == value;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
            selected: isSelected,
            onSelected: (val) {
              if (val) {
                context.read<AdminBloc>().add(FilterHelpersByOccupation(value));
              }
            },
            selectedColor: const Color(0xFF22D3EE),
            backgroundColor: const Color(0xFF334155),
            labelStyle: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      },
    );
  }

  void _preLoadMarkers(List<Map<String, dynamic>> helpers) async {
    bool changed = false;
    for (var h in helpers) {
      final name = h['profiles']['full_name'] as String;
      final occupation = h['occupation'] as String;
      final key = '$name-$occupation';
      if (!_markerCache.containsKey(key)) {
        await _getMarkerIcon(name, occupation);
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  Future<BitmapDescriptor> _getMarkerIcon(
    String name,
    String occupation,
  ) async {
    final key = '$name-$occupation';
    if (_markerCache.containsKey(key)) return _markerCache[key]!;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    const width = 240.0;
    const height = 80.0;

    final paint = ui.Paint()
      ..color = _getOccupationColor(occupation)
      ..style = ui.PaintingStyle.fill;

    // Draw bubble
    final rrect = RRect.fromLTRBR(
      0,
      0,
      width,
      height - 20,
      const Radius.circular(12),
    );
    canvas.drawRRect(rrect, paint);

    // Draw point
    final path = ui.Path()
      ..moveTo(width / 2 - 10, height - 20)
      ..lineTo(width / 2 + 10, height - 20)
      ..lineTo(width / 2, height)
      ..close();
    canvas.drawPath(path, paint);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.text = TextSpan(
      children: [
        TextSpan(
          text: '${occupation.toUpperCase()}\n',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextSpan(
          text: name.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );

    textPainter.layout(minWidth: width, maxWidth: width);
    textPainter.paint(canvas, const Offset(0, 10));

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final descriptor = BitmapDescriptor.fromBytes(
      byteData!.buffer.asUint8List(),
    );

    _markerCache[key] = descriptor;
    return descriptor;
  }

  Color _getOccupationColor(String occ) {
    occ = occ.toLowerCase();
    if (occ.contains('police')) return Colors.blueAccent;
    if (occ.contains('hospital') || occ.contains('medical')) {
      return Colors.redAccent;
    }
    if (occ.contains('fire')) return Colors.orangeAccent;
    return const ui.Color.fromARGB(255, 155, 14, 226);
  }
}
