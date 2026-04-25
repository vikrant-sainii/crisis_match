import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import '../../repositories/help_request_repository.dart';
import 'help_request_event.dart';
import 'help_request_state.dart';
import '../../models/help_request_model.dart';
import 'dart:developer' as developer;

class HelpRequestBloc extends Bloc<HelpRequestEvent, HelpRequestState> {
  final HelpRequestRepository _repository;
  StreamSubscription? _requestSubscription;
  StreamSubscription? _helperSubscription;
  HelpRequestModel? _currentActiveRequest;
  HelpRequestModel? get currentActiveRequest => _currentActiveRequest;
  String? _currentMatchedId;
  String? _currentDistance;
  final DateTime _sessionStartTime = DateTime.now();
  Timer? _prioritySortTimer;

  HelpRequestBloc({required HelpRequestRepository repository})
    : _repository = repository,
      super(HelpRequestInitial()) {
    on<FindHelper>(_onFindHelper);
    on<LoadActiveRequest>(_onLoadActiveRequest);
    on<ListenToVictimRequests>(_onListenToVictimRequests);
    on<CheckRequestStatus>(_onCheckRequestStatus);
    on<ListenForHelperMatches>(_onListenForHelperMatches);
    on<UpdateHelpRequestStatus>(_onUpdateStatus);
    on<RequestUpdated>(_onRequestUpdated, transformer: restartable());
    on<HelperMatchesUpdated>(_onHelperMatchesUpdated);
    on<SortRequestsByPriority>(_onSortRequestsByPriority);
    on<ClearHelpRequest>(_onClearHelpRequest);
  }

  Future<void> _onUpdateStatus(
    UpdateHelpRequestStatus event,
    Emitter<HelpRequestState> emit,
  ) async {
    try {
      // PURE DATABASE-DRIVEN ACTION
      // We only update Supabase. The stream listener (_onRequestUpdated) handles everything else.
      await _repository.updateStatus(event.requestId, event.status);
    } catch (e) {
      emit(HelpRequestError(e.toString()));
    }
  }

  void _onClearHelpRequest(
    ClearHelpRequest event,
    Emitter<HelpRequestState> emit,
  ) {
    _requestSubscription?.cancel();
    _helperSubscription?.cancel();
    _requestSubscription = null;
    _helperSubscription = null;
    emit(HelpRequestInitial());
  }

