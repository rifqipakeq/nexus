import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
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

  Future<void> _sendMessage() async {
    final isPremium = ref.read(isPremiumProvider);
    if (!isPremium) return; 

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();

    // Deduct token
    final quizService = ref.read(quizServiceProvider);
    final hasTokens = await quizService.spendToken();
    if (!hasTokens) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Token anda habis. Main quiz untuk dapat token lagi!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final storage = ref.read(userScopedStorageProvider);
    ref.read(quizTokensProvider.notifier).state = storage.getQuizTokens();
    ref.read(isPremiumProvider.notifier).state = storage.isPremium;

    final userMsg = {'role': 'user', 'text': text};
    await storage.addChatMessage(userMsg);
    ref.read(chatHistoryProvider.notifier).state = storage.getChatHistory();
    ref.read(chatLoadingProvider.notifier).state = true;
    _scrollToBottom();

    // Gather context
    final currentUser = ref.read(currentUserProvider);
    final balance = ref.read(walletBalanceProvider);
    final address = ref.read(walletAddressProvider);
    final prices = ref.read(ethPriceProvider);
    final isInSafeZone = ref.read(isInSafeZoneProvider);
    final safeZones = ref.read(userSafeZonesProvider);
    final timezone = ref.read(selectedTimezoneProvider);
    final quizTokens = ref.read(quizTokensProvider);

    final ctx = {
      'username': currentUser?.username ?? 'User',
      'walletAddress': address,
      'balance': balance,
      'ethUsd': prices['usd'] ?? 0.0,
      'ethIdr': prices['idr'] ?? 0.0,
      'isInSafeZone': isInSafeZone,
      'safeZoneCount': safeZones.length,
      'timezone': timezone,
      'quizTokens': quizTokens,
      'isPremium': true,
    };

    final gemini = ref.read(geminiServiceProvider);
    final response = await gemini.sendContextualMessage(text, ctx);

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
    final isPremium = ref.watch(isPremiumProvider);
    final quizTokens = ref.watch(quizTokensProvider);

    if (!isPremium) {
      return _PremiumLockScreen(
        currentTokens: quizTokens,
        threshold: AppConstants.premiumTokenThreshold,
      );
    }

    final chatHistory = ref.watch(chatHistoryProvider);
    final isLoading = ref.watch(chatLoadingProvider);
    final currentUser = ref.watch(currentUserProvider);
    final balance = ref.watch(walletBalanceProvider);
    final isInSafeZone = ref.watch(isInSafeZoneProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        elevation: 0,
        title: Row(
          children: [
            const Text(
              'NexusBot',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            // Premium badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'PREMIUM',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Token counter
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.token, size: 13, color: Color(0xFF6C63FF)),
                    const SizedBox(width: 4),
                    Text(
                      '$quizTokens',
                      style: const TextStyle(
                        color: Color(0xFF6C63FF),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white70),
            onPressed: _clearHistory,
            tooltip: 'Bersihkan Riwayat Chat',
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

          // Messages
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
                          style: TextStyle(color: Colors.grey[500], fontSize: 13),
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
                      return _ChatBubble(
                        text: msg['text'] ?? '',
                        isUser: msg['role'] == 'user',
                      );
                    },
                  ),
          ),

          // Loading
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF6C63FF),
                    ),
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
              color: const Color(0xFF16213E),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Tanyakan sesuatu...',
                      hintStyle: TextStyle(color: Colors.white38),
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


class _PremiumLockScreen extends StatelessWidget {
  final int currentTokens;
  final int threshold;

  const _PremiumLockScreen({
    required this.currentTokens,
    required this.threshold,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (currentTokens / threshold).clamp(0.0, 1.0);
    final remaining = (threshold - currentTokens).clamp(0, threshold);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        elevation: 0,
        title: const Text(
          'NexusBot',
          style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w600),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lock icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6C63FF).withValues(alpha: 0.3),
                      const Color(0xFF6C63FF).withValues(alpha: 0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: Color(0xFF6C63FF),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Premium Feature',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'NexusBot AI adalah fitur premium.\nDapatkan $threshold quiz tokens untuk membuka akses penuh.',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 15,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Progress
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.token,
                                size: 16, color: Color(0xFF6C63FF)),
                            const SizedBox(width: 6),
                            const Text(
                              'Your Tokens',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 13),
                            ),
                          ],
                        ),
                        Text(
                          '$currentTokens / $threshold',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF6C63FF),
                        ),
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      remaining > 0
                          ? 'Play $remaining more tokens worth of quizzes to unlock!'
                          : 'Almost there!',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // CTA Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.quiz_outlined, size: 20),
                  label: const Text('Play Crypto Quiz to Earn Tokens'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '10 tokens per correct answer · Bonus for streaks',
                style: TextStyle(color: Colors.white24, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Existing sub-widgets (preserved) ────────────────────────────────────────

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
          Text(username!,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
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
          color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 12),
        ),
      ),
    );
  }
}

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
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color:
              isUser ? const Color(0xFF6C63FF) : const Color(0xFF16213E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(text, style: const TextStyle(fontSize: 14, color: Colors.white)),
      ),
    );
  }
}
