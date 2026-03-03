import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/app_colors.dart';
import '../../models/chat_message.dart';
import 'disambiguation_card.dart';
import 'clarification_card.dart';
import 'message_metadata.dart';
import '../charts/chart_widget.dart';
import 'data_table_view.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final Function(String) onDisambiguationSelect;
  final Function(String, String) onClarificationSelect;
  final Function(String messageId, int page)? onPageSelect;
  final bool isLoadingPage;

  const MessageBubble({
    super.key,
    required this.message,
    required this.onDisambiguationSelect,
    required this.onClarificationSelect,
    this.onPageSelect,
    this.isLoadingPage = false,
  });

  void _showShareMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Text'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share Message'),
              onTap: () {
                Navigator.pop(ctx);
                Share.share(message.content);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: isUser ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: GestureDetector(
        onLongPress: () {
          HapticFeedback.mediumImpact();
          _showShareMenu(context);
        },
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.85,
          ),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: isUser ? AppColors.userBubbleGradient : null,
            color: isUser
                ? null
                : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
            borderRadius: BorderRadiusDirectional.only(
              topStart: const Radius.circular(16),
              topEnd: const Radius.circular(16),
              bottomStart: isUser
                  ? const Radius.circular(16)
                  : const Radius.circular(4),
              bottomEnd: isUser
                  ? const Radius.circular(4)
                  : const Radius.circular(16),
            ),
            border: isUser
                ? null
                : Border.all(
                    color: AppColors.indigo500.withValues(alpha: 0.2),
                  ),
          ),
          child: isUser
              ? Text(
                  message.content,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                )
              : _BotMessageContent(
                  message: message,
                  onDisambiguationSelect: onDisambiguationSelect,
                  onClarificationSelect: onClarificationSelect,
                  onPageSelect: onPageSelect,
                  isLoadingPage: isLoadingPage,
                ),
        ),
      ),
    );
  }
}

class _BotMessageContent extends StatelessWidget {
  final ChatMessage message;
  final Function(String) onDisambiguationSelect;
  final Function(String, String) onClarificationSelect;
  final Function(String messageId, int page)? onPageSelect;
  final bool isLoadingPage;

  const _BotMessageContent({
    required this.message,
    required this.onDisambiguationSelect,
    required this.onClarificationSelect,
    this.onPageSelect,
    this.isLoadingPage = false,
  });

  @override
  Widget build(BuildContext context) {
    final meta = message.metadata;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Markdown content (selectable on web, non-selectable on mobile
        // to reduce selection handle overhead; long-press copy is available)
        MarkdownBody(
          data: message.content,
          selectable: kIsWeb,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: Theme.of(context).textTheme.bodyMedium,
            code: TextStyle(
              backgroundColor:
                  AppColors.indigo900.withValues(alpha: 0.3),
              color: AppColors.indigo500,
              fontSize: 13,
            ),
            codeblockDecoration: BoxDecoration(
              color: AppColors.indigo900.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),

        // Visualization (chart + table toggle)
        if (meta?.visualization?.shouldVisualize == true &&
            meta?.tableData != null) ...[
          const SizedBox(height: 12),
          ChartWidget(
            visualization: meta!.visualization!,
            tableData: meta.tableData!,
          ),
        ]
        // Data table only (when no chart)
        else if (meta?.tableData != null && meta!.tableData!.hasData) ...[
          const SizedBox(height: 12),
          DataTableView(
            tableData: meta.tableData!,
            onPageSelect: onPageSelect != null
                ? (page) => onPageSelect!(message.id, page)
                : null,
            isLoadingPage: isLoadingPage,
          ),
        ],

        // Disambiguation options
        if (meta?.needsDisambiguation == true &&
            meta?.disambiguationOptions != null) ...[
          const SizedBox(height: 12),
          DisambiguationCard(
            options: meta!.disambiguationOptions!,
            onSelect: onDisambiguationSelect,
          ),
        ],

        // Clarification options
        if (meta?.needsClarification == true &&
            meta?.clarificationOptions != null) ...[
          const SizedBox(height: 12),
          ClarificationCard(
            message: meta!.clarificationMessage ?? '',
            options: meta.clarificationOptions!,
            originalQuery: message.originalQuery ?? message.content,
            onSelect: onClarificationSelect,
          ),
        ],

        // Metadata footer
        if (meta != null &&
            !meta.needsDisambiguation &&
            !meta.needsClarification) ...[
          const SizedBox(height: 8),
          MessageMetadataBar(
            responseTime: meta.responseTime,
            sources: meta.sources,
            tableData: meta.tableData,
          ),
        ],
      ],
    );
  }
}
