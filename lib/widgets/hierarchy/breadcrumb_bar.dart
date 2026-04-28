import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';

/// Reusable breadcrumb navigation bar.
class BreadcrumbBar extends StatelessWidget {
  const BreadcrumbBar({
    super.key,
    required this.path,
    required this.onTap,
    this.focusLabel,
    this.showHome = true,
  });

  /// List of (id, title) pairs representing the path.
  final List<({String id, String title})> path;

  /// Called when a breadcrumb segment is tapped. Index -1 = root.
  final ValueChanged<int> onTap;

  /// Optional focus label for the current deep-nested item.
  final String? focusLabel;

  /// Whether to show the Home icon as the first crumb.
  final bool showHome;

  @override
  Widget build(BuildContext context) {
    final noda = Theme.of(context).extension<NodaThemeExtension>(); if (noda == null) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 32,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (showHome) ...[
              _BreadcrumbText(
                label: 'LIBRARY',
                onTap: () => onTap(-1),
              ),
              _Separator(color: noda.textSecondary),
            ],
            for (int i = 0; i < path.length; i++) ...[
              _BreadcrumbText(
                label: path[i].title,
                isLast: i == path.length - 1 && focusLabel == null,
                onTap: () => onTap(i),
              ),
              if (i < path.length - 1)
                _Separator(color: noda.textSecondary),
            ],
            if (focusLabel != null) ...[
              _Separator(color: noda.textSecondary),
              _BreadcrumbText(
                label: focusLabel!,
                isLast: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BreadcrumbText extends StatelessWidget {
  const _BreadcrumbText({
    required this.label,
    this.isLast = false,
    this.onTap,
  });

  final String label;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final noda = theme.extension<NodaThemeExtension>(); if (noda == null) return const SizedBox.shrink();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          isLast ? label : label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: isLast 
                ? colorScheme.onSurface 
                : colorScheme.onSurfaceVariant.withOpacity(0.5),
            fontWeight: isLast ? FontWeight.w800 : FontWeight.w600,
            fontSize: 10,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Text(
        ' / ',
        style: TextStyle(
          color: color.withOpacity(0.15),
          fontSize: 12,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }
}


