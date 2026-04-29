import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../data/database/app_database.dart';
import '../providers/database_provider.dart';
import '../providers/revision_provider.dart';
import '../widgets/revision/note_card.dart';
import '../widgets/revision/long_press_menu.dart';
import '../providers/settings_provider.dart';
import '../providers/tts_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/nodes_provider.dart';
import 'keep_note_screen.dart';


/// Full-screen revision feed — scrolls horizontally through notes.
class RevisionFeedScreen extends ConsumerStatefulWidget {
  const RevisionFeedScreen({super.key});

  @override
  ConsumerState<RevisionFeedScreen> createState() => _RevisionFeedScreenState();
}class _RevisionFeedScreenState extends ConsumerState<RevisionFeedScreen> {
  late final PageController _pageController;
  bool _hasSpokenInitial = false;
  bool _isPopping = false;

  @override
  void initState() {
    super.initState();
    final revision = ref.read(revisionProvider);
    _pageController = PageController(initialPage: revision.currentIndex);
    
    // Initial speech for the first note
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsProvider);
      final revision = ref.read(revisionProvider);
      if (settings.autoplayTts && revision.notes.isNotEmpty && !_hasSpokenInitial) {
        _hasSpokenInitial = true;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_isPopping && ref.read(settingsProvider).autoplayTts) {
            final revision = ref.read(revisionProvider);
            if (revision.currentIndex < revision.notes.length) {
              final currentNote = revision.notes[revision.currentIndex];
              ref.read(ttsProvider.notifier).speak(currentNote.content);
            }
          }
        });

      }
    });
  }

  @override
  void deactivate() {
    _isPopping = true;
    ref.read(ttsProvider.notifier).stop();
    super.deactivate();
  }

  @override
  void dispose() {
    _isPopping = true;
    _pageController.dispose();
    ref.read(ttsProvider.notifier).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final revision = ref.watch(revisionProvider);

    if (revision.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Revision')),
        body: const Center(child: Text('No notes to display.')),
      );
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        // Stop TTS immediately on any pop attempt (system back or cross button)
        _isPopping = true;
        ref.read(ttsProvider.notifier).stop();
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Note cards feed
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: revision.totalCount,
              onPageChanged: (index) {
                if (_isPopping) return;
                ref.read(revisionProvider.notifier).goToIndex(index);
                final settings = ref.read(settingsProvider);
                if (settings.autoplayTts) {
                  final note = revision.notes[index];
                  ref.read(ttsProvider.notifier).speak(note.content);
                }
              },
              itemBuilder: (context, index) {
                final note = revision.notes[index];
                return NoteCard(
                  note: note,
                  controller: _pageController,
                  onLongPress: (selectedText) {
                    LongPressMenu.show(
                      context: context,
                      ref: ref,
                      note: note,
                      selectedText: selectedText,
                    );
                  },
                );
              },
            ),

            // Top overlay: breadcrumb + progress
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _TopOverlay(
                revision: revision,
                onBack: () => Navigator.pop(context),
                onShuffle: () {
                  ref.read(revisionProvider.notifier).reshuffle();
                  _pageController.jumpToPage(0);
                },
              ),
            ),

            // Bottom progress bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _BottomProgressBar(revision: revision),
            ),
          ],
        ),
      ),
    );
  }
}

/// Top overlay with status bar safe area, breadcrumb trail, and controls.
class _TopOverlay extends ConsumerWidget {
  const _TopOverlay({
    required this.revision,
    required this.onBack,
    required this.onShuffle,
  });

