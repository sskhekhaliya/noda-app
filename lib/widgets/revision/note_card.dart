import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown/markdown.dart' as md;
import 'dart:io';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../data/database/app_database.dart';
import '../../providers/tts_provider.dart';
import '../../providers/database_provider.dart';
import '../common/noda_markdown.dart';

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
    final noda = Theme.of(context).extension<NodaThemeExtension>();
    if (noda == null) return const SizedBox.shrink();
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
                color: colorScheme.onSurface.withOpacity(0.04),
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
                    color: colorScheme.primary.withOpacity(0.05),
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
                            widget.note.title.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: colorScheme.primary,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        _TtsActionButton(text: (widget.note.content ?? "")),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: colorScheme.primary.withOpacity(0.1)),
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
                            child: NotificationListener<ScrollNotification>(
                              onNotification: (notification) {
                                if (notification is ScrollUpdateNotification) {
                                  if (_isAtBottom && (notification.scrollDelta ?? 0) > 0) {
                                    widget.controller.position.jumpTo(
                                      widget.controller.position.pixels + (notification.scrollDelta ?? 0),
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
                                child: NodaMarkdown(
                                  data: (widget.note.content?.isEmpty ?? true) ? 'No content yet.' : (widget.note.content ?? ""),
                                  selectable: true,
                                  padding: const EdgeInsets.only(bottom: 40),
                                ),
                              ),
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
          ref.read(ttsProvider.notifier).speak(text, resume: true);
        }
      },
      style: IconButton.styleFrom(
        backgroundColor: isPlaying ? colorScheme.primary : colorScheme.surfaceContainerHigh,
        foregroundColor: isPlaying ? colorScheme.onPrimary : colorScheme.primary,
      ),
    );
  }
}
