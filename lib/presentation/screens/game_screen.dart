import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

/// Price Guess Game – Simple implementation without Flame engine.
/// Shows ETH price, user guesses up or down, random simulated result.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with SingleTickerProviderStateMixin {
  String? _result;
  bool _isRevealing = false;
  double _simulatedChange = 0;

  Future<void> _makeGuess(String direction) async {
    setState(() {
      _isRevealing = true;
      _result = null;
    });

    // Simulate a 2-second "price movement"
    await Future.delayed(const Duration(seconds: 2));

    // Random result: price goes up or down
    final random = Random();
    _simulatedChange = (random.nextDouble() * 200 - 100); // -100 to +100
    final actualDirection = _simulatedChange >= 0 ? 'up' : 'down';
    final won = direction == actualDirection;

    final db = ref.read(localDbProvider);
    int score = ref.read(gameScoreProvider);
    int totalGames = ref.read(totalGamesProvider);

    if (won) {
      score += 10;
    } else {
      score = (score - 5).clamp(0, 999999);
    }
    totalGames++;

    await db.saveGameScore(score);
    await db.saveHighScore(score);
    await db.saveTotalGames(totalGames);

    ref.read(gameScoreProvider.notifier).state = score;
    ref.read(highScoreProvider.notifier).state = db.getHighScore();
    ref.read(totalGamesProvider.notifier).state = totalGames;

    setState(() {
      _result = won ? '🎉 Correct!' : '❌ Wrong!';
      _isRevealing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final prices = ref.watch(ethPriceProvider);
    final score = ref.watch(gameScoreProvider);
    final highScore = ref.watch(highScoreProvider);
    final totalGames = ref.watch(totalGamesProvider);
    final ethUsd = prices['usd'] ?? 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Price Guess Game')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // ─── Score Board ────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ScoreTile(label: 'Score', value: score.toString()),
                    _ScoreTile(label: 'Best', value: highScore.toString()),
                    _ScoreTile(label: 'Games', value: totalGames.toString()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ─── Current Price ──────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text(
                      'Current ETH Price',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${ethUsd.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_simulatedChange != 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Simulated move: ${_simulatedChange >= 0 ? '+' : ''}${_simulatedChange.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: _simulatedChange >= 0
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ─── Game Question ──────────────────────
            const Text(
              'Will ETH price go UP or DOWN?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),

            if (_isRevealing) ...[
              const SizedBox(
                height: 60,
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Simulating price...'),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 80,
                      child: ElevatedButton(
                        onPressed: () => _makeGuess('up'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_upward, size: 32),
                            Text('UP', style: TextStyle(fontSize: 18)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 80,
                      child: ElevatedButton(
                        onPressed: () => _makeGuess('down'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_downward, size: 32),
                            Text('DOWN', style: TextStyle(fontSize: 18)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // ─── Result ─────────────────────────────
            if (_result != null)
              Text(
                _result!,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _result!.contains('Correct')
                      ? Colors.greenAccent
                      : Colors.redAccent,
                ),
              ),

            const SizedBox(height: 24),

            // ─── Rules ──────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How to Play',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Guess if ETH price will go up or down\n'
                      '• Correct guess: +10 points\n'
                      '• Wrong guess: -5 points\n'
                      '• Price movement is simulated randomly',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreTile extends StatelessWidget {
  final String label;
  final String value;

  const _ScoreTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6C63FF),
          ),
        ),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
      ],
    );
  }
}
