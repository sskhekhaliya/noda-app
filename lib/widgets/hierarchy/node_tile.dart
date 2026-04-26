import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../data/database/app_database.dart';
import '../../providers/nodes_provider.dart';
import '../../providers/revision_provider.dart';
import '../../providers/database_provider.dart';
import '../../screens/hierarchy_screen.dart';
import '../../screens/note_editor_screen.dart';
import '../../screens/revision_feed_screen.dart';
import '../../screens/keep_note_screen.dart';
import '../../providers/selection_provider.dart';
import 'dart:convert';
import 'revision_buttons.dart';

class NodeTile extends ConsumerWidget {
  const NodeTile({
    super.key,
    required this.node,
    required this.onPlay,
    required this.onShuffle,
    this.onLongPress,
    this.onDelete,
    this.onAdd,
    this.onNavigate,
    this.onTap,
    this.index = 0,
  });

  final Node node;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;
  final VoidCallback? onAdd;
  final VoidCallback? onNavigate;
  final VoidCallback? onTap;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final noda = theme.extension<NodaThemeExtension>()!;
    final selection = ref.watch(selectionProvider);
    final isSelected = selection.contains(node.id);
    final isSelectionMode = selection.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.1),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: isSelectionMode 
            ? () => ref.read(selectionProvider.notifier).toggle(node.id) 
            : onTap,
        onLongPress: () => ref.read(selectionProvider.notifier).toggle(node.id),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              if (isSelectionMode) ...[
                _SelectionIndicator(isSelected: isSelected),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (node.title.isNotEmpty) ...[
                      Text(
                        node.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isSelected ? colorScheme.primary : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 3,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildPreview(context, node.content),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.description_outlined, color: noda.iconInactive.withValues(alpha: 0.5), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context, String content) {
    final theme = Theme.of(context);
    final noda = theme.extension<NodaThemeExtension>()!;
    
    String displayContent = content;
    bool isRichText = false;

    if (content.startsWith('[{"insert":')) {
      try {
        final List<dynamic> json = jsonDecode(content);
        displayContent = json.map((part) => part['insert'] ?? '').join().trim();
        isRichText = true;
      } catch (_) {}
    }

    if (!isRichText) {
      return MarkdownBody(
        data: content,
        styleSheet: MarkdownStyleSheet(
          p: theme.textTheme.bodySmall?.copyWith(color: noda.textSecondary),
        ),
      );
    }

    return Text(
      displayContent,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(color: noda.textSecondary),
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
          color: isSelected ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      child: isSelected 
          ? const Icon(Icons.check, size: 16, color: Colors.white) 
          : null,
    );
  }
}


