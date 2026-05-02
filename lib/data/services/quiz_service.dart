import 'package:flutter/foundation.dart';
import '../local/user_scoped_storage.dart';
import '../../core/constants.dart';

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

class QuizService {
  static const int tokensPerCorrect = 10;
  static const int bonusStreakTokens = 5;
  static const int streakThreshold = 3;

  final UserScopedStorage _storage;

  QuizService(this._storage);

static const List<QuizQuestion> _questionBank = [
  QuizQuestion(
    question: 'Apa itu "blockchain"?',
    options: [
      'Database yang disimpan di banyak komputer',
      'Kumpulan kotak di brankas',
      'Program komputer tertentu',
      'Penyimpanan online',
    ],
    correctIndex: 0,
    explanation:
        'Blockchain adalah sistem pencatatan data yang disalin ke banyak komputer agar aman.',
  ),
  QuizQuestion(
    question: 'Apa itu "private key" di dompet kripto?',
    options: [
      'Alamat dompet yang bisa dilihat orang lain',
      'Kode rahasia untuk mengakses dan kirim kripto',
      'Password akun biasa',
      'Alat penyimpan kripto',
    ],
    correctIndex: 1,
    explanation:
        'Private key adalah kode rahasia penting untuk mengontrol aset kripto kamu.',
  ),
  QuizQuestion(
    question: 'Apa itu jaringan uji Sepolia?',
    options: [
      'Tempat jual beli ETH asli',
      'Cara menambang ETH',
      'Tempat latihan pakai ETH tanpa nilai',
      'Tempat simpan NFT',
    ],
    correctIndex: 2,
    explanation:
        'Sepolia digunakan untuk belajar dan testing tanpa risiko kehilangan uang.',
  ),
  QuizQuestion(
    question: 'Apa itu "gas" di Ethereum?',
    options: [
      'Kecepatan transaksi',
      'Biaya untuk memproses transaksi',
      'Jumlah saldo',
      'Jumlah konfirmasi',
    ],
    correctIndex: 1,
    explanation:
        'Gas adalah biaya yang dibayar agar transaksi bisa diproses di jaringan.',
  ),
  QuizQuestion(
    question: 'Apa itu token ERC-20?',
    options: [
      'Standar dompet fisik',
      'Mata uang utama Ethereum',
      'Standar token di Ethereum',
      'Sistem keamanan',
    ],
    correctIndex: 2,
    explanation:
        'ERC-20 adalah standar untuk membuat token yang bisa dipertukarkan di Ethereum.',
  ),
  QuizQuestion(
    question: 'Apa arti DeFi?',
    options: [
      'Keuangan tanpa perantara (bank)',
      'Sistem keuangan khusus',
      'Alat uang digital',
      'Indeks keuangan',
    ],
    correctIndex: 0,
    explanation:
        'DeFi adalah layanan keuangan yang berjalan di blockchain tanpa bank.',
  ),
  QuizQuestion(
    question: 'Apa itu seed phrase?',
    options: [
      'PIN HP',
      'Kata cadangan untuk memulihkan dompet',
      'Alamat kontrak',
      'Kode QR',
    ],
    correctIndex: 1,
    explanation:
        'Seed phrase adalah kumpulan kata untuk backup dompet kripto.',
  ),
  QuizQuestion(
    question: 'Apa itu smart contract?',
    options: [
      'Perjanjian digital',
      'Program otomatis di blockchain',
      'Dompet khusus',
      'API biasa',
    ],
    correctIndex: 1,
    explanation:
        'Smart contract adalah program yang berjalan otomatis di blockchain.',
  ),
  QuizQuestion(
    question: 'Ethereum sekarang pakai sistem apa?',
    options: [
      'Proof of Work',
      'Delegated Proof of Stake',
      'Proof of Authority',
      'Proof of Stake',
    ],
    correctIndex: 3,
    explanation:
        'Ethereum sekarang memakai Proof of Stake yang lebih hemat energi.',
  ),
  QuizQuestion(
    question: 'Apa itu Gwei?',
    options: [
      '1 miliar ETH',
      'Satuan kecil dari ETH',
      'Jenis token',
      'Unit terkecil ETH',
    ],
    correctIndex: 1,
    explanation:
        'Gwei adalah satuan kecil ETH yang dipakai untuk biaya transaksi.',
  ),
  QuizQuestion(
    question: 'Apa arti non-custodial wallet?',
    options: [
      'Kunci dipegang exchange',
      'Kamu pegang sendiri akses dompet',
      'Harus verifikasi identitas',
      'Dijamin bank',
    ],
    correctIndex: 1,
    explanation:
        'Artinya kamu sendiri yang punya kontrol penuh atas kripto.',
  ),
  QuizQuestion(
    question: 'Apa itu slippage?',
    options: [
      'Delay transaksi',
      'Selisih harga saat transaksi',
      'Biaya tambahan',
      'Transaksi gagal',
    ],
    correctIndex: 1,
    explanation:
        'Slippage terjadi saat harga berubah sebelum transaksi selesai.',
  ),
  QuizQuestion(
    question: 'Apa itu block explorer?',
    options: [
      'Aplikasi dompet',
      'Alat untuk melihat transaksi blockchain',
      'Software mining',
      'Marketplace NFT',
    ],
    correctIndex: 1,
    explanation:
        'Block explorer dipakai untuk cek transaksi dan alamat di blockchain.',
  ),
  QuizQuestion(
    question: 'Format alamat Ethereum seperti apa?',
    options: [
      'Seperti Bitcoin',
      'Format bank',
      'Diawali 0x dan panjang',
      'Format UUID',
    ],
    correctIndex: 2,
    explanation:
        'Alamat Ethereum selalu diawali dengan 0x.',
  ),
  QuizQuestion(
    question: 'Apa itu DEX?',
    options: [
      'Exchange biasa',
      'Exchange tanpa perantara',
      'Alat keamanan',
      'Layanan data',
    ],
    correctIndex: 1,
    explanation:
        'DEX memungkinkan tukar aset langsung tanpa pihak ketiga.',
  ),
  QuizQuestion(
    question: 'Apa arti "to" di transaksi?',
    options: [
      'Orang yang mengirim',
      'Orang yang menerima',
      'Alamat wallet',
      'Biaya transaksi',
    ],
    correctIndex: 1,
    explanation:
        '"to" menunjukkan siapa yang menerima transaksi.',
  ),
  QuizQuestion(
    question: 'Apa itu cold wallet?',
    options: [
      'Dompet di tempat dingin',
      'Dompet offline',
      'Dompet kosong',
      'Dompet di cloud',
    ],
    correctIndex: 1,
    explanation:
        'Cold wallet tidak terhubung internet sehingga lebih aman.',
  ),
  QuizQuestion(
    question: 'Apa arti "from" di transaksi?',
    options: [
      'Penerima',
      'Kontrak',
      'Pengirim',
      'Pembuat blok',
    ],
    correctIndex: 2,
    explanation:
        'Menunjukkan siapa yang mengirim transaksi.',
  ),
  QuizQuestion(
    question: 'Apa itu NFT?',
    options: [
      'Token biasa',
      'Aset digital unik',
      'Jaringan layer-2',
      'Token biaya',
    ],
    correctIndex: 1,
    explanation:
        'NFT adalah aset digital yang unik dan tidak bisa ditukar sama persis.',
  ),
  QuizQuestion(
    question: 'Apa itu staking?',
    options: [
      'Mengunci kripto untuk bantu jaringan',
      'Menambang',
      'Nabung di bank',
      'Mengirim permanen',
    ],
    correctIndex: 0,
    explanation:
        'Staking adalah mengunci kripto untuk membantu jaringan dan mendapat reward.',
  ),
];

