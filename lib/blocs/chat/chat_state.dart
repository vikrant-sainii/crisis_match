import 'package:equatable/equatable.dart';
import '../../models/chat_message_model.dart';

abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatLoaded extends ChatState {
  final List<ChatMessageModel> messages;
  // n8n conversation messages (local, before request is created)
  final List<ChatMessageModel> n8nMessages;

  const ChatLoaded({
    this.messages = const [],
    this.n8nMessages = const [],
  });

  ChatLoaded copyWith({
    List<ChatMessageModel>? messages,
    List<ChatMessageModel>? n8nMessages,
  }) {
    return ChatLoaded(
      messages: messages ?? this.messages,
      n8nMessages: n8nMessages ?? this.n8nMessages,
    );
  }

  @override
  List<Object?> get props => [messages, n8nMessages];
}

class ChatError extends ChatState {
  final String message;

  const ChatError(this.message);

  @override
  List<Object?> get props => [message];
}
