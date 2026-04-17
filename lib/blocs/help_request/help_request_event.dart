import 'package:equatable/equatable.dart';
import '../../models/help_request_model.dart';

abstract class HelpRequestEvent extends Equatable {
  const HelpRequestEvent();

  @override
  List<Object?> get props => [];
}

/// Victim requests AI matching from n8n
class FindHelper extends HelpRequestEvent {
  final String message;
  final String victimId;
  final double lat;
  final double lng;
  final bool isVoice;

  const FindHelper({
    required this.message,
    required this.victimId,
    required this.lat,
    required this.lng,
    this.isVoice = false,
  });

  @override
  List<Object?> get props => [message, victimId, lat, lng, isVoice];
}

/// Victim triggers retry based on rejected state or timeout (passed matched_id array pointer)
class RetryFindHelper extends HelpRequestEvent {
  final String matchedId;
  final String victimId;
  final bool isVoice;

  const RetryFindHelper({
    required this.matchedId,
    required this.victimId,
    this.isVoice = false,
  });

  @override
  List<Object?> get props => [matchedId, victimId, isVoice];
}
/// Check if Victim already has an active request on app load(fresh request)
class LoadActiveRequest extends HelpRequestEvent {
  final String victimId;

  const LoadActiveRequest(this.victimId);

  @override
  List<Object?> get props => [victimId];
}

/// Start listening for ALL requests related to a victim (Realtime safety net)
class ListenToVictimRequests extends HelpRequestEvent {
  final String victimId;

  const ListenToVictimRequests(this.victimId);

  @override
  List<Object?> get props => [victimId];
}

/// Fallback polling for status check
class CheckRequestStatus extends HelpRequestEvent {
  final String requestId;

  const CheckRequestStatus(this.requestId);

  @override
  List<Object?> get props => [requestId];
}

/// Load and listen to all incoming requests for the Helper's Tab View
class ListenForHelperMatches extends HelpRequestEvent {
  final String helperId;

  const ListenForHelperMatches(this.helperId);

  @override
  List<Object?> get props => [helperId];
}

/// Helper accepts
class AcceptRequest extends HelpRequestEvent {
  final String requestId;

  const AcceptRequest(this.requestId);

  @override
  List<Object?> get props => [requestId];
}

/// Helper rejects
class RejectRequest extends HelpRequestEvent {
  final String requestId;
  final String victimId;
  final String? matchedId;

    const RejectRequest({
    required this.requestId,
    required this.victimId,
    this.matchedId,
  });

  @override
  List<Object?> get props => [requestId];
}

/// Helper marks request successfully resolved (triggers blockchain)
class ResolveRequest extends HelpRequestEvent {
  final String requestId;

  const ResolveRequest(this.requestId);

  @override
  List<Object?> get props => [requestId];
}

class CancelAcceptedRequest extends HelpRequestEvent {
  final String requestId;
  final String victimId;
  final String? matchedId;

  const CancelAcceptedRequest({
    required this.requestId,
    required this.victimId,
    this.matchedId,
  });

  @override
  List<Object?> get props => [requestId, victimId, matchedId];
}

/// Fired privately by realtime subscriptions
class RequestUpdated extends HelpRequestEvent {
  final HelpRequestModel request;

  const RequestUpdated(this.request);

  @override
  List<Object?> get props => [request];
}

class HelperMatchesUpdated extends HelpRequestEvent {
  final List<HelpRequestModel> requests;

  const HelperMatchesUpdated(this.requests);

  @override
  List<Object?> get props => [requests];
}

class StartHelperTracking extends HelpRequestEvent {
  final String requestId;

  const StartHelperTracking(this.requestId);

  @override
  List<Object?> get props => [requestId];
}

class StopHelperTracking extends HelpRequestEvent {}

class ClearHelpRequest extends HelpRequestEvent {}

class MarkAsSpam extends HelpRequestEvent {
  final String requestId;
  const MarkAsSpam(this.requestId);

  @override
  List<Object?> get props => [requestId];
}
