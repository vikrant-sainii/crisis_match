import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/help_request_repository.dart';
import 'help_request_event.dart';
import 'help_request_state.dart';
import '../../models/help_request_model.dart';
import 'dart:developer' as developer;

class HelpRequestBloc extends Bloc<HelpRequestEvent, HelpRequestState> {
  final HelpRequestRepository _repository;
  StreamSubscription? _requestSubscription;
  StreamSubscription? _helperSubscription;
  Timer? _matchingTimer;
  HelpRequestModel? _currentActiveRequest;

  HelpRequestBloc({required HelpRequestRepository repository})
    : _repository = repository,
      super(HelpRequestInitial()) {
    on<FindHelper>(_onFindHelper);
    on<RetryFindHelper>(_onRetryFindHelper);
    on<LoadActiveRequest>(_onLoadActiveRequest);
    on<ListenToVictimRequests>(_onListenToVictimRequests);
    on<CheckRequestStatus>(_onCheckRequestStatus);
    on<ListenForHelperMatches>(_onListenForHelperMatches);
    on<AcceptRequest>(_onAcceptRequest);
    on<RejectRequest>(_onRejectRequest);
    on<ResolveRequest>(_onResolveRequest);
    on<CancelAcceptedRequest>(_onCancelAcceptedRequest);
    on<MarkAsSpam>(_onMarkAsSpam);
    on<RequestUpdated>(_onRequestUpdated);
    on<HelperMatchesUpdated>(_onHelperMatchesUpdated);
    on<ClearHelpRequest>(_onClearHelpRequest);
  }

  Future<void> _onMarkAsSpam(MarkAsSpam event, Emitter<HelpRequestState> emit) async {
    try {
      await _repository.markAsSpam(event.requestId);
    } catch (e) {
      emit(HelpRequestError(e.toString()));
    }
  }

  void _onClearHelpRequest(ClearHelpRequest event, Emitter<HelpRequestState> emit) {
    _requestSubscription?.cancel();
    _helperSubscription?.cancel();
    _matchingTimer?.cancel();
    _requestSubscription = null;
    _helperSubscription = null;
    _matchingTimer = null;
    emit(HelpRequestInitial());
  }

  void _startTimer(String matchedId, String victimId) {
    _matchingTimer?.cancel();
    _matchingTimer = Timer(const Duration(minutes: 5), () {
      add(RetryFindHelper(matchedId: matchedId, victimId: victimId));
    });
  }

  Future<void> _onFindHelper(FindHelper event, Emitter<HelpRequestState> emit) async {
    // 1. Determine routing mode based on persistent context
    bool hasActiveRequest = _currentActiveRequest != null && 
                     (_currentActiveRequest!.status == 'pending' || _currentActiveRequest!.status == 'accepted');
    
    if (!hasActiveRequest) {
      emit(HelpRequestSearching());
    }

    try {
      if (event.isVoice) {
        developer.log('HelpRequestBloc: Voice Input detected. Routing to Voice Assistant.');
        
        if (hasActiveRequest) {
          // VOICE + ACTIVE REQUEST: ONLY Voice Assist
          developer.log('HelpRequestBloc: [VOICE] Active mission found. Routing to Voice Assist (Only)');
          final voiceResponse = await _repository.triggerN8nVoiceAssist(
            message: event.message,
            victimId: event.victimId,
            lat: event.lat,
            lng: event.lng,
          );
          emit(HelpRequestConversation(
            voiceResponse['reply'], 
            audioPath: voiceResponse['audioPath'],
            activeRequest: _currentActiveRequest
          ));
        } else {
          // VOICE + NO ACTIVE REQUEST: BOTH Voice Assist and Initial Search (Parallel)
          developer.log('HelpRequestBloc: [VOICE] No active mission. Dual routing: Voice Assist + Matcher Agent');
          
          final matcherFuture = _repository.triggerN8nInitialSearch(
            message: event.message,
            victimId: event.victimId,
            lat: event.lat,
            lng: event.lng,
          ).catchError((e) {
            developer.log('HelpRequestBloc: Matcher Agent error: $e');
            return <String, dynamic>{'error': e.toString()};
          });

          final voiceFuture = _repository.triggerN8nVoiceAssist(
            message: event.message,
            victimId: event.victimId,
            lat: event.lat,
            lng: event.lng,
          ).catchError((e) {
            developer.log('HelpRequestBloc: Voice Assist error: $e');
            return <String, dynamic>{'reply': 'Voice assistant unavailable.', 'audioPath': null};
          });

          final results = await Future.wait([matcherFuture, voiceFuture]);
          final matcherResponse = results[0];
          final voiceResponse = results[1];

          // 1. Emit Voice Assistant conversation first
          if (voiceResponse.containsKey('reply')) {
            emit(HelpRequestConversation(
              voiceResponse['reply'], 
              audioPath: voiceResponse['audioPath'],
              activeRequest: _currentActiveRequest
            ));
          }

          // 2. Process matching results
          await _processMatcherResponse(matcherResponse, event.victimId, emit);
        }
      } else {
        // TEXT INPUT FLOW
        if (hasActiveRequest) {
          developer.log('HelpRequestBloc: [TEXT] Routing to Assist Agent (Only)');
          final assistResponse = await _repository.triggerN8nAssist(
            message: event.message,
            victimId: event.victimId,
            lat: event.lat,
            lng: event.lng,
          );
          emit(HelpRequestConversation(assistResponse['reply'], activeRequest: _currentActiveRequest));
        } else {
          developer.log('HelpRequestBloc: [TEXT] Routing to Dual Agents (Parallel)');
          
          final matcherFuture = _repository.triggerN8nInitialSearch(
            message: event.message,
            victimId: event.victimId,
            lat: event.lat,
            lng: event.lng,
          ).catchError((e) {
            developer.log('HelpRequestBloc: Matcher Agent error: $e');
            return <String, dynamic>{'error': e.toString()};
          });

          final assistFuture = _repository.triggerN8nAssist(
            message: event.message,
            victimId: event.victimId,
            lat: event.lat,
            lng: event.lng,
          ).catchError((e) {
            developer.log('HelpRequestBloc: Assist Agent error: $e');
            return <String, dynamic>{'reply': 'Assistant currently unavailable.'};
          });

          final results = await Future.wait([matcherFuture, assistFuture]);
          final matcherResponse = results[0];
          final assistResponse = results[1];

          if (assistResponse.containsKey('reply')) {
            emit(HelpRequestConversation(assistResponse['reply'], activeRequest: _currentActiveRequest));
          }

          await _processMatcherResponse(matcherResponse, event.victimId, emit);
        }
      }
    } catch (e) {
      developer.log('HelpRequestBloc: Critical error in _onFindHelper: $e');
      emit(HelpRequestError(e.toString()));
    }
  }

