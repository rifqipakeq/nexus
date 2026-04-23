import 'dart:async';
import 'package:flutter/widgets.dart';

/// SESSION MANAGEMENT
/// 1. Wrap app pada gesture detector untuk capture tap/scroll.
/// 2. Setiap interaksi user reset timer.
/// 3. Jika tidak ada interaksi selama timeour, panggil onTimeout.
/// 4. Layer auth listen ke  onTimeout dan navigasi ke login screen.
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
