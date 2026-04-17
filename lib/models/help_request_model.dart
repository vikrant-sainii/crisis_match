import 'package:equatable/equatable.dart';

class HelpRequestModel extends Equatable {
  final String id; // maps to request_id
  final String victimId;
  final String helperId;
  final String status;
  final String crisisType;
  final double victimCurrLat;
  final double victimCurrLong;
  final double? helperCurrLat;
  final double? helperCurrLong;
  final String? txHash;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? matchedId; // ID from the matching session/table

  // Joined fields (not in request_table, but fetched via SQL joins or n8n JSON)
  final double? helperLat; // Base/On-duty lat
  final double? helperLng; // Base/On-duty lng
  final String? helperName;
  final String? helperOccupation;
  final String? helperPhone;
  final String? distance;
  final String? victimName;

  const HelpRequestModel({
    required this.id,
    required this.victimId,
    required this.helperId,
    required this.status,
    required this.crisisType,
    required this.victimCurrLat,
    required this.victimCurrLong,
    this.helperCurrLat,
    this.helperCurrLong,
    this.txHash,
    this.createdAt,
    this.updatedAt,
    this.helperLat,
    this.helperLng,
    this.helperName,
    this.helperOccupation,
    this.helperPhone,
    this.distance,
    this.victimName,
    this.matchedId,
  });

  factory HelpRequestModel.fromJson(Map<String, dynamic> json) {
    // Handle nested helper join if applicable
    double? hBaseLat;
    double? hBaseLng;
    String? hOcc;
    if (json['helpers'] != null) {
      if (json['helpers']['lat'] != null) hBaseLat = (json['helpers']['lat'] as num).toDouble();
      if (json['helpers']['lng'] != null) hBaseLng = (json['helpers']['lng'] as num).toDouble();
      hOcc = json['helpers']['occupation'] as String?;
    }
    
    // Handle specific N8N JSON payload mapping if required
    if (json['helper_lat'] != null) hBaseLat = (json['helper_lat'] as num).toDouble();
    if (json['helper_lng'] != null) hBaseLng = (json['helper_lng'] as num).toDouble();

    // Mission-specific location (helper_curr_lat/long)
    final double? hCurrLat = (json['helper_curr_lat'] as num?)?.toDouble();
    final double? hCurrLong = (json['helper_curr_long'] as num?)?.toDouble();

    return HelpRequestModel(
      id: json['request_id'] as String? ?? json['id'] as String? ?? '',
      victimId: json['victim_id'] as String? ?? '',
      helperId: json['helper_id'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      crisisType: json['crisis_type'] as String? ?? 'general',
      victimCurrLat: (json['victim_curr_lat'] as num?)?.toDouble() ?? 0.0,
      victimCurrLong: (json['victim_curr_long'] as num?)?.toDouble() ?? 0.0,
      helperCurrLat: hCurrLat ?? hBaseLat, // Initializing with base lat if mission-specific is null
      helperCurrLong: hCurrLong ?? hBaseLng, // Initializing with base lng if mission-specific is null
      txHash: json['tx_hash'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      helperLat: hBaseLat,
      helperLng: hBaseLng,
      helperOccupation: hOcc,
      helperName: json['helper_name'] as String?, // From temporary joining or n8n logic
      helperPhone: json['helper_phone'] as String?,
      distance: json['distance']?.toString(), // From n8n response
      victimName: json['victim_name'] as String?, // From Supabase join
      matchedId: json['matched_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'request_id': id,
      'victim_id': victimId,
      'helper_id': helperId,
      'status': status,
      'crisis_type': crisisType,
      'victim_curr_lat': victimCurrLat,
      'victim_curr_long': victimCurrLong,
      'helper_curr_lat': helperCurrLat,
      'helper_curr_long': helperCurrLong,
      'tx_hash': txHash,
      'matched_id': matchedId,
      'helper_phone': helperPhone,
    };
  } 
                                       
  HelpRequestModel copyWith({
    String? status,
    String? txHash,
    double? victimCurrLat,
    double? victimCurrLong,
    double? helperCurrLat,
    double? helperCurrLong,
    double? helperLat,
    double? helperLng,
    String? helperName,
    String? helperOccupation,
    String? helperPhone,
    String? distance,
    String? matchedId,
  }) {
    return HelpRequestModel(
      id: id,
      victimId: victimId,
      helperId: helperId,
      status: status ?? this.status,
      crisisType: crisisType,
      victimCurrLat: victimCurrLat ?? this.victimCurrLat,
      victimCurrLong: victimCurrLong ?? this.victimCurrLong,
      helperCurrLat: helperCurrLat ?? this.helperCurrLat,
      helperCurrLong: helperCurrLong ?? this.helperCurrLong,
      txHash: txHash ?? this.txHash,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      helperLat: helperLat ?? this.helperLat,
      helperLng: helperLng ?? this.helperLng,
      helperName: helperName ?? this.helperName,
      helperOccupation: helperOccupation ?? this.helperOccupation,
      helperPhone: helperPhone ?? this.helperPhone,
      distance: distance ?? this.distance,
      victimName: victimName ?? victimName,
      matchedId: matchedId ?? this.matchedId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        victimId,
        helperId,
        status,
        crisisType,
        victimCurrLat,
        victimCurrLong,
        helperCurrLat,
        helperCurrLong,
        txHash,
        helperLat,
        helperLng,
        helperName,
        helperOccupation,
        helperPhone,
        distance,
        victimName,
        matchedId,
      ];
}
