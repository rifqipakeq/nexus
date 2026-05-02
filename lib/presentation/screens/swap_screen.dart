import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/swap_quote.dart';
import '../providers.dart';

class SwapScreen extends ConsumerStatefulWidget {
  const SwapScreen({super.key});

  @override
  ConsumerState<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends ConsumerState<SwapScreen>
    with SingleTickerProviderStateMixin {
  final _amountController = TextEditingController();

  String _tokenIn = 'ETH';
  String _tokenOut = 'USDC';
  SwapQuote? _quote;
  bool _isLoadingQuote = false;
  bool _isExecuting = false;
  String? _resultHash;

  late AnimationController _rotateController;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  final List<Map<String, String>> _tokens = const [
    {'symbol': 'ETH', 'name': 'Ethereum', 'icon': '⟠'},
    {'symbol': 'LINK', 'name': 'Chainlink', 'icon': '🔗'},
    {'symbol': 'UNI', 'name': 'Uniswap', 'icon': '🦄'},
    {'symbol': 'USDC', 'name': 'USD Coin', 'icon': '💵'},
  ];

  Future<void> _getQuote() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showSnack('Enter a valid amount');
      return;
    }
    if (_tokenIn == _tokenOut) {
      _showSnack('Select different tokens');
      return;
    }

    setState(() {
      _isLoadingQuote = true;
      _quote = null;
      _resultHash = null;
    });

    final swapService = ref.read(swapServiceProvider);
    final quote = await swapService.getQuote(
      tokenInSymbol: _tokenIn,
      tokenOutSymbol: _tokenOut,
      amountIn: amount,
    );

