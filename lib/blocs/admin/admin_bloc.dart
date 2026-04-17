import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/helper_repository.dart';
import '../../repositories/help_request_repository.dart';
import 'admin_event.dart';
import 'admin_state.dart';

class AdminBloc extends Bloc<AdminEvent, AdminState> {
  final AuthRepository _authRepository;
  final HelperRepository _helperRepository;
  final HelpRequestRepository _helpRequestRepository;
  StreamSubscription? _approvalsSubscription;
  StreamSubscription? _spamSubscription;

  AdminBloc({
    required AuthRepository authRepository,
    required HelperRepository helperRepository,
    required HelpRequestRepository helpRequestRepository,
  }) : _authRepository = authRepository,
       _helperRepository = helperRepository,
       _helpRequestRepository = helpRequestRepository,
       super(AdminInitial()) {
    on<LoadAdminData>(_onLoadAdminData);
    on<UpdateAdminApprovals>(_onUpdateAdminApprovals);
    on<UpdateAdminSpamReports>(_onUpdateAdminSpamReports);
    on<ApproveRequest>(_onApproveRequest);
    on<BlockVictim>(_onBlockVictim);
    on<AddHelperAccount>(_onAddHelperAccount);
    on<FilterHelpersByOccupation>(_onFilterHelpersByOccupation);
  }

  Future<void> _onLoadAdminData(
    LoadAdminData event,
    Emitter<AdminState> emit,
  ) async {
    emit(AdminLoading());
    try {
      final helpers = await _helperRepository.getAllHelpers();
      final approvals = await _helpRequestRepository
          .getRequestsAwaitingApproval();
      final spamReports = await _helpRequestRepository.getSpamRequests();
      final occupations = await _helperRepository.getAvailableOccupations();

      // Start real-time subscription for approvals
      await _approvalsSubscription?.cancel();
      _approvalsSubscription = _helpRequestRepository
          .subscribeToRequestsAwaitingApproval((list) {
            add(UpdateAdminApprovals(list));
          });

      // Start real-time subscription for spam reports
      await _spamSubscription?.cancel();
      _spamSubscription = _helpRequestRepository
          .subscribeToSpamRequests((list) {
            add(UpdateAdminSpamReports(list));
          });

      emit(
        AdminDataLoaded(
          helpers: helpers,
          pendingApprovals: approvals,
          spamReports: spamReports,
          occupations: occupations,
        ),
      );
    } catch (e) {
      emit(AdminActionError(e.toString()));
    }
  }

  void _onUpdateAdminApprovals(
    UpdateAdminApprovals event,
    Emitter<AdminState> emit,
  ) {
    if (state is AdminDataLoaded) {
      final currentState = state as AdminDataLoaded;
      emit(
        AdminDataLoaded(
          helpers: currentState.helpers,
          pendingApprovals: event.pendingApprovals,
          spamReports: currentState.spamReports,
          occupations: currentState.occupations,
          selectedOccupation: currentState.selectedOccupation,
        ),
      );
    }
  }

  void _onUpdateAdminSpamReports(
    UpdateAdminSpamReports event,
    Emitter<AdminState> emit,
  ) {
    if (state is AdminDataLoaded) {
      final currentState = state as AdminDataLoaded;
      emit(
        AdminDataLoaded(
          helpers: currentState.helpers,
          pendingApprovals: currentState.pendingApprovals,
          spamReports: event.spamReports,
          occupations: currentState.occupations,
          selectedOccupation: currentState.selectedOccupation,
        ),
      );
    }
  }

  Future<void> _onBlockVictim(
    BlockVictim event,
    Emitter<AdminState> emit,
  ) async {
    try {
      await _authRepository.blockUser(
        profileId: event.profileId,
        requestId: event.requestId,
      );
      add(LoadAdminData());
      emit(const AdminActionSuccess('Victim has been blocked for 15 days.'));
    } catch (e) {
      emit(AdminActionError(e.toString()));
    }
  }

  Future<void> _onApproveRequest(
    ApproveRequest event,
    Emitter<AdminState> emit,
  ) async {
    try {
      await _helpRequestRepository.triggerBlockchainLog(
        requestId: event.request.id,
        dataToHash: {
          'id': event.request.id,
          'type': event.request.crisisType,
          'ts': DateTime.now().toIso8601String(),
          'admin_id': _authRepository.getCurrentUserId(),
        },
      );
      add(LoadAdminData()); // Refresh lists
      emit(const AdminActionSuccess('Blockchain log triggered successfully.'));
    } catch (e) {
      emit(AdminActionError(e.toString()));
    }
  }

  Future<void> _onAddHelperAccount(
    AddHelperAccount event,
    Emitter<AdminState> emit,
  ) async {
    try {
      // Create auth user & profile via signUp
      // WARNING: In standard Supabase, this might session-swap.
      // For Demo/Dev, we assume this is the intended path for simple admin flow.
      final newProfile = await _authRepository.signUp(
        email: event.email,
        password: event.password,
        fullName: event.fullName,
        role: 'helper',
      );

      // Register as helper in the helper table
      await _helperRepository.registerHelper(
        profileId: newProfile.id,
        occupation: event.occupation,
        state: event.state,
        lat: event.lat,
        lng: event.lng,
      );

      add(LoadAdminData());
      emit(
        const AdminActionSuccess('New helper account created successfully.'),
      );
    } catch (e) {
      emit(AdminActionError(e.toString()));
    }
  }

  void _onFilterHelpersByOccupation(
    FilterHelpersByOccupation event,
    Emitter<AdminState> emit,
  ) {
    if (state is AdminDataLoaded) {
      final currentState = state as AdminDataLoaded;
      emit(
        AdminDataLoaded(
          helpers: currentState.helpers,
          pendingApprovals: currentState.pendingApprovals,
          spamReports: currentState.spamReports,
          occupations: currentState.occupations,
          selectedOccupation: event.occupation,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _approvalsSubscription?.cancel();
    _spamSubscription?.cancel();
    return super.close();
  }
}