  List<QuizQuestion> getQuestions({int count = 10}) {
    final shuffled = List<QuizQuestion>.from(_questionBank)..shuffle();
    return shuffled.take(count.clamp(1, _questionBank.length)).toList();
  }

  int calculateTokens({required int correct, required int streak}) {
    int tokens = correct * tokensPerCorrect;
    if (streak >= streakThreshold) {
      tokens += bonusStreakTokens;
    }
    return tokens;
  }

  Future<int> awardTokens(int earned) async {
    final current = _storage.getQuizTokens();
    final total = current + earned;
    await _storage.saveQuizTokens(total);

    if (total >= AppConstants.premiumTokenThreshold && !_storage.isPremium) {
      await _storage.savePremiumStatus(true);
      debugPrint('Fitur premium terbuka! Jumlah tokens: $total');
    }

    debugPrint('Menerima $earned token. Total: $total');
    return total;
  }

  Future<bool> spendToken() async {
    final current = _storage.getQuizTokens();
    if (current < AppConstants.tokensPerAiMessage) return false;
    final newTotal = current - AppConstants.tokensPerAiMessage;
    await _storage.saveQuizTokens(newTotal);

    if (newTotal == 0 && _storage.isPremium) {
      await _storage.savePremiumStatus(false);
      debugPrint('Fitur premium dihapus — mohon isi ulang token..');
    }
    return true;
  }
}