    setState(() {
      _quote = quote;
      _isLoadingQuote = false;
    });
  }

  Future<void> _executeSwap() async {
    if (_quote == null) return;

    final confirmed = await _showConfirmDialog();
    if (!confirmed) return;

    setState(() => _isExecuting = true);

    final swapService = ref.read(swapServiceProvider);
    try {
      final hash = await swapService.executeSwap(_quote!);
      setState(() {
        _resultHash = hash;
        _isExecuting = false;
        _quote = null;
        _amountController.clear();
      });
      _showSnack('Swap simulated ✓');
    } catch (e) {
      setState(() => _isExecuting = false);
      _showSnack('Swap failed: $e');
    }
  }

  Future<bool> _showConfirmDialog() async {
    final q = _quote!;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF16213E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Confirm Swap',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ConfirmRow(
                  label: 'You Pay',
                  value: '${q.amountIn} ${q.tokenInSymbol}',
                ),
                _ConfirmRow(
                  label: 'You Receive',
                  value:
                      '≈ ${q.estimatedAmountOut.toStringAsFixed(6)} ${q.tokenOutSymbol}',
                ),
                _ConfirmRow(
                  label: 'Min. Received',
                  value:
                      '${q.minimumReceived.toStringAsFixed(6)} ${q.tokenOutSymbol}',
                ),
                _ConfirmRow(
                  label: 'Slippage',
                  value: q.slippageLabel,
                ),
                _ConfirmRow(
                  label: 'Est. Gas',
                  value: '${q.estimatedGasEth.toStringAsFixed(6)} ETH',
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber, size: 14),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'This is a simulated swap on Sepolia testnet.',
                          style: TextStyle(color: Colors.amber, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _swapTokens() {
    _rotateController.forward(from: 0);
    setState(() {
      final tmp = _tokenIn;
      _tokenIn = _tokenOut;
      _tokenOut = tmp;
      _quote = null;
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        elevation: 0,
        title: const Text(
          'Token Swap',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Testnet banner
            _TestnetBanner(),
            const SizedBox(height: 20),

            // Swap Card
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white12),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Token In
                  _TokenInputSection(
                    label: 'You Pay',
                    selectedSymbol: _tokenIn,
                    tokens: _tokens,
                    controller: _amountController,
                    onTokenChanged: (v) => setState(() {
                      _tokenIn = v;
                      _quote = null;
                    }),
                  ),
                  const SizedBox(height: 8),

                  // Swap Direction Button
                  Center(
                    child: GestureDetector(
                      onTap: _swapTokens,
                      child: AnimatedBuilder(
                        animation: _rotateController,
                        builder: (_, child) => Transform.rotate(
                          angle: _rotateController.value * 3.14159,
                          child: child,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF6C63FF).withValues(alpha: 0.5),
                            ),
                          ),
                          child: const Icon(
                            Icons.swap_vert,
                            color: Color(0xFF6C63FF),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Token Out
                  _TokenOutputSection(
                    label: 'You Receive',
                    selectedSymbol: _tokenOut,
                    tokens: _tokens,
                    estimatedAmount: _quote?.estimatedAmountOut,
                    onTokenChanged: (v) => setState(() {
                      _tokenOut = v;
                      _quote = null;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Get Quote Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoadingQuote ? null : _getQuote,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoadingQuote
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Get Quote',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),

            // Quote Card
            if (_quote != null) ...[
              const SizedBox(height: 20),
              _QuoteCard(quote: _quote!),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isExecuting ? null : _executeSwap,
                  icon: _isExecuting
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.swap_horiz, size: 20),
                  label: Text(_isExecuting ? 'Executing...' : 'Execute Swap'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BFA5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],

            // Result
            if (_resultHash != null) ...[
              const SizedBox(height: 20),
              _ResultCard(hash: _resultHash!),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _TestnetBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.science_outlined, color: Colors.amber, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sepolia Testnet · Simulated Swap · No Real Value',
              style: TextStyle(color: Colors.amber, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _TokenInputSection extends StatelessWidget {
  final String label;
  final String selectedSymbol;
  final List<Map<String, String>> tokens;
  final TextEditingController controller;
  final ValueChanged<String> onTokenChanged;

  const _TokenInputSection({
    required this.label,
    required this.selectedSymbol,
    required this.tokens,
    required this.controller,
    required this.onTokenChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    hintText: '0.0',
                    hintStyle: TextStyle(color: Colors.white24),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              _TokenPicker(
                selectedSymbol: selectedSymbol,
                tokens: tokens,
                onChanged: onTokenChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TokenOutputSection extends StatelessWidget {
  final String label;
  final String selectedSymbol;
  final List<Map<String, String>> tokens;
  final double? estimatedAmount;
  final ValueChanged<String> onTokenChanged;

  const _TokenOutputSection({
    required this.label,
    required this.selectedSymbol,
    required this.tokens,
    required this.estimatedAmount,
    required this.onTokenChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  estimatedAmount != null
                      ? estimatedAmount!.toStringAsFixed(6)
                      : '—',
                  style: TextStyle(
                    color: estimatedAmount != null
                        ? Colors.white
                        : Colors.white38,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _TokenPicker(
                selectedSymbol: selectedSymbol,
                tokens: tokens,
                onChanged: onTokenChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TokenPicker extends StatelessWidget {
  final String selectedSymbol;
  final List<Map<String, String>> tokens;
  final ValueChanged<String> onChanged;

  const _TokenPicker({
    required this.selectedSymbol,
    required this.tokens,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: const Color(0xFF16213E),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: tokens.length,
            itemBuilder: (_, i) {
              final t = tokens[i];
              return ListTile(
                leading: Text(t['icon']!, style: const TextStyle(fontSize: 24)),
                title: Text(t['symbol']!,
                    style: const TextStyle(color: Colors.white)),
                subtitle: Text(t['name']!,
                    style: const TextStyle(color: Colors.white54)),
                onTap: () => Navigator.pop(ctx, t['symbol']),
              );
            },
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedSymbol,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down,
                color: Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  final SwapQuote quote;

  const _QuoteCard({required this.quote});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.receipt_long, color: Color(0xFF6C63FF), size: 16),
              SizedBox(width: 6),
              Text(
                'Quote Summary',
                style: TextStyle(
                  color: Color(0xFF6C63FF),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _QuoteRow('Rate',
              '1 ${quote.tokenInSymbol} = ${quote.exchangeRate.toStringAsFixed(4)} ${quote.tokenOutSymbol}'),
          _QuoteRow('Est. Output',
              '${quote.estimatedAmountOut.toStringAsFixed(6)} ${quote.tokenOutSymbol}'),
          _QuoteRow('Min. Received',
              '${quote.minimumReceived.toStringAsFixed(6)} ${quote.tokenOutSymbol}'),
          _QuoteRow('Slippage', quote.slippageLabel),
          _QuoteRow('Est. Gas', '${quote.estimatedGasEth.toStringAsFixed(6)} ETH'),
          if (quote.isSimulated)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  const Icon(Icons.computer, size: 12, color: Colors.white38),
                  const SizedBox(width: 4),
                  Text(
                    'Simulated price — for testnet demo only',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _QuoteRow extends StatelessWidget {
  final String label;
  final String value;

  const _QuoteRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;

  const _ConfirmRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String hash;

  const _ResultCard({required this.hash});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF00BFA5).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF00BFA5).withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF00BFA5), size: 40),
          const SizedBox(height: 10),
          const Text(
            'Swap Simulated Successfully!',
            style: TextStyle(
                color: Color(0xFF00BFA5),
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            hash,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
