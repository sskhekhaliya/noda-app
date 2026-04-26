import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Node;
import 'dart:io';
import 'dart:convert';
import 'dart:ui';

import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../data/database/app_database.dart';
import '../providers/database_provider.dart';
import '../providers/tts_provider.dart';
import 'keep_note_screen.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final List<Node> notes;
  final int initialIndex;

  const ReaderScreen({
    super.key,
    required this.notes,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late PageController _pageController;
  late int _currentIndex;
  late List<Node> _notes;

  @override
  void initState() {
    super.initState();
    _notes = List.from(widget.notes);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _extractPlainText(String content) {
    if (content.startsWith('[{"insert":')) {
      try {
        final List<dynamic> json = jsonDecode(content);
        return json.map((part) => part['insert'] ?? '').join();
      } catch (_) {}
    }
    return content;
  }

  void _toggleTts() {
    final tts = ref.read(ttsProvider.notifier);
    final isPlaying = ref.read(ttsProvider).isPlaying;
    
    if (isPlaying) {
      tts.stop();
    } else {
      final note = _notes[_currentIndex];
      final textToSpeak = [note.title, _extractPlainText(note.content)]
          .where((s) => s.isNotEmpty)
          .join('. ');
      tts.speak(textToSpeak);
    }
  }

  Future<void> _deleteNote() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note?'),
        content: const Text('This will permanently delete this note and cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final note = _notes[_currentIndex];
    await ref.read(databaseProvider).deleteNodeRecursive(note.id);
    
    if (!mounted) return;

    // Stop TTS if it's playing this note
    ref.read(ttsProvider.notifier).stop();

    setState(() {
      _notes.removeAt(_currentIndex);
      if (_currentIndex >= _notes.length && _notes.isNotEmpty) {
        _currentIndex = _notes.length - 1;
      }
    });

    if (_notes.isEmpty) {
      Navigator.pop(context);
    } else {
      _pageController.jumpToPage(_currentIndex);
    }
  }

  void _editNote() {
    final note = _notes[_currentIndex];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KeepNoteScreen(
          parentId: note.parentId ?? '', 
          nodeId: note.id,
          initialContent: note.content,
        ),
      ),
    ).then((_) {
      // In a real scenario we'd want to reload the note from DB here.
      // For now, it will refresh when we pop out to the hierarchy screen.
      // A full fix would listen to a stream of this specific node.
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_notes.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final noda = theme.extension<NodaThemeExtension>()!;
    final isPlaying = ref.watch(ttsProvider).isPlaying;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close_rounded, size: 20),
          ),
          onPressed: () {
            ref.read(ttsProvider.notifier).stop();
            Navigator.pop(context);
          },
        ),
        title: _notes.length > 1
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentIndex + 1} of ${_notes.length}',
                  style: AppTypography.caption(color: colorScheme.onSurface),
                ),
              )
            : null,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.surface,
                    colorScheme.surfaceContainerLowest,
                  ],
                ),
              ),
            ),
          ),

          // Main Content Pager
          PageView.builder(
            controller: _pageController,
            itemCount: _notes.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              if (isPlaying) {
                ref.read(ttsProvider.notifier).stop();
              }
            },
            itemBuilder: (context, index) {
              return _ReaderPage(note: _notes[index]);
            },
          ),

          // Bottom Action Pill
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PillButton(
                          icon: isPlaying ? Icons.stop_rounded : Icons.headphones_rounded,
                          label: isPlaying ? 'Stop' : 'Listen',
                          color: isPlaying ? colorScheme.primary : colorScheme.onSurface,
                          onTap: _toggleTts,
                        ),
                        Container(
                          width: 1,
                          height: 24,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          color: colorScheme.outline.withValues(alpha: 0.3),
                        ),
                        _PillButton(
                          icon: Icons.edit_rounded,
                          label: 'Edit',
                          color: colorScheme.onSurface,
                          onTap: _editNote,
                        ),
                        Container(
                          width: 1,
                          height: 24,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          color: colorScheme.outline.withValues(alpha: 0.3),
                        ),
                        _PillButton(
                          icon: Icons.delete_outline_rounded,
                          label: 'Delete',
                          color: colorScheme.error,
                          onTap: _deleteNote,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PillButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.buttonText(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderPage extends StatelessWidget {
  final Node note;

  const _ReaderPage({required this.note});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 110, 20, 120), // Leave room for app bar and bottom pill
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (note.title.isNotEmpty) ...[
                  Text(
                    note.title,
                    style: AppTypography.headingLarge().copyWith(
                      fontSize: 32,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                _buildContent(context, note.content),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, String content) {
    if (content.isEmpty) {
      return Text(
        '*No content*',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final noda = theme.extension<NodaThemeExtension>()!;

    if (content.startsWith('[{"insert":')) {
      try {
        final doc = Document.fromJson(jsonDecode(content));
        final controller = QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: true,
        );
        return QuillEditor.basic(
          controller: controller,
          config: const QuillEditorConfig(
            autoFocus: false,
            scrollable: false,
            padding: EdgeInsets.zero,
          ),
        );
      } catch (_) {}
    }

    return MarkdownBody(
      data: content,
      selectable: true,
      imageBuilder: (uri, title, alt) {
        if (uri.scheme == 'file') {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(File(uri.toFilePath())),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(uri.toString()),
          ),
        );
      },
      styleSheet: MarkdownStyleSheet(
        p: AppTypography.bodyLarge().copyWith(
          height: 1.8,
          fontSize: 18,
          color: noda.textSecondary.withValues(alpha: 0.9),
        ),
        h1: AppTypography.headingLarge(),
        h2: AppTypography.headingMedium(),
        h3: AppTypography.headingSmall(),
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          backgroundColor: colorScheme.surfaceContainerLow,
        ),
        codeblockPadding: const EdgeInsets.all(16),
        codeblockDecoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(left: BorderSide(color: colorScheme.primary, width: 4)),
          color: colorScheme.surfaceContainerLowest,
        ),
        blockquotePadding: const EdgeInsets.all(16),
      ),
    );
  }
}

