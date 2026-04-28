import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart' hide Node;
import '../widgets/common/noda_markdown.dart';
import 'package:drift/drift.dart' show Value;

import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../core/layout/adaptive_breakpoints.dart';
import '../data/database/app_database.dart';
import '../providers/database_provider.dart';

import '../providers/revision_provider.dart';
import '../widgets/hierarchy/breadcrumb_bar.dart';
import '../widgets/hierarchy/revision_buttons.dart';
import '../providers/selection_provider.dart';
import 'note_editor_screen.dart';
import 'revision_feed_screen.dart';
import 'create_node_screen.dart';
import 'create_card_screen.dart';
import 'study_screen.dart';
import 'reader_screen.dart';
import 'keep_note_screen.dart';
import '../providers/cards_provider.dart';
import '../providers/study_provider.dart';
import '../providers/nodes_provider.dart';
import '../widgets/hierarchy/card_tile.dart';

/// The hierarchy navigation screen — entered from a subject card.
/// Implements Adaptive Depth Flattening at depth > 2.
class HierarchyScreen extends ConsumerStatefulWidget {
  const HierarchyScreen({
    super.key,
    required this.rootNodeId,
    required this.rootNodeTitle,
  });

  final String rootNodeId;
  final String rootNodeTitle;

  @override
  ConsumerState<HierarchyScreen> createState() => _HierarchyScreenState();
}

class _HierarchyScreenState extends ConsumerState<HierarchyScreen> {
  /// Local navigation stack for this subtree.
  final List<_NavEntry> _navStack = [];
  String _currentParentId = '';

  String get _currentTitle =>
      _navStack.isEmpty ? widget.rootNodeTitle : _navStack.last.title;

  int get _currentDepth => _navStack.length;
  bool get _shouldFlatten => _currentDepth > 2;

  @override
  void initState() {
    super.initState();
    _currentParentId = widget.rootNodeId;
  }

  void _navigateInto(String nodeId, String title) {
    setState(() {
      _navStack.add(_NavEntry(id: nodeId, title: title));
      _currentParentId = nodeId;
    });
  }

