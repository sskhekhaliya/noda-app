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

/// Full-screen revision feed — scrolls vertically through notes.
class RevisionFeedScreen extends ConsumerStatefulWidget {
  const RevisionFeedScreen({super.key});

  @override
  ConsumerState<RevisionFeedScreen> createState() => _RevisionFeedScreenState();
}

class _RevisionFeedScreenState extends ConsumerState<RevisionFeedScreen> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
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

    return Scaffold(
      body: Stack(
        children: [
          // Note cards feed
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: revision.totalCount,
            onPageChanged: (index) {
              ref.read(revisionProvider.notifier).goToIndex(index);
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
    final noda = theme.extension<NodaThemeExtension>()!;
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
                              (revision.mode == RevisionMode.linear
                                      ? 'Linear Revision'
                                      : 'Deep Shuffle')
                                  .toUpperCase(),
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
                                .getAncestorPath(revision.currentNote!.id),
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
                  // Counter
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '${revision.currentIndex + 1} / ${revision.totalCount}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (revision.mode == RevisionMode.shuffle) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Reshuffle',
                      onPressed: onShuffle,
                    ),
                  ],
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
    final noda = theme.extension<NodaThemeExtension>()!;
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            theme.scaffoldBackgroundColor,
            theme.scaffoldBackgroundColor.withValues(alpha: 0),
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
                                color: colorScheme.primary.withValues(alpha: 0.3),
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
              Text(
                '${(revision.progress * 100).round()}% Immersion',
                style: theme.textTheme.labelSmall?.copyWith(
                      color: noda.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
