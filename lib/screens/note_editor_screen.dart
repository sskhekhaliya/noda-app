import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;
import '../widgets/common/noda_markdown.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../data/database/app_database.dart';
import '../providers/database_provider.dart';
import '../providers/nodes_provider.dart';
import '../core/utils/image_utils.dart';

/// Editor screen for creating and editing notes.
class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({
    super.key,
    required this.nodeId,
  });

  final String nodeId;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isLoading = true;
  bool _hasChanges = false;
  bool _isPreviewMode = false;


  @override
  void initState() {
    super.initState();
    _loadNode();
  }

  Future<void> _loadNode() async {
    final db = ref.read(databaseProvider);
    final node = await db.getNodeById(widget.nodeId);
    if (node != null && mounted) {
      setState(() {
        _titleController.text = node.title;
        _contentController.text = node.content;
        _isLoading = false;
      });

      _titleController.addListener(_markChanged);
      _contentController.addListener(_markChanged);
    }
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  Future<void> _save() async {
    if (!_hasChanges) return;

    final db = ref.read(databaseProvider);
    await db.updateNode(
      widget.nodeId,
      NodesCompanion(
        title: Value(_titleController.text),
        content: Value(_contentController.text),
        updatedAt: Value(DateTime.now()),
      ),
    );

    setState(() => _hasChanges = false);
  }

  Future<void> _createSubNote() async {
    final title = await _showCreateDialog('New Sub-Note');
    if (title == null || title.isEmpty) return;

    final db = ref.read(databaseProvider);
    final children = await db.getChildrenOf(widget.nodeId);
    final newId = const Uuid().v4();

    await db.insertNode(
      NodesCompanion.insert(
        id: newId,
        parentId: Value(widget.nodeId),
        type: 'NOTE',
        title: title,
        orderIndex: Value(children.length),
      ),
    );

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NoteEditorScreen(nodeId: newId),
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    final path = await ImageUtils.pickAndSaveImage();
    if (path != null && mounted) {
      final text = _contentController.text;
      final selection = _contentController.selection;

      final markdown = '\n\n![Image](file://${path.replaceAll("\\", "/")})\n\n';

      final int start = selection.start != -1 ? selection.start : text.length;
      final int end = selection.end != -1 ? selection.end : text.length;

      final newText = text.replaceRange(start, end, markdown);

      setState(() {
        _contentController.text = newText;
        _contentController.selection = TextSelection.collapsed(
          offset: start + markdown.length,
        );
        _hasChanges = true;
      });
    }
  }

  Future<String?> _showCreateDialog(String dialogTitle) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(dialogTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Sub-note title...'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Auto-save on exit
    if (_hasChanges) _saveSync();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _saveSync() {
    final db = ref.read(databaseProvider);
    db.updateNode(
      widget.nodeId,
      NodesCompanion(
        title: Value(_titleController.text),
        content: Value(_contentController.text),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final noda = Theme.of(context).extension<NodaThemeExtension>();
    if (noda == null) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final ancestorPath = ref.watch(ancestorPathProvider(widget.nodeId));

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      onPopInvokedWithResult: (_, __) => _save(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isPreviewMode ? 'Preview Note' : 'Edit Note'),
          actions: [
            // Preview Toggle
            IconButton(
              icon: Icon(
                _isPreviewMode ? Icons.edit_note_rounded : Icons.remove_red_eye_outlined,
                color: _isPreviewMode ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
              tooltip: _isPreviewMode ? 'Switch to Edit' : 'Switch to Preview',
              onPressed: () => setState(() => _isPreviewMode = !_isPreviewMode),
            ),
            // Create sub-note
            if (!_isPreviewMode)
              IconButton(
                icon: const Icon(Icons.subdirectory_arrow_right_rounded),
                tooltip: 'Create Sub-Note',
                onPressed: _createSubNote,
              ),
            // Save indicator
            if (_hasChanges)
              IconButton(
                icon: const Icon(Icons.save_rounded),
                onPressed: _save,
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            // Breadcrumb trail
            ancestorPath.when(
              data: (path) {
                if (path.isEmpty) return const SizedBox.shrink();
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  color: noda.surfaceAlt,
                  child: Text(
                    path.map((n) => n.title).join(' › '),
                    style: AppTypography.breadcrumb(
                        color: noda.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // Editor or Preview
            Expanded(
              child: _isPreviewMode ? _buildPreview() : _buildEditor(),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildEditor() {
    final noda = Theme.of(context).extension<NodaThemeExtension>();
    final colorScheme = Theme.of(context).colorScheme;
    if (noda == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title field
          TextField(
            controller: _titleController,
            style: AppTypography.noteTitle(
              color: colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'Note title',
              hintStyle: AppTypography.noteTitle(
                color: noda.textSecondary.withOpacity(0.5),
              ),
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 4),
          Divider(color: colorScheme.outline),
          const SizedBox(height: 12),

          // Content field
          TextField(
            controller: _contentController,
            style: AppTypography.bodyLarge(
              color: colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'Start writing your note...',
              hintStyle: AppTypography.bodyLarge(
                color: noda.textSecondary.withOpacity(0.5),
              ),
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
            maxLines: null,
            minLines: 15,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _titleController.text.isEmpty ? 'Untitled' : _titleController.text,
            style: AppTypography.headingLarge().copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: colorScheme.primary.withOpacity(0.1)),
          const SizedBox(height: 24),
          NodaMarkdown(
            data: _contentController.text,
            selectable: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outline.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.add_photo_alternate_outlined, color: colorScheme.primary),
            onPressed: _pickImage,
            tooltip: 'Add Photo',
          ),
          const Spacer(),
          if (_hasChanges)
            TextButton(
              onPressed: _save,
              child: Text('SAVE', style: AppTypography.buttonText(color: colorScheme.primary)),
            ),
        ],
      ),
    );
  }
}

