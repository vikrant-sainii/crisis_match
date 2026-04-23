import 'package:equatable/equatable.dart';

abstract class LeaderboardEvent extends Equatable {
  const LeaderboardEvent();

  @override
  List<Object?> get props => [];
}

class LoadLeaderboard extends LeaderboardEvent {
  const LoadLeaderboard();
}

class FilterLeaderboard extends LeaderboardEvent {
  final String? occupation;

  const FilterLeaderboard(this.occupation);

  @override
  List<Object?> get props => [occupation];
}
