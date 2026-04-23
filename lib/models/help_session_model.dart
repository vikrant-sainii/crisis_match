import 'package:equatable/equatable.dart';

/// Represents a single help session, used for scoring and history.
/// Completely isolated from HelpRequestModel.
class HelpSessionModel extends Equatable {
  final String? id;
  final String requestId;
  final String helperId;
  final String victimId;
  final String status; // 'accepted' | 'completed' | 'cancelled'
  final DateTime requestCreatedAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final int? responseTimeSec;
  final int? victimRating;
  final double ratingMultiplier;
  final int speedBonus;
  final int completionPoints;
  final int cancellationPenalty;
  final double totalScore;

  const HelpSessionModel({
    this.id,
    required this.requestId,
    required this.helperId,
    required this.victimId,
    required this.status,
    required this.requestCreatedAt,
    this.acceptedAt,
    this.completedAt,
    this.responseTimeSec,
    this.victimRating,
    this.ratingMultiplier = 1.0,
    this.speedBonus = 0,
    this.completionPoints = 50,
    this.cancellationPenalty = -40,
    this.totalScore = 0,
  });

  Map<String, dynamic> toInsertJson() {
    return {
      'request_id': requestId,
      'helper_id': helperId,
      'victim_id': victimId,
      'status': status,
      'request_created_at': requestCreatedAt.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
    };
  }

  factory HelpSessionModel.fromJson(Map<String, dynamic> json) {
    return HelpSessionModel(
      id: json['id'] as String?,
      requestId: json['request_id'] as String? ?? '',
      helperId: json['helper_id'] as String? ?? '',
      victimId: json['victim_id'] as String? ?? '',
      status: json['status'] as String? ?? 'accepted',
      requestCreatedAt: DateTime.parse(json['request_created_at'] as String),
      acceptedAt: json['accepted_at'] != null ? DateTime.parse(json['accepted_at'] as String) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
      responseTimeSec: json['response_time_sec'] as int?,
      victimRating: json['victim_rating'] as int?,
      ratingMultiplier: (json['rating_multiplier'] as num?)?.toDouble() ?? 1.0,
      speedBonus: (json['speed_bonus'] as num?)?.toInt() ?? 0,
      completionPoints: (json['completion_points'] as num?)?.toInt() ?? 50,
      cancellationPenalty: (json['cancellation_penalty'] as num?)?.toInt() ?? -40,
      totalScore: (json['total_score'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  List<Object?> get props => [id, requestId, helperId, status];
}
