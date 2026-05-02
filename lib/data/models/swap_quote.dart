/// Model for a token swap quote.
class SwapQuote {
  final String tokenInSymbol;
  final String tokenOutSymbol;
  final double amountIn;
  final double estimatedAmountOut;
  final double slippagePct; // e.g. 0.5 = 0.5%
  final double estimatedGasEth;
  final double exchangeRate; // 1 tokenIn = X tokenOut
  final bool isSimulated;

  const SwapQuote({
    required this.tokenInSymbol,
    required this.tokenOutSymbol,
    required this.amountIn,
    required this.estimatedAmountOut,
    required this.slippagePct,
    required this.estimatedGasEth,
    required this.exchangeRate,
    this.isSimulated = true,
  });

  /// Minimum received after slippage
  double get minimumReceived =>
      estimatedAmountOut * (1 - slippagePct / 100);

  /// Price impact label
  String get slippageLabel => '${slippagePct.toStringAsFixed(1)}%';

  @override
  String toString() =>
      'SwapQuote($amountIn $tokenInSymbol → ${estimatedAmountOut.toStringAsFixed(6)} $tokenOutSymbol)';
}