  void _navigateUp() {
    if (_navStack.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _navStack.removeLast();
      _currentParentId =
          _navStack.isEmpty ? widget.rootNodeId : _navStack.last.id;
    });
  }

  void _navigateToBreadcrumb(int index) {
    if (index < 0) {
      // Go to subject root
      setState(() {
        _navStack.clear();
        _currentParentId = widget.rootNodeId;
      });
      return;
    }
    setState(() {
      final target = _navStack[index];
      _navStack.removeRange(index + 1, _navStack.length);
      _currentParentId = target.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final selection = ref.watch(selectionProvider);
    final isSelectionMode = selection.isNotEmpty;

    final nodesAsync = ref.watch(childrenOfProvider(_currentParentId));
    final nodes = nodesAsync.valueOrNull ?? [];

    return PopScope(
      canPop: _navStack.isEmpty && !isSelectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        if (isSelectionMode) {
          ref.read(selectionProvider.notifier).clear();
        } else {
          _navigateUp();
        }
      },
      child: Scaffold(
        appBar: isSelectionMode ? _buildSelectionAppBar(selection.length) : _buildStandardAppBar(nodes),
        body: Consumer(
          builder: (context, ref, child) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;
            final db = ref.read(databaseProvider);
            final cardsAsync = ref.watch(cardsOfProvider(_currentParentId));

            return cardsAsync.when(
              data: (cards) {
                final folderNodes = nodes.where((n) => n.type == 'FOLDER').toList();
                
                if (folderNodes.isEmpty && cards.isEmpty) {
                  return _EmptyFolder(
                    title: _currentParentId == widget.rootNodeId ? 'Empty Subject' : 'Empty Topic',
                    onCreate: () => _showCreateOptions(context),
                  );
                }

                return CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          if (folderNodes.isNotEmpty) ...[
                            ...folderNodes.map((node) => 
                              _FolderTile(
                                node: node,
                                onTap: () => _navigateInto(node.id, node.title),
                                onLongPress: () => _showNodeActions(context, node),
                              ),
                            ),
                          ],
                          if (cards.isNotEmpty) ...[
                            ...cards.map((card) => 
                              CardTile(
                                card: card,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => CreateCardScreen(
                                    parentId: _currentParentId,
                                    cardId: card.id,
                                    initialFront: card.front,
                                    initialBack: card.back,
                                  )),
                                ),
                              ),
                            ),
                            const SizedBox(height: 100), // Space for FAB
                          ],
                        ]),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading cards: $e')),
            );
          },
        ),
        floatingActionButton: isSelectionMode ? null : Consumer(
          builder: (context, ref, child) {
            return FloatingActionButton.extended(
              onPressed: () {
                final nodes = ref.read(childrenOfProvider(_currentParentId)).valueOrNull ?? [];
                _showCreateOptions(context);
              },
              label: Text('NEW', style: AppTypography.buttonText()),
              icon: const Icon(Icons.add),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildStandardAppBar(List<Node> currentNodes) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final notes = currentNodes.where((n) => n.type == 'NOTE').toList();
    final hasNotes = notes.isNotEmpty;

    return AppBar(
      toolbarHeight: 90,
      leading: const SizedBox.shrink(),
      leadingWidth: 0,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.arrow_back, size: 24),
                  onPressed: _navigateUp,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentTitle,
                    style: AppTypography.headingMedium(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasNotes)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 22,
                    icon: Icon(Icons.book_rounded, color: colorScheme.primary),
                    tooltip: 'Topic Library',
                    onPressed: () => _showTopicLibrary(context, notes),
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 22,
                  icon: Icon(Icons.play_arrow_rounded, color: colorScheme.primary),
                  tooltip: 'Study (Linear)',
                  onPressed: () => _startStudy(isShuffle: false),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 22,
                  icon: Icon(Icons.shuffle_rounded, color: colorScheme.primary),
                  tooltip: 'Shuffle Play',
                  onPressed: () => _startStudy(isShuffle: true),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'reset') _handleBulkDeleteAll();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'reset',
                      child: Text('Reset Subject (Delete All)'),
                    ),
                  ],
                ),
              ],
            ),
            Transform.translate(
              offset: const Offset(12, -4),
              child: BreadcrumbBar(
                path: [
                  (id: widget.rootNodeId, title: widget.rootNodeTitle),
                  ..._navStack.map((e) => (id: e.id, title: e.title)),
                ],
                focusLabel: _shouldFlatten ? _currentTitle : null,
                onTap: (index) {
                  if (index == -1) {
                    _navigateToBreadcrumb(-1);
                  } else {
                    _navigateToBreadcrumb(index - 1);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(int count) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: colorScheme.primaryContainer.withOpacity(0.1),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => ref.read(selectionProvider.notifier).clear(),
      ),
      title: Text('$count selected', style: AppTypography.headingSmall()),
      actions: [
        IconButton(
          icon: Icon(Icons.delete_outline, color: colorScheme.error),
          onPressed: _handleBulkDelete,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Future<void> _handleBulkDelete() async {
    final selection = ref.read(selectionProvider);
    if (selection.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Items?'),
        content: Text('This will permanently delete ${selection.length} items and all their nested content.'),
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

    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      for (final id in selection) {
        await db.deleteNodeRecursive(id);
      }
      ref.read(selectionProvider.notifier).clear();
    }
  } 

  Future<void> _handleBulkDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Subject?'),
        content: const Text('This will permanently delete ALL content inside this subject. This action cannot be undone.'),
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
            child: const Text('RESET ALL'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      final children = await db.getChildrenOf(_currentParentId);
      for (final node in children) {
        await db.deleteNodeRecursive(node.id);
      }
      // Also delete cards for the current parent
      final cards = await db.getCardsOf(_currentParentId);
      for (final card in cards) {
        await db.deleteCard(card.id);
      }
    }
  }

  Future<void> _startRevision(Node? node, RevisionMode mode) async {
    final notifier = ref.read(revisionProvider.notifier);
    final id = node?.id ?? _currentParentId;
    final title = node?.title ?? _currentTitle;

    if (mode == RevisionMode.linear) {
      await notifier.startLinear(id, title);
    } else {
      await notifier.startShuffle(id, title);
    }

    if (!mounted) return;
    final state = ref.read(revisionProvider);
    if (state.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No notes found in this topic.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RevisionFeedScreen()),
    );
  }

  Future<void> _startStudy({bool isShuffle = true}) async {
    final notifier = ref.read(studyProvider.notifier);
    await notifier.startSession(_currentParentId, _currentTitle, isShuffle: isShuffle);
    
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StudyScreen()),
    );
  }

  void _showNodeActions(BuildContext context, Node node) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                if (node.type == 'FOLDER') {
                  _showFolderDialog(context, initialTitle: node.title, nodeId: node.id);
                } else {
                  // Rename for note? usually notes don't have titles in this style
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete?'),
                    content: const Text('This will permanently remove this item and all its contents.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE')),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(databaseProvider).deleteNodeRecursive(node.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('ADD TO ${_currentTitle.toUpperCase()}', style: AppTypography.caption(color: Theme.of(context).colorScheme.primary)),
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Folder'),
              subtitle: const Text('Organize your chapters and topics'),
              onTap: () {
                Navigator.pop(context);
                _showFolderDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.style_outlined),
              title: const Text('Card'),
              subtitle: const Text('Create flashcards for active recall'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CreateCardScreen(parentId: _currentParentId)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.book_outlined),
              title: const Text('Note'),
              subtitle: const Text('Write long-form thoughts or summaries'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => KeepNoteScreen(parentId: _currentParentId)),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showFolderDialog(BuildContext context, {String? initialTitle, String? nodeId}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = TextEditingController(text: initialTitle);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nodeId == null ? 'NEW TOPIC' : 'RENAME TOPIC',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'e.g. Molecular Biology',
                        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.4)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      ),
                      onSubmitted: (_) => _handleFolderSubmit(context, controller.text, nodeId),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                        child: Text(
                          'CANCEL',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => _handleFolderSubmit(context, controller.text, nodeId),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        ),
                        child: Text(
                          nodeId == null ? 'CREATE' : 'SAVE',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleFolderSubmit(BuildContext context, String title, String? nodeId) async {
    if (title.trim().isEmpty) return;
    
    final db = ref.read(databaseProvider);
    
    // Uniqueness check
    final exists = await db.doesFolderExistInParent(_currentParentId, title.trim(), excludeId: nodeId);
    if (exists) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A topic with this name already exists here.')),
        );
      }
      return;
    }

    if (nodeId == null) {
      await db.insertNode(
        NodesCompanion.insert(
          id: const Uuid().v4(),
          type: 'FOLDER',
          title: title.trim(),
          parentId: Value(_currentParentId),
          createdAt: Value(DateTime.now()),
        ),
      );
    } else {
      await db.updateNode(
        nodeId,
        NodesCompanion(title: Value(title.trim())),
      );
    }
    if (context.mounted) Navigator.pop(context);
  }

  void _showTopicLibrary(BuildContext context, List<Node> notes) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final noda = theme.extension<NodaThemeExtension>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outline.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LEARNING MATERIAL',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Topic Library',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReaderScreen(notes: notes, initialIndex: 0),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: noda?.brandGradient,
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 4),
                          Text(
                            'READ ALL',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: notes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final note = notes[index];
                  final snippet = _extractSnippet(note.content);
                  
                  return InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReaderScreen(notes: notes, initialIndex: index),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.description_outlined,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  note.title.isNotEmpty ? note.title : 'Note ${index + 1}',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  snippet,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: colorScheme.outline.withValues(alpha: 0.3),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _extractSnippet(String content) {
    if (content.startsWith('[{"insert":')) {
      try {
        final List<dynamic> json = jsonDecode(content);
        final plainText = json.map((part) => part['insert'] ?? '').join().trim();
        return plainText.length > 100 ? '${plainText.substring(0, 100)}...' : plainText;
      } catch (_) {}
    }
    return content.length > 100 ? '${content.substring(0, 100)}...' : content;
  }
}

