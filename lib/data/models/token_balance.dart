/// Represents an ERC-20 token and its balance for a wallet address.
class TokenBalance {
  final String symbol;
  final String name;
  final String contractAddress;
  final int decimals;
  final BigInt rawBalance; // in smallest unit
  final String? lastUpdated;

  const TokenBalance({
    required this.symbol,
    required this.name,
    required this.contractAddress,
    required this.decimals,
    required this.rawBalance,
    this.lastUpdated,
  });

  /// Human-readable balance
  double get balance {
    if (rawBalance == BigInt.zero) return 0.0;
    final divisor = BigInt.from(10).pow(decimals);
    final whole = rawBalance ~/ divisor;
    final frac = rawBalance % divisor;
    return whole.toDouble() +
        (frac.toDouble() / divisor.toDouble());
  }

  String get balanceFormatted {
    final b = balance;
    if (b == 0.0) return '0.0000';
    if (b < 0.0001) return '< 0.0001';
    return b.toStringAsFixed(4);
  }

  TokenBalance copyWith({BigInt? rawBalance, String? lastUpdated}) {
    return TokenBalance(
      symbol: symbol,
      name: name,
      contractAddress: contractAddress,
      decimals: decimals,
      rawBalance: rawBalance ?? this.rawBalance,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'symbol': symbol,
      'name': name,
      'contractAddress': contractAddress,
      'decimals': decimals,
      'rawBalance': rawBalance.toString(),
      'lastUpdated': lastUpdated,
    };
  }

  factory TokenBalance.fromMap(Map<dynamic, dynamic> map) {
    return TokenBalance(
      symbol: map['symbol'] as String? ?? '',
      name: map['name'] as String? ?? '',
      contractAddress: map['contractAddress'] as String? ?? '',
      decimals: (map['decimals'] as num?)?.toInt() ?? 18,
      rawBalance: BigInt.tryParse(map['rawBalance'] as String? ?? '0') ?? BigInt.zero,
      lastUpdated: map['lastUpdated'] as String?,
    );
  }

  @override
  String toString() => 'TokenBalance($symbol: $balanceFormatted)';
}

const kDefaultSepoliaTokens = [
  {
    'symbol': 'LINK',
    'name': 'Chainlink Token',
    'address': '0x779877A7B0D9E8603169DdbD7836e478b4624789',
    'decimals': 18,
  },
  {
    'symbol': 'UNI',
    'name': 'Uniswap',
    'address': '0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984',
    'decimals': 18,
  },
  {
    'symbol': 'USDC',
    'name': 'USD Coin',
    'address': '0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C4',
    'decimals': 6,
  },
];
