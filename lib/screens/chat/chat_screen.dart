import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_theme.dart';
import '../../providers/app_provider.dart';
import '../../widgets/transaction_tile.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  bool _showHints = false;
  bool _showSuggestionsPanel = false;
  bool _hasText = false;

  static const _fallbackHints = [
    'coffee 35',
    'spent 85 on lunch today',
    'salary 12000',
    'paid rent 3500 yesterday',
    'saved 500 to emergency fund',
    'uber 45 last Friday',
    'got paid 12000',
    'electricity bill 280',
  ];

  @override
  void initState() {
    super.initState();
    _inputCtrl.addListener(() {
      final hasText = _inputCtrl.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send(AppProvider provider) {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    setState(() {
      _showSuggestionsPanel = false;
      _showHints = false;
    });
    provider.sendMessage(text).then((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<String> _buildHints(List<Map<String, dynamic>> suggestions) {
    if (suggestions.isEmpty) return _fallbackHints;
    final fromDb = suggestions.map((s) {
      final item = s['item'] as String;
      final amount = s['amount'];
      if (amount != null) return '$item ${(amount as num).toStringAsFixed(0)}';
      return item;
    }).toList();
    if (fromDb.length < 4) {
      final extra = _fallbackHints
          .where((h) => !fromDb.any(
              (f) => f.toLowerCase().contains(h.split(' ').first)))
          .take(4 - fromDb.length);
      return [...fromDb, ...extra];
    }
    return fromDb;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = context.appColors;
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final messages       = provider.chatMessages;
        final currency       = provider.profile?.currency ?? 'EGP';
        final hasSuggestions =
            provider.showSuggestions && provider.suggestions.isNotEmpty;
        final hints = _buildHints(provider.suggestions);

        return Scaffold(
          backgroundColor: c.bgPrimary,
          appBar: AppBar(
            backgroundColor: c.bgPrimary,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Budget Chat',
                    style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                Text('Log transactions or ask anything',
                    style: TextStyle(color: c.textMuted, fontSize: 11)),
              ],
            ),
          ),
          body: Column(
            children: [
              // ── Messages ──────────────────────────────────
              Expanded(
                child: messages.isEmpty
                    ? _EmptyChat(
                        onHintTap: () => setState(() => _showHints = true))
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding:
                            const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        itemCount:
                            messages.length + (provider.isProcessing ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i == messages.length) {
                            return const _TypingIndicator();
                          }
                          return _ChatBubble(
                            key: ValueKey(messages[i].id),
                            message: messages[i],
                          );
                        },
                      ),
              ),

              // ── Inline suggestions panel (above input bar) ─
              if (hasSuggestions && _showSuggestionsPanel)
                _SuggestionsPanel(
                  provider: provider,
                  currency: currency,
                  inputCtrl: _inputCtrl,
                  focusNode: _focusNode,
                  onClose: () => setState(() => _showSuggestionsPanel = false),
                ),

              // ── Hints bar (ABOVE input bar, animated) ─────
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: _showHints
                    ? _HintsBar(
                        hints: hints,
                        onSelect: (h) {
                          _inputCtrl.text = h;
                          _inputCtrl.selection = TextSelection.fromPosition(
                            TextPosition(offset: h.length),
                          );
                          setState(() => _showHints = false);
                          _focusNode.requestFocus();
                        },
                        onClose: () => setState(() => _showHints = false),
                      )
                    : const SizedBox.shrink(),
              ),

              // ── Input bar ─────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: c.bgSecondary,
                  border: Border(top: BorderSide(color: c.border)),
                ),
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 8,
                  bottom:
                      MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 20,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Text field
                    Expanded(
                      child: TextField(
                        controller: _inputCtrl,
                        focusNode: _focusNode,
                        style: TextStyle(color: c.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText:
                              'Type a transaction or ask a question…',
                          hintStyle:
                              TextStyle(color: c.textMuted, fontSize: 14),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        onSubmitted: (_) => _send(provider),
                        textInputAction: TextInputAction.send,
                      ),
                    ),

                    const SizedBox(width: 8),

                    // ── Adaptive action button ─────────────────
                    _AdaptiveActionButton(
                      hasText: _hasText,
                      isProcessing: provider.isProcessing,
                      hasSuggestions: hasSuggestions,
                      showSuggestionsPanel: _showSuggestionsPanel,
                      showHints: _showHints,
                      onSend: () => _send(provider),
                      onToggleSuggestions: () => setState(() {
                        _showSuggestionsPanel = !_showSuggestionsPanel;
                        _showHints = false;
                      }),
                      onToggleHints: () => setState(() {
                        _showHints = !_showHints;
                        _showSuggestionsPanel = false;
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

}

// ── Hints Bar (now above input) ────────────────────────────────
class _HintsBar extends StatelessWidget {
  final List<String> hints;
  final ValueChanged<String> onSelect;
  final VoidCallback onClose;

  const _HintsBar({
    required this.hints,
    required this.onSelect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      color: c.bgSecondary,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '💡 Try saying...',
                style: TextStyle(
                    color: AppTheme.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              GestureDetector(
                onTap: onClose,
                child: Icon(Icons.close_rounded,
                    color: c.textMuted, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: hints
                .map((h) => GestureDetector(
                      onTap: () => onSelect(h),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.warning.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          h,
                          style: const TextStyle(
                              color: AppTheme.warning, fontSize: 12),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ── Suggestions panel ──────────────────────────────────────────
class _SuggestionsPanel extends StatelessWidget {
  final AppProvider provider;
  final String currency;
  final TextEditingController inputCtrl;
  final FocusNode focusNode;
  final VoidCallback onClose;

  const _SuggestionsPanel({
    required this.provider,
    required this.currency,
    required this.inputCtrl,
    required this.focusNode,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      color: c.bgSecondary,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 92,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: provider.suggestions.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final s = provider.suggestions[i];
            final item = s['item'] as String;
            final amount = s['amount'];
            return GestureDetector(
              onTap: () {
                if (amount != null) {
                  inputCtrl.text =
                      '$item ${(amount as num).toStringAsFixed(2)}';
                } else {
                  inputCtrl.text = item;
                }
                inputCtrl.selection = TextSelection.fromPosition(
                    TextPosition(offset: inputCtrl.text.length));
                focusNode.requestFocus();
                onClose();
              },
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.42,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: c.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      if (amount != null) ...[
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$currency ${(amount as num).toStringAsFixed(0)}',
                            style: TextStyle(
                                color: c.textMuted, fontSize: 11),
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Adaptive action button ─────────────────────────────────────
class _AdaptiveActionButton extends StatelessWidget {
  final bool hasText;
  final bool isProcessing;
  final bool hasSuggestions;
  final bool showSuggestionsPanel;
  final bool showHints;
  final VoidCallback onSend;
  final VoidCallback onToggleSuggestions;
  final VoidCallback onToggleHints;

  const _AdaptiveActionButton({
    required this.hasText,
    required this.isProcessing,
    required this.hasSuggestions,
    required this.showSuggestionsPanel,
    required this.showHints,
    required this.onSend,
    required this.onToggleSuggestions,
    required this.onToggleHints,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    if (hasText || isProcessing) {
      return GestureDetector(
        onTap: isProcessing ? null : onSend,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: isProcessing ? null : AppTheme.primaryGradient,
            color: isProcessing ? c.bgCardAlt : null,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: isProcessing
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.textMuted,
                  ),
                )
              : Icon(Icons.arrow_upward_rounded,
                  color: c.bgPrimary, size: 18),
        ),
      );
    }

    if (hasSuggestions) {
      final isActive = showSuggestionsPanel;
      return GestureDetector(
        onTap: onToggleSuggestions,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.accent.withValues(alpha: 0.2) : c.bgCard,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: isActive ? AppTheme.accent : c.border),
          ),
          alignment: Alignment.center,
          child: const Text('✨', style: TextStyle(fontSize: 16)),
        ),
      );
    }

    final isActive = showHints;
    return GestureDetector(
      onTap: onToggleHints,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isActive ? AppTheme.warning.withValues(alpha: 0.15) : c.bgCard,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: isActive ? AppTheme.warning : c.border),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.lightbulb_outline_rounded,
          color: isActive ? AppTheme.warning : c.textMuted,
          size: 18,
        ),
      ),
    );
  }
}

// ── Chat bubble ────────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const _ChatBubble({required Key key, required this.message})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c       = context.appColors;
    final isUser  = message.type == ChatMessageType.user;
    final isTip   = message.type == ChatMessageType.tip;
    final isError = message.type == ChatMessageType.error;
    final isArlo  = message.type == ChatMessageType.chatbot;

    if (isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 60),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: c.bgPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    if (isTip) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
          ),
          child: Text(
            message.text,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    // Arlo chatbot bubble — distinct style with purple/indigo accent
    if (isArlo) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16, right: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Text('Arlo',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  border: Border.all(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.2)),
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final tx = message.transaction;
    // Logged transactions: show only the editable tile (summary text is redundant).
    if (tx != null && !isError) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12, right: 8),
        child: TransactionTile(
          tx: tx,
          showCategory: true,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isError
                  ? AppTheme.danger.withValues(alpha: 0.1)
                  : c.bgCard,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(
                color: isError
                    ? AppTheme.danger.withValues(alpha: 0.3)
                    : c.border,
              ),
            ),
            child: _buildMessageContent(message.text, c),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(String text, AppColors c) {
    final spans = <TextSpan>[];
    final parts = text.split('**');
    for (int i = 0; i < parts.length; i++) {
      spans.add(TextSpan(
        text: parts[i],
        style: TextStyle(
          color: c.textPrimary,
          fontSize: 14,
          height: 1.5,
          fontWeight: i.isOdd ? FontWeight.w700 : FontWeight.w400,
        ),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }
}

// ── Typing indicator ───────────────────────────────────────────
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: c.bgCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.border),
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Row(
                children: List.generate(3, (i) {
                  final delay   = i * 0.3;
                  final t       = (_ctrl.value + delay) % 1.0;
                  final opacity =
                      (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.2, 1.0);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Opacity(
                      opacity: opacity,
                      child: CircleAvatar(
                        radius: 3.5,
                        backgroundColor: c.textMuted,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty chat ─────────────────────────────────────────────────
class _EmptyChat extends StatelessWidget {
  final VoidCallback onHintTap;
  const _EmptyChat({required this.onHintTap});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('💬', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'Start chatting!',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Log a transaction or ask me anything about budgeting.',
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: onHintTap,
              icon: const Icon(Icons.lightbulb_outline_rounded,
                  color: AppTheme.warning, size: 16),
              label: const Text('See examples'),
              style:
                  TextButton.styleFrom(foregroundColor: AppTheme.warning),
            ),
          ],
        ),
      ),
    );
  }
}
