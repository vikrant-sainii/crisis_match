import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/helper_repository.dart';
import '../../repositories/location_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final HelperRepository _helperRepository;
  final LocationRepository _locationRepository;

  AuthBloc({
    required AuthRepository authRepository,
    required HelperRepository helperRepository,
    required LocationRepository locationRepository,
  })  : _authRepository = authRepository,
        _helperRepository = helperRepository,
        _locationRepository = locationRepository,
        super(AuthInitial()) {
    on<AuthCheckStatus>(_onCheckStatus);
    on<AuthSignUpRequested>(_onSignUp);
    on<AuthSignInRequested>(_onSignIn);
    on<AuthSignOutRequested>(_onSignOut);
  }

  Future<void> _onCheckStatus(
    AuthCheckStatus event,
    Emitter<AuthState> emit,
  ) async {
    final userId = _authRepository.getCurrentUserId();
    if (userId != null) {
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
      emit(AuthUnauthenticated());
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
    emit(AuthUnauthenticated());
  }
}
