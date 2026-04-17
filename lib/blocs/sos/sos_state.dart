import 'package:equatable/equatable.dart';

abstract class SosState extends Equatable {
  const SosState();

  @override
  List<Object?> get props => [];
}

/// SOS toggle is OFF — not listening
class SosDisabled extends SosState {}

/// Background service is running, waiting for power button trigger
class SosListening extends SosState {
  final double? gZ;
  final int? shakeCount;

  const SosListening({this.gZ, this.shakeCount});

  @override
  List<Object?> get props => [gZ, shakeCount];
}

/// Wake word detected — app launched to foreground
class SosActivated extends SosState {}

/// Recording the victim's distress message (dynamic capturing)
class SosCapturing extends SosState {
  final String liveText;
  const SosCapturing(this.liveText);

  @override
  List<Object?> get props => [liveText];
}
/// New terminal state: Voice message captured, ready for handoff
class SosCaptured extends SosState {
  final String message;
  const SosCaptured(this.message);

  @override
  List<Object?> get props => [message];
}

/// Recording ended but no speech was recognized
class SosNoCapture extends SosState {}

/// Something went wrong
class SosError extends SosState {
  final String message;
  const SosError(this.message);

  @override
  List<Object?> get props => [message];
}