  /// Helper method to process common matcher response logic
  Future<void> _processMatcherResponse(Map<String, dynamic> matcherResponse, String victimId, Emitter<HelpRequestState> emit) async {
    if (matcherResponse.containsKey('error')) return;

    if (matcherResponse.containsKey('reply') && !matcherResponse.containsKey('matched_id')) {
      emit(HelpRequestConversation(matcherResponse['reply'], activeRequest: _currentActiveRequest));
      return;
    }

    final String? matchedId = matcherResponse['matched_id'];
    final String? requestId = matcherResponse['request_id'];
    final String distance = matcherResponse['distance']?.toString() ?? 'Nearby';
    
    if (matchedId != null && requestId != null) {
      final request = await _repository.getRequestById(requestId);
      if (request != null) {
        _currentActiveRequest = request;
        emit(HelpRequestPending(request, matchedId: matchedId, distance: distance));
        _startTimer(matchedId, victimId);
        add(ListenToVictimRequests(victimId));
      } else {
        emit(HelpRequestError("Matched but failed to fetch request locally."));
      }
    } else {
      final msg = matcherResponse['message'] ?? matcherResponse['output'] ?? matcherResponse.toString();
      emit(HelpRequestConversation(msg.toString(), activeRequest: _currentActiveRequest));
    }
  }

  Future<void> _onRetryFindHelper(RetryFindHelper event, Emitter<HelpRequestState> emit) async {
    _matchingTimer?.cancel();
    emit(HelpRequestSearching());
    try {
      final n8nResponse = await _repository.triggerN8nRetrySearch(
        matchedId: event.matchedId,
        victimId: event.victimId,
      );
      
      final String newMatchedId = n8nResponse['matched_id'];
      final String requestId = n8nResponse['request_id'];
      final String distance = n8nResponse['distance']?.toString() ?? 'Nearby';
      
      final request = await _repository.getRequestById(requestId);
      if (request != null) {
        emit(HelpRequestPending(request, matchedId: newMatchedId, distance: distance));
        _startTimer(newMatchedId, event.victimId);
        add(ListenToVictimRequests(event.victimId));
      } else {
        emit(HelpRequestError("Failed to find next helper in the queue."));
      }
    } catch (e) {
      emit(HelpRequestError(e.toString()));
    }
  }

  Future<void> _onLoadActiveRequest(LoadActiveRequest event, Emitter<HelpRequestState> emit) async {
    // ALWAYS clear old state/subs before loading for a new user
    _requestSubscription?.cancel();
    _helperSubscription?.cancel();
    _matchingTimer?.cancel();
    _requestSubscription = null;
    _helperSubscription = null;
    _matchingTimer = null;
    emit(HelpRequestInitial());

    // Start a global victim listener as a safety net (Persistent)
    add(ListenToVictimRequests(event.victimId));

    try {
      final request = await _repository.getActiveRequest(event.victimId);
      if (request != null) {
        _currentActiveRequest = request;
        if (request.status == 'accepted') {
          emit(HelpRequestAccepted(request, distance: "In Progress"));
        } else if (request.status == 'pending') {
          emit(HelpRequestPending(request, distance: "Awaiting Response"));
        } else {
          // If it's something else like 'completed' or 'rejected', revert to initial
          _currentActiveRequest = null;
          emit(HelpRequestInitial());
        }
      } else {
        _currentActiveRequest = null;
        emit(HelpRequestInitial());
      }
    } catch (e) {
      developer.log('HelpRequestBloc: Error in _onLoadActiveRequest: $e');
      emit(HelpRequestError("Secure Link Initialization Failed: $e"));
    }
  }