  final RevisionState revision;
  final VoidCallback onBack;
  final VoidCallback onShuffle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final noda = theme.extension<NodaThemeExtension>(); if (noda == null) return const SizedBox.shrink();
    final colorScheme = theme.colorScheme;
    final db = ref.watch(databaseProvider);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: noda.glassBlur, sigmaY: noda.glassBlur),
        child: Container(
          decoration: BoxDecoration(
            color: noda.glassBackground,
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: colorScheme.onSurface,
                    ),
                    onPressed: onBack,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Mode indicator
                        Row(
                          children: [
                            Icon(
                              revision.mode == RevisionMode.linear
                                  ? Icons.play_circle_filled_rounded
                                  : Icons.shuffle_on_rounded,
                              size: 14,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'NOTES',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Breadcrumb for current note
                        if (revision.currentNote != null)
                          FutureBuilder<List<Node>>(
                            future: db
                                .getAncestorPath((revision.currentNote?.id ?? "")),
                            builder: (context, snap) {
                              if (!snap.hasData) return const SizedBox.shrink();
                              final path = snap.data!;
                              return Text(
                                path.map((n) => n.title).join(' › '),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: noda.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  if (revision.mode == RevisionMode.shuffle) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: colorScheme.onSurface,
                      ),
                      tooltip: 'Reshuffle',
                      onPressed: onShuffle,
                    ),
                  ],
                  const SizedBox(width: 4),
                  Consumer(
                    builder: (context, ref, _) {
                      final settings = ref.watch(settingsProvider);
                      return IconButton(
                        icon: Icon(
                          settings.autoplayTts ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                          color: settings.autoplayTts ? colorScheme.primary : colorScheme.onSurface,
                        ),
                        onPressed: () {
                          if (!settings.autoplayTts && revision.currentNote != null) {
                            ref.read(settingsProvider.notifier).setAutoplayTts(true);
                            ref.read(ttsProvider.notifier).speak(revision.currentNote!.content, resume: true);
                          } else {
                            ref.read(settingsProvider.notifier).setAutoplayTts(false);
                            ref.read(ttsProvider.notifier).stop();
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      Icons.replay_rounded,
                      color: colorScheme.onSurface,
                    ),
                    tooltip: 'Restart from beginning',
                    onPressed: () {
                      if (revision.currentNote != null) {
                        ref.read(settingsProvider.notifier).setAutoplayTts(true);
                        ref.read(ttsProvider.notifier).speak(revision.currentNote!.content, resume: false);
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      Icons.edit_rounded,
                      color: colorScheme.onSurface,
                    ),
                    tooltip: 'Edit Note',
                    onPressed: () async {
                      final currentNote = revision.currentNote;
                      if (currentNote == null) return;
                      
                      // Stop TTS when editing
                      ref.read(ttsProvider.notifier).stop();
                      
                      final result = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => KeepNoteScreen(
                            parentId: currentNote.parentId ?? '',
                            nodeId: currentNote.id,
                            initialContent: currentNote.content,
                          ),
                        ),
                      );
                      
                      if (result != null) {
                        ref.read(revisionProvider.notifier).updateNoteContent(currentNote.id, result);
                        // Invalidate providers to force a refresh of the library and recents
                        ref.invalidate(notesChildrenProvider);
                        ref.invalidate(recentNotesProvider);
                        ref.invalidate(allNotesProvider);
                      }

                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom progress indicator.
class _BottomProgressBar extends StatelessWidget {
  const _BottomProgressBar({required this.revision});
  final RevisionState revision;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noda = theme.extension<NodaThemeExtension>(); if (noda == null) return const SizedBox.shrink();
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            theme.scaffoldBackgroundColor,
            theme.scaffoldBackgroundColor.withOpacity(0),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: SizedBox(
                  height: 6,
                  child: Stack(
                    children: [
                      Container(color: colorScheme.surfaceContainerHigh),
                      FractionallySizedBox(
                        widthFactor: revision.progress.clamp(0.01, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: noda.brandGradient,
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 0),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${(revision.progress * 100).round()}% Immersion',
                    style: theme.textTheme.labelSmall?.copyWith(
                          color: noda.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '${revision.currentIndex + 1} / ${revision.totalCount}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: noda.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
