import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_provider.dart';
import 'nodes_provider.dart';
import 'cards_provider.dart';

/// Combined stats provider that updates in real-time.
final statsProvider = Provider<AsyncValue<Map<String, String>>>((ref) {
  final nodesAsync = ref.watch(rootNodesProvider);
  final cardsAsync = ref.watch(allCardsProvider);

  return nodesAsync.when(
    data: (nodes) => cardsAsync.when(
      data: (cards) {
        // 1. Learned: Cards where Upvotes > Downvotes and Upvotes > 0
        final learnedCount = cards.where((c) => c.upvotes > c.downvotes && c.upvotes > 0).length;
        final learnedPercent = cards.isEmpty ? 0 : (learnedCount / cards.length * 100).toInt();

        // 2. Streak: Calculate from updatedAt of cards
        final studyDates = cards
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

        return AsyncData({
          'subjects': nodes.length.toString(),
          'learned': '$learnedPercent%',
          'streak': '${streak}d',
        });
      },
      loading: () => const AsyncLoading(),
      error: (e, s) => AsyncError(e, s),
    ),
    loading: () => const AsyncLoading(),
    error: (e, s) => AsyncError(e, s),
  );
});
