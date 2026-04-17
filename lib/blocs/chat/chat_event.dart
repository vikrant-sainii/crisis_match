import 'package:equatable/equatable.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class LoadMessages extends ChatEvent {
  final String requestId;

  const LoadMessages(this.requestId);

  @override
  List<Object?> get props => [requestId];
}

class SendMessage extends ChatEvent {
  final String requestId;
  final String senderId;
  final String senderRole;
  final String message;

  const SendMessage({
    required this.requestId,
    required this.senderId,
    required this.senderRole,
    required this.message,
  });

  @override
  List<Object?> get props => [requestId, senderId, senderRole, message];
}

class SendToN8n extends ChatEvent {
  final String message;
  final String victimId;
  final double? lat;
  final double? lng;

  const SendToN8n({
    required this.message,
    required this.victimId,
    this.lat,
    this.lng,
  });

  @override
  List<Object?> get props => [message, victimId, lat, lng];
}

class MessagesUpdated extends ChatEvent {
  final List<dynamic> messages;

  const MessagesUpdated(this.messages);

  @override
  List<Object?> get props => [messages];
}

class ClearChat extends ChatEvent {}
