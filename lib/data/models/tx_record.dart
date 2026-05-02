class TxRecord {
  final String hash;
  final String from;
  final String to;
  final String valueWei; 
  final String gas;
  final String gasUsed;
  final String gasPrice; // in wei
  final String status; // '1' = success, '0' = fail
  final String timeStamp; 
  final String blockNumber;
  final bool isError;

  const TxRecord({
    required this.hash,
    required this.from,
    required this.to,
    required this.valueWei,
    required this.gas,
    required this.gasUsed,
    required this.gasPrice,
    required this.status,
    required this.timeStamp,
    required this.blockNumber,
    required this.isError,
  });

  /// Value in ETH converted from wei
  double get valueEth {
    final wei = double.tryParse(valueWei) ?? 0;
    return wei / 1e18;
  }

  /// Gas price in Gwei
  double get gasPriceGwei {
    final gwei = double.tryParse(gasPrice) ?? 0;
    return gwei / 1e9;
  }

  /// Total gas fee in ETH
  double get gasFeeEth {
    final used = double.tryParse(gasUsed) ?? 0;
    final price = double.tryParse(gasPrice) ?? 0;
    return (used * price) / 1e18;
  }

  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(int.parse(timeStamp) * 1000);

  bool get isSuccess => status == '1' && !isError;

  factory TxRecord.fromEtherscanJson(Map<String, dynamic> json) {
    return TxRecord(
      hash: json['hash'] as String? ?? '',
      from: json['from'] as String? ?? '',
      to: json['to'] as String? ?? '',
      valueWei: json['value'] as String? ?? '0',
      gas: json['gas'] as String? ?? '0',
      gasUsed: json['gasUsed'] as String? ?? '0',
      gasPrice: json['gasPrice'] as String? ?? '0',
      status: json['txreceipt_status'] as String? ?? '0',
      timeStamp: json['timeStamp'] as String? ?? '0',
      blockNumber: json['blockNumber'] as String? ?? '0',
      isError: (json['isError'] as String? ?? '0') == '1',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hash': hash,
      'from': from,
      'to': to,
      'valueWei': valueWei,
      'gas': gas,
      'gasUsed': gasUsed,
      'gasPrice': gasPrice,
      'status': status,
      'timeStamp': timeStamp,
      'blockNumber': blockNumber,
      'isError': isError,
    };
  }

  factory TxRecord.fromMap(Map<dynamic, dynamic> map) {
    return TxRecord(
      hash: map['hash'] as String? ?? '',
      from: map['from'] as String? ?? '',
      to: map['to'] as String? ?? '',
      valueWei: map['valueWei'] as String? ?? '0',
      gas: map['gas'] as String? ?? '0',
      gasUsed: map['gasUsed'] as String? ?? '0',
      gasPrice: map['gasPrice'] as String? ?? '0',
      status: map['status'] as String? ?? '0',
      timeStamp: map['timeStamp'] as String? ?? '0',
      blockNumber: map['blockNumber'] as String? ?? '0',
      isError: map['isError'] as bool? ?? false,
    );
  }

  @override
  String toString() => 'TxRecord(hash: $hash, value: ${valueEth.toStringAsFixed(6)} ETH)';
}