  Future<void> _onFindHelper(
    FindHelper event,
    Emitter<HelpRequestState> emit,
  ) async {
    // 1. Determine routing mode based on persistent context
    bool hasActiveRequest =
        _currentActiveRequest != null &&
        (_currentActiveRequest!.status == 'pending' ||
            _currentActiveRequest!.status == 'accepted');

    if (!hasActiveRequest) {
      emit(HelpRequestSearching());
    }

    try {
      if (event.isVoice) {
        developer.log(
          'HelpRequestBloc: Voice Input detected. Routing to Voice Assistant.',
        );

        if (hasActiveRequest) {
          // VOICE + ACTIVE REQUEST: ONLY Voice Assist
          developer.log(
            'HelpRequestBloc: [VOICE] Active mission found. Routing to Voice Assist (Only)',
          );
          final voiceResponse = await _repository.triggerN8nVoiceAssist(
            message: event.message,
            victimId: event.victimId,
            lat: event.lat,
            lng: event.lng,
          );
          emit(
            HelpRequestConversation(
              voiceResponse['reply'],
              audioPath: voiceResponse['audioPath'],
              activeRequest: _currentActiveRequest,
            ),
          );
        } else {
          // VOICE + NO ACTIVE REQUEST: BOTH Voice Assist and Initial Search (Parallel)
          developer.log(
            'HelpRequestBloc: [VOICE] No active mission. Dual routing: Voice Assist + Matcher Agent',
          );

          final matcherFuture = _repository
              .triggerN8nInitialSearch(
                message: event.message,
                victimId: event.victimId,
                lat: event.lat,
                lng: event.lng,
              )
              .catchError((e) {
                developer.log('HelpRequestBloc: Matcher Agent error: $e');
                return <String, dynamic>{'error': e.toString()};
              });

          final voiceFuture = _repository
              .triggerN8nVoiceAssist(
                message: event.message,
                victimId: event.victimId,
                lat: event.lat,
                lng: event.lng,
              )
              .catchError((e) {
                developer.log('HelpRequestBloc: Voice Assist error: $e');
                return <String, dynamic>{
                  'reply': 'Voice assistant unavailable.',
                  'audioPath': null,
                };
              });

          final results = await Future.wait([matcherFuture, voiceFuture]);
          final matcherResponse = results[0];
          final voiceResponse = results[1];

          // 1. Process matching results FIRST
          await _processMatcherResponse(matcherResponse, event.victimId, emit);

          // 2. Emit Voice Assistant conversation
          if (voiceResponse.containsKey('reply')) {
            emit(
              HelpRequestConversation(
                voiceResponse['reply'],
                audioPath: voiceResponse['audioPath'],
                activeRequest: _currentActiveRequest,
                matchedId: _currentMatchedId,
                distance: _currentDistance,
              ),
            );
          }
        }
      } else {
        // TEXT INPUT FLOW
        if (hasActiveRequest) {
          developer.log(
            'HelpRequestBloc: [TEXT] Routing to Assist Agent (Only)',
          );
          final assistResponse = await _repository.triggerN8nAssist(
            message: event.message,
            victimId: event.victimId,
            lat: event.lat,
            lng: event.lng,
          );
          emit(
            HelpRequestConversation(
              assistResponse['reply'],
              activeRequest: _currentActiveRequest,
            ),
          );
        } else {
          developer.log(
            'HelpRequestBloc: [TEXT] Routing to Dual Agents (Parallel)',
          );

          final matcherFuture = _repository
              .triggerN8nInitialSearch(
                message: event.message,
                victimId: event.victimId,
                lat: event.lat,
                lng: event.lng,
              )
              .timeout(const Duration(seconds: 60))
              .catchError((e) {
                developer.log('HelpRequestBloc: Matcher Agent error: $e');
                return <String, dynamic>{'error': e.toString()};
              });

          final assistFuture = _repository
              .triggerN8nAssist(
                message: event.message,
                victimId: event.victimId,
                lat: event.lat,
                lng: event.lng,
              )
              .catchError((e) {
                developer.log('HelpRequestBloc: Assist Agent error: $e');
                return <String, dynamic>{'reply': 'Assistant Core Error: $e'};
              });

          final results = await Future.wait([matcherFuture, assistFuture]);
          final matcherResponse = results[0];
          final assistResponse = results[1];

          await _processMatcherResponse(matcherResponse, event.victimId, emit);

          if (assistResponse.containsKey('reply')) {
            emit(
              HelpRequestConversation(
                assistResponse['reply'],
                activeRequest: _currentActiveRequest,
                matchedId: _currentMatchedId,
                distance: _currentDistance,
              ),
            );
          }
        }
      }
    } catch (e) {
      developer.log('HelpRequestBloc: Critical error in _onFindHelper: $e');
      emit(HelpRequestError(e.toString()));
    }
  }

  /// Helper method to process common matcher response logic
  Future<void> _processMatcherResponse(
    Map<String, dynamic> matcherResponse,
    String victimId,
    Emitter<HelpRequestState> emit,
  ) async {
    if (matcherResponse.containsKey('error')) return;

    if (matcherResponse.containsKey('reply') &&
        !matcherResponse.containsKey('matched_id')) {
      _currentActiveRequest = null;
      emit(
        HelpRequestConversation(
          matcherResponse['reply'],
          activeRequest: _currentActiveRequest,
        ),
      );
      return;
    }

    final String? matchedId = matcherResponse['matched_id'];
    final String? requestId = matcherResponse['request_id'];
    final String distance = matcherResponse['distance']?.toString() ?? 'Nearby';

    if (matchedId != null && requestId != null) {
      final request = await _repository.getRequestById(requestId);
      if (request != null) {
        _currentActiveRequest = request;
        _currentMatchedId = matchedId;
        _currentDistance = distance;
        // Centralized: Trigger an update event with the full metadata attached to the model
        add(
          RequestUpdated(
            request.copyWith(matchedId: matchedId, distance: distance),
          ),
        );
        add(ListenToVictimRequests(victimId));
      } else {
        emit(HelpRequestError("Matched but failed to fetch request locally."));
      }
    } else {
      final msg =
          matcherResponse['message'] ??
          matcherResponse['output'] ??
          matcherResponse.toString();
      emit(
        HelpRequestConversation(
          msg.toString(),
          activeRequest: _currentActiveRequest,
        ),
      );
    }
  }

