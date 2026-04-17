import 'package:equatable/equatable.dart';

class ChatMessageModel extends Equatable {
  final String? id;
  final String? requestId;
  final String senderId;
  final String senderRole;
  final String message;
  final DateTime? createdAt;

  const ChatMessageModel({
    this.id,
    this.requestId,
    required this.senderId,
    required this.senderRole,
    required this.message,
    this.createdAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String?,
      requestId: json['request_id'] as String?,
      senderId: json['sender_id'] as String? ?? '',
      senderRole: json['sender_role'] as String? ?? '',
      message: json['message'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'request_id': requestId,
      'sender_id': senderId,
      'sender_role': senderRole,
      'message': message,
    };
  }

  @override
  List<Object?> get props =>
      [id, requestId, senderId, senderRole, message, createdAt];
}
