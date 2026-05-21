import 'package:flutter/material.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = Colors.white.withValues(alpha: 0.62);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(opacity: _phase(t, 0.0), color: dotColor),
            const SizedBox(width: 6),
            _Dot(opacity: _phase(t, 0.2), color: dotColor),
            const SizedBox(width: 6),
            _Dot(opacity: _phase(t, 0.4), color: dotColor),
            const SizedBox(width: 10),
            Text(
              'CrtMu 正在输入…',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.70),
                height: 1.0,
              ),
            ),
          ],
        );
      },
    );
  }

  double _phase(double t, double shift) {
    final x = (t + shift) % 1.0;
    final value = (1.0 - (x - 0.5).abs() * 2).clamp(0.0, 1.0);
    return 0.25 + value * 0.75;
  }
}

class _Dot extends StatelessWidget {
  final double opacity;
  final Color color;

  const _Dot({required this.opacity, required this.color});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
