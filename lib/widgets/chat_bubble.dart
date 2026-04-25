import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final String senderLabel;
  final String? time;

  /// Called when the user taps the 🔊 SPEAK button.
  /// Only shown on bot messages (isMe == false) when this is non-null.
  final VoidCallback? onSpeak;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.senderLabel,
    this.time,
    this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    const Color neonCyan = Color(0xFF2563EB); // Trust Blue

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Sender label
            Padding(
              padding: const EdgeInsets.only(left: 10, right: 10, bottom: 4),
              child: Text(
                senderLabel.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: isMe
                      ? neonCyan.withValues(alpha: 0.8)
                      : Colors.blueGrey.shade400,
                ),
              ),
            ),

            // Message bubble
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
              decoration: BoxDecoration(
                color: isMe ? neonCyan : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
                border: Border.all(
                  color: isMe
                      ? neonCyan.withValues(alpha: 0.1)
                      : const Color(0xFFE2E8F0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      color: isMe ? Colors.white : const Color(0xFF1E293B),
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: isMe ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  if (time != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      time!,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: isMe
                            ? Colors.white.withValues(alpha: 0.7)
                            : Colors.blueGrey.shade300,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 🔊 SPEAK button — only for bot messages when onSpeak is provided
            if (!isMe && onSpeak != null) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onSpeak,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.volume_up_rounded,
                          size: 14,
                          color: neonCyan),
                      const SizedBox(width: 6),
                      Text(
                        'LISTEN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: neonCyan,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
