import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/location_repository.dart';
import 'location_event.dart';
import 'location_state.dart';

class LocationBloc extends Bloc<LocationEvent, LocationState> {
  final LocationRepository _repository;

  LocationBloc({required LocationRepository repository})
      : _repository = repository,
        super(LocationInitial()) {
    on<GetCurrentLocation>(_onGetCurrentLocation);
  }

  Future<void> _onGetCurrentLocation(
    GetCurrentLocation event,
    Emitter<LocationState> emit,
  ) async {
    emit(LocationLoading());
    try {
      final position = await _repository.getCurrentLocation();
      emit(LocationLoaded(lat: position.latitude, lng: position.longitude));
    } catch (e) {
      emit(LocationError(e.toString()));
    }
  }
}