  Future<void> _onLoadActiveRequest(
    LoadActiveRequest event,
    Emitter<HelpRequestState> emit,
  ) async {
    _requestSubscription?.cancel();
    _helperSubscription?.cancel();
    _requestSubscription = null;
    _helperSubscription = null;
    emit(HelpRequestInitial());

    // Start a global victim listener as a safety net (Persistent)
    add(ListenToVictimRequests(event.victimId));

    try {
      final request = await _repository.getActiveRequest(event.victimId);
      if (request != null) {
        // 🔒 SAFETY CHECK: If the mission is old, auto-clear it.
        if (_isRequestExpired(request)) {
          developer.log(
            'HelpRequestBloc: Active request found but expired (${request.id}). Clearing.',
          );
          _currentActiveRequest = null;
          emit(HelpRequestInitial());
          return;
        }

        _currentActiveRequest = request;
        // Centralized: Initial load triggers a RequestUpdated event to standardize state emission
        add(RequestUpdated(request));
      } else {
        _currentActiveRequest = null;
        emit(HelpRequestInitial());
      }
    } catch (e) {
      developer.log('HelpRequestBloc: Error in _onLoadActiveRequest: $e');
      emit(HelpRequestError("Secure Link Initialization Failed: $e"));
    }
  }

  void _onListenToVictimRequests(
    ListenToVictimRequests event,
    Emitter<HelpRequestState> emit,
  ) {
    _requestSubscription?.cancel();
    _requestSubscription = _repository.subscribeToVictimRequests(
      event.victimId,
      (request) => add(RequestUpdated(request)),
    );
  }

  Future<void> _onCheckRequestStatus(
    CheckRequestStatus event,
    Emitter<HelpRequestState> emit,
  ) async {
    try {
      final request = await _repository.getRequestById(event.requestId);
      if (request != null) {
        add(RequestUpdated(request));
      }
    } catch (_) {}
  }

  void _onListenForHelperMatches(
    ListenForHelperMatches event,
    Emitter<HelpRequestState> emit,
  ) {
    _helperSubscription?.cancel();
    _helperSubscription = _repository.subscribeToHelperRequests(
      event.helperId,
      (requests) => add(HelperMatchesUpdated(requests)),
    );
  }

