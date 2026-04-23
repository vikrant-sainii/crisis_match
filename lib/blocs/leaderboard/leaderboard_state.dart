import 'package:equatable/equatable.dart';
import '../../models/leaderboard_entry_model.dart';

abstract class LeaderboardState extends Equatable {
  const LeaderboardState();

  @override
  List<Object?> get props => [];
}

class LeaderboardInitial extends LeaderboardState {
  const LeaderboardInitial();
}

class LeaderboardLoading extends LeaderboardState {
  const LeaderboardLoading();
}

class LeaderboardLoaded extends LeaderboardState {
  final List<LeaderboardEntry> entries;
  final List<String> occupations; // For filter tabs
  final String? selectedOccupation;

  const LeaderboardLoaded({
    required this.entries,
    required this.occupations,
    this.selectedOccupation,
  });

  @override
  List<Object?> get props => [entries, selectedOccupation];
}

class LeaderboardError extends LeaderboardState {
  final String message;

  const LeaderboardError(this.message);

  @override
  List<Object?> get props => [message];
}
