import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Kumpulkan context dari providers dan kirim ke Gemini
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();

    // Simpan pesan user
    final storage = ref.read(userScopedStorageProvider);
    final userMsg = {'role': 'user', 'text': text};
    await storage.addChatMessage(userMsg);

    ref.read(chatHistoryProvider.notifier).state = storage.getChatHistory();
    ref.read(chatLoadingProvider.notifier).state = true;

    _scrollToBottom();

    // Kumpulkan context dari providers
    final currentUser = ref.read(currentUserProvider);
    final balance = ref.read(walletBalanceProvider);
    final address = ref.read(walletAddressProvider);
    final prices = ref.read(ethPriceProvider);
    final isInSafeZone = ref.read(isInSafeZoneProvider);
    final safeZones = ref.read(userSafeZonesProvider);
    final timezone = ref.read(selectedTimezoneProvider);

    final context = {
      'username': currentUser?.username ?? 'User',
      'walletAddress': address,
      'balance': balance,
      'ethUsd': prices['usd'] ?? 0.0,
      'ethIdr': prices['idr'] ?? 0.0,
      'isInSafeZone': isInSafeZone,
      'safeZoneCount': safeZones.length,
      'timezone': timezone,
    };

    // Kirim ke Gemini dengan context
    final gemini = ref.read(geminiServiceProvider);
    final response = await gemini.sendContextualMessage(text, context);

    final aiMsg = {'role': 'assistant', 'text': response};
    await storage.addChatMessage(aiMsg);

    ref.read(chatHistoryProvider.notifier).state = storage.getChatHistory();
    ref.read(chatLoadingProvider.notifier).state = false;

    _scrollToBottom();
  }

  void _scrollToBottom() {
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

  Future<void> _clearHistory() async {
    final storage = ref.read(userScopedStorageProvider);
    await storage.clearChatHistory();
    ref.read(chatHistoryProvider.notifier).state = [];
  }

  @override
  Widget build(BuildContext context) {
    final chatHistory = ref.watch(chatHistoryProvider);
    final isLoading = ref.watch(chatLoadingProvider);
    final currentUser = ref.watch(currentUserProvider);
    final balance = ref.watch(walletBalanceProvider);
    final isInSafeZone = ref.watch(isInSafeZoneProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('NexusBot'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearHistory,
            tooltip: 'Bersihkan Riwayat',
          ),
        ],
      ),
      body: Column(
        children: [
          _ContextBadge(
            username: currentUser?.username,
            balance: balance,
            isInSafeZone: isInSafeZone,
          ),

          // Messages List
          Expanded(
            child: chatHistory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Color(0xFF16213E),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.smart_toy,
                            size: 48,
                            color: Color(0xFF6C63FF),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Halo, Saya NexusBot',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ada yang bisa saya bantu?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _SuggestionChip(
                              label: 'Berapa saldo saya?',
                              onTap: () {
                                _controller.text = 'Berapa saldo saya?';
                                _sendMessage();
                              },
                            ),
                            _SuggestionChip(
                              label: 'Bisa transaksi sekarang?',
                              onTap: () {
                                _controller.text =
                                    'Apakah saya bisa melakukan transaksi sekarang?';
                                _sendMessage();
                              },
                            ),
                            _SuggestionChip(
                              label: 'Harga ETH hari ini?',
                              onTap: () {
                                _controller.text = 'Berapa harga ETH sekarang?';
                                _sendMessage();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: chatHistory.length,
                    itemBuilder: (context, index) {
                      final msg = chatHistory[index];
                      final isUser = msg['role'] == 'user';
                      return _ChatBubble(
                        text: msg['text'] ?? '',
                        isUser: isUser,
                      );
                    },
                  ),
          ),

          // Loading Indicator
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'NexusBot sedang mengetik...',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(top: BorderSide(color: Colors.grey[800]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Tanyakan sesuatu...',
                      border: InputBorder.none,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: isLoading ? null : _sendMessage,
                  icon: const Icon(Icons.send, color: Color(0xFF6C63FF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Context Badge 
class _ContextBadge extends StatelessWidget {
  final String? username;
  final double balance;
  final bool isInSafeZone;

  const _ContextBadge({
    required this.username,
    required this.balance,
    required this.isInSafeZone,
  });

  @override
  Widget build(BuildContext context) {
    if (username == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: const Color(0xFF0F3460),
      child: Row(
        children: [
          const Icon(Icons.person, size: 12, color: Colors.white54),
          const SizedBox(width: 4),
          Text(
            username!,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.currency_bitcoin, size: 12, color: Colors.white54),
          const SizedBox(width: 4),
          Text(
            '${balance.toStringAsFixed(4)} ETH',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const Spacer(),
          Icon(
            isInSafeZone ? Icons.shield : Icons.shield_outlined,
            size: 12,
            color: isInSafeZone ? Colors.greenAccent : Colors.redAccent,
          ),
          const SizedBox(width: 4),
          Text(
            isInSafeZone ? 'Zona Aman' : 'Luar Zona',
            style: TextStyle(
              color: isInSafeZone ? Colors.greenAccent : Colors.redAccent,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// Suggestion prompt
class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF).withAlpha(30),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF6C63FF).withAlpha(80)),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 12),
        ),
      ),
    );
  }
}

// Chat Bubble 
class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const _ChatBubble({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF6C63FF) : const Color(0xFF16213E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(text, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}
