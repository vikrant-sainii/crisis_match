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

/// Device power button pressed 3 times
class SosPowerButtonTriggered extends SosEvent {}

/// 10-second distress recording is complete
class DistressCaptured extends SosEvent {
  final String message;
  const DistressCaptured(this.message);

  @override
  List<Object?> get props => [message];
}

/// n8n responded with match data and/or voice reply
class SosResponseReceived extends SosEvent {
  final String? voiceReply;
  final String? audioPath;
  final Map<String, dynamic>? matchData;

  const SosResponseReceived({
    this.voiceReply,
    this.audioPath,
    this.matchData,
  });

  @override
  List<Object?> get props => [voiceReply, audioPath, matchData];
}

/// New event to pipe background sensor values for testing
class SensorDebugDataReceived extends SosEvent {
  final double gZ;
  final int count;
  const SensorDebugDataReceived(this.gZ, this.count);

  @override
  List<Object?> get props => [gZ, count];
}
