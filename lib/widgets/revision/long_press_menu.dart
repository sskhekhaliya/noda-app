import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../data/database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../screens/note_editor_screen.dart';
import 'hierarchy_picker_modal.dart';

/// Long-press context menu shown as a bottom sheet.
class LongPressMenu {
  LongPressMenu._();

  static void show({
    required BuildContext context,
    required WidgetRef ref,
    required Node note,
    required String selectedText,
  }) {
    final noda = Theme.of(context).extension<NodaThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Context header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: noda.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'From: ${note.title}',
                      style: AppTypography.chipLabel(
                          color: noda.textSecondary),
                    ),
                    if (selectedText.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        selectedText.length > 120
                            ? '${selectedText.substring(0, 120)}...'
                            : selectedText,
                        style: AppTypography.bodySmall(
                            color: colorScheme.onSurface),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Action A: Create Sub-Note
              _ActionTile(
                icon: Icons.subdirectory_arrow_right_rounded,
                color: colorScheme.primary,
                title: 'Create Sub-Note',
                subtitle: 'Add as a child of this note',
                onTap: () {
                  Navigator.pop(ctx);
                  _createSubNote(context, ref, note, selectedText);
                },
              ),

              const SizedBox(height: 4),

              // Action B: Assign as Universal
              _ActionTile(
                icon: Icons.public_rounded,
                color: colorScheme.secondary,
                title: 'Assign as Universal',
                subtitle: 'Save to Universal Node Library',
                onTap: () {
                  Navigator.pop(ctx);
                  _assignUniversal(context, ref, note, selectedText);
                },
              ),

              const SizedBox(height: 4),

              // Action C: Attach to Existing
              _ActionTile(
                icon: Icons.link_rounded,
                color: noda.iconActive,
                title: 'Attach to Existing',
                subtitle: 'Hook onto another branch',
                onTap: () {
                  Navigator.pop(ctx);
                  HierarchyPickerModal.show(
                    context: context,
                    ref: ref,
                    onSelected: (parentId) async {
                      final db = ref.read(databaseProvider);
                      final newId = const Uuid().v4();
                      await db.insertNode(
                        NodesCompanion.insert(
                          id: newId,
                          parentId: Value(parentId),
                          type: 'NOTE',
                          title: selectedText.isNotEmpty
                              ? selectedText.split('\n').first
                              : 'Note from ${note.title}',
                          content: Value(selectedText),
                        ),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Note attached!')),
                        );
                      }
                    },
                  );
                },
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _createSubNote(
    BuildContext context,
    WidgetRef ref,
    Node parentNote,
    String selectedText,
  ) async {
    final db = ref.read(databaseProvider);
    final children = await db.getChildrenOf(parentNote.id);
    final newId = const Uuid().v4();

    await db.insertNode(
      NodesCompanion.insert(
        id: newId,
        parentId: Value(parentNote.id),
        type: 'NOTE',
        title: selectedText.isNotEmpty
            ? selectedText.split('\n').first
            : 'Sub-note',
        content: Value(selectedText),
        orderIndex: Value(children.length),
      ),
    );

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NoteEditorScreen(nodeId: newId),
        ),
      );
    }
  }

  static Future<void> _assignUniversal(
    BuildContext context,
    WidgetRef ref,
    Node sourceNote,
    String selectedText,
  ) async {
    final db = ref.read(databaseProvider);
    final newId = const Uuid().v4();

    await db.insertNode(
      NodesCompanion.insert(
        id: newId,
        type: 'NOTE',
        title: selectedText.isNotEmpty
            ? selectedText.split('\n').first
            : 'Universal: ${sourceNote.title}',
        content: Value(selectedText.isNotEmpty ? selectedText : sourceNote.content),
      ),
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to Universal Library!')),
      );
    }
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title,
          style: AppTypography.subtitle(
              color: Theme.of(context).colorScheme.onSurface)),
      subtitle:
          Text(subtitle, style: AppTypography.caption()),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
