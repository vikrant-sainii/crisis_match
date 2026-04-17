import 'package:equatable/equatable.dart';

class HelperModel extends Equatable {
  final String id;
  final String profileId;
  final String occupation;
  final String? state;
  final double? lat;
  final double? lng;
  final bool isAvailable;
  final String? addedBy;
  final DateTime? createdAt;

  const HelperModel({
    required this.id,
    required this.profileId,
    required this.occupation,
    this.state,
    this.lat,
    this.lng,
    this.isAvailable = true,
    this.addedBy,
    this.createdAt,
  });

  factory HelperModel.fromJson(Map<String, dynamic> json) {
    // Handle is_available as bool or string
    bool available = true;
    final raw = json['is_available'];
    if (raw is bool) {
      available = raw;
    } else if (raw is String) {
      available = raw.toLowerCase() == 'true';
    }

    return HelperModel(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      occupation: json['occupation'] as String? ?? '',
      state: json['state'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      isAvailable: available,
      addedBy: json['added_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profile_id': profileId,
      'occupation': occupation,
      'state': state,
      'lat': lat,
      'lng': lng,
      'is_available': isAvailable,
      'added_by': addedBy,
    };
  }

  HelperModel copyWith({
    bool? isAvailable,
    double? lat,
    double? lng,
  }) {
    return HelperModel(
      id: id,
      profileId: profileId,
      occupation: occupation,
      state: state,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      isAvailable: isAvailable ?? this.isAvailable,
      addedBy: addedBy,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, profileId, occupation, state, lat, lng, isAvailable, addedBy, createdAt];
}
