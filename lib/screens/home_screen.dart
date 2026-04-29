import 'dart:async'; // For Timer
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'dart:io';

import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';

import '../core/layout/adaptive_breakpoints.dart';
import '../data/database/app_database.dart';
import '../providers/database_provider.dart';
import '../providers/nodes_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/revision_provider.dart';
import '../providers/cards_provider.dart';
import 'hierarchy_screen.dart';
import 'revision_feed_screen.dart';
import 'create_subject_screen.dart';
import '../providers/stats_provider.dart';
import '../services/import_export_service.dart';
import '../widgets/import_conflict_dialog.dart';
import 'study_screen.dart';
import '../providers/study_provider.dart';
import 'notes_library_screen.dart';
import 'settings_screen.dart';
import '../providers/navigation_provider.dart';

/// Main home screen showing root-level subjects.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  int _currentIndex = 0;
  late final AnimationController _fabController;
  late final Animation<double> _fabScale;
  Timer? _debounce;
  StreamSubscription? _intentSubscription;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..forward();
    _fabScale = CurvedAnimation(parent: _fabController, curve: Curves.elasticOut);
    
    _searchController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 200), () {
        if (mounted) {
          ref.read(homeSearchQueryProvider.notifier).state = _searchController.text;
        }
      });
    });

    // Listen to media sharing incoming intents
    _intentSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      if (value != null && value.isNotEmpty) {
        _processIncomingFilePath(value.first.path);
      }
    }, onError: (err) {
      debugPrint("getIntentDataStream error: $err");
    });

    // Get the media sharing coming from outside the app while the app is closed.
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value != null && value.isNotEmpty) {
        // Delay slightly to ensure widget is mounted
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _processIncomingFilePath(value.first.path);
        });
      }
    }).catchError((e) {
      debugPrint("getInitialMedia error: $e");
    });
  }

  @override
  void dispose() {
    _fabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    _intentSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rootNodes = ref.watch(rootNodesProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final noda = theme.extension<NodaThemeExtension>();
    if (noda == null) return const SizedBox.shrink();
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _SideDrawer(
        onImport: _handleImport,
        onImportJson: _showJsonImportDialog,
      ),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.menu_rounded,
            color: colorScheme.primary,
          ),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/Logo.png', width: 28, height: 28),
            const SizedBox(width: 8),
            Text(
              'Noda',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                fontSize: 28.0,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Toggle theme',
            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: colorScheme.onSurfaceVariant),
            onSelected: (value) async {
              final service = ref.read(importExportServiceProvider);
              if (value == 'export_backup') {
                await service.exportFullBackupAsNpack();
              } else if (value == 'import') {
                _handleImport();
              } else if (value == 'import_json') {
                _showJsonImportDialog();
              } else if (value == 'settings') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import',
                child: Text('Import File (.noda / .npack)'),
              ),
              const PopupMenuItem(
                value: 'import_json',
                child: Text('Import JSON Text'),
              ),
              const PopupMenuItem(
                value: 'export_backup',
                child: Text('Export Full Backup (.npack)'),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Text('Settings'),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            _currentIndex == 0
                ? CustomScrollView(
                    slivers: _buildLibrarySlivers(ref),
                  )
                : _currentIndex == 1
                    ? _EmptyTabScreen(title: 'Search')
                    : _currentIndex == 2
                        ? _EmptyTabScreen(title: 'Focus')
                        : const NotesLibraryScreen(),
            // Floating Bottom Navigation Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _BottomNavBar(
                currentIndex: _currentIndex,
                onTap: (index) => setState(() => _currentIndex = index),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: ScaleTransition(
                scale: _fabScale,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: noda.brandGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
                    onPressed: () => _createSubject(context),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
                  ),
                ),
              ),
            )
          : _currentIndex == 3
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 80),
                  child: ScaleTransition(
                    scale: _fabScale,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: noda.brandGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: FloatingActionButton(
                        onPressed: () async {
                          final navState = ref.read(notesNavigationProvider);
                          await ref.read(revisionProvider.notifier).startChronological(
                            navState.currentParentId, 
                            navState.currentParentId == null ? 'Knowledge Base' : (navState.navigationPath.lastOrNull?.title ?? 'Folder')
                          );
                          if (!mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RevisionFeedScreen()),
                          );
                        },
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                      ),
                    ),
                  ),
                )
              : null,
    );
  }

  void _navigateToHierarchy(BuildContext context, Node node) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HierarchyScreen(
          rootNodeId: node.id,
          rootNodeTitle: node.title,
        ),
      ),
    );
  }

  Future<void> _startRevision(
      BuildContext context, Node node, RevisionMode mode) async {
    final notifier = ref.read(revisionProvider.notifier);
    if (mode == RevisionMode.linear) {
      await notifier.startLinear(node.id, node.title);
    } else {
      await notifier.startShuffle(node.id, node.title);
    }

    if (!mounted) return;
    final state = ref.read(revisionProvider);
    if (state.isEmpty) {
      // If no notes, try starting study session instead? 
      // Or just show message.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No notes found in this topic.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RevisionFeedScreen()),
    );
  }

  Future<void> _startStudy(BuildContext context, Node node, {required bool isShuffle}) async {
    final notifier = ref.read(studyProvider.notifier);
    await notifier.startSession(node.id, node.title, isShuffle: isShuffle);
    
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StudyScreen()),
    );
  }

  Future<void> _deleteNode(Node node) async {
    final db = ref.read(databaseProvider);
    await db.deleteNodeRecursive(node.id);
  }

  Future<void> _createSubject(BuildContext context) async {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateSubjectScreen()),
    );
  }

  Future<void> _handleImport() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonStr = await file.readAsString();
        await _processJsonStr(jsonStr);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting file: $e')),
        );
      }
    }
  }

  Future<void> _showJsonImportDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import from JSON'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Paste your Noda JSON content here:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: '{ "subject": { ... } }',
                fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _processJsonStr(result);
    }
  }

  Future<void> _processIncomingFilePath(String path) async {
    try {
      if (!path.endsWith('.noda') && !path.endsWith('.npack')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid file type. Only .noda and .npack are supported.')),
        );
        return;
      }

      final file = File(path);
      final jsonStr = await file.readAsString();
      await _processJsonStr(jsonStr);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing shared file: $e')),
        );
      }
    }
  }

  Future<void> _processJsonStr(String jsonStr) async {
    try {
      final service = ref.read(importExportServiceProvider);
      final analysis = await service.analyzeImport(jsonStr);

      ImportStrategy? strategy;
      if (analysis.subjectExists) {
        strategy = await showDialog<ImportStrategy>(
          context: context,
          builder: (context) => ImportConflictDialog(analysis: analysis),
        );
      } else {
        // If no conflict, we just insert as new
        strategy = ImportStrategy.appendSkip;
      }

      if (strategy == null) return; // User cancelled

      String? newName;
      if (strategy == ImportStrategy.rename) {
        newName = await showDialog<String>(
          context: context,
          builder: (context) {
            final controller = TextEditingController(text: '${analysis.title} (Imported)');
            return AlertDialog(
              title: const Text('Rename Subject'),
              content: TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'New Subject Name'),
                autofocus: true,
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                TextButton(
                  onPressed: () => Navigator.pop(context, controller.text.trim()),
                  child: const Text('Import'),
                ),
              ],
            );
          },
        );
        if (newName == null || newName.isEmpty) return; // Cancelled
      }

      await service.executeImport(jsonStr, strategy, analysis, newName: newName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import successful!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing file: $e')),
        );
      }
    }
  }

  List<Widget> _buildLibrarySlivers(WidgetRef ref) {
    final query = ref.watch(homeSearchQueryProvider);
    final rootNodes = ref.watch(rootNodesProvider);
    final searchResults = ref.watch(searchResultsProvider(query));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isWide = context.isWideScreen;

    return [
      // 1. Stable Header & Search Bar
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(isWide ? 64 : 24, 32, isWide ? 64 : 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Section
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Collection'.toUpperCase(),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Library',
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 48,
                            letterSpacing: -1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Organize your thoughts and subjects into focused study nodes.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 32),
                        const _StudyStats(),
                      ],
                    ),
                  ),
                  if (isWide && (rootNodes.value?.isNotEmpty ?? false))
                    Row(
                      children: [
                        _MasterAction(
                          icon: Icons.school_rounded,
                          label: 'Study All',
                          isGradient: true,
                        onTap: () async {
                          await ref.read(studyProvider.notifier).startGlobalSession(isShuffle: false);
                          if (!mounted) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const StudyScreen()),
                          );
                        },
                        ),
                        const SizedBox(width: 12),
                        _MasterAction(
                          icon: Icons.shuffle_rounded,
                          label: 'Shuffle',
                          isGradient: false,
                          onTap: () async {
                            if (rootNodes.value?.isNotEmpty ?? false) {
                              await ref.read(studyProvider.notifier).startGlobalSession(isShuffle: true);
                              if (!mounted) return;
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const StudyScreen()),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                ],
              ),
              if (!isWide && (rootNodes.value?.isNotEmpty ?? false)) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    _MasterAction(
                      icon: Icons.school_rounded,
                      label: 'Study All',
                      isGradient: true,
                      onTap: () async {
                        await ref.read(studyProvider.notifier).startGlobalSession(isShuffle: false);
                        if (!mounted) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const StudyScreen()),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    _MasterAction(
                      icon: Icons.shuffle_rounded,
                      label: 'Shuffle',
                      isGradient: false,
                      onTap: () async {
                        if (rootNodes.value?.isNotEmpty ?? false) {
                          await ref.read(studyProvider.notifier).startGlobalSession(isShuffle: true);
                          if (!mounted) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const StudyScreen()),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 32),
              // Search Bar (Persistent Controller)
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _searchController,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded, color: colorScheme.outline, size: 24),
                    hintText: 'Search your subjects...',
                    hintStyle: TextStyle(color: colorScheme.outline),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),

      // 2. Dynamic Content Area
      if (query.isNotEmpty)
        searchResults.when(
          data: (nodes) => _buildGridSliver(nodes, isSearch: true),
          loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
          error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
        )
      else
        rootNodes.when(
          data: (nodes) => _buildGridSliver(nodes, isSearch: false),
          loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
          error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
        ),
        
      // Bottom spacing for FAB and Nav
      const SliverToBoxAdapter(child: SizedBox(height: 120)),
    ];
  }

  Widget _buildGridSliver(List<Node> nodes, {required bool isSearch}) {
    final isWide = context.isWideScreen;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isSearch && nodes.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Column(
              children: [
                Icon(Icons.search_off_rounded, size: 64, color: colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  'No results found',
                  style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.outline),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    if (!isSearch && nodes.isEmpty) {
      return SliverToBoxAdapter(child: _EmptyState(onCreateFirst: () => _createSubject(context)));
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 64 : 24),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: isWide ? 420 : 600,
          mainAxisExtent: 240,
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            if (i == nodes.length) {
              return _CreateNewCard(onTap: () => _createSubject(context));
            }
            return _SubjectCard(
              node: nodes[i],
              index: i,
              onTap: () => _navigateToHierarchy(context, nodes[i]),
              onPlay: () => _startStudy(context, nodes[i], isShuffle: false),
              onShuffle: () => _startStudy(context, nodes[i], isShuffle: true),
              onDelete: () => _deleteNode(nodes[i]),
            );
          },
          childCount: nodes.length + 1,
        ),
      ),
    );
  }
}