  void _onListenToVictimRequests(ListenToVictimRequests event, Emitter<HelpRequestState> emit) {
    _requestSubscription?.cancel();
    _requestSubscription = _repository.subscribeToVictimRequests(
      event.victimId,
      (request) => add(RequestUpdated(request)),
    );
  }

  Future<void> _onCheckRequestStatus(CheckRequestStatus event, Emitter<HelpRequestState> emit) async {
    try {
      final request = await _repository.getRequestById(event.requestId);
      if (request != null) {
        add(RequestUpdated(request));
      }
    } catch (_) {}
  }

  void _onListenForHelperMatches(ListenForHelperMatches event, Emitter<HelpRequestState> emit) {
    _helperSubscription?.cancel();
    _helperSubscription = _repository.subscribeToHelperRequests(
      event.helperId,
      (requests) => add(HelperMatchesUpdated(requests)),
    );
  }

  Future<void> _onAcceptRequest(AcceptRequest event, Emitter<HelpRequestState> emit) async {
    try {
      await _repository.updateStatus(event.requestId, 'accepted');
    } catch (e) {
      emit(HelpRequestError(e.toString()));
    }
  }

  Future<void> _onRejectRequest(RejectRequest event, Emitter<HelpRequestState> emit) async {
    try {
      // 1. Update status to rejected
      await _repository.updateStatus(event.requestId, 'rejected');
      
      // 2. Trigger n8n retry if matchedId exists
      if (event.matchedId != null && event.matchedId!.isNotEmpty) {
        await _repository.triggerN8nRetrySearch(
          matchedId: event.matchedId!,
          victimId: event.victimId,
        );
      }
      // Local UI will refresh via stream subscriptions
    } catch (e) {
      emit(HelpRequestError(e.toString()));
    } 
  }

  Future<void> _onResolveRequest(ResolveRequest event, Emitter<HelpRequestState> emit) async {
    try {
      await _repository.updateStatus(event.requestId, 'completed');
    } catch (e) {
      emit(HelpRequestError(e.toString()));
    }
  }

  Future<void> _onCancelAcceptedRequest(CancelAcceptedRequest event, Emitter<HelpRequestState> emit) async {
    try {
      // 1. Update status to rejected
      await _repository.updateStatus(event.requestId, 'rejected');
      
      // 2. Trigger n8n retry if matchedId exists
      if (event.matchedId != null && event.matchedId!.isNotEmpty) {
        await _repository.triggerN8nRetrySearch(
          matchedId: event.matchedId!,
          victimId: event.victimId,
        );
      }
      
      // Local UI will refresh via stream subscriptions
    } catch (e) {
      emit(HelpRequestError(e.toString()));
    }
  }

  void _onRequestUpdated(RequestUpdated event, Emitter<HelpRequestState> emit) {
    final request = event.request;
    String? mId;
    String? dist;
    if (state is HelpRequestActive) {
      mId = (state as HelpRequestActive).matchedId;
      dist = (state as HelpRequestActive).distance;
    }

    if (request.status == 'accepted') {
      _matchingTimer?.cancel();
      _currentActiveRequest = request;
      emit(HelpRequestAccepted(request, matchedId: mId, distance: dist));
    } else if (request.status == 'rejected') {
      _matchingTimer?.cancel();
      _currentActiveRequest = null;
      
      // 🛡️ STALE REJECTION GUARD: If app just opened (Initial), ignore old rejected rows
      if (state is HelpRequestInitial) return;

      // Auto-trigger retry if we have a matchedId pointer (Victim flow)
      if (mId != null) {
        add(RetryFindHelper(matchedId: mId, victimId: request.victimId));
      } else {
        // If no pointer, just show rejection (Helper flow)
        emit(HelpRequestRejected(request, matchedId: mId, distance: dist));
      }
    } else if (request.status == 'completed') {
      _matchingTimer?.cancel();
      _currentActiveRequest = null;
      emit(HelpRequestResolved(request, matchedId: mId, distance: dist));
    } else if (request.status == 'spam' || request.status == 'blocked') {
      _matchingTimer?.cancel();
      _currentActiveRequest = null;
      emit(HelpRequestError("This communication has been flagged for security review."));
    } else if (request.status == 'pending') {
      _currentActiveRequest = request;
      emit(HelpRequestPending(request, matchedId: mId, distance: dist));
    } else {
       // Catch-all for other states (e.g. idle or cancelled)
      _currentActiveRequest = null;
      emit(HelpRequestInitial());
    }
  }

  void _onHelperMatchesUpdated(HelperMatchesUpdated event, Emitter<HelpRequestState> emit) {
    emit(HelperRequestsLoaded(event.requests));
  }

  @override
  Future<void> close() {
    _matchingTimer?.cancel();
    _requestSubscription?.cancel();
    _helperSubscription?.cancel();
    return super.close();
  }
}
