import 'package:equatable/equatable.dart';
import '../../models/help_request_model.dart';

abstract class HelpRequestState extends Equatable {
  const HelpRequestState();

  @override
  List<Object?> get props => [];
}

class HelpRequestInitial extends HelpRequestState {}

/// Victim is waiting for AI to find a helper
class HelpRequestSearching extends HelpRequestState {}

/// Active state handling a specific request in any status (pending, accepted, completed, etc.)
class HelpRequestActive extends HelpRequestState {
  final HelpRequestModel request;
  final String? matchedId; // The pointer for the N8N array
  final String? distance; // E.g., "2.5 km"

  const HelpRequestActive(this.request, {this.matchedId, this.distance});

  @override
  List<Object?> get props => [request, matchedId, distance];
}

/// Loaded for Helper's tab viewer (contains ALL requests split by status locally)
class HelperRequestsLoaded extends HelpRequestState {
  final List<HelpRequestModel> requests;
  const HelperRequestsLoaded(this.requests);

  @override
  List<Object?> get props => [requests];
}

class HelpRequestError extends HelpRequestState {
  final String message;
  const HelpRequestError(this.message);

  @override
  List<Object?> get props => [message];
}

class HelpRequestConversation extends HelpRequestState {
  final String message;
  final String? audioPath;
  final HelpRequestModel? activeRequest;
  final String? matchedId;
  final String? distance;

  const HelpRequestConversation(
    this.message, {
    this.audioPath,
    this.activeRequest,
    this.matchedId,
    this.distance,
  });

  @override
  List<Object?> get props => [
    message,
    audioPath,
    activeRequest,
    matchedId,
    distance,
  ];
}
