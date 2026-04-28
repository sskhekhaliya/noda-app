import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;

import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../data/database/app_database.dart';
import '../providers/database_provider.dart';
import '../providers/nodes_provider.dart';
import '../widgets/common/noda_markdown.dart';

class KeepNoteScreen extends ConsumerStatefulWidget {
  final String parentId;
  final String? nodeId;
  final String? initialContent;

  const KeepNoteScreen({
    super.key,
    required this.parentId,
    this.nodeId,
    this.initialContent,
  });

  @override
  ConsumerState<KeepNoteScreen> createState() => _KeepNoteScreenState();
}

class _KeepNoteScreenState extends ConsumerState<KeepNoteScreen> {
  late TextEditingController _titleController;
  late TextEditingController _controller;
  bool _isSaving = false;
  bool _isPreviewMode = false;
  bool _hasChanges = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    String content = widget.initialContent ?? '';
    
    // Auto-convert JSON Delta to Plain Text if needed
    if (content.startsWith('[{"insert":')) {
      try {
        final List<dynamic> json = jsonDecode(content);
        content = json.map((part) => part['insert'] ?? '').join().trim();
      } catch (_) {}
    }
    
    _titleController = TextEditingController();
    _controller = TextEditingController(text: content);

    if (widget.nodeId != null) {
      ref.read(databaseProvider).getNodeById(widget.nodeId!).then((node) {
        if (node != null && mounted) {
          _titleController.text = node.title;
        }
      });
    }

    _controller.addListener(_onChanged);
    _titleController.addListener(_onChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isPreviewMode) _focusNode.requestFocus();
    });
  }

  void _onChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _titleController.removeListener(_onChanged);
    _controller.dispose();
    _titleController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final content = _controller.text.trim();
    
    if (content.isEmpty && title.isEmpty && widget.nodeId == null) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = ref.read(databaseProvider);
      if (widget.nodeId != null) {
        await db.updateNode(
          widget.nodeId!,
          NodesCompanion(
            title: Value(title),
            content: Value(content),
            updatedAt: Value(DateTime.now()),
          ),
        );
      } else {
        await db.insertNode(
          NodesCompanion.insert(
            id: const Uuid().v4(),
            type: 'NOTE',
            title: title,
            content: Value(content),
            parentId: Value(widget.parentId),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
      setState(() => _hasChanges = false);
      if (mounted) Navigator.pop(context, content);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bg = colorScheme.surface;
    final accent = colorScheme.primary;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _saveNote();
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _saveNote,
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isPreviewMode ? Icons.edit_note_rounded : Icons.remove_red_eye_outlined,
                color: _isPreviewMode ? accent : colorScheme.onSurfaceVariant,
              ),
              tooltip: _isPreviewMode ? 'Switch to Edit' : 'Switch to Preview',
              onPressed: () => setState(() => _isPreviewMode = !_isPreviewMode),
            ),
            if (_isSaving)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: TextButton(
                    onPressed: _saveNote,
                    child: Text(
                      'SAVE',
                      style: AppTypography.buttonText(color: accent).copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: _isPreviewMode ? _buildPreview() : _buildEditor(),
      ),
    );
  }

  Widget _buildEditor() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 20),
      child: Column(
        children: [
          TextField(
            controller: _titleController,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'Title',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.3)),
              filled: false,
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLines: null,
              expands: true,
              style: AppTypography.bodyLarge(color: colorScheme.onSurface).copyWith(
                height: 1.6,
              ),
              decoration: InputDecoration(
                hintText: 'Take a note...',
                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
                filled: false,
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final colorScheme = Theme.of(context).colorScheme;
    final title = _titleController.text.trim();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: colorScheme.primary,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: colorScheme.outline.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
          ],
          NodaMarkdown(
            data: _controller.text.isEmpty ? '*Empty note*' : _controller.text,
            selectable: true,
          ),
        ],
      ),
    );
  }
}



