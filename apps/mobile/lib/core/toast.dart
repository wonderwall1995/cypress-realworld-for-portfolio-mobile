import 'package:flutter/material.dart';

import 'test_id.dart';

/// Colors of the two kinds of toast: light green for success, pink for failure.
class ToastColors {
  const ToastColors({required this.background, required this.border, required this.text});

  final Color background;
  final Color border;
  final Color text;

  static const success = ToastColors(
    background: Color(0xFFDFF5E1),
    border: Color(0xFF9BD6A3),
    text: Color(0xFF1B5E20),
  );

  static const failure = ToastColors(
    background: Color(0xFFFFE0E6),
    border: Color(0xFFF4A6B7),
    text: Color(0xFF9C1C3B),
  );
}

const toastDuration = Duration(seconds: 2);

OverlayEntry? _current;

/// Shows a small rounded toast in the middle of the screen for two seconds.
///
/// Take [overlay] with `Overlay.of(context, rootOverlay: true)` *before* an
/// `await`, because the page may be gone after it.
void showToast(
  OverlayState overlay, {
  required String message,
  required bool success,
}) {
  if (_current?.mounted ?? false) _current!.remove();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Toast(
      message: message,
      success: success,
      onDone: () {
        if (entry.mounted) entry.remove();
        if (identical(_current, entry)) _current = null;
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

/// Fades in, stays, fades out. One animation does all three, so no timer is left
/// behind when the screen is closed.
class _Toast extends StatefulWidget {
  const _Toast({required this.message, required this.success, required this.onDone});

  final String message;
  final bool success;
  final VoidCallback onDone;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: toastDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 75),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 15),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.success ? ToastColors.success : ToastColors.failure;
    return IgnorePointer(
      child: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: Material(
            color: colors.background,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: colors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: TestId(
                widget.success ? 'alert-bar-success' : 'alert-bar-error',
                child: Text(
                  widget.message,
                  style: TextStyle(color: colors.text, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
