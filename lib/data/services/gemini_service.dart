import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/env_config.dart';

class GeminiService {
  late final GenerativeModel _model;

  GeminiService() {
    final apiKey = EnvConfig.geminiApiKey;

    if (apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY tidak ditemukan.');
    }

    _model = GenerativeModel(
      model: 'gemini-2.5-flash-lite',
      apiKey: apiKey,
    );
  }

  Future<String> sendMessage(String prompt) async {
    try {
      final response = await _model.generateContent([
        Content.text(prompt),
      ]);

      return response.text ?? 'Tidak ada respon dari model.';
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Personalisasi char
  Future<String> sendContextualMessage(
    String userMessage,
    Map<String, dynamic> context,
  ) async {
    try {
      final username = context['username'] ?? 'User';
      final walletAddress = context['walletAddress'] as String?;
      final balance = context['balance'] as double? ?? 0.0;
      final ethUsd = context['ethUsd'] as double? ?? 0.0;
      final ethIdr = context['ethIdr'] as double? ?? 0.0;
      final isInSafeZone = context['isInSafeZone'] as bool? ?? false;
      final safeZoneCount = context['safeZoneCount'] as int? ?? 0;
      final timezone = context['timezone'] as String? ?? 'Asia/Jakarta';

      final balanceUsd = balance * ethUsd;
      final balanceIdr = balance * ethIdr;

      final systemPrompt = '''
Kamu adalah NexusBot, asisten AI personal untuk aplikasi Nexus — aplikasi portofolio Web3 testnet Ethereum (Sepolia).
Kamu memiliki akses ke data real-time pengguna berikut dan gunakan data ini untuk menjawab pertanyaan dengan tepat dan personal.

=== DATA PENGGUNA ===
- Nama pengguna: $username
- Wallet address: ${walletAddress ?? 'Belum ada wallet'}
- Saldo ETH: ${balance.toStringAsFixed(6)} ETH
- Nilai saldo: \$${balanceUsd.toStringAsFixed(2)} USD | Rp ${balanceIdr.toStringAsFixed(0)} IDR
- Harga ETH saat ini: \$${ethUsd.toStringAsFixed(2)} USD
- Status zona aman: ${isInSafeZone ? '✅ Di dalam zona aman (transaksi diizinkan)' : '❌ Di luar zona aman (transaksi diblokir)'}
- Jumlah zona aman yang dibuat: $safeZoneCount zona
- Zona waktu aktif: $timezone
- Jaringan: Sepolia Testnet (bukan uang nyata)

=== INSTRUKSI ===
- Jawab dalam Bahasa Indonesia kecuali user bertanya dalam bahasa lain
- Jadilah ramah, ringkas, dan informatif
- Jika user menanyakan saldo, harga, atau apakah bisa transaksi — gunakan data di atas
- Ingatkan bahwa ini adalah testnet, bukan mainnet
- Jangan membahas topik di luar Web3, crypto, atau aplikasi ini

=== PERTANYAAN USER ===
$userMessage
''';

      final response = await _model.generateContent([
        Content.text(systemPrompt),
      ]);

      return response.text ?? 'Tidak ada respon dari model.';
    } catch (e) {
      return 'Error: $e';
    }
  }
}
