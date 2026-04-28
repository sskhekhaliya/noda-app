import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../data/database/app_database.dart';
import '../providers/nodes_provider.dart';
import '../providers/navigation_provider.dart';
import '../widgets/hierarchy/breadcrumb_bar.dart';
import 'reader_screen.dart';
import '../core/utils/preview_utils.dart';

class NotesLibraryScreen extends ConsumerWidget {
  const NotesLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(notesNavigationProvider);
    final navNotifier = ref.read(notesNavigationProvider.notifier);
    final viewMode = ref.watch(notesViewModeProvider);
    final childrenAsync = ref.watch(notesChildrenProvider);
    final recentNotes = ref.watch(recentNotesProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        
        // Recents Section
        if (recentNotes.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'RECENTLY EDITED',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: recentNotes.length,
                itemBuilder: (context, index) {
                  return _RecentNoteCard(note: recentNotes[index]);
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],

        // Explorer Header & Breadcrumbs & View Toggle
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      navState.currentParentId == null ? 'KNOWLEDGE BASE' : 'EXPLORING',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                    ),
                    const Spacer(),
                    _ViewModeToggle(
                      viewMode: viewMode,
                      onChanged: (mode) => ref.read(notesViewModeProvider.notifier).state = mode,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (navState.navigationPath.isNotEmpty)
                  BreadcrumbBar(
                    path: navState.navigationPath.map((e) => (id: e.id, title: e.title)).toList(),
                    onTap: (index) => navNotifier.navigateToIndex(index),
                    focusLabel: null,
                    showHome: true,
                  ),
                if (navState.currentParentId != null)
                   const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        // Main Explorer Content
        childrenAsync.when(
          data: (children) {
            final folders = children.where((n) => n.type == 'FOLDER').toList();
            final notes = children.where((n) => n.type == 'NOTE').toList();

            if (folders.isEmpty && notes.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyFolderState(isRoot: navState.currentParentId == null),
              );
            }

            if (viewMode == ViewMode.grid) {
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.85,
                  ),
                  delegate: SliverChildListDelegate([
                    ...folders.map((f) => _FolderGridTile(
                      folder: f, 
                      onTap: () => navNotifier.navigateInto(f.id, f.title),
                    )),
                    ...notes.asMap().entries.map((entry) => _NoteGridTile(
                      note: entry.value, 
                      index: entry.key,
                      allNotesInView: notes,
                    )),
                  ]),
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (folders.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...folders.map((f) => _FolderTile(
                      folder: f, 
                      onTap: () => navNotifier.navigateInto(f.id, f.title),
                    )),
                    const SizedBox(height: 16),
                  ],
                  if (notes.isNotEmpty) ...[
                    if (folders.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Divider(color: colorScheme.outline.withOpacity(0.05)),
                      ),
                    ...notes.asMap().entries.map((entry) => _FeedCard(
                      note: entry.value, 
                      index: entry.key,
                      allNotesInView: notes,
                    )),
                  ],
                ]),
              ),
            );
          },
          loading: () => const SliverToBoxAdapter(
            child: Center(child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            )),
          ),
          error: (e, _) => SliverToBoxAdapter(
            child: Center(child: Text('Error: $e')),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}

class _ViewModeToggle extends StatelessWidget {
  final ViewMode viewMode;
  final ValueChanged<ViewMode> onChanged;

  const _ViewModeToggle({required this.viewMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleItem(
            icon: Icons.view_list_rounded,
            isSelected: viewMode == ViewMode.list,
            onTap: () => onChanged(ViewMode.list),
          ),
          _ToggleItem(
            icon: Icons.grid_view_rounded,
            isSelected: viewMode == ViewMode.grid,
            onTap: () => onChanged(ViewMode.grid),
          ),
        ],
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleItem({required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant.withOpacity(0.4),
        ),
      ),
    );
  }
}

class _FolderGridTile extends StatelessWidget {
  final Node folder;
  final VoidCallback onTap;

  const _FolderGridTile({required this.folder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final folderColor = folder.colorValue != null ? Color(folder.colorValue!) : colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: folderColor.withOpacity(0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: folderColor.withOpacity(0.1),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: folderColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                folder.icon ?? '📁',
                style: const TextStyle(fontSize: 28),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              folder.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteGridTile extends StatelessWidget {
  final Node note;
  final int index;
  final List<Node> allNotesInView;

  const _NoteGridTile({
    required this.note, 
    required this.index,
    required this.allNotesInView,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReaderScreen(
              notes: allNotesInView,
              initialIndex: index,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.description_rounded, size: 18, color: colorScheme.primary.withOpacity(0.4)),
            const Spacer(),
            Text(
              note.title.isNotEmpty ? note.title : 'Untitled Note',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _extractSnippet(note.content),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                fontSize: 10,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _extractSnippet(String content) {
    return PreviewUtils.stripMarkdown(content);
  }
}

class _FolderTile extends StatelessWidget {
  final Node folder;
  final VoidCallback onTap;

  const _FolderTile({required this.folder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final folderColor = folder.colorValue != null ? Color(folder.colorValue!) : colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.05),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: folderColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  folder.icon ?? '📁',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to view topics',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  final Node note;
  final int index;
  final List<Node> allNotesInView;

  const _FeedCard({
    required this.note, 
    required this.index,
    required this.allNotesInView,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReaderScreen(
                notes: allNotesInView,
                initialIndex: index,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.description_outlined, size: 14, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'NOTE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary.withOpacity(0.5),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTimeAgo(note.updatedAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                note.title.isNotEmpty ? note.title : 'Untitled Note',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _extractSnippet(note.content),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  String _extractSnippet(String content) {
    return PreviewUtils.stripMarkdown(content);
  }
}

class _RecentNoteCard extends StatelessWidget {
  final Node note;
  const _RecentNoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReaderScreen(notes: [note], initialIndex: 0),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.surfaceContainerHigh,
                colorScheme.surfaceContainerLow,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.description_rounded, color: colorScheme.primary, size: 16),
              ),
              const Spacer(),
              Text(
                note.title.isNotEmpty ? note.title : 'Untitled Note',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                _formatTimeAgo(note.updatedAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

class _EmptyFolderState extends StatelessWidget {
  final bool isRoot;
  const _EmptyFolderState({required this.isRoot});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isRoot ? Icons.auto_awesome_motion_rounded : Icons.folder_open_rounded,
            size: 64,
            color: colorScheme.primary.withOpacity(0.1),
          ),
          const SizedBox(height: 24),
          Text(
            isRoot ? 'Your library is empty' : 'Empty folder',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isRoot 
                ? 'Create subjects and notes to build your knowledge base.' 
                : 'There are no notes or sub-modules in this folder.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
