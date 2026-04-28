import 'package:flutter/material.dart';
import '../services/import_export_service.dart';
import '../core/theme/app_typography.dart';

class ImportConflictDialog extends StatelessWidget {
  final ImportAnalysis analysis;

  const ImportConflictDialog({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_rounded, color: colorScheme.error, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Subject Already Exists',
                    style: AppTypography.headingMedium().copyWith(fontSize: 22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'A subject named "${analysis.title}" already exists in your library. How would you like to proceed?',
              style: AppTypography.bodyMedium().copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),

            // Stat cards
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Incoming',
                    topics: analysis.incomingTopicsCount,
                    cards: analysis.incomingCardsCount,
                    color: colorScheme.primary,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Existing',
                    topics: analysis.existingTopicsCount,
                    cards: analysis.existingCardsCount,
                    color: colorScheme.secondary,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Options
            _OptionTile(
              icon: Icons.edit_rounded,
              title: 'Rename Subject',
              subtitle: 'Import the subject under a new name.',
              onTap: () => Navigator.pop(context, ImportStrategy.rename),
            ),
            const SizedBox(height: 8),
            _OptionTile(
              icon: Icons.add_circle_outline_rounded,
              title: 'Append',
              subtitle: 'Adds new topics, notes, and cards. Keeps your existing notes untouched.',
              onTap: () => Navigator.pop(context, ImportStrategy.appendSkip),
            ),
            const SizedBox(height: 8),
            _OptionTile(
              icon: Icons.update_rounded,
              title: 'Update',
              subtitle: 'Adds new items and overwrites existing notes with the file version.',
              onTap: () => Navigator.pop(context, ImportStrategy.appendUpdate),
            ),
            const SizedBox(height: 8),
            _OptionTile(
              icon: Icons.delete_forever_rounded,
              title: 'Overwrite Completely',
              subtitle: 'Deletes your existing subject and replaces it entirely.',
              isDestructive: true,
              onTap: () => Navigator.pop(context, ImportStrategy.overwrite),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: Text('CANCEL', style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int topics;
  final int cards;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.title,
    required this.topics,
    required this.cards,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.headingSmall(color: color).copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('$topics Topics', style: AppTypography.bodySmall()),
          Text('$cards Cards', style: AppTypography.bodySmall()),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDestructive;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isDestructive ? colorScheme.error : colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.subtitle(color: color).copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTypography.bodySmall().copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

