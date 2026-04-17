import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/chat_message_model.dart';
import '../../repositories/chat_repository.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository _repository;
  StreamSubscription? _messagesSubscription;

  ChatBloc({required ChatRepository repository})
      : _repository = repository,
        super(const ChatLoaded()) {
    on<LoadMessages>(_onLoadMessages);
    on<SendMessage>(_onSendMessage);
    on<SendToN8n>(_onSendToN8n);
    on<MessagesUpdated>(_onMessagesUpdated);
    on<ClearChat>(_onClearChat);
  }

  void _onClearChat(ClearChat event, Emitter<ChatState> emit) {
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    emit(const ChatLoaded());
  }

  Future<void> _onLoadMessages(
    LoadMessages event,
    Emitter<ChatState> emit,
  ) async {
    try {
      final messages = await _repository.getMessages(event.requestId);
      final currentState = state;
      if (currentState is ChatLoaded) {
        emit(currentState.copyWith(messages: messages));
      } else {
        emit(ChatLoaded(messages: messages));
      }
      // Subscribe to realtime
      _messagesSubscription?.cancel();
      _messagesSubscription = _repository.subscribeToMessages(
        event.requestId,
        (msgs) => add(MessagesUpdated(msgs)),
      );
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onSendMessage(
    SendMessage event,
    Emitter<ChatState> emit,
  ) async {
    try {
      await _repository.sendMessage(
        requestId: event.requestId,
        senderId: event.senderId,
        senderRole: event.senderRole,
        message: event.message,
      );
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _onSendToN8n(
    SendToN8n event,
    Emitter<ChatState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatLoaded) return;

    // Add user message to local n8n chat
    final userMsg = ChatMessageModel(
      senderId: event.victimId,
      senderRole: 'victim',
      message: event.message,
      createdAt: DateTime.now(),
    );
    final updatedN8nMessages = List<ChatMessageModel>.from(currentState.n8nMessages)..add(userMsg);
    emit(currentState.copyWith(n8nMessages: updatedN8nMessages));

    developer.log('ChatBloc: Sending to n8n: ${event.message}');

    // Send to n8n and get response
    final response = await _repository.sendToN8n(
      message: event.message,
      victimId: event.victimId,
      lat: event.lat,
      lng: event.lng,
    );

    developer.log('ChatBloc: Got n8n response: $response');

    // Add bot response
    final botMsg = ChatMessageModel(
      senderId: 'n8n',
      senderRole: 'bot',
      message: response,
      createdAt: DateTime.now(),
    );

    // Re-read state after async gap — it may have changed
    final latestState = state;
    if (latestState is ChatLoaded) {
      final newN8nMessages = List<ChatMessageModel>.from(latestState.n8nMessages)..add(botMsg);
      developer.log('ChatBloc: Emitting ${newN8nMessages.length} n8n messages');
      emit(latestState.copyWith(n8nMessages: newN8nMessages));
    }
  }

  void _onMessagesUpdated(
    MessagesUpdated event,
    Emitter<ChatState> emit,
  ) {
    final messages =
        event.messages.map((e) => e as ChatMessageModel).toList();
    final currentState = state;
    if (currentState is ChatLoaded) {
      emit(currentState.copyWith(messages: messages));
    } else {
      emit(ChatLoaded(messages: messages));
    }
  }

  @override
  Future<void> close() {
    _messagesSubscription?.cancel();
    return super.close();
  }
}
