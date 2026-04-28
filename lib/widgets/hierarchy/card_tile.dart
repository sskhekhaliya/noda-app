import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../data/database/app_database.dart';
import '../../providers/selection_provider.dart';

class CardTile extends ConsumerWidget {
  const CardTile({
    super.key,
    required this.card,
    this.onTap,
    this.onLongPress,
  });

  final Card card;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final noda = theme.extension<NodaThemeExtension>(); if (noda == null) return const SizedBox.shrink();
    final selection = ref.watch(selectionProvider);
    final isSelected = selection.contains(card.id);
    final isSelectionMode = selection.isNotEmpty;

    String _getPreviewText(String text) {
      if (text.isEmpty) return '';
      return text
          .replaceAll(RegExp(r'^\s*[-*_]{3,}\s*$', multiLine: true), '') // Horizontal rules
          .replaceAll(RegExp(r'^#+\s+', multiLine: true), '') // Headers
          .replaceAllMapped(RegExp(r'[*_]{1,2}([^*_]+)[*_]{1,2}'), (m) => m[1] ?? '') // Bold/Italic
          .replaceAllMapped(RegExp(r'~~([^~]+)~~'), (m) => m[1] ?? '') // Strikethrough
          .replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m[1] ?? '') // Inline code
          .replaceAll(RegExp(r'```[^`]*```'), '') // Code blocks
          .replaceAll(RegExp(r'^>\s+', multiLine: true), '') // Blockquotes
          .replaceAll(RegExp(r'^[*-]\s+', multiLine: true), '') // Unordered lists
          .replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '') // Ordered lists
          .replaceAllMapped(RegExp(r'\[(.*?)\]\(.*?\)'), (m) => m[1] ?? '') // Links
          .replaceAll(RegExp(r'\n+'), ' ') // Convert newlines to spaces
          .replaceAll(RegExp(r'\s+'), ' ') // Collapse multiple spaces
          .trim();
    }

    final frontPreview = _getPreviewText(card.front);
    final backPreview = _getPreviewText(card.back);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? colorScheme.primary : colorScheme.outline.withOpacity(0.08),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: isSelectionMode 
            ? () => ref.read(selectionProvider.notifier).toggle(card.id) 
            : onTap,
        onLongPress: () => ref.read(selectionProvider.notifier).toggle(card.id),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (isSelectionMode) ...[
                _SelectionIndicator(isSelected: isSelected),
                const SizedBox(width: 12),
              ],
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.style_outlined, size: 20, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      frontPreview.isEmpty ? 'Untitled' : frontPreview,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? colorScheme.primary : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      backPreview.isEmpty ? 'No answer' : backPreview,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: noda.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                '${card.score}',
                style: AppTypography.caption(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                ).copyWith(fontWeight: FontWeight.w300),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class _SelectionIndicator extends StatelessWidget {
  final bool isSelected;
  const _SelectionIndicator({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? colorScheme.primary : Colors.transparent,
        border: Border.all(
          color: isSelected ? colorScheme.primary : colorScheme.outline.withOpacity(0.4),
          width: 2,
        ),
      ),
      child: isSelected 
          ? const Icon(Icons.check, size: 16, color: Colors.white) 
          : null,
    );
  }
}


