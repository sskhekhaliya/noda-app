import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/app_database.dart';
import 'database_provider.dart';

/// Provider for cards of a specific parent.
final cardsOfProvider =
    StreamProvider.family<List<Card>, String>((ref, parentId) {
  final db = ref.watch(databaseProvider);
  return db.watchCardsOf(parentId);
});

/// Provider for recursive card count under a node.
final recursiveCardCountProvider =
    FutureProvider.family<int, String>((ref, nodeId) {
  final db = ref.watch(databaseProvider);
  return db.countRecursiveCards(nodeId);
});

/// Provider for all cards in the database.
final allCardsProvider = StreamProvider<List<Card>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllCards();
});

