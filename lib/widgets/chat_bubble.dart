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
    const Color neonCyan = Color(0xFF22D3EE);
    const Color darkBg = Color(0xFF0F172A);
    const Color slatePanel = Color(0xFF1E293B);

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
                  letterSpacing: 1.5,
                  color: isMe
                      ? neonCyan.withOpacity(0.7)
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
                color: isMe ? neonCyan : slatePanel.withOpacity(0.6),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
                border: Border.all(
                  color: isMe
                      ? neonCyan.withOpacity(0.3)
                      : neonCyan.withOpacity(0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  if (isMe)
                    BoxShadow(
                      color: neonCyan.withOpacity(0.15),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
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
                      color:
                          isMe ? darkBg : Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      height: 1.5,
                      fontWeight:
                          isMe ? FontWeight.w900 : FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (time != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      time!,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isMe
                            ? darkBg.withOpacity(0.5)
                            : Colors.blueGrey.shade400,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 🔊 SPEAK button — only for bot messages when onSpeak is provided
            if (!isMe && onSpeak != null) ...[
              const SizedBox(height: 5),
              GestureDetector(
                onTap: onSpeak,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: slatePanel,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: neonCyan.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.volume_up_rounded,
                          size: 13,
                          color: neonCyan.withOpacity(0.8)),
                      const SizedBox(width: 4),
                      Text(
                        'SPEAK',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: neonCyan.withOpacity(0.8),
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