class _NavEntry {
  final String id;
  final String title;
  const _NavEntry({required this.id, required this.title});
}

class _EmptyFolder extends StatelessWidget {
  final String title;
  final VoidCallback onCreate;
  const _EmptyFolder({required this.title, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 64,
                color: colorScheme.primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Structure your knowledge with modules, \nrich notes, and revision cards.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 48),
            GestureDetector(
              onTap: onCreate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  gradient: theme.extension<NodaThemeExtension>()?.brandGradient,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'GET STARTED',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _FolderTile extends StatelessWidget {
  final Node node;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FolderTile({
    required this.node,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final noda = theme.extension<NodaThemeExtension>(); if (noda == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withOpacity(0.08)),
      ),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.folder_outlined, color: colorScheme.onSurfaceVariant, size: 22),
        ),
        title: Text(
          node.title,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: noda.iconInactive),
      ),
    );
  }
}

class _ModuleNotePreview extends StatelessWidget {
  final Node note;
  
  const _ModuleNotePreview({required this.note});

  String _extractPlainText(String? content) {
    if (content != null && content.startsWith('[{"insert":')) {
      try {
        final List<dynamic> json = jsonDecode(content);
        return json.map((part) => part['insert'] ?? '').join().trim();
      } catch (_) {}
    }
    return content ?? "";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReaderScreen(notes: [note]),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        width: double.infinity,
        child: Stack(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black,
                      Colors.black.withOpacity(0.1),
                      Colors.transparent,
                    ],
                    stops: const [0.6, 0.9, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: IgnorePointer(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: NodaMarkdown(
                        data: _extractPlainText(note.content),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'See more',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
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




