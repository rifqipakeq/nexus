import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/quiz_service.dart';
import '../providers.dart';

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen>
    with TickerProviderStateMixin {
  late List<QuizQuestion> _questions;
  int _currentIndex = 0;
  int _selectedAnswer = -1;
  bool _answered = false;
  int _correctCount = 0;
  int _streak = 0;
  int _maxStreak = 0;
  bool _quizComplete = false;

  late AnimationController _progressController;
  late AnimationController _feedbackController;
  late Animation<double> _feedbackAnimation;

  @override
  void initState() {
    super.initState();
    final quizService = ref.read(quizServiceProvider);
    _questions = quizService.getQuestions(count: 10);

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _feedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _feedbackAnimation = CurvedAnimation(
      parent: _feedbackController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  QuizQuestion get _current => _questions[_currentIndex];

  void _onAnswer(int index) {
    if (_answered) return;

    final isCorrect = index == _current.correctIndex;

    setState(() {
      _selectedAnswer = index;
      _answered = true;
      if (isCorrect) {
        _correctCount++;
        _streak++;
        if (_streak > _maxStreak) _maxStreak = _streak;
      } else {
        _streak = 0;
      }
    });

    _feedbackController.forward(from: 0);
  }

  void _next() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = -1;
        _answered = false;
      });
      _feedbackController.reset();
      _progressController.animateTo((_currentIndex + 1) / _questions.length);
    } else {
      _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
    setState(() {
      _quizComplete = true;
    });

    final storage = ref.read(userScopedStorageProvider);
    await storage.saveGameScore(_correctCount * 10);
    await storage.saveHighScore(_correctCount * 10);
    await storage.saveTotalGames(storage.getTotalGames() + 1);
    ref.read(gameScoreProvider.notifier).state = _correctCount * 10;
    ref.read(highScoreProvider.notifier).state = storage.getHighScore();
    ref.read(totalGamesProvider.notifier).state = storage.getTotalGames();
  }

  void _restart() {
    final quizService = ref.read(quizServiceProvider);
    setState(() {
      _questions = quizService.getQuestions(count: 10);
      _currentIndex = 0;
      _selectedAnswer = -1;
      _answered = false;
      _correctCount = 0;
      _streak = 0;
      _maxStreak = 0;
      _quizComplete = false;
    });
    _progressController.reset();
    _feedbackController.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        elevation: 0,
        title: const Text(
          'Kuis Kripto',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (!_quizComplete)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_currentIndex + 1} / ${_questions.length}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
      body: _quizComplete ? _buildResultScreen() : _buildQuizScreen(),
    );
  }

  Widget _buildQuizScreen() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (_currentIndex + (_answered ? 1 : 0)) / _questions.length,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF6C63FF)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 20),

          // Streak Banner
          if (_streak >= 2) _StreakBanner(streak: _streak),

          const SizedBox(height: 16),

          // Question Card
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A1F3A), Color(0xFF16213E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF6C63FF,
                            ).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Q${_currentIndex + 1}',
                            style: const TextStyle(
                              color: Color(0xFF6C63FF),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _current.question,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Options
                  ...List.generate(_current.options.length, (i) {
                    return _OptionTile(
                      label: _current.options[i],
                      index: i,
                      selectedIndex: _selectedAnswer,
                      correctIndex: _current.correctIndex,
                      answered: _answered,
                      onTap: () => _onAnswer(i),
                    );
                  }),

                  // Explanation (after answer)
                  if (_answered) ...[
                    const SizedBox(height: 16),
                    FadeTransition(
                      opacity: _feedbackAnimation,
                      child: _ExplanationCard(
                        text: _current.explanation,
                        isCorrect: _selectedAnswer == _current.correctIndex,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _currentIndex < _questions.length - 1
                              ? 'Pertanyaan Selanjutnya→'
                              : 'Selesai',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultScreen() {
    final totalQuestions = _questions.length;
    final pct = _correctCount / totalQuestions;
    final grade = pct >= 0.8
        ? 'Mantap jiwaa'
        : pct >= 0.6
        ? 'GGWP!'
        : 'Belajar lagi ya deck!';
    final gradeColor = pct >= 0.8
        ? const Color(0xFFFFD700)
        : pct >= 0.6
        ? const Color(0xFF6C63FF)
        : Colors.white70;

    // Quiz is pure now; no tokens or premium displayed

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            grade,
            style: TextStyle(
              fontSize: 32,
              color: gradeColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_correctCount / $totalQuestions Benar',
            style: const TextStyle(color: Colors.white70, fontSize: 18),
          ),
          const SizedBox(height: 24),

          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatChip(
                icon: Icons.check_circle,
                value: '$_correctCount',
                label: 'Benar',
                color: const Color(0xFF4CAF50),
              ),
              _StatChip(
                icon: Icons.cancel,
                value: '${totalQuestions - _correctCount}',
                label: 'Salah',
                color: Colors.redAccent,
              ),
              _StatChip(
                icon: Icons.local_fire_department,
                value: '$_maxStreak',
                label: 'Best Record',
                color: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 24),

          const SizedBox(height: 24),

          // Action Buttons
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _restart,
              icon: const Icon(Icons.refresh),
              label: const Text('Mainkan Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
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
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('Kembali ke Dashboard'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakBanner extends StatelessWidget {
  final int streak;
  const _StreakBanner({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            '🔥 $streak in a row!',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final int index;
  final int selectedIndex;
  final int correctIndex;
  final bool answered;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.index,
    required this.selectedIndex,
    required this.correctIndex,
    required this.answered,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor = Colors.white12;
    Color bgColor = const Color(0xFF16213E);
    Color textColor = Colors.white70;
    Widget? trailingIcon;

    if (answered) {
      if (index == correctIndex) {
        borderColor = const Color(0xFF4CAF50);
        bgColor = const Color(0xFF4CAF50).withValues(alpha: 0.15);
        textColor = Colors.white;
        trailingIcon = const Icon(
          Icons.check_circle,
          color: Color(0xFF4CAF50),
          size: 20,
        );
      } else if (index == selectedIndex) {
        borderColor = Colors.redAccent;
        bgColor = Colors.redAccent.withValues(alpha: 0.15);
        textColor = Colors.white70;
        trailingIcon = const Icon(
          Icons.cancel,
          color: Colors.redAccent,
          size: 20,
        );
      }
    } else if (index == selectedIndex) {
      borderColor = const Color(0xFF6C63FF);
      bgColor = const Color(0xFF6C63FF).withValues(alpha: 0.15);
      textColor = Colors.white;
    }

    final optionLetters = ['A', 'B', 'C', 'D'];

    return GestureDetector(
      onTap: answered ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: borderColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Text(
                optionLetters[index],
                style: TextStyle(
                  color: borderColor == Colors.white12
                      ? Colors.white54
                      : borderColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: textColor, fontSize: 14, height: 1.4),
              ),
            ),
            if (trailingIcon != null) trailingIcon,
          ],
        ),
      ),
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  final String text;
  final bool isCorrect;

  const _ExplanationCard({required this.text, required this.isCorrect});

  @override
  Widget build(BuildContext context) {
    final color = isCorrect ? const Color(0xFF4CAF50) : Colors.amber;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.lightbulb : Icons.school,
                color: color,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                isCorrect
                    ? 'Bener banget! Ini Penjelasannya:'
                    : 'Belajar dulu yahh:',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