/// Grid/List of subject cards.
class _SubjectList extends ConsumerWidget {
  const _SubjectList({
    required this.nodes,
    required this.onNodeTap,
    required this.onPlay,
    required this.onShuffle,
    required this.onDelete,
    required this.onCreateFirst,
    this.isSearch = false,
  });

  final List<Node> nodes;
  final ValueChanged<Node> onNodeTap;
  final ValueChanged<Node> onPlay;
  final ValueChanged<Node> onShuffle;
  final ValueChanged<Node> onDelete;
  final VoidCallback onCreateFirst;
  final bool isSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isWide = context.isWideScreen;
    final noda = theme.extension<NodaThemeExtension>();
    if (noda == null) return const SizedBox.shrink();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        isWide ? 64 : 24,
        32,
        isWide ? 64 : 24,
        120, // Space for bottom nav
      ),
      children: [
        // Hero Section
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Collection'.toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Library',
                    style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 48,
                          letterSpacing: -1.2,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Organize your thoughts and subjects into focused study nodes.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            if (isWide && nodes.isNotEmpty)
              Row(
                children: [
                  _MasterAction(
                    icon: Icons.play_arrow_rounded,
                    label: 'Play All',
                    isGradient: true,
                    onTap: () {
                      // Trigger play for all subjects sequentially? 
                      // Or just first one? For now placeholder
                    },
                  ),
                  const SizedBox(width: 12),
                  _MasterAction(
                    icon: Icons.shuffle_rounded,
                    label: 'Shuffle',
                    isGradient: false,
                    onTap: () {},
                  ),
                ],
              ),
          ],
        ),
        if (!isWide && nodes.isNotEmpty) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _MasterAction(
                  icon: Icons.play_arrow_rounded,
                  label: 'Play All',
                  isGradient: true,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MasterAction(
                  icon: Icons.shuffle_rounded,
                  label: 'Shuffle',
                  isGradient: false,
                  onTap: () {},
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 48),

        // Search Bar
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            textAlignVertical: TextAlignVertical.center,
            onChanged: (v) => ref.read(homeSearchQueryProvider.notifier).state = v,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search_rounded, color: colorScheme.outline, size: 24),
              hintText: 'Search your subjects...',
              hintStyle: TextStyle(color: colorScheme.outline),
              filled: true,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 32),

        if (isSearch && nodes.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Column(
                children: [
                  Icon(Icons.search_off_rounded, size: 64, color: colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'No results found',
                    style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.outline),
                  ),
                ],
              ),
            ),
          )
        else if (nodes.isEmpty)
          _EmptyState(onCreateFirst: onCreateFirst)
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: isWide ? 420 : 600,
              mainAxisExtent: 240,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
            ),
            itemCount: nodes.length + 1, // +1 for the "Add New" card
            itemBuilder: (ctx, i) {
              if (i == nodes.length) {
                return _CreateNewCard(onTap: onCreateFirst);
              }
              return _SubjectCard(
                node: nodes[i],
                index: i,
                onTap: () => onNodeTap(nodes[i]),
                onPlay: () => onPlay(nodes[i]),
                onShuffle: () => onShuffle(nodes[i]),
                onDelete: () => onDelete(nodes[i]),
              );
            },
          ),
      ],
    );
  }
}

