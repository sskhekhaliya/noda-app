import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/app_database.dart';
import 'database_provider.dart';

class StudyState {
  final List<Card> allCards;
  final Card? currentCard;
  final bool isFlipped;
  final bool isLoading;
  final String parentTitle;
  final bool isShuffle;
  final String startNodeId;
  final Map<String, String> nodeTitles;

  const StudyState({
    this.allCards = const [],
    this.currentCard,
    this.isFlipped = false,
    this.isLoading = false,
    this.parentTitle = '',
    this.isShuffle = true,
    this.startNodeId = '',
    this.nodeTitles = const {},
  });

  StudyState copyWith({
    List<Card>? allCards,
    Card? currentCard,
    bool? isFlipped,
    bool? isLoading,
    String? parentTitle,
    bool? isShuffle,
    String? startNodeId,
    Map<String, String>? nodeTitles,
    bool clearCurrentCard = false,
  }) {
    return StudyState(
      allCards: allCards ?? this.allCards,
      currentCard: clearCurrentCard ? null : (currentCard ?? this.currentCard),
      isFlipped: isFlipped ?? this.isFlipped,
      isLoading: isLoading ?? this.isLoading,
      parentTitle: parentTitle ?? this.parentTitle,
      isShuffle: isShuffle ?? this.isShuffle,
      startNodeId: startNodeId ?? this.startNodeId,
      nodeTitles: nodeTitles ?? this.nodeTitles,
    );
  }
}

class StudyNotifier extends StateNotifier<StudyState> {
  final AppDatabase _db;

  StudyNotifier(this._db) : super(const StudyState());

  Future<void> startSession(String parentId, String title, {bool isShuffle = true}) async {
    state = state.copyWith(
      isLoading: true, 
      parentTitle: title, 
      isShuffle: isShuffle, 
      startNodeId: parentId,
      allCards: [],
      clearCurrentCard: true,
    );
    
    // Fetch cards and all relevant node titles for context
    final nodes = await _db.getRecursiveDescendants(parentId);
    final rootNode = await _db.getNodeById(parentId);
    final allNodes = rootNode != null ? [rootNode, ...nodes] : nodes;
    final nodeTitles = {for (var n in allNodes) n.id: n.title};

    List<Card> cards;
    if (isShuffle) {
      cards = await _db.getRecursiveCards(parentId);
    } else {
      cards = await _fetchHierarchyOrderedCards(parentId);
    }

    // Filter out cards reviewed today
    final now = DateTime.now();
    cards = cards.where((c) {
      if (c.lastReviewAt == null) return true;
      final last = c.lastReviewAt!;
      return !(last.year == now.year && last.month == now.month && last.day == now.day);
    }).toList();
    
    state = state.copyWith(
      allCards: cards,
      isLoading: false,
      nodeTitles: nodeTitles,
    );
    
    _pickNextCard();
  }

  Future<List<Card>> _fetchHierarchyOrderedCards(String rootId) async {
    // 1. Get all nodes in the hierarchy
    final nodes = await _db.getRecursiveDescendants(rootId);
    final rootNode = await _db.getNodeById(rootId);
    if (rootNode == null) return [];

    final allNodes = [rootNode, ...nodes];
    final nodeMap = <String?, List<Node>>{};
    for (final n in allNodes) {
      nodeMap.putIfAbsent(n.parentId, () => []).add(n);
    }

    // 2. Get all cards in the hierarchy
    final allCards = await _db.getRecursiveCards(rootId);
    final cardMap = <String, List<Card>>{};
    for (final c in allCards) {
      cardMap.putIfAbsent(c.parentId, () => []).add(c);
    }

    final orderedCards = <Card>[];

    void traverse(String nodeId) {
      // Add cards of current node first
      final cards = cardMap[nodeId] ?? [];
      // Sort cards by creation date (within the folder)
      cards.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      orderedCards.addAll(cards);

      // Then recurse into children folders
      final children = nodeMap[nodeId] ?? [];
      children.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      for (final child in children) {
        if (child.type == 'FOLDER') {
          traverse(child.id);
        }
      }
    }

    traverse(rootId);
    return orderedCards;
  }

  Future<List<Card>> _fetchGlobalOrderedCards() async {
    final rootNodes = await _db.watchRootNodes().first;
    final orderedCards = <Card>[];

    for (final root in rootNodes) {
      final cards = await _fetchHierarchyOrderedCards(root.id);
      orderedCards.addAll(cards);
    }
    return orderedCards;
  }

