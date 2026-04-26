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
