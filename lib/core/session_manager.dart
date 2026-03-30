import 'dart:async';
import 'package:flutter/widgets.dart';

/// Tracks user inactivity and triggers auto-logout after a specified duration.
///
/// HOW IT WORKS:
/// 1. Wraps the entire app in a GestureDetector that captures taps/scrolls.
/// 2. Every user interaction resets a countdown timer.
/// 3. If no interaction happens for [timeout] (default 10 min), [onTimeout] fires.
/// 4. The auth layer listens to [onTimeout] and navigates to the login screen.
class SessionManager extends StatefulWidget {
  final Widget child;
  final Duration timeout;
  final VoidCallback onTimeout;

  const SessionManager({
    super.key,
    required this.child,
    required this.onTimeout,
    this.timeout = const Duration(minutes: 10),
  });

  /// Allow resetting the timer from anywhere via context.
  static void resetTimer(BuildContext context) {
    context.findAncestorStateOfType<_SessionManagerState>()?._resetTimer();
  }

  @override
  State<SessionManager> createState() => _SessionManagerState();
}

class _SessionManagerState extends State<SessionManager> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(widget.timeout, widget.onTimeout);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _resetTimer,
      onPanDown: (_) => _resetTimer(),
      onScaleStart: (_) => _resetTimer(),
      child: widget.child,
    );
  }
}
