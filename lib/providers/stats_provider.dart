import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_provider.dart';
import '../data/database/app_database.dart';

final statsProvider = FutureProvider<Map<String, String>>((ref) async {
  final db = ref.watch(databaseProvider);
  
  // Get all nodes (subjects/modules)
  final rootNodes = await db.watchRootNodes().first;
  
  // Get all cards
  // Drift doesn't have a simple 'getAllCards' in the provided snippet, 
  // but I can add one or use a custom query.
  final allCards = await (db.select(db.cards)).get();
  
  // Learned: Cards where Upvotes > Downvotes and Upvotes > 0
  final learnedCount = allCards.where((c) => c.upvotes > c.downvotes && c.upvotes > 0).length;
  final learnedPercent = allCards.isEmpty ? 0 : (learnedCount / allCards.length * 100).toInt();

  // Streak: Calculate from updatedAt of cards (as a proxy for review date)
  final studyDates = allCards
      .map((c) => DateTime(c.updatedAt.year, c.updatedAt.month, c.updatedAt.day))
      .toSet()
      .toList()
    ..sort((a, b) => b.compareTo(a));

  int streak = 0;
  if (studyDates.isNotEmpty) {
    DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    DateTime checkDate = today;
    
    if (!studyDates.contains(today)) {
      checkDate = today.subtract(const Duration(days: 1));
    }

    for (int i = 0; i < 365; i++) {
      if (studyDates.contains(checkDate)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
  }

  return {
    'subjects': rootNodes.length.toString(),
    'learned': '$learnedPercent%',
    'streak': '${streak}d',
  };
});
