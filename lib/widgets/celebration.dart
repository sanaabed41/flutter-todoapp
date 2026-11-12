import 'package:flutter/material.dart';

/// Affiche une petite carte animée en haut de l'écran (« +10 XP », niveau
/// atteint, succès débloqué…). Elle ne bloque pas les interactions et
/// disparaît d'elle-même.
void showCelebration(
  BuildContext context, {
  required String emoji,
  required String title,
  List<String> lines = const [],
  bool big = false,
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Celebration(
      emoji: emoji,
      title: title,
      lines: lines,
      big: big,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _Celebration extends StatefulWidget {
  const _Celebration({
    required this.emoji,
    required this.title,
    required this.lines,
    required this.big,
    required this.onDone,
  });

  final String emoji;
  final String title;
  final List<String> lines;
  final bool big;
  final VoidCallback onDone;

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.big ? 2800 : 1300),
  );

  late final Animation<double> _opacity = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 12),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 18),
  ]).animate(_controller);

  late final Animation<double> _scale = TweenSequence([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.6,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 30,
    ),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
  ]).animate(_controller);

  late final Animation<Offset> _slide = TweenSequence([
    TweenSequenceItem(
      tween: Tween(
        begin: const Offset(0, -0.4),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 20,
    ),
    TweenSequenceItem(tween: ConstantTween(Offset.zero), weight: 62),
    TweenSequenceItem(
      tween: Tween(begin: Offset.zero, end: const Offset(0, -0.3)),
      weight: 18,
    ),
  ]).animate(_controller);

  @override
  void initState() {
    super.initState();
    _controller.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Positioned(
      top: MediaQuery.paddingOf(context).top + 12,
      left: 24,
      right: 24,
      child: IgnorePointer(
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _opacity,
            child: ScaleTransition(
              scale: _scale,
              child: Center(
                child: Material(
                  elevation: 6,
                  color: widget.big
                      ? scheme.primaryContainer
                      : scheme.inverseSurface,
                  borderRadius: BorderRadius.circular(widget.big ? 24 : 40),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.big ? 24 : 18,
                      vertical: widget.big ? 18 : 10,
                    ),
                    child: widget.big
                        ? _buildBig(theme, scheme)
                        : _buildSmall(theme, scheme),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmall(ThemeData theme, ColorScheme scheme) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(widget.emoji, style: const TextStyle(fontSize: 18)),
      const SizedBox(width: 8),
      Text(
        widget.title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
    ],
  );

  Widget _buildBig(ThemeData theme, ColorScheme scheme) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(widget.emoji, style: const TextStyle(fontSize: 44)),
      const SizedBox(height: 6),
      Text(
        widget.title,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleLarge?.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
      for (final line in widget.lines)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            line,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
    ],
  );
}
