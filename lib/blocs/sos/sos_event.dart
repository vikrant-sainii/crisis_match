import 'package:equatable/equatable.dart';

abstract class SosEvent extends Equatable {
  const SosEvent();

  @override
  List<Object?> get props => [];
}

/// User toggles SOS listening ON
class EnableSos extends SosEvent {}

/// User toggles SOS listening OFF
class DisableSos extends SosEvent {}

/// Live transcription update during capture
class SosLiveTextUpdated extends SosEvent {
  final String text;
  const SosLiveTextUpdated(this.text);

  @override
  List<Object?> get props => [text];
}

/// Hardware/Sensor shake trigger detected
class StartSosCapture extends SosEvent {}

/// User submits the offline SOS sheet
class SubmitOfflineSos extends SosEvent {
  final String message;
  final String priority;
  final double? lat;
  final double? lon;

  const SubmitOfflineSos(this.message, this.priority, {this.lat, this.lon});

  @override
  List<Object?> get props => [message, priority, lat, lon];
}

/// 10-second distress recording is complete
class DistressCaptured extends SosEvent {
  final String message;
  const DistressCaptured(this.message);

  @override
  List<Object?> get props => [message];
}



/// New event to pipe background sensor values for testing
class SensorDebugDataReceived extends SosEvent {
  final double gZ;
  final int count;
  const SensorDebugDataReceived(this.gZ, this.count);

  @override
  List<Object?> get props => [gZ, count];
}
