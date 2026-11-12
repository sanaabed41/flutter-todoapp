import 'package:flutter/material.dart';

import '../services/workload.dart';
import '../theme/app_theme_data.dart';
import '../utils/date_format.dart';

/// Alerte affichée quand un des prochains jours dépasse le rythme habituel.
class OverloadBanner extends StatelessWidget {
  const OverloadBanner({
    super.key,
    required this.overloaded,
    required this.canRebalance,
    required this.onRebalance,
  });

  /// Jours surchargés, du plus proche au plus lointain (non vide).
  final List<DayLoad> overloaded;
  final bool canRebalance;
  final VoidCallback onRebalance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = scheme.onErrorContainer;
    final first = overloaded.first;
    final others = overloaded.length - 1;

    final detail = StringBuffer(
      '${first.count} tâches prévues pour un rythme de ~${first.capacity}/jour.',
    );
    if (others > 0) {
      detail.write(
        ' Et $others autre${others > 1 ? 's' : ''} jour'
        '${others > 1 ? 's' : ''}.',
      );
    }
    if (!canRebalance) {
      detail.write(' Tout est prioritaire : repousse une échéance toi-même.');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        key: const Key('overload-banner'),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(Icons.warning_amber_rounded, color: fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${formatDayHeader(first.day)} est surchargé',
                    style: theme.textTheme.titleSmall?.copyWith(color: fg),
                  ),
                  Text(
                    detail.toString(),
                    style: theme.textTheme.bodySmall?.copyWith(color: fg),
                  ),
                  if (canRebalance) ...[
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.error,
                        foregroundColor: scheme.onError,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      onPressed: onRebalance,
                      icon: const Icon(Icons.auto_fix_high, size: 18),
                      label: const Text('Rééquilibrer'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
