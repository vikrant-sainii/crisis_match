import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/leaderboard_repository.dart';
import 'leaderboard_event.dart';
import 'leaderboard_state.dart';

class LeaderboardBloc extends Bloc<LeaderboardEvent, LeaderboardState> {
  final LeaderboardRepository repository;
  List<String> _cachedOccupations = [];

  LeaderboardBloc({required this.repository}) : super(const LeaderboardInitial()) {
    on<LoadLeaderboard>(_onLoadLeaderboard);
    on<FilterLeaderboard>(_onFilterLeaderboard);
  }

  Future<void> _onLoadLeaderboard(
    LoadLeaderboard event,
    Emitter<LeaderboardState> emit,
  ) async {
    emit(const LeaderboardLoading());
    try {
      // Fetch both data and unique occupations for filters
      final results = await repository.fetchLeaderboard();
      _cachedOccupations = await repository.fetchOccupations();

      emit(LeaderboardLoaded(
        entries: results,
        occupations: _cachedOccupations,
        selectedOccupation: null,
      ));
    } catch (e) {
      emit(LeaderboardError('Failed to load leaderboard: ${e.toString()}'));
    }
  }

  Future<void> _onFilterLeaderboard(
    FilterLeaderboard event,
    Emitter<LeaderboardState> emit,
  ) async {
    // We only filter if we are already in a loaded state effectively
    // But we re-fetch from repo to get accurate top 10 for THAT occupation
    emit(const LeaderboardLoading());
    try {
      final results = await repository.fetchLeaderboard(occupation: event.occupation);
      
      emit(LeaderboardLoaded(
        entries: results,
        occupations: _cachedOccupations,
        selectedOccupation: event.occupation,
      ));
    } catch (e) {
      emit(LeaderboardError('Failed to filter leaderboard: ${e.toString()}'));
    }
  }
}
