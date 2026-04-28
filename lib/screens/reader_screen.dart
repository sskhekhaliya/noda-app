import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/common/noda_markdown.dart';
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

  static String _extractPlainText(String? content) {
    if (content != null && content.startsWith('[{"insert":')) {
      try {
        final List<dynamic> json = jsonDecode(content);
        return json.map((part) => part['insert'] ?? '').join().trim();
      } catch (_) {}
    }
    return content ?? "";
  }
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
    // Stop TTS when leaving the screen
    ref.read(ttsProvider.notifier).stop();
    super.dispose();
  }

  void _nextPage() {
    if (_currentIndex < _notes.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _previousPage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_notes.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final noda = theme.extension<NodaThemeExtension>();
    if (noda == null) return const SizedBox.shrink();
    final isPlaying = ref.watch(ttsProvider).isPlaying;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // Force stop TTS when popping the screen
          ref.read(ttsProvider.notifier).stop();
        }
      },
      child: Scaffold(
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
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isPlaying ? colorScheme.primary : colorScheme.surface).withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded,
                  size: 20,
                  color: isPlaying ? colorScheme.onPrimary : colorScheme.primary,
                ),
              ),
              onPressed: () {
                final currentNote = _notes[_currentIndex];
                if (isPlaying) {
                  ref.read(ttsProvider.notifier).stop();
                } else {
                  // Speak the title then the content
                  final speechText = currentNote.title.isNotEmpty 
                      ? '${currentNote.title}. ${currentNote.content}' 
                      : currentNote.content;
                  ref.read(ttsProvider.notifier).speak(speechText);
                }
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit_rounded, size: 20),
              ),
              onPressed: () async {
                final result = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => KeepNoteScreen(
                      parentId: _notes[_currentIndex].parentId ?? '',
                      nodeId: _notes[_currentIndex].id,
                      initialContent: _notes[_currentIndex].content,
                    ),
                  ),
                );
                if (result != null) {
                  setState(() {
                    _notes[_currentIndex] = _notes[_currentIndex].copyWith(content: result);
                  });
                }
              },
            ),
            const SizedBox(width: 16),
          ],
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
                      colorScheme.primary.withValues(alpha: 0.05),
                      colorScheme.surface,
                    ],
                  ),
                ),
              ),
            ),
            
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
                if (ref.read(ttsProvider).isPlaying) {
                  ref.read(ttsProvider.notifier).stop();
                }
              },
              itemCount: _notes.length,
              itemBuilder: (context, index) {
                return _ReaderPage(note: _notes[index]);
              },
            ),
  
            // Navigation Overlay (Left/Right areas)
            Positioned.fill(
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _previousPage,
                    child: Container(
                      width: 60,
                      color: Colors.transparent,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _nextPage,
                    child: Container(
                      width: 60,
                      color: Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
  
            // Bottom Navigation Pill
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
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
                      _NavButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        label: 'Prev',
                        onTap: _currentIndex > 0 ? _previousPage : null,
                        color: _currentIndex > 0 ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      Container(
                        height: 24,
                        width: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        color: colorScheme.outline.withValues(alpha: 0.1),
                      ),
                      Text(
                        '${_currentIndex + 1} / ${_notes.length}',
                        style: AppTypography.caption(color: colorScheme.onSurface).copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Container(
                        height: 24,
                        width: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        color: colorScheme.outline.withValues(alpha: 0.1),
                      ),
                      _NavButton(
                        icon: Icons.arrow_forward_ios_rounded,
                        label: 'Next',
                        onTap: _currentIndex < _notes.length - 1 ? _nextPage : null,
                        color: _currentIndex < _notes.length - 1 ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  const _NavButton({
    required this.icon,
    required this.label,
    this.onTap,
    required this.color,
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

    return Container(
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
    
    return NodaMarkdown(
      data: ReaderScreen._extractPlainText(content),
      selectable: true,
    );
  }
}