  Future<void> startGlobalSession({bool isShuffle = true}) async {
    state = state.copyWith(
      isLoading: true, 
      parentTitle: 'All Subjects',
      allCards: [],
      clearCurrentCard: true,
      startNodeId: 'GLOBAL',
      isShuffle: isShuffle,
    );
    
    // Fetch all node titles for global context
    final allNodes = await (_db.select(_db.nodes)).get();
    final nodeTitles = {for (var n in allNodes) n.id: n.title};

    List<Card> cards;
    if (isShuffle) {
      cards = await (_db.select(_db.cards)).get();
    } else {
      // For global sequential, we traverse each subject in order
      final rootNodes = await _db.watchRootNodes().first;
      final tempCards = <Card>[];
      for (final root in rootNodes) {
        final subjectCards = await _fetchHierarchyOrderedCards(root.id);
        tempCards.addAll(subjectCards);
      }
      cards = tempCards;
    }

    // Filter out cards reviewed today
    final now = DateTime.now();
    cards = cards.where((c) {
      if (c.lastReviewAt == null) return true;
      final last = c.lastReviewAt!;
      return !(last.year == now.year && last.month == now.month && last.day == now.day);
    }).toList();
    
    state = state.copyWith(
      allCards: cards,
      isLoading: false,
      nodeTitles: nodeTitles,
    );
    
    _pickNextCard();
  }

  void _pickNextCard() {
    if (state.allCards.isEmpty) {
      state = state.copyWith(currentCard: null, isFlipped: false);
      return;
    }

    final random = Random();
    Card selected;
    
    if (!state.isShuffle) {
      selected = state.allCards.first;
    } else {
      // Weighted random + coin flip for mastery (score >= 50)
      final pool = state.allCards;
      
      // Calculate weights
      final now = DateTime.now();
      final weights = pool.map((c) {
        double weight = (c.downvotes + 1.0) / (c.upvotes + 1.0);
        
        // If card is NOT due yet, give it a very low priority (but not 0)
        bool isDue = c.nextReviewAt == null || (c.nextReviewAt?.isBefore(now) ?? true);
        if (!isDue) {
          weight *= 0.05; // 20x less likely to appear than a due card
        }
        
        // Mastery Maintenance: if score 50, even if due, it's low priority
        if (c.score >= 50) {
          weight *= 0.1;
        }

        return weight;
      }).toList();

      final totalWeight = weights.fold(0.0, (sum, w) => sum + w);
      
      if (totalWeight == 0) {
        // All cards are either mastery-skipped or filtered. 
        // Just pick one at random or show mastery
        selected = pool[random.nextInt(pool.length)];
      } else {
        final r = random.nextDouble() * totalWeight;
        double currentSum = 0;
        selected = pool.first;
        for (int i = 0; i < pool.length; i++) {
          currentSum += weights[i];
          if (currentSum >= r) {
            selected = pool[i];
            break;
          }
        }
      }
    }

    state = state.copyWith(
      currentCard: selected,
      isFlipped: false,
    );
  }

  void flip() {
    state = state.copyWith(isFlipped: !state.isFlipped);
  }

  Future<void> vote(bool isUpvote) async {
    final current = state.currentCard;
    if (current == null) return;

    // 1. Update database with SRS logic
    await _db.updateCardSRS(current.id, isUpvote);
    
    // 2. Calculate next pool
    List<Card> nextPool = List.from(state.allCards);
    nextPool.removeWhere((c) => c.id == current.id);

    // In SRS mode, cards are usually removed from session after one vote 
    // to wait for their next scheduled date.
    // However, if it's a downvote, we might want to keep it in the pool 
    // for "cramming" if it's a Sequential session.
    
    if (!isUpvote && !state.isShuffle) {
      // Re-fetch the updated card to get the new state (optional, or just add back)
      nextPool.add(current); // Simple move to end
    }

    // 3. Pick next card
    if (nextPool.isEmpty) {
      state = state.copyWith(
        allCards: [],
        clearCurrentCard: true,
        isFlipped: false,
        isLoading: false,
      );
      return;
    }

    Card nextCard;
    if (!state.isShuffle) {
      nextCard = nextPool.first;
    } else {
      // Weighted random
      final weights = nextPool.map((c) => (c.downvotes + 1.0) / (c.upvotes + 1.0)).toList();
      final totalWeight = weights.fold(0.0, (sum, w) => sum + w);
      final random = Random().nextDouble() * totalWeight;
      double currentSum = 0;
      nextCard = nextPool.first;
      for (int i = 0; i < nextPool.length; i++) {
        currentSum += weights[i];
        if (currentSum >= random) {
          nextCard = nextPool[i];
          break;
        }
      }
    }

    state = state.copyWith(
      allCards: nextPool,
      currentCard: nextCard,
      isFlipped: false,
    );
  }
}

final studyProvider = StateNotifierProvider<StudyNotifier, StudyState>((ref) {
  final db = ref.watch(databaseProvider);
  return StudyNotifier(db);
});


