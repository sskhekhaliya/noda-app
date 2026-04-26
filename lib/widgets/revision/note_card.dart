import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'dart:io';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../data/database/app_database.dart';
import '../../providers/tts_provider.dart';
import '../../providers/revision_provider.dart';

/// A full-screen note card displayed in the revision feed.
class NoteCard extends ConsumerStatefulWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.controller,
    this.onLongPress,
  });

  final Node note;
  final PageController controller;
  final void Function(String selectedText)? onLongPress;

  @override
  ConsumerState<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends ConsumerState<NoteCard> {
  final ScrollController _scrollController = ScrollController();
  bool _isAtBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final atBottom = pos.pixels >= pos.maxScrollExtent - 20;
    if (atBottom != _isAtBottom) {
      setState(() => _isAtBottom = atBottom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final noda = Theme.of(context).extension<NodaThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 80, 20, 60),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: colorScheme.onSurface.withValues(alpha: 0.04),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                left: -40,
                top: -40,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            widget.note.title,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        _TtsActionButton(text: widget.note.content),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: colorScheme.primary.withValues(alpha: 0.1)),
                    const SizedBox(height: 24),
                    Expanded(
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
                            child: Consumer(
                              builder: (context, ref, _) {
                                final tts = ref.watch(ttsProvider);
                                final isSpeakingThisNote = tts.isPlaying && tts.currentText == widget.note.content;
                                final displayData = (isSpeakingThisNote && tts.start != null)
                                    ? _injectHighlight(widget.note.content, tts.start!, tts.end!)
                                    : (widget.note.content.isEmpty ? 'No content yet.' : widget.note.content);

                                return NotificationListener<ScrollNotification>(
                                  onNotification: (notification) {
                                    if (notification is ScrollUpdateNotification) {
                                      if (_isAtBottom && notification.scrollDelta! > 0) {
                                        widget.controller.position.jumpTo(
                                          widget.controller.position.pixels + notification.scrollDelta!,
                                        );
                                      }
                                    } else if (notification is OverscrollNotification) {
                                      if (notification.overscroll > 0) {
                                        widget.controller.position.jumpTo(
                                          widget.controller.position.pixels + notification.overscroll,
                                        );
                                      }
                                    }
                                    return false;
                                  },
                                  child: SingleChildScrollView(
                                    controller: _scrollController,
                                    physics: const ClampingScrollPhysics(),
                                    child: MarkdownBody(
                                      data: displayData,
                                      selectable: true,
                                      onTapText: () {},
                                      builders: {
                                        'highlight': HighlightBuilder(
                                          TextStyle(
                                            backgroundColor: colorScheme.primary.withValues(alpha: 0.2),
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                          AppTypography.bodySmall(
                                            color: Theme.of(context).extension<NodaThemeExtension>()!.textSecondary,
                                          ),
                                          AppTypography.headingSmall(),
                                        ),
                                      },
                                      inlineSyntaxes: [HighlightSyntax()],
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
                                          color: Theme.of(context).extension<NodaThemeExtension>()!.textSecondary,
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
                                              color: colorScheme.primary.withValues(alpha: 0.15),
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TtsActionButton extends ConsumerWidget {
  final String text;
  const _TtsActionButton({required this.text});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tts = ref.watch(ttsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isPlaying = tts.isPlaying && tts.currentText == text;

    return IconButton.filledTonal(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded,
          key: ValueKey(isPlaying),
          size: 20,
        ),
      ),
      onPressed: () {
        if (isPlaying) {
          ref.read(ttsProvider.notifier).stop();
        } else {
          ref.read(ttsProvider.notifier).speak(text);
        }
      },
      style: IconButton.styleFrom(
        backgroundColor: isPlaying ? colorScheme.primary : colorScheme.surfaceContainerHigh,
        foregroundColor: isPlaying ? colorScheme.onPrimary : colorScheme.primary,
      ),
    );
  }
}

String _injectHighlight(String raw, int start, int end) {
  if (start < 0 || end > raw.length || start >= end) return raw;

  // Find the start of the line where the highlight begins
  int lineStart = raw.lastIndexOf('\n', start);
  lineStart = lineStart == -1 ? 0 : lineStart + 1;

  // Check if the line starts with a common markdown block marker
  // Markers: Unordered (*, -, +), Ordered (\d+.), Headers (#+), Blockquote (>)
  final lineMarkerMatch = RegExp(r'^(\s*(\d+\.|[-*+]|#{1,6}|>)\s+)').matchAsPrefix(raw.substring(lineStart));
  
  if (lineMarkerMatch != null) {
    int markerEnd = lineStart + lineMarkerMatch.end;
    // If the highlight begins inside or before the marker, shift it past the marker
    // to prevent flutter_markdown from failing to parse the block type (like a list item).
    if (start < markerEnd) {
      start = markerEnd;
    }
  }

  // If after adjustment the highlight is empty or negative, don't inject.
  if (start >= end) return raw;

  final before = raw.substring(0, start);
  final target = raw.substring(start, end);
  final after = raw.substring(end);
  return '$before<highlight>$target</highlight>$after';
}

class HighlightSyntax extends md.InlineSyntax {
  HighlightSyntax() : super(r'<highlight>(.*?)</highlight>');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('highlight', match[1]!));
    return true;
  }
}

class HighlightBuilder extends MarkdownElementBuilder {
  final TextStyle highlightStyle;
  final TextStyle? baseStyle;
  final TextStyle? headerStyle;

  HighlightBuilder(this.highlightStyle, this.baseStyle, this.headerStyle);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    // Determine the correct style by merging the parser's preferred style with our base/header context.
    // If the parser doesn't provide a size, we fallback to our known header or base styles.
    final bool isHeaderStyle = (preferredStyle?.fontSize ?? 0) > (baseStyle?.fontSize ?? 0);
    final TextStyle effectiveStyle = preferredStyle ?? (isHeaderStyle ? headerStyle : baseStyle) ?? const TextStyle();
    
    return Text.rich(
      TextSpan(
        text: element.textContent,
        style: effectiveStyle.copyWith(
          backgroundColor: highlightStyle.backgroundColor,
          color: highlightStyle.color,
          // Use ultra-bold to ensure it stands out in headers
          fontWeight: FontWeight.w900,
        ),
      ),
      // Ensure the widget doesn't add any extra width or block-level constraints
      // that could break list indentation.
      softWrap: true,
      textAlign: TextAlign.start,
      // StrutStyle is crucial for visual stability. It forces the line height
      // to remain constant regardless of the highlighting, preventing "shaking" in lists.
      strutStyle: StrutStyle(
        fontSize: effectiveStyle.fontSize,
        height: effectiveStyle.height ?? 1.8,
        forceStrutHeight: true,
      ),
    );
  }
}
