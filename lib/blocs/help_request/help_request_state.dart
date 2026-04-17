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

/// Base class for any active state handling a specific request
abstract class HelpRequestActive extends HelpRequestState {
  final HelpRequestModel request;
  final String? matchedId; // The pointer for the N8N array
  final String? distance; // E.g., "2.5 km"
  
  const HelpRequestActive(this.request, {this.matchedId, this.distance});

  @override
  List<Object?> get props => [request, matchedId, distance];
}

/// Request created, Victim sees pending card, Helper sees it in Pending tab
class HelpRequestPending extends HelpRequestActive {
  const HelpRequestPending(super.request, {super.matchedId, super.distance});
}

/// Helper has accepted, map connects, chat connects
class HelpRequestAccepted extends HelpRequestActive {
  const HelpRequestAccepted(super.request, {super.matchedId, super.distance});
}

/// Request completed by Helper, triggered blockchain
class HelpRequestResolved extends HelpRequestActive {
  const HelpRequestResolved(super.request, {super.matchedId, super.distance});
}

/// Helper clicked reject OR 5 mins timeout
class HelpRequestRejected extends HelpRequestActive {
  const HelpRequestRejected(super.request, {super.matchedId, super.distance});
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

  const HelpRequestConversation(this.message, {this.audioPath, this.activeRequest});

  @override
  List<Object?> get props => [message, audioPath, activeRequest];
}
