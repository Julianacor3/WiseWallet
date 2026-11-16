import 'package:flutter/material.dart';

import '../services/api_service.dart';

class ChatbotScreen extends StatefulWidget {
  final String token;

  const ChatbotScreen({super.key, required this.token});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _messages = [];

  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Limpia Markdown, conserva los saltos de linea y presenta las listas
  // con viñetas sencillas.
  String _formatAssistantText(String text) {
    final cleanedText = text
        .replaceAll(RegExp(r'```[\s\S]*?```'), '')
        .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true), '')
        .replaceAll('**', '')
        .replaceAll('__', '')
        .replaceAll('`', '')
        .replaceAll(RegExp(r'^\s*[-*]\s+', multiLine: true), '• ')
        .replaceAll(RegExp(r'^\s*\d+[.)]\s+', multiLine: true), '• ')
        .replaceAll(RegExp(r'^\s*>\s?', multiLine: true), '')
        .replaceAll('*', '')
        .trim();

    return _formatThousandsSeparators(cleanedText);
  }

  // Normaliza cantidades con o sin separadores de miles.
  // Evita modificar fechas como 2026-11-16 y valores junto a fechas/horas.
  String _formatThousandsSeparators(String text) {
    final numberPattern = RegExp(
      r'(?<![\d/:-])(?:\d{1,3}(?:[.,]\d{3})+|\d{4,})(?![\d/:-])',
    );

    return text.replaceAllMapped(numberPattern, (match) {
      final number = match.group(0)!;
      final digitsOnly = number.replaceAll(RegExp(r'[.,]'), '');

      if (digitsOnly.length < 4) {
        return number;
      }

      final formatted = digitsOnly.replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => '.',
      );

      return formatted;
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();

    if (message.isEmpty || _isSending) return;

    setState(() {
      _messages.add({'text': message, 'isUser': true});
      _isSending = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await ApiService.sendChatbotMessage(
        token: widget.token,
        message: message,
      );

      final reply = (response['reply'] ?? '').toString().trim();

      if (reply.isEmpty) {
        throw Exception('El asistente no devolvio una respuesta.');
      }

      if (!mounted) return;

      setState(() {
        _messages.add({'text': _formatAssistantText(reply), 'isUser': false});
      });
    } catch (error) {
      if (!mounted) return;

      final errorMessage = error
          .toString()
          .replaceFirst('Exception: ', '')
          .trim();

      setState(() {
        _messages.add({
          'text':
              'No pude obtener una respuesta en este momento. '
              '$errorMessage\n\nPuedes intentarlo nuevamente.',
          'isUser': false,
        });
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    final isUser = message['isUser'] as bool;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: 7),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFFD5D2F0) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message['text'] as String,
          style: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: Color(0xFF292638),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 7),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF7569B5),
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Wise Assistant está pensando...',
              style: TextStyle(fontSize: 13, color: Color(0xFF292638)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcome() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 42,
              backgroundColor: Color(0xFFEAE7F8),
              child: Icon(
                Icons.smart_toy_outlined,
                size: 45,
                color: Color(0xFF7569B5),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '¡Hola! Soy Wise Assistant',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Estoy aquí para ayudarte a organizar '
              'tus finanzas, comprender tus gastos '
              'y trabajar hacia tus metas financieras.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            const Text(
              '¿Qué te gustaría consultar?',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF7569B5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFD5D2F0),
        title: const Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.smart_toy_outlined, color: Color(0xFF7569B5)),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wise Assistant',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                Text('Tu asistente financiero', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildWelcome()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isSending) {
                        return _buildTypingIndicator();
                      }

                      return _buildMessage(_messages[index]);
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Escribe tu mensaje...',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF7569B5),
                  child: IconButton(
                    onPressed: _isSending ? null : _sendMessage,
                    icon: _isSending
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 20),
                    tooltip: 'Enviar mensaje',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
