import 'package:flutter/material.dart';
import '../services/assistant_service.dart';

class MessageBubble extends StatelessWidget {
  final AssistantMessage message;

  const MessageBubble({
    Key? key,
    required this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    switch (message.type) {
      case MessageType.user:
        return _buildUserMessage(context);
      case MessageType.assistant:
        return _buildAssistantMessage(context);
      case MessageType.system:
        return _buildSystemMessage(context);
      case MessageType.error:
        return _buildErrorMessage(context);
    }
  }

  Widget _buildUserMessage(BuildContext context) {
    return _buildBubble(
      context,
      message: message.content,
      isInterim: message.isInterim,
      alignment: Alignment.centerRight,
      color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
      textColor: Colors.white,
      icon: Icons.person,
    );
  }

  Widget _buildAssistantMessage(BuildContext context) {
    return _buildBubble(
      context,
      message: message.content,
      isInterim: message.isInterim,
      alignment: Alignment.centerLeft,
      color: Theme.of(context).colorScheme.secondary.withOpacity(0.8),
      textColor: Colors.white,
      icon: Icons.assistant,
    );
  }

  Widget _buildSystemMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.content,
            style: TextStyle(
              color: Colors.grey[700],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message.content,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(
      BuildContext context, {
        required String message,
        required bool isInterim,
        required AlignmentGeometry alignment,
        required Color color,
        required Color textColor,
        required IconData icon,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Align(
        alignment: alignment,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isInterim ? color.withOpacity(0.5) : color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (this.message.image != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        this.message.image!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: textColor, size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: isInterim
                          ? _buildInterimText(message, textColor)
                          : Text(
                        message,
                        style: TextStyle(color: textColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInterimText(String text, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: TextStyle(color: textColor),
        ),
        const SizedBox(width: 4),
        _buildTypingIndicator(textColor),
      ],
    );
  }

  Widget _buildTypingIndicator(Color color) {
    return SizedBox(
      width: 24,
      height: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          3,
              (index) => _buildDot(index, color),
        ),
      ),
    );
  }

  Widget _buildDot(int index, Color color) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}