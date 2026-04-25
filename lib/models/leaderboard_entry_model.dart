import 'package:equatable/equatable.dart';

class LeaderboardEntry extends Equatable {
  final String helperId;
  final String name;
  final String occupation;
  final double totalScore;
  final int totalHelps;
  final double avgRating;
  final int rank;
  final double? lat;
  final double? lng;

  const LeaderboardEntry({
    required this.helperId,
    required this.name,
    required this.occupation,
    required this.totalScore,
    required this.totalHelps,
    required this.avgRating,
    required this.rank,
    this.lat,
    this.lng,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json, {required int rank}) {
    return LeaderboardEntry(
      helperId: json['helper_id'] ?? '',
      name: json['name'] ?? 'Anonymous Helper',
      occupation: json['occupation'] ?? 'Volunteer',
      totalScore: (json['total_score'] ?? 0).toDouble(),
      totalHelps: json['total_helps'] ?? 0,
      avgRating: (json['avg_rating'] ?? 0).toDouble(),
      rank: rank,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }

  @override
  List<Object?> get props => [helperId, name, occupation, totalScore, totalHelps, avgRating, rank, lat, lng];
}
