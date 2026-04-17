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

/// Recording the victim's distress message (10-second capture)
class SosCapturing extends SosState {
  final int secondsRemaining;
  const SosCapturing(this.secondsRemaining);

  @override
  List<Object?> get props => [secondsRemaining];
}

/// Distress captured, calling n8n webhooks
class SosSending extends SosState {
  final String message;
  const SosSending(this.message);

  @override
  List<Object?> get props => [message];
}

/// Got response from n8n — voice reply and/or helper match
class SosResponseState extends SosState {
  final String voiceReply;
  final String? audioPath;
  final Map<String, dynamic>? matchData;

  const SosResponseState({
    required this.voiceReply,
    this.audioPath,
    this.matchData,
  });

  @override
  List<Object?> get props => [voiceReply, audioPath, matchData];
}

/// Something went wrong
class SosError extends SosState {
  final String message;
  const SosError(this.message);

  @override
  List<Object?> get props => [message];
}
