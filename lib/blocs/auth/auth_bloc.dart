import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/helper_repository.dart';
import '../../repositories/location_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import '../../repositories/low_network_repository.dart';
import '../../models/profile_model.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final HelperRepository _helperRepository;
  final LocationRepository _locationRepository;
  final LowNetworkRepository _lowNetworkRepo;

  AuthBloc({
    required AuthRepository authRepository,
    required HelperRepository helperRepository,
    required LocationRepository locationRepository,
    required LowNetworkRepository lowNetworkRepo,
  })  : _authRepository = authRepository,
        _helperRepository = helperRepository,
        _locationRepository = locationRepository,
        _lowNetworkRepo = lowNetworkRepo,
        super(AuthInitial()) {
    on<AuthCheckStatus>(_onCheckStatus);
    on<AuthSignUpRequested>(_onSignUp);
    on<AuthSignInRequested>(_onSignIn);
    on<AuthSignOutRequested>(_onSignOut);
    on<AuthUpdateEmergencyContactsRequested>(_onUpdateEmergencyContacts);
  }

  Future<void> _onUpdateEmergencyContacts(
    AuthUpdateEmergencyContactsRequested event,
    Emitter<AuthState> emit,
  ) async {
    final currentState = state;
    if (currentState is AuthAuthenticated) {
      try {
        await _authRepository.updateEmergencyContacts(
          currentState.profile.id,
          event.contacts,
        );
        final updatedProfile =
            currentState.profile.copyWith(emergencyContacts: event.contacts);
        emit(AuthAuthenticated(updatedProfile));
      } catch (e) {
        emit(AuthError('Failed to update emergency contacts: ${e.toString()}'));
        // Re-emit original state to recover
        emit(AuthAuthenticated(currentState.profile));
      }
    }
  }


  Future<void> _onCheckStatus(
    AuthCheckStatus event,
    Emitter<AuthState> emit,
  ) async {
    final userId = _authRepository.getCurrentUserId();
    final isOnline = await _lowNetworkRepo.hasInternet();

    if (userId != null) {
      if (!isOnline) {
        // We have a local session, but offline. Allow entry with cached profile info if possible.
        // For now, we trust the Supabase local persistence.
        try {
          final profile = await _authRepository.getProfile(userId);
          emit(AuthAuthenticated(profile));
        } catch (_) {
          // If we can't even get the local profile, treat as offline guest or authenticated fallback
          emit(AuthAuthenticated(ProfileModel(id: userId, role: 'victim', fullName: 'Cached User', email: '')));
        }
        return;
      }

      try {
        final profile = await _authRepository.getProfile(userId);
        if (profile.isBlocked) {
          emit(AuthBlocked(profile, 'Access Restricted: Suspicious activity reported.'));
        } else {
          emit(AuthAuthenticated(profile));
        }
      } catch (_) {
        emit(AuthUnauthenticated());
      }
    } else {
      if (!isOnline) {
        final prefs = await SharedPreferences.getInstance();
        final savedId = prefs.getString('last_user_id');
        final savedName = prefs.getString('last_user_name') ?? 'Offline User';
        
        if (savedId != null) {
          emit(AuthAuthenticated(ProfileModel(
            id: savedId, 
            role: 'victim', 
            fullName: savedName, 
            email: ''
          )));
        } else {
          emit(AuthOfflineGuest());
        }
      } else {
        emit(AuthUnauthenticated());
      }
    }
  }

  Future<void> _onSignUp(
    AuthSignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final profile = await _authRepository.signUp(
        email: event.email,
        password: event.password,
        fullName: event.fullName,
        role: event.role,
        phone: event.phone,
      );

      // If helper, also create helper record
      if (event.role == 'helper' && event.occupation != null) {
        double lat;
        double lng;
        try {
          final position = await _locationRepository.getCurrentLocation();
          lat = position.latitude;
          lng = position.longitude;
        } catch (e) {
          throw Exception('Location permission is required for helpers. Please enable location services and try again.');
        }

        await _helperRepository.registerHelper(
          profileId: profile.id,
          occupation: event.occupation!,
          state: event.state,
          lat: lat,
          lng: lng,
        );
      }
      
      await _persistProfile(profile);
      emit(AuthAuthenticated(profile));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignIn(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final profile = await _authRepository.signIn(
        email: event.email,
        password: event.password,
      );
      
      await _persistProfile(profile);
      if (profile.isBlocked) {
        emit(AuthBlocked(profile, 'Access Restricted for 15 days due to multiple false requests.'));
      } else {
        emit(AuthAuthenticated(profile));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignOut(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    emit(AuthUnauthenticated());
  }

  Future<void> _persistProfile(ProfileModel profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_user_id', profile.id);
    await prefs.setString('last_user_name', profile.fullName);
  }
}
