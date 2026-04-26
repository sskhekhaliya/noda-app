import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';

class RichTextEditorScreen extends StatefulWidget {
  final String initialJson;
  final String title;

  const RichTextEditorScreen({
    super.key,
    required this.initialJson,
    this.title = 'Edit Description',
  });

  @override
  State<RichTextEditorScreen> createState() => _RichTextEditorScreenState();
}

class _RichTextEditorScreenState extends State<RichTextEditorScreen> {
  late QuillController _controller;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.initialJson.isNotEmpty) {
      try {
        final doc = Document.fromJson(jsonDecode(widget.initialJson));
        _controller = QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (e) {
        _controller = QuillController.basic();
      }
    } else {
      _controller = QuillController.basic();
    }
    
    // Add listener for reactive toolbar updates
    _controller.addListener(_onStateChanged);
    
    // Auto focus and place cursor at end
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

  void _save() {
    final json = jsonEncode(_controller.document.toDelta().toJson());
    Navigator.pop(context, json);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = colorScheme.primary;
    final bg = colorScheme.surface;
    final textColor = colorScheme.onSurface;
    final shadowColor = isDark ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.05);

    // Check active attributes for toolbar icons
    final selectionStyle = _controller.getSelectionStyle();
    final isBold = selectionStyle.attributes.containsKey(Attribute.bold.key);
    final isItalic = selectionStyle.attributes.containsKey(Attribute.italic.key);
    final isUnderline = selectionStyle.attributes.containsKey(Attribute.underline.key);
    final isBullet = selectionStyle.attributes.containsKey(Attribute.list.key) && 
                    selectionStyle.attributes[Attribute.list.key]?.value == 'bullet';
    
    // Header states
    int currentHeader = 0;
    if (selectionStyle.attributes.containsKey(Attribute.header.key)) {
      currentHeader = selectionStyle.attributes[Attribute.header.key]?.value ?? 0;
    }

    // Quote state
    final isQuote = selectionStyle.attributes.containsKey(Attribute.blockQuote.key);

    return Scaffold(
      backgroundColor: bg,
      resizeToAvoidBottomInset: true, // Crucial for natural resizing
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.title.toUpperCase(),
          style: AppTypography.headingSmall(color: textColor.withOpacity(0.6)).copyWith(
            fontSize: 12,
            letterSpacing: 2,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: textColor.withOpacity(0.5), size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: TextButton(
                onPressed: _save,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text(
                  'DONE',
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
          // Main Editor Area
          Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 100), // Extra bottom padding for toolbar
                  child: QuillEditor.basic(
                    controller: _controller,
                    config: QuillEditorConfig(
                      autoFocus: true,
                      placeholder: 'Start typing...',
                      expands: true,
                      padding: EdgeInsets.zero,
                      enableInteractiveSelection: true,
                      // Custom styles for better typography using Noda's Manrope
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

          // Floating Minimal Toolbar (at bottom)
          Positioned(
            bottom: 20, 
            left: 20,
            right: 20,
            child: Material(
              type: MaterialType.transparency,
              child: Hero(
                tag: 'editor_toolbar',
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
