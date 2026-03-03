import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../l10n/app_localizations.dart';

import '../../core/config/app_colors.dart';

class QueryInputBar extends StatefulWidget {
  final Function(String) onSend;
  final VoidCallback onClear;
  final bool isLoading;

  const QueryInputBar({
    super.key,
    required this.onSend,
    required this.onClear,
    required this.isLoading,
  });

  @override
  State<QueryInputBar> createState() => _QueryInputBarState();
}

class _QueryInputBarState extends State<QueryInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _speech.stop();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    widget.onSend(text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.speechNotAvailable)),
        );
      }
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      HapticFeedback.mediumImpact();
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _controller.text = result.recognizedWords;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
          });
          if (result.finalResult) {
            setState(() => _isListening = false);
          }
        },
        localeId: Localizations.localeOf(context).languageCode == 'ar'
            ? 'ar-SA'
            : 'en-US',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: AppColors.indigo500.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Listening indicator
            if (_isListening)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mic, color: AppColors.error, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      l10n.listening,
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            Row(
              children: [
                // Voice input button
                IconButton(
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? AppColors.error : null,
                  ),
                  tooltip: l10n.voiceInput,
                  onPressed: widget.isLoading ? null : _toggleListening,
                ),
                const SizedBox(width: 4),

                // Text input
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: 4,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: l10n.typeMessage,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
                const SizedBox(width: 8),

                // Send button
                Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.sendButtonGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: widget.isLoading ? null : _handleSend,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
