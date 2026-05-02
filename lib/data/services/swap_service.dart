import 'package:flutter/foundation.dart';
import '../models/swap_quote.dart';

/// Simulated token swap service.
///
/// Uses hardcoded exchange rates relative to ETH for demo/testnet purposes.
/// In production, replace _getRate() with a 0x API or Uniswap call.
class SwapService {
  /// Simulated exchange rates (all relative to ETH = 1.0)
  static const Map<String, double> _ratesInEth = {
    'ETH': 1.0,
    'LINK': 0.005,    // 1 LINK ≈ 0.005 ETH
    'UNI': 0.003,     // 1 UNI  ≈ 0.003 ETH
    'USDC': 0.00025,  // 1 USDC ≈ 0.00025 ETH (at ~$4000/ETH)
  };

  static const double _defaultSlippagePct = 0.5;
  static const double _estimatedGasEth = 0.0003; // ~$1.20 at $4000/ETH

  /// Get a simulated swap quote.
  Future<SwapQuote?> getQuote({
    required String tokenInSymbol,
    required String tokenOutSymbol,
    required double amountIn,
  }) async {
    if (amountIn <= 0) return null;

    final rateIn = _ratesInEth[tokenInSymbol];
    final rateOut = _ratesInEth[tokenOutSymbol];

    if (rateIn == null || rateOut == null) {
      debugPrint('[SwapService] Unknown token: $tokenInSymbol or $tokenOutSymbol');
      return null;
    }

    // Convert: amountIn (tokenIn) → ETH → tokenOut
    final ethValue = amountIn * rateIn;
    final amountOut = ethValue / rateOut;
    final exchangeRate = amountOut / amountIn; // 1 tokenIn = X tokenOut

    // Simulate small async delay (as if hitting an API)
    await Future.delayed(const Duration(milliseconds: 600));

    return SwapQuote(
      tokenInSymbol: tokenInSymbol,
      tokenOutSymbol: tokenOutSymbol,
      amountIn: amountIn,
      estimatedAmountOut: amountOut,
      slippagePct: _defaultSlippagePct,
      estimatedGasEth: _estimatedGasEth,
      exchangeRate: exchangeRate,
      isSimulated: true,
    );
  }

  /// Simulate executing a swap (returns a fake tx hash).
  Future<String> executeSwap(SwapQuote quote) async {
    // Simulate network latency
    await Future.delayed(const Duration(seconds: 2));

    // Generate a plausible-looking fake hash for demo
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fakeHash = '0xSIM${timestamp.toRadixString(16).padLeft(16, '0')}';

    debugPrint(
      '[SwapService] Simulated swap: ${quote.amountIn} ${quote.tokenInSymbol} '
      '→ ${quote.estimatedAmountOut.toStringAsFixed(6)} ${quote.tokenOutSymbol} | hash: $fakeHash',
    );

    return fakeHash;
  }

  /// All tokens available for swapping
  List<String> get availableTokens => _ratesInEth.keys.toList();

  /// List of TokenBalance stubs for the swap UI token picker
  List<Map<String, String>> get tokenPickerItems => [
    {'symbol': 'ETH',  'name': 'Ethereum'},
    {'symbol': 'LINK', 'name': 'Chainlink'},
    {'symbol': 'UNI',  'name': 'Uniswap'},
    {'symbol': 'USDC', 'name': 'USD Coin'},
  ];
}
