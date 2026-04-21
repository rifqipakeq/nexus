import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  final Random _random = Random();

  double _circleX = 100;
  double _circleY = 100;
  bool _isCircleVisible = false;

  DateTime? _spawnTime;
  int _difficultyMs = 1500;

  Timer? _roundTimer;

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  @override
  void dispose() {
    _roundTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    _scheduleNextRound();
  }

  void _scheduleNextRound() {
    _roundTimer?.cancel();

    _roundTimer = Timer(Duration(milliseconds: _difficultyMs), () {
      _spawnCircle();
    });
  }

  // fungsi spawn lingkaran acak
  void _spawnCircle() {
    final size = MediaQuery.of(context).size;

    setState(() {
      _circleX = _random.nextDouble() * (size.width - 80);
      _circleY = _random.nextDouble() * (size.height - 200);
      _isCircleVisible = true;
      _spawnTime = DateTime.now();
    });

    // Penalti jika user tidak menekan
    _roundTimer = Timer(Duration(milliseconds: _difficultyMs), () {
      if (_isCircleVisible) {
        setState(() {
          _isCircleVisible = false;
        });
        _scheduleNextRound();
      }
    });
  }

  // fungsi saat lingkaran ditekan
  Future<void> _onTapCircle() async {
    if (_spawnTime == null) return;

    final reactionTime = DateTime.now().difference(_spawnTime!).inMilliseconds;

    int score = ref.read(gameScoreProvider);
    int totalGames = ref.read(totalGamesProvider);

    // logic scoring: semakin cepat, semakin banyak poin (maks 1000ms = 100 poin, min 10 poin)
    final gained = (1000 - reactionTime).clamp(10, 100);
    score += gained;
    totalGames++;

    // setiap 5 poin, tingkat kesulitan naik
    _difficultyMs = (_difficultyMs * 0.9).clamp(400, 2000).toInt();

    // simpan data game
    final db = ref.read(localDbProvider);
    await db.saveGameScore(score);
    await db.saveHighScore(score);
    await db.saveTotalGames(totalGames);

    ref.read(gameScoreProvider.notifier).state = score;
    ref.read(highScoreProvider.notifier).state = db.getHighScore();
    ref.read(totalGamesProvider.notifier).state = totalGames;

    setState(() {
      _isCircleVisible = false;
    });

    _scheduleNextRound();
  }

  @override
  Widget build(BuildContext context) {
    final score = ref.watch(gameScoreProvider);
    final highScore = ref.watch(highScoreProvider);
    final totalGames = ref.watch(totalGamesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reaction Game')),
      body: Column(
        children: [
          // Scoreboard
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ScoreTile(label: 'Score', value: '$score'),
                _ScoreTile(label: 'Best', value: '$highScore'),
                _ScoreTile(label: 'Rounds', value: '$totalGames'),
              ],
            ),
          ),

          // Game field
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Container(color: Colors.black),

                    if (_isCircleVisible)
                      Positioned(
                        left: _circleX.clamp(0, constraints.maxWidth - 80),
                        top: _circleY.clamp(0, constraints.maxHeight - 80),
                        child: GestureDetector(
                          onTap: _onTapCircle,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),

                    // Indikator kecepatan
                    Positioned(
                      bottom: 20,
                      left: 20,
                      child: Text(
                        'Speed: ${_difficultyMs}ms',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Widget  score, best score, dan total games
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
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6C63FF),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
      ],
    );
  }
}
