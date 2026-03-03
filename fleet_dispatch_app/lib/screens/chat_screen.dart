import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';

import '../core/config/app_colors.dart';
import '../providers/chat_provider.dart';
import '../providers/category_provider.dart';
import '../providers/connectivity_provider.dart';
import '../widgets/chat/message_bubble.dart';
import '../widgets/chat/typing_indicator.dart';
import '../widgets/chat/streaming_indicator.dart';
import '../widgets/chat/query_input_bar.dart';
import '../widgets/chat/empty_state.dart';
import '../widgets/chat/category_chip_bar.dart';
import '../widgets/common/network_banner.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final categories = ref.watch(categoriesProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final l10n = AppLocalizations.of(context)!;

    // Auto-scroll when new messages arrive
    ref.listen(chatProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length ||
          previous?.streamingContent != next.streamingContent) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(l10n.chatTitle),
            Text(
              l10n.online,
              style: TextStyle(
                fontSize: 12,
                color: isOnline ? AppColors.success : AppColors.error,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.clearChat,
            onPressed: () => ref.read(chatProvider.notifier).clearChat(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Offline banner
          if (!isOnline) const NetworkBanner(),

          // Category chip bar (visible when messages exist)
          if (chatState.messages.isNotEmpty)
            CategoryChipBar(
              categories: categories,
              onQueryTap: (query) =>
                  ref.read(chatProvider.notifier).sendMessage(query),
            ),

          // Message list or empty state
          Expanded(
            child: chatState.messages.isEmpty
                ? EmptyState(
                    categories: categories,
                    selectedCategory: chatState.selectedCategory,
                    onCategoryTap: (id) =>
                        ref.read(chatProvider.notifier).selectCategory(id),
                    onQueryTap: (query) =>
                        ref.read(chatProvider.notifier).sendMessage(query),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: chatState.messages.length +
                        (chatState.isLoading ||
                                chatState.streamingContent.isNotEmpty
                            ? 1
                            : 0),
                    itemBuilder: (context, index) {
                      if (index < chatState.messages.length) {
                        final msg = chatState.messages[index];
                        return MessageBubble(
                          message: msg,
                          onDisambiguationSelect: (value) =>
                              ref.read(chatProvider.notifier).sendMessage(value),
                          onClarificationSelect: (route, originalQuery) => ref
                              .read(chatProvider.notifier)
                              .sendMessage(originalQuery, forcedRoute: route),
                          onPageSelect: (messageId, page) => ref
                              .read(chatProvider.notifier)
                              .loadPage(messageId, page),
                          isLoadingPage:
                              chatState.loadingMoreMessageId == msg.id,
                        );
                      }
                      // Streaming or loading indicator
                      if (chatState.streamingContent.isNotEmpty) {
                        return StreamingIndicator(
                          content: chatState.streamingContent,
                          phase: chatState.streamingPhase,
                        );
                      }
                      return const TypingIndicator();
                    },
                  ),
          ),

          // Input bar
          QueryInputBar(
            onSend: (text) =>
                ref.read(chatProvider.notifier).sendMessage(text),
            onClear: () => ref.read(chatProvider.notifier).clearChat(),
            isLoading: chatState.isLoading,
          ),
        ],
      ),
    );
  }
}