class _MasterAction extends StatelessWidget {
  const _MasterAction({
    required this.icon,
    required this.label,
    required this.isGradient,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isGradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final noda = Theme.of(context).extension<NodaThemeExtension>();
    if (noda == null) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            gradient: isGradient ? noda.brandGradient : null,
            color: isGradient ? null : colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(100),
            boxShadow: isGradient
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isGradient ? Colors.white : colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: isGradient ? Colors.white : colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateNewCard extends StatelessWidget {
  const _CreateNewCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.3),
            width: 2,
            style: BorderStyle.solid, // Dash effect limited in standard Flutter
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_rounded, color: colorScheme.primary, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              'Create New Subject',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual subject card with gradient accent.
class _SubjectCard extends ConsumerStatefulWidget {
  const _SubjectCard({
    required this.node,
    required this.index,
    required this.onTap,
    required this.onPlay,
    required this.onShuffle,
    required this.onDelete,
  });

  final Node node;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  final VoidCallback onDelete;

  @override
  ConsumerState<_SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends ConsumerState<_SubjectCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slideIn;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideIn = Tween(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fadeIn = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    Future.delayed(Duration(milliseconds: 80 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noda = theme.extension<NodaThemeExtension>();
    if (noda == null) return const SizedBox.shrink();
    final colorScheme = theme.colorScheme;
    final cardCount = ref.watch(recursiveCardCountProvider(widget.node.id));

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _slideIn.value),
        child: Opacity(opacity: _fadeIn.value, child: child),
      ),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: () => _showOptions(context),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(24),
            // No-line rule: depth via color contrast, no borders
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Background Highlight on Hover (simulated for touch)
              Positioned.fill(
                child: Ink(
                  color: colorScheme.primary.withOpacity(0.02),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: (widget.node.colorValue != null
                                    ? Color(widget.node.colorValue!)
                                    : colorScheme.primary)
                                .withOpacity(0.25),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              widget.node.icon ?? '📁',
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(Icons.more_vert_rounded, color: colorScheme.outline),
                          onPressed: () => _showOptions(context),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.node.title,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.node.content?.isNotEmpty ?? false) ...[
                                const SizedBox(height: 6),
                                Text(
                                  widget.node.content!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.style_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                                  const SizedBox(width: 4),
                                  cardCount.when(
                                    data: (c) => Text(
                                      '$c cards',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    loading: () => const Text('...'),
                                    error: (_, __) => const SizedBox.shrink(),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('•', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatTimeAgo(widget.node.updatedAt),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _IconButton(
                              icon: Icons.play_arrow_rounded,
                              color: colorScheme.primary,
                              onTap: widget.onPlay,
                              tooltip: 'Play',
                            ),
                            const SizedBox(height: 8),
                            _IconButton(
                              icon: Icons.shuffle_rounded,
                              color: colorScheme.secondary,
                              onTap: widget.onShuffle,
                              tooltip: 'Shuffle',
                            ),
                          ],
                        ),
                      ],
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

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays >= 365) return 'Updated ${(difference.inDays / 365).floor()}y ago';
    if (difference.inDays >= 30) return 'Updated ${(difference.inDays / 30).floor()}mo ago';
    if (difference.inDays >= 1) return 'Updated ${difference.inDays}d ago';
    if (difference.inHours >= 1) return 'Updated ${difference.inHours}h ago';
    if (difference.inMinutes >= 1) return 'Updated ${difference.inMinutes}m ago';
    return 'Updated Just now';
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Edit Subject'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateSubjectScreen(editingNode: widget.node),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: const Text('Share Subject (.noda)'),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(importExportServiceProvider).exportSubjectAsNoda(widget.node.id, saveToDevice: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('Download to Device'),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(importExportServiceProvider).exportSubjectAsNoda(widget.node.id, saveToDevice: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Colors.red),
              title: const Text('Delete Subject'),
              subtitle: Text('Delete "${widget.node.title}" and all contents'),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeletion(context);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _confirmDeletion(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete "${widget.node.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(100),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}

class _EmptyTabScreen extends StatelessWidget {
  const _EmptyTabScreen({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            title == 'Search'
                ? Icons.search_rounded
                : title == 'Focus'
                    ? Icons.timer_outlined
                    : Icons.settings_outlined,
            size: 64,
            color: colorScheme.primary.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            '$title screen coming soon',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state shown when no subjects exist.
class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.currentIndex, required this.onTap});
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NavBarItem(
              icon: currentIndex == 0 ? Icons.account_tree : Icons.account_tree_outlined,
              label: 'Library',
              isSelected: currentIndex == 0,
              onTap: () => onTap(0),
            ),
            _NavBarItem(
              icon: currentIndex == 1 ? Icons.search_rounded : Icons.search_outlined,
              label: 'Search',
              isSelected: currentIndex == 1,
              onTap: () => onTap(1),
            ),
            _NavBarItem(
              icon: currentIndex == 2 ? Icons.timer : Icons.timer_outlined,
              label: 'Focus',
              isSelected: currentIndex == 2,
              onTap: () => onTap(2),
            ),
            _NavBarItem(
              icon: currentIndex == 3 ? Icons.book : Icons.book_outlined,
              label: 'Notes',
              isSelected: currentIndex == 3,
              onTap: () => onTap(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.primary.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                    color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideDrawer extends ConsumerWidget {
  final VoidCallback onImport;
  final VoidCallback onImportJson;
  const _SideDrawer({
    required this.onImport,
    required this.onImportJson,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Drawer(
      backgroundColor: colorScheme.surface,
      elevation: 0,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: colorScheme.surface),
            child: Row(
              children: [
                Image.asset('assets/Logo.png', width: 40, height: 40),
                const SizedBox(width: 12),
                Text(
                  'Noda',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.2,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.account_tree_outlined),
            title: const Text('Library'),
            selected: true,
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.history_rounded),
            title: const Text('Recent'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.push_pin_outlined),
            title: const Text('Pinned'),
            onTap: () {},
          ),
          const Divider(indent: 24, endIndent: 24),
          ListTile(
            leading: const Icon(Icons.upload_file_rounded),
            title: const Text('Share Full Backup'),
            onTap: () async {
              final service = ref.read(importExportServiceProvider);
              await service.exportFullBackupAsNpack(saveToDevice: false);
            },
          ),
          ListTile(
            leading: const Icon(Icons.download_for_offline_rounded),
            title: const Text('Download Backup'),
            onTap: () async {
              final service = ref.read(importExportServiceProvider);
              await service.exportFullBackupAsNpack(saveToDevice: true);
            },
          ),
          ListTile(
            leading: const Icon(Icons.code_rounded),
            title: const Text('Import JSON Text'),
            onTap: () {
              Navigator.pop(context);
              onImportJson();
            },
          ),
          ListTile(
            leading: const Icon(Icons.download_for_offline_rounded),
            title: const Text('Import File'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              onImport();
            },
          ),
          const Divider(indent: 24, endIndent: 24),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          const Spacer(),
          ListTile(
            leading: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            title: Text(isDark ? 'Light Mode' : 'Dark Mode'),
            onTap: () {
              ref.read(themeProvider.notifier).toggleTheme();
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreateFirst});
  final VoidCallback onCreateFirst;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noda = theme.extension<NodaThemeExtension>();
    if (noda == null) return const SizedBox.shrink();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: noda.brandGradient,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Start building your knowledge tree',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Create your first subject to begin organizing notes and revising with Play and Shuffle modes.',
              style: AppTypography.bodyMedium(color: noda.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onCreateFirst,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create First Subject'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudyStats extends ConsumerWidget {
  const _StudyStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final noda = theme.extension<NodaThemeExtension>();
    if (noda == null) return const SizedBox.shrink();

    return stats.when(
      data: (data) => Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              label: "Subjects",
              value: data["subjects"] ?? "0",
              icon: Icons.folder_open_rounded,
              color: colorScheme.primary,
            ),
            _StatDivider(),
            _StatItem(
              label: "Learned",
              value: data["learned"] ?? "0%",
              icon: Icons.check_circle_outline_rounded,
              color: Colors.green,
            ),
            _StatDivider(),
            _StatItem(
              label: "Streak",
              value: data["streak"] ?? "0d",
              icon: Icons.local_fire_department_rounded,
              color: Colors.orange,
            ),
          ],
        ),
      ),
      loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noda = theme.extension<NodaThemeExtension>();
    if (noda == null) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: noda.textSecondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width: 1,
      color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
    );
  }
}