  void _onRequestUpdated(RequestUpdated event, Emitter<HelpRequestState> emit) {
    var request = event.request;

    // 🛡️ CLEAN HANDOVER: Ensure Row 2/3/etc. inherits session-long metadata
    // from the BLoC's memory if the database row hasn't populated them yet.
    if (request.matchedId == null && _currentMatchedId != null) {
      request = request.copyWith(matchedId: _currentMatchedId);
    }
    if (request.distance == null && _currentDistance != null) {
      request = request.copyWith(distance: _currentDistance);
    }

    // 🛡️ PERSISTENT METADATA TRACKING (Update memory based on latest valid data)
    if (request.matchedId != null) _currentMatchedId = request.matchedId;
    if (request.distance != null) _currentDistance = request.distance;

    final String? mId = _currentMatchedId;
    final String? dist = _currentDistance;

    developer.log(
      'HelpRequestBloc: Processing Stream Update. ID: ${request.id}, Status: ${request.status}',
    );

    if (request.status == 'accepted') {
      _currentActiveRequest = request;
      emit(HelpRequestActive(request, matchedId: mId, distance: dist));
    } else if (request.status == 'rejected') {
      _currentActiveRequest = null;

      // 🛡️ STALE REJECTION GUARD: Ignore rejections from previous app sessions
      // or if we are just initializing in an idle state.
      final bool isHistorical =
          request.updatedAt != null &&
          request.updatedAt!.isBefore(_sessionStartTime);
      if (state is HelpRequestInitial || isHistorical) {
        developer.log(
          'HelpRequestBloc: Ignoring historical or premature rejection (${request.id})',
        );
        return;
      }

      // 🕒 EXPIRY GUARD: If the rejection is more than 3 minutes old, stop searching.
      if (_isRequestExpired(request)) {
        developer.log(
          'HelpRequestBloc: Search loop timed out for mission ${request.id}',
        );
        emit(HelpRequestInitial());
        return;
      }

      // 🛡️ RE-SEARCH: Handled by n8n. Frontend just shows the searching radar.
      emit(HelpRequestSearching());
    } else if (request.status == 'cancelled') {
      _currentActiveRequest = null;
      emit(HelpRequestInitial());
    } else if (request.status == 'completed') {
      _currentActiveRequest = null;
      emit(HelpRequestActive(request, matchedId: mId, distance: dist));
    } else if (request.status == 'spam' || request.status == 'blocked') {
      _currentActiveRequest = null;
      emit(
        HelpRequestError(
          "This communication has been flagged for security review.",
        ),
      );
    } else if (request.status == 'pending' || request.status == 'accepted') {
      _currentActiveRequest = request;
      emit(HelpRequestActive(request, matchedId: mId, distance: dist));
    } else {
      // Catch-all for other states (Initial, etc.)
      _currentActiveRequest = null;
      _currentMatchedId = null;
      _currentDistance = null;
      emit(HelpRequestInitial());
    }
  }

  bool _isRequestExpired(HelpRequestModel request) {
    if (request.updatedAt == null) return false;
    final diff = DateTime.now().difference(request.updatedAt!);
    return diff.inMinutes >= 1;
  }

  void _onHelperMatchesUpdated(
    HelperMatchesUpdated event,
    Emitter<HelpRequestState> emit,
  ) {
    // Start the priority sort timer if not already running for helpers
    if (_prioritySortTimer == null) {
      _startPrioritySortTimer();
    }
    emit(HelperRequestsLoaded(event.requests));
  }

  void _onSortRequestsByPriority(
    SortRequestsByPriority event,
    Emitter<HelpRequestState> emit,
  ) {
    if (state is! HelperRequestsLoaded) return;

    final currentRequests = (state as HelperRequestsLoaded).requests;
    
    // Create a new list and sort only PENDING requests by priority score
    final updatedRequests = List<HelpRequestModel>.from(currentRequests).map((r) {
      if (r.status == 'pending') {
        final score = r.calculatePriorityScore(event.helperLat, event.helperLng);
        return r.copyWith(priorityScore: score);
      }
      return r;
    }).toList();

    // Sort: Pending requests with higher scores come first
    updatedRequests.sort((a, b) {
      if (a.status == 'pending' && b.status == 'pending') {
        return (b.priorityScore ?? 0.0).compareTo(a.priorityScore ?? 0.0);
      }
      return 0; // Maintain original order for non-pending
    });

    emit(HelperRequestsLoaded(updatedRequests));
  }

  void _startPrioritySortTimer() {
    _prioritySortTimer?.cancel();
    _prioritySortTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      // Find current helper location from another BLoC or local cache
      // For now, we trigger an event that the UI will fill with location
      add(const SortRequestsByPriority(helperLat: 0.0, helperLng: 0.0));
    });
  }

  @override
  Future<void> close() {
    _requestSubscription?.cancel();
    _helperSubscription?.cancel();
    _prioritySortTimer?.cancel();
    return super.close();
  }
}
