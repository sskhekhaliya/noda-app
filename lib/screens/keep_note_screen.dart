import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Node;
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;

import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../data/database/app_database.dart';
import '../providers/database_provider.dart';

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
  late QuillController _controller;
  bool _isSaving = false;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.initialContent != null && widget.initialContent!.isNotEmpty) {
      try {
        final doc = Document.fromJson(jsonDecode(widget.initialContent!));
        _controller = QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (e) {
        // Fallback if not JSON (legacy markdown)
        _controller = QuillController.basic();
        _controller.document.insert(0, widget.initialContent!);
      }
    } else {
      _controller = QuillController.basic();
    }
    
    _controller.addListener(_onStateChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onStateChanged);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    final content = jsonEncode(_controller.document.toDelta().toJson());
    
    // Don't save empty notes
    if (_controller.document.isEmpty()) {
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
            content: Value(content),
            updatedAt: Value(DateTime.now()),
          ),
        );
      } else {
        await db.insertNode(
          NodesCompanion.insert(
            id: const Uuid().v4(),
            type: 'NOTE',
            title: '', // Keep notes have no title
            content: Value(content),
            parentId: Value(widget.parentId),
            createdAt: Value(DateTime.now()),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = colorScheme.primary;
    final bg = colorScheme.surface;
    final textColor = colorScheme.onSurface;
    final shadowColor = isDark ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.05);

    final selectionStyle = _controller.getSelectionStyle();
    final isBold = selectionStyle.attributes.containsKey(Attribute.bold.key);
    final isItalic = selectionStyle.attributes.containsKey(Attribute.italic.key);
    final isUnderline = selectionStyle.attributes.containsKey(Attribute.underline.key);
    final isBullet = selectionStyle.attributes.containsKey(Attribute.list.key) && 
                    selectionStyle.attributes[Attribute.list.key]?.value == 'bullet';
    
    int currentHeader = 0;
    if (selectionStyle.attributes.containsKey(Attribute.header.key)) {
      currentHeader = selectionStyle.attributes[Attribute.header.key]?.value ?? 0;
    }

    final isQuote = selectionStyle.attributes.containsKey(Attribute.blockQuote.key);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _saveNote();
      },
      child: Scaffold(
        backgroundColor: bg,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _saveNote,
          ),
          actions: [
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
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
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
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 8, 28, 100),
                    child: QuillEditor.basic(
                      controller: _controller,
                      config: QuillEditorConfig(
                        autoFocus: true,
                        placeholder: 'Take a note...',
                        expands: true,
                        padding: EdgeInsets.zero,
                        enableInteractiveSelection: true,
                        customStyles: DefaultStyles(
                          h1: DefaultTextBlockStyle(
                            AppTypography.headingLarge(color: textColor),
                            const HorizontalSpacing(0, 0),
                            const VerticalSpacing(24, 8),
                            const VerticalSpacing(0, 0),
                            null,
                          ),
                          h2: DefaultTextBlockStyle(
                            AppTypography.headingMedium(color: textColor),
                            const HorizontalSpacing(0, 0),
                            const VerticalSpacing(20, 8),
                            const VerticalSpacing(0, 0),
                            null,
                          ),
                          h3: DefaultTextBlockStyle(
                            AppTypography.headingSmall(color: textColor),
                            const HorizontalSpacing(0, 0),
                            const VerticalSpacing(16, 6),
                            const VerticalSpacing(0, 0),
                            null,
                          ),
                          h4: DefaultTextBlockStyle(
                            AppTypography.subtitle(color: textColor).copyWith(fontWeight: FontWeight.w600, fontSize: 16),
                            const HorizontalSpacing(0, 0),
                            const VerticalSpacing(14, 6),
                            const VerticalSpacing(0, 0),
                            null,
                          ),
                          h5: DefaultTextBlockStyle(
                            AppTypography.subtitle(color: textColor).copyWith(fontWeight: FontWeight.w500, fontSize: 15),
                            const HorizontalSpacing(0, 0),
                            const VerticalSpacing(12, 4),
                            const VerticalSpacing(0, 0),
                            null,
                          ),
                          h6: DefaultTextBlockStyle(
                            AppTypography.subtitle(color: textColor).copyWith(fontWeight: FontWeight.w500, fontSize: 14),
                            const HorizontalSpacing(0, 0),
                            const VerticalSpacing(10, 4),
                            const VerticalSpacing(0, 0),
                            null,
                          ),
                          paragraph: DefaultTextBlockStyle(
                            AppTypography.bodyLarge(color: textColor.withOpacity(0.9)),
                            const HorizontalSpacing(0, 0),
                            const VerticalSpacing(0, 0),
                            const VerticalSpacing(0, 0),
                            null,
                          ),
                          quote: DefaultTextBlockStyle(
                            AppTypography.bodyLarge(color: textColor.withOpacity(0.7)).copyWith(fontStyle: FontStyle.italic),
                            const HorizontalSpacing(0, 0),
                            const VerticalSpacing(12, 12),
                            const VerticalSpacing(0, 0),
                            BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  width: 4,
                                  color: accent.withOpacity(0.3),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      scrollController: _scrollController,
                      focusNode: _focusNode,
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 20, 
              left: 20,
              right: 20,
              child: Material(
                type: MaterialType.transparency,
                child: Hero(
                  tag: 'keep_editor_toolbar',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: shadowColor,
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _headerPicker(
                          currentHeader: currentHeader,
                          onSelected: (level) {
                            _controller.formatSelection(
                              level == 0 ? Attribute.clone(Attribute.header, null) : Attribute.fromKeyValue('header', level),
                            );
                          },
                          accent: accent,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 20, child: VerticalDivider(width: 1, thickness: 1)),
                        _toolbarItem(
                          icon: Icons.format_quote_rounded, 
                          onPressed: () => _toggleAttribute(Attribute.blockQuote),
                          isSelected: isQuote,
                          accent: accent,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 20, child: VerticalDivider(width: 1, thickness: 1)),
                        _toolbarItem(
                          icon: Icons.format_bold_rounded, 
                          onPressed: () => _toggleAttribute(Attribute.bold),
                          isSelected: isBold,
                          accent: accent,
                          isDark: isDark,
                        ),
                        _toolbarItem(
                          icon: Icons.format_italic_rounded, 
                          onPressed: () => _toggleAttribute(Attribute.italic),
                          isSelected: isItalic,
                          accent: accent,
                          isDark: isDark,
                        ),
                        _toolbarItem(
                          icon: Icons.format_underlined_rounded, 
                          onPressed: () => _toggleAttribute(Attribute.underline),
                          isSelected: isUnderline,
                          accent: accent,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 20, child: VerticalDivider(width: 1, thickness: 1)),
                        _toolbarItem(
                          icon: Icons.format_list_bulleted_rounded, 
                          onPressed: () => _toggleAttribute(Attribute.ul),
                          isSelected: isBullet,
                          accent: accent,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 20, child: VerticalDivider(width: 1, thickness: 1)),
                        _toolbarItem(
                          icon: Icons.undo_rounded, 
                          onPressed: _controller.undo,
                          accent: accent,
                          isDark: isDark,
                        ),
                        _toolbarItem(
                          icon: Icons.redo_rounded, 
                          onPressed: _controller.redo,
                          accent: accent,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleAttribute(Attribute attribute) {
    final style = _controller.getSelectionStyle();
    if (style.attributes.containsKey(attribute.key)) {
      _controller.formatSelection(Attribute.clone(attribute, null));
    } else {
      _controller.formatSelection(attribute);
    }
  }

  Widget _headerPicker({
    required int currentHeader,
    required Function(int) onSelected,
    required Color accent,
    required bool isDark,
  }) {
    return PopupMenuButton<int>(
      onSelected: onSelected,
      offset: const Offset(0, -280),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      itemBuilder: (context) => [
        _buildPopupItem(0, 'Normal', currentHeader == 0, accent, isDark),
        _buildPopupItem(1, 'Heading 1', currentHeader == 1, accent, isDark),
        _buildPopupItem(2, 'Heading 2', currentHeader == 2, accent, isDark),
        _buildPopupItem(3, 'Heading 3', currentHeader == 3, accent, isDark),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: currentHeader > 0 ? accent.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.format_size_rounded,
              size: 20,
              color: currentHeader > 0 ? accent : (isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(width: 4),
            Text(
              currentHeader == 0 ? 'T' : 'H$currentHeader',
              style: AppTypography.chipLabel(
                color: currentHeader > 0 ? accent : (isDark ? Colors.white70 : Colors.black54),
              ).copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<int> _buildPopupItem(int value, String label, bool isSelected, Color accent, bool isDark) {
    return PopupMenuItem<int>(
      value: value,
      child: Row(
        children: [
          Text(
            label,
            style: AppTypography.bodyMedium(
              color: isSelected ? accent : (isDark ? Colors.white70 : Colors.black87),
            ).copyWith(
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            Icon(Icons.check_rounded, color: accent, size: 18),
          ],
        ],
      ),
    );
  }

  Widget _toolbarItem({
    required IconData icon,
    required VoidCallback onPressed,
    bool isSelected = false,
    required Color accent,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accent.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? accent : (isDark ? Colors.white70 : Colors.black54),
        ),
      ),
    );
  }
}
