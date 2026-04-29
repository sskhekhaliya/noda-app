import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../data/database/app_database.dart';
import 'database_provider.dart';

/// Represents a node in the navigation path (for breadcrumbs).
class NavigationEntry {
  final String id;
  final String title;

  const NavigationEntry({required this.id, required this.title});
}

/// State for the hierarchy navigator.
class NavigationState {
  /// Current parent ID (null = root level showing main subjects).
  final String? currentParentId;

  /// Full navigation path from root to current position.
  final List<NavigationEntry> navigationPath;

  /// Whether the adaptive depth flattening is active.
  bool get shouldFlatten => navigationPath.length > 2;

  /// Current depth in the hierarchy (0 = root).
  int get currentDepth => navigationPath.length;

  const NavigationState({
    this.currentParentId,
    this.navigationPath = const [],
  });

  NavigationState copyWith({
    String? Function()? currentParentId,
    List<NavigationEntry>? navigationPath,
  }) {
    return NavigationState(
      currentParentId: currentParentId != null ? currentParentId() : this.currentParentId,
      navigationPath: navigationPath ?? this.navigationPath,
    );
  }
}

/// Controls navigation through the node hierarchy.
class NavigationNotifier extends StateNotifier<NavigationState> {
  NavigationNotifier() : super(const NavigationState());

  /// Navigate into a folder (push onto path).
  void navigateInto(String nodeId, String title) {
    state = state.copyWith(
      currentParentId: () => nodeId,
      navigationPath: [
        ...state.navigationPath,
        NavigationEntry(id: nodeId, title: title),
      ],
    );
  }

  /// Navigate back one level.
  void navigateUp() {
    if (state.navigationPath.isEmpty) return;

    final newPath = List<NavigationEntry>.from(state.navigationPath)..removeLast();
    state = state.copyWith(
      currentParentId: () => newPath.isEmpty ? null : newPath.last.id,
      navigationPath: newPath,
    );
  }

  /// Navigate to a specific breadcrumb index.
  void navigateToIndex(int index) {
    if (index < 0) {
      // Navigate to root
      state = const NavigationState();
      return;
    }
    if (index >= state.navigationPath.length) return;

    final newPath = state.navigationPath.sublist(0, index + 1);
    state = state.copyWith(
      currentParentId: () => newPath.last.id,
      navigationPath: newPath,
    );
  }

  /// Reset to root level.
  void resetToRoot() {
    state = const NavigationState();
  }
}

final navigationProvider =
    StateNotifierProvider<NavigationNotifier, NavigationState>((ref) {
  return NavigationNotifier();
});

/// Dedicated navigation provider for the Notes tab.
final notesNavigationProvider =
    StateNotifierProvider<NavigationNotifier, NavigationState>((ref) {
  return NavigationNotifier();
});

/// Watches children of the current navigation parent.
final currentChildrenProvider = StreamProvider<List<Node>>((ref) {
  final db = ref.watch(databaseProvider);
  final navState = ref.watch(navigationProvider);

  if (navState.currentParentId == null) {
    return db.watchRootNodes();
  }
  return db.watchChildrenOf(navState.currentParentId!);
});

/// Watches folders and notes (no cards) for the Notes tab navigation.
/// Only keeps folders that contain at least one note.
final notesChildrenProvider = StreamProvider<List<Node>>((ref) {
  final db = ref.watch(databaseProvider);
  final navState = ref.watch(notesNavigationProvider);
  final explorerMode = ref.watch(notesExplorerModeProvider);

  // Explorer mode (File vs Folder) only applies when inside a subject.
  // At the root level, we always show the subject hierarchy regardless of the toggle state.
  if (explorerMode == ExplorerMode.file && navState.currentParentId != null) {
    // Watch all nodes to ensure any structural change triggers a re-flattening.
    return db.select(db.nodes).watch().asyncMap((_) async {
      return _fetchFlattenedNotes(db, navState.currentParentId!);
    });
  } else {
    // Folder Mode or Root level: Direct children with recursive note count check for folders.
    final baseStream = navState.currentParentId == null
        ? db.watchRootNodes()
        : db.watchChildrenOf(navState.currentParentId!);


    return baseStream.asyncMap((nodes) async {
      final filtered = <Node>[];
      for (final node in nodes) {
        if (node.type == 'NOTE') {
          filtered.add(node);
        } else if (node.type == 'FOLDER') {
          final count = await db.countRecursiveNotes(node.id);
          if (count > 0) {
            filtered.add(node);
          }
        }
      }
      return filtered;
    });
  }
});




/// Helper to fetch notes in the specific order: 
/// Direct notes of parent, then recursively notes of each subfolder.
Future<List<Node>> _fetchFlattenedNotes(AppDatabase db, String parentId) async {
  final children = await db.getChildrenOf(parentId);
  final notes = children.where((n) => n.type == 'NOTE').toList();
  final folders = children.where((n) => n.type == 'FOLDER').toList();
  
  List<Node> result = [...notes];
  for (final folder in folders) {
    result.addAll(await _fetchFlattenedNotes(db, folder.id));
  }
  return result;
}


enum ViewMode { list, grid }
enum ExplorerMode { folder, file }

/// Controls the view mode (list/grid) in the Notes tab.
final notesViewModeProvider = StateProvider<ViewMode>((ref) => ViewMode.list);

/// Controls the explorer mode (folder/file) in the Notes tab.
final notesExplorerModeProvider = StateProvider<ExplorerMode>((ref) => ExplorerMode.folder);


