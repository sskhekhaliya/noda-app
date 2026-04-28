import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/app_database.dart';
import 'database_provider.dart';

/// Provider for root-level subjects (main topics).
final rootNodesProvider = StreamProvider<List<Node>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchRootNodes();
});

/// Provider for children of a specific parent.
final childrenOfProvider =
    StreamProvider.family<List<Node>, String>((ref, parentId) {
  final db = ref.watch(databaseProvider);
  return db.watchChildrenOf(parentId);
});

/// Provider for a single node by ID.
final nodeByIdProvider =
    FutureProvider.family<Node?, String>((ref, nodeId) {
  final db = ref.watch(databaseProvider);
  return db.getNodeById(nodeId);
});

/// Provider for ancestor path (breadcrumbs) of a node.
final ancestorPathProvider =
    FutureProvider.family<List<Node>, String>((ref, nodeId) {
  final db = ref.watch(databaseProvider);
  return db.getAncestorPath(nodeId);
});

/// Provider for recursive note count under a node.
final recursiveNoteCountProvider =
    FutureProvider.family<int, String>((ref, nodeId) {
  final db = ref.watch(databaseProvider);
  return db.countRecursiveNotes(nodeId);
});

/// Provider for universal (orphan) notes.
final universalNotesProvider = StreamProvider<List<Node>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchUniversalNotes();
});

/// Provider for all notes in the system.
final allNotesProvider = StreamProvider<List<Node>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllNotes();
});

/// Search provider.
final searchResultsProvider =
    FutureProvider.family<List<Node>, String>((ref, query) {
  if (query.isEmpty) return Future.value([]);
  final db = ref.watch(databaseProvider);
  return db.searchNodes(query);
});

/// Folder search provider (for hierarchy picker).
final folderSearchProvider =
    FutureProvider.family<List<Node>, String>((ref, query) {
  if (query.isEmpty) return Future.value([]);
  final db = ref.watch(databaseProvider);
  return db.searchFolders(query);
});

/// Home search query state provider.
final homeSearchQueryProvider = StateProvider<String>((ref) => '');

/// Provider that groups all notes by their root subject.
final notesBySubjectProvider = FutureProvider<Map<Node, List<Node>>>((ref) async {
  // Watch root nodes to trigger updates when subjects change
  final rootNodes = ref.watch(rootNodesProvider).valueOrNull ?? [];
  // Watch all notes to trigger updates when any note changes
  final _ = ref.watch(allNotesProvider);
  
  final db = ref.read(databaseProvider);
  final Map<Node, List<Node>> grouped = {};
  
  for (final subject in rootNodes) {
    final notes = await db.getRecursiveChildNotes(subject.id);
    if (notes.isNotEmpty) {
      grouped[subject] = notes;
    }
  }
  
  return grouped;
});

/// Provider for the 10 most recently updated notes.
final recentNotesProvider = Provider<List<Node>>((ref) {
  final allNotes = ref.watch(allNotesProvider).valueOrNull ?? [];
  final sortedNotes = List<Node>.from(allNotes)
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return sortedNotes.take(10).toList();
});

