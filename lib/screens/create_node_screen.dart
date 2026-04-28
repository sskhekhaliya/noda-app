import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_markdown/flutter_markdown.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../data/database/app_database.dart';
import '../providers/database_provider.dart';
import '../core/utils/image_utils.dart';

class CreateNodeScreen extends ConsumerStatefulWidget {
  final String parentId;
  final String initialType;
  const CreateNodeScreen({super.key, required this.parentId, this.initialType = 'NOTE'});

  @override
  ConsumerState<CreateNodeScreen> createState() => _CreateNodeScreenState();
}

class _CreateNodeScreenState extends ConsumerState<CreateNodeScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _contentFocusNode = FocusNode();
  String _nodeType = 'NOTE'; 
  bool _isSaving = false;
  bool _isPreviewMode = false;

  @override
  void initState() {
    super.initState();
    _nodeType = widget.initialType;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveNode() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (_nodeType == 'FOLDER' && title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A topic requires a title.')),
      );
      return;
    }
    if (_nodeType == 'NOTE' && content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add some thoughts to your note.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = ref.read(databaseProvider);
      final nodeId = const Uuid().v4();

      await db.insertNode(
        NodesCompanion.insert(
          id: nodeId,
          type: _nodeType,
          title: title,
          content: Value(content),
          parentId: Value(widget.parentId),
          createdAt: Value(DateTime.now()),
        ),
      );

      if (_nodeType == 'FOLDER' && content.isNotEmpty) {
        await db.insertNode(
          NodesCompanion.insert(
            id: const Uuid().v4(),
            type: 'NOTE',
            title: '',
            content: Value(content),
            parentId: Value(nodeId),
            createdAt: Value(DateTime.now().add(const Duration(milliseconds: 100))),
          ),
        );
      }

      if (mounted) Navigator.pop(context);
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

  Future<void> _pickImage() async {
    final path = await ImageUtils.pickAndSaveImage();
    if (path != null && mounted) {
      final text = _contentController.text;
      final selection = _contentController.selection;
      
      // We'll use file URI style for local consistency
      final markdown = '\n\n![Image](file://${path.replaceAll("\\", "/")})\n\n';

      final int start = selection.start != -1 ? selection.start : text.length;
      final int end = selection.end != -1 ? selection.end : text.length;

      final newText = text.replaceRange(start, end, markdown);

      setState(() {
        _contentController.text = newText;
        _contentController.selection = TextSelection.collapsed(
          offset: start + markdown.length,
        );
      });
      
      // Briefly focus to show the updated content
      _contentFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isPreviewMode ? Icons.edit_note_outlined : Icons.remove_red_eye_outlined,
              color: _isPreviewMode ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            tooltip: _isPreviewMode ? 'Switch to Edit' : 'Switch to Preview',
            onPressed: () => setState(() => _isPreviewMode = !_isPreviewMode),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isPreviewMode ? _buildPremiumPreview() : _buildEditor(),
            ),
            _buildBottomBar(),
          ],
        ),
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
          _buildMinimalToggle(),
          const SizedBox(width: 12),
          IconButton(
            icon: Icon(Icons.add_photo_alternate_outlined, color: colorScheme.primary),
            onPressed: _pickImage,
            tooltip: 'Add Photo',
          ),
          const Spacer(),
          TextButton(
            onPressed: _isSaving ? null : _saveNode,
            child: _isSaving 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('POST', style: AppTypography.buttonText(color: colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalToggle() {
    final colorScheme = Theme.of(context).colorScheme;
    final isNote = _nodeType == 'NOTE';
    
    return Container(
      height: 36,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleAction(
            label: 'Note',
            isSelected: isNote,
            onTap: () => setState(() => _nodeType = 'NOTE'),
          ),
          _ToggleAction(
            label: 'Topic',
            isSelected: !isNote,
            onTap: () => setState(() => _nodeType = 'FOLDER'),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _contentFocusNode.requestFocus(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    autofocus: true,
                    style: AppTypography.headingLarge().copyWith(fontWeight: FontWeight.w600, fontSize: 20),
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Title',
                      hintStyle: TextStyle(color: colorScheme.outline.withOpacity(0.3)),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _contentController,
                    focusNode: _contentFocusNode,
                    style: AppTypography.bodyLarge().copyWith(height: 1.6),
                    minLines: 1,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Type your thoughts here...',
                      hintStyle: TextStyle(color: colorScheme.outline.withOpacity(0.3)),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPremiumPreview() {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (_titleController.text.isEmpty ? 'Untitled' : _titleController.text).toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: colorScheme.primary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            height: 1,
            width: 40,
            color: colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 40),
          if (_contentController.text.isNotEmpty) ...[
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MarkdownBody(
                      data: _contentController.text,
                      selectable: true,
                      imageBuilder: (uri, title, alt) {
                        if (uri.scheme == 'file') {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(File(uri.toFilePath())),
                          );
                        }
                        return Image.network(uri.toString());
                      },
                      styleSheet: MarkdownStyleSheet(
                        p: AppTypography.bodySmall(
                          color: Theme.of(context).extension<NodaThemeExtension>()?.textSecondary,
                        ),
                        strong: const TextStyle(fontWeight: FontWeight.w700),
                        em: const TextStyle(fontStyle: FontStyle.italic),
                        del: const TextStyle(decoration: TextDecoration.lineThrough),
                        code: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          backgroundColor: colorScheme.surfaceContainerLow,
                        ),
                        codeblockPadding: const EdgeInsets.all(12),
                        codeblockDecoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        horizontalRuleDecoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: colorScheme.primary.withOpacity(0.15),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
             Text(
               '*No content to preview*',
               style: AppTypography.bodySmall(color: colorScheme.outline.withOpacity(0.5)),
             ),
          ],
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

class _ToggleAction extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleAction({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ),
    );
  }
}


