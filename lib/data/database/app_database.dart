import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

/// Single self-referencing table for the entire node hierarchy.
class Nodes extends Table {
  TextColumn get id => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get type => text()(); // 'FOLDER' or 'NOTE'
  TextColumn get title => text()();
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get icon => text().nullable()();
  IntColumn get colorValue => integer().nullable()();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Cards extends Table {
  TextColumn get id => text()();
  TextColumn get parentId => text().references(Nodes, #id)();
  TextColumn get front => text()();
  TextColumn get back => text()();
  IntColumn get upvotes => integer().withDefault(const Constant(0))();
  IntColumn get downvotes => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get score => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastReviewAt => dateTime().nullable()();
  DateTimeColumn get nextReviewAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}


@DriftDatabase(tables: [Nodes, Cards])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(nodes, nodes.icon);
            await m.addColumn(nodes, nodes.colorValue);
          }
          if (from < 3) {
            await m.createTable(cards);
          }
          if (from < 4) {
            await m.addColumn(cards, cards.score);
            await m.addColumn(cards, cards.lastReviewAt);
            await m.addColumn(cards, cards.nextReviewAt);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  // ──────────────────────────────────────────
  // Root-level queries
  // ──────────────────────────────────────────

  /// Watch all root-level nodes (Main Subjects) ordered by orderIndex.
  Stream<List<Node>> watchRootNodes() {
    return (select(nodes)
          ..where((n) => n.parentId.isNull())
          ..orderBy([(n) => OrderingTerm.asc(n.orderIndex)]))
        .watch();
  }

  /// Watch direct children of a given parent, ordered by orderIndex.
  Stream<List<Node>> watchChildrenOf(String parentId) {
    return (select(nodes)
          ..where((n) => n.parentId.equals(parentId))
          ..orderBy([(n) => OrderingTerm.asc(n.createdAt)]))
        .watch();
  }

  /// Get direct children synchronously.
  Future<List<Node>> getChildrenOf(String parentId) {
    return (select(nodes)
          ..where((n) => n.parentId.equals(parentId))
          ..orderBy([(n) => OrderingTerm.asc(n.createdAt)]))
        .get();
  }

  /// Get a single node by ID.
  Future<Node?> getNodeById(String nodeId) {
    return (select(nodes)..where((n) => n.id.equals(nodeId)))
        .getSingleOrNull();
  }

  /// Get a single node by title (case-insensitive).
  Future<Node?> getNodeByTitle(String title) {
    return (select(nodes)..where((n) => n.title.lower().equals(title.toLowerCase())))
        .getSingleOrNull();
  }

  /// Watch a single node.
  Stream<Node?> watchNodeById(String nodeId) {
    return (select(nodes)..where((n) => n.id.equals(nodeId)))
        .watchSingleOrNull();
  }

  // ──────────────────────────────────────────
  // Card-specific queries
  // ──────────────────────────────────────────

  /// Watch all cards for a specific parent.
  Stream<List<Card>> watchCardsOf(String parentId) {
    return (select(cards)
          ..where((c) => c.parentId.equals(parentId))
          ..orderBy([(c) => OrderingTerm.asc(c.createdAt)]))
        .watch();
  }

  /// Get all cards for a specific parent.
  Future<List<Card>> getCardsOf(String parentId) {
    return (select(cards)
          ..where((c) => c.parentId.equals(parentId))
          ..orderBy([(c) => OrderingTerm.asc(c.createdAt)]))
        .get();
  }

  /// Alias for getCardsOf used in import/export logic.
  Future<List<Card>> getCardsForFolder(String parentId) => getCardsOf(parentId);

  /// Get all cards recursively under a node (using CTE).
  Future<List<Card>> getRecursiveCards(String startNodeId) async {
    final result = await customSelect(
      '''
      WITH RECURSIVE descendants AS (
        SELECT id FROM nodes WHERE id = ?
        UNION ALL
        SELECT n.id FROM nodes n
        INNER JOIN descendants d ON n.parent_id = d.id
      )
      SELECT c.* FROM cards c
      WHERE c.parent_id IN (SELECT id FROM descendants)
      ORDER BY c.created_at DESC
      ''',
      variables: [
        Variable.withString(startNodeId),
      ],
      readsFrom: {nodes, cards},
    ).get();

    return result.map((row) {
      return Card(
        id: row.read<String>('id'),
        parentId: row.read<String>('parent_id'),
        front: row.read<String>('front'),
        back: row.read<String>('back'),
        upvotes: row.read<int>('upvotes'),
        downvotes: row.read<int>('downvotes'),
        createdAt: row.read<DateTime>('created_at'),
        updatedAt: row.read<DateTime>('updated_at'),
        score: row.read<int>('score'),
        lastReviewAt: row.readNullable<DateTime>('last_review_at'),
        nextReviewAt: row.readNullable<DateTime>('next_review_at'),
      );
    }).toList();
  }

  /// Insert a new card.
  Future<void> insertCard(CardsCompanion card) {
    return into(cards).insert(card);
  }

  /// Update an existing card.
  Future<void> updateCard(String cardId, CardsCompanion companion) {
    return (update(cards)..where((c) => c.id.equals(cardId)))
        .write(companion);
  }

  /// Delete a card.
  Future<void> deleteCard(String cardId) {
    return (delete(cards)..where((c) => c.id.equals(cardId))).go();
  }

  /// Vote on a card.
  Future<void> voteCard(String cardId, {required bool isUpvote}) async {
    final card = await (select(cards)..where((c) => c.id.equals(cardId))).getSingle();
    await (update(cards)..where((c) => c.id.equals(cardId))).write(
      CardsCompanion(
        upvotes: Value(isUpvote ? card.upvotes + 1 : card.upvotes),
        downvotes: Value(isUpvote ? card.downvotes : card.downvotes + 1),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateCardSRS(String id, bool isUpvote) async {
    final card = await (select(cards)..where((c) => c.id.equals(id))).getSingle();
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Once-per-day logic
    bool wasReviewedToday = card.lastReviewAt != null && 
        card.lastReviewAt?.year == now.year &&
        card.lastReviewAt?.month == now.month &&
        card.lastReviewAt?.day == now.day;

    int newScore = card.score;
    if (!wasReviewedToday) {
      newScore = isUpvote ? card.score + 1 : card.score - 1;
      // Cap at 50 as requested
      if (newScore > 50) newScore = 50;
    }

    // Calculate next review based on user's 1+2+3 logic
    DateTime nextReview;
    if (newScore < 10) {
      nextReview = today.add(const Duration(days: 1));
    } else if (newScore < 20) {
      nextReview = today.add(const Duration(days: 3)); // 1+2
    } else if (newScore < 30) {
      nextReview = today.add(const Duration(days: 6)); // 1+2+3
    } else if (newScore < 40) {
      nextReview = today.add(const Duration(days: 10)); // 1+2+3+4
    } else if (newScore < 50) {
      nextReview = today.add(const Duration(days: 15)); // 1+2+3+4+5
    } else {
      // Mastery (50): Set to 30 days but deck logic can randomly pick it
      nextReview = today.add(const Duration(days: 30));
    }

    await (update(cards)..where((c) => c.id.equals(id))).write(
      CardsCompanion(
        score: Value(newScore),
        lastReviewAt: Value(now),
        nextReviewAt: Value(nextReview),
        upvotes: Value(isUpvote ? card.upvotes + 1 : card.upvotes),
        downvotes: Value(!isUpvote ? card.downvotes + 1 : card.downvotes),
        updatedAt: Value(now),
      ),
    );
  }

  // ──────────────────────────────────────────
  // Recursive queries (CTE-based DFS)
  // ──────────────────────────────────────────

  /// Get all descendant notes under a given start node using recursive CTE.
  /// Returns notes in hierarchical (DFS) order for Linear Play.
  Future<List<Node>> getRecursiveChildNotes(String startNodeId) async {
    final result = await customSelect(
      '''
      WITH RECURSIVE descendants AS (
        SELECT * FROM nodes WHERE parent_id = ?
        UNION ALL
        SELECT n.* FROM nodes n
        INNER JOIN descendants d ON n.parent_id = d.id
      )
      SELECT * FROM descendants WHERE type = 'NOTE'
      ORDER BY order_index ASC
      ''',
      variables: [Variable.withString(startNodeId)],
      readsFrom: {nodes},
    ).get();

    return result.map((row) {
      return Node(
        id: row.read<String>('id'),
        parentId: row.readNullable<String>('parent_id'),
        type: row.read<String>('type'),
        title: row.read<String>('title'),
        content: row.read<String>('content'),
        icon: row.readNullable<String>('icon'),
        colorValue: row.readNullable<int>('color_value'),
        orderIndex: row.read<int>('order_index'),
        createdAt: row.read<DateTime>('created_at'),
        updatedAt: row.read<DateTime>('updated_at'),
      );
    }).toList();
  }

  /// Get all descendant notes under a given start node, ordered by createdAt.
  /// If [startNodeId] is null, returns all notes in the database.
  Future<List<Node>> getAllNotesRecursiveChronological(String? startNodeId) async {
    if (startNodeId == null) {
      return (select(nodes)
            ..where((n) => n.type.equals('NOTE'))
            ..orderBy([(n) => OrderingTerm.asc(n.createdAt)]))
          .get();
    }

    final result = await customSelect(
      '''
      WITH RECURSIVE descendants AS (
        SELECT * FROM nodes WHERE parent_id = ?
        UNION ALL
        SELECT n.* FROM nodes n
        INNER JOIN descendants d ON n.parent_id = d.id
      )
      SELECT * FROM descendants WHERE type = 'NOTE'
      ORDER BY created_at ASC
      ''',
      variables: [Variable.withString(startNodeId)],
      readsFrom: {nodes},
    ).get();

    return result.map((row) {
      return Node(
        id: row.read<String>('id'),
        parentId: row.readNullable<String>('parent_id'),
        type: row.read<String>('type'),
        title: row.read<String>('title'),
        content: row.read<String>('content'),
        icon: row.readNullable<String>('icon'),
        colorValue: row.readNullable<int>('color_value'),
        orderIndex: row.read<int>('order_index'),
        createdAt: row.read<DateTime>('created_at'),
        updatedAt: row.read<DateTime>('updated_at'),
      );
    }).toList();
  }

  /// Get all descendants (Folders and Notes) under a given start node.
  Future<List<Node>> getRecursiveDescendants(String startNodeId) async {
    final result = await customSelect(
      '''
      WITH RECURSIVE descendants AS (
        SELECT * FROM nodes WHERE parent_id = ?
        UNION ALL
        SELECT n.* FROM nodes n
        INNER JOIN descendants d ON n.parent_id = d.id
      )
      SELECT * FROM descendants
      ORDER BY order_index ASC
      ''',
      variables: [Variable.withString(startNodeId)],
      readsFrom: {nodes},
    ).get();

    return result.map((row) {
      return Node(
        id: row.read<String>('id'),
        parentId: row.readNullable<String>('parent_id'),
        type: row.read<String>('type'),
        title: row.read<String>('title'),
        content: row.read<String>('content'),
        icon: row.readNullable<String>('icon'),
        colorValue: row.readNullable<int>('color_value'),
        orderIndex: row.read<int>('order_index'),
        createdAt: row.read<DateTime>('created_at'),
        updatedAt: row.read<DateTime>('updated_at'),
      );
    }).toList();
  }

  /// Get the ancestor path for breadcrumb rendering.
  /// Returns list from root → target node.
  Future<List<Node>> getAncestorPath(String nodeId) async {
    final result = await customSelect(
      '''
      WITH RECURSIVE ancestors AS (
        SELECT * FROM nodes WHERE id = ?
        UNION ALL
        SELECT n.* FROM nodes n
        INNER JOIN ancestors a ON n.id = a.parent_id
      )
      SELECT * FROM ancestors
      ''',
      variables: [Variable.withString(nodeId)],
      readsFrom: {nodes},
    ).get();

    final ancestors = result.map((row) {
      return Node(
        id: row.read<String>('id'),
        parentId: row.readNullable<String>('parent_id'),
        type: row.read<String>('type'),
        title: row.read<String>('title'),
        content: row.read<String>('content'),
        icon: row.readNullable<String>('icon'),
        colorValue: row.readNullable<int>('color_value'),
        orderIndex: row.read<int>('order_index'),
        createdAt: row.read<DateTime>('created_at'),
        updatedAt: row.read<DateTime>('updated_at'),
      );
    }).toList();

    // Reverse to get root → target order
    return ancestors.reversed.toList();
  }

  /// Count all descendant notes under a node.
  Future<int> countRecursiveNotes(String startNodeId) async {
    final result = await customSelect(
      '''
      WITH RECURSIVE descendants AS (
        SELECT id, type FROM nodes WHERE id = ?
        UNION ALL
        SELECT n.id, n.type FROM nodes n
        INNER JOIN descendants d ON n.parent_id = d.id
      )
      SELECT COUNT(*) as cnt FROM descendants WHERE type = 'NOTE'
      ''',
      variables: [Variable.withString(startNodeId)],
      readsFrom: {nodes},
    ).getSingle();
    return result.read<int>('cnt');
  }

  /// Watch recursive note count.
  Stream<int> watchRecursiveNotesCount(String startNodeId) {
    return customSelect(
      '''
      WITH RECURSIVE descendants AS (
        SELECT id, type FROM nodes WHERE id = ?
        UNION ALL
        SELECT n.id, n.type FROM nodes n
        INNER JOIN descendants d ON n.parent_id = d.id
      )
      SELECT COUNT(*) as cnt FROM descendants WHERE type = 'NOTE'
      ''',
      variables: [Variable.withString(startNodeId)],
      readsFrom: {nodes},
    ).watchSingle().map((row) => row.read<int>('cnt'));
  }

  /// Count all descendant cards under a node hierarchy.
  Future<int> countRecursiveCards(String startNodeId) async {
    final result = await customSelect(
      '''
      WITH RECURSIVE descendants AS (
        SELECT id FROM nodes WHERE id = ?
        UNION ALL
        SELECT n.id FROM nodes n
        INNER JOIN descendants d ON n.parent_id = d.id
      )
      SELECT COUNT(*) as cnt FROM cards WHERE parent_id IN (SELECT id FROM descendants)
      ''',
      variables: [Variable.withString(startNodeId)],
      readsFrom: {nodes, cards},
    ).getSingle();
    return result.read<int>('cnt');
  }

  /// Watch recursive card count.
  Stream<int> watchRecursiveCardsCount(String startNodeId) {
    return customSelect(
      '''
      WITH RECURSIVE descendants AS (
        SELECT id FROM nodes WHERE id = ?
        UNION ALL
        SELECT n.id FROM nodes n
        INNER JOIN descendants d ON n.parent_id = d.id
      )
      SELECT COUNT(*) as cnt FROM cards WHERE parent_id IN (SELECT id FROM descendants)
      ''',
      variables: [Variable.withString(startNodeId)],
      readsFrom: {nodes, cards},
    ).watchSingle().map((row) => row.read<int>('cnt'));
  }

  /// Count direct children of a node.
  Future<int> countDirectChildren(String parentId) async {
    final result = await customSelect(
      'SELECT COUNT(*) as cnt FROM nodes WHERE parent_id = ?',
      variables: [Variable.withString(parentId)],
      readsFrom: {nodes},
    ).getSingle();
    return result.read<int>('cnt');
  }

  // ──────────────────────────────────────────
  // CRUD Operations
  // ──────────────────────────────────────────

  /// Insert a new node.
  Future<void> insertNode(NodesCompanion node) {
    return into(nodes).insert(node);
  }

  /// Update an existing node.
  Future<void> updateNode(String nodeId, NodesCompanion companion) {
    return (update(nodes)..where((n) => n.id.equals(nodeId)))
        .write(companion);
  }

  /// Delete a node and all its descendants recursively.
  Future<void> deleteNodeRecursive(String nodeId) async {
    // Also delete cards for these nodes
    await customUpdate(
      '''
      WITH RECURSIVE descendants AS (
        SELECT id FROM nodes WHERE id = ?
        UNION ALL
        SELECT n.id FROM nodes n
        INNER JOIN descendants d ON n.parent_id = d.id
      )
      DELETE FROM cards WHERE parent_id IN (SELECT id FROM descendants)
      ''',
      variables: [Variable.withString(nodeId)],
      updates: {cards},
    );

    await customUpdate(
      '''
      WITH RECURSIVE descendants AS (
        SELECT id FROM nodes WHERE id = ?
        UNION ALL
        SELECT n.id FROM nodes n
        INNER JOIN descendants d ON n.parent_id = d.id
      )
      DELETE FROM nodes WHERE id IN (SELECT id FROM descendants)
      ''',
      variables: [Variable.withString(nodeId)],
      updates: {nodes},
    );
  }

  /// Batch-update orderIndex for reordering within a parent.
  Future<void> reorderNodes(List<String> orderedIds) async {
    await batch((b) {
      for (int i = 0; i < orderedIds.length; i++) {
        b.update(
          nodes,
          NodesCompanion(orderIndex: Value(i)),
          where: (n) => n.id.equals(orderedIds[i]),
        );
      }
    });
  }

  // ──────────────────────────────────────────
  // Universal Node Library
  // ──────────────────────────────────────────

  /// Watch all universal (orphan) notes — notes with no parent.
  Stream<List<Node>> watchUniversalNotes() {
    return (select(nodes)
          ..where((n) => n.parentId.isNull() & n.type.equals('NOTE'))
          ..orderBy([(n) => OrderingTerm.desc(n.createdAt)]))
        .watch();
  }

  /// Watch all notes in the database.
  Stream<List<Node>> watchAllNotes() {
    return (select(nodes)..where((n) => n.type.equals('NOTE'))).watch();
  }

  /// Watch all cards in the database.
  Stream<List<Card>> watchAllCards() {
    return select(cards).watch();
  }

  /// Attach a node to a new parent (re-parent).
  Future<void> attachToParent(String nodeId, String newParentId) {
    return (update(nodes)..where((n) => n.id.equals(nodeId))).write(
      NodesCompanion(
        parentId: Value(newParentId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ──────────────────────────────────────────
  // Search
  // ──────────────────────────────────────────

  /// Search nodes by title (case-insensitive).
  Future<List<Node>> searchNodes(String query) {
    return (select(nodes)
          ..where((n) => n.title.like('%$query%'))
          ..orderBy([(n) => OrderingTerm.asc(n.title)])
          ..limit(50))
        .get();
  }

  /// Search only folders.
  Future<List<Node>> searchFolders(String query) {
    return (select(nodes)
          ..where((n) => n.title.like('%$query%') & n.type.equals('FOLDER'))
          ..orderBy([(n) => OrderingTerm.asc(n.title)])
          ..limit(50))
        .get();
  }

  // ──────────────────────────────────────────
  // Uniqueness Checks
  // ──────────────────────────────────────────

  /// Check if a root subject with the given title already exists (case-insensitive).
  /// Excludes the node with [excludeId] if provided (useful for renaming).
  Future<bool> doesSubjectExist(String title, {String? excludeId}) async {
    final query = select(nodes)
      ..where((n) {
        var condition = n.parentId.isNull() & n.title.lower().equals(title.toLowerCase());
        if (excludeId != null) {
          condition = condition & n.id.isNotValue(excludeId);
        }
        return condition;
      });
    final result = await query.get();
    return result.isNotEmpty;
  }

  /// Check if a folder with the given title already exists in the parent (case-insensitive).
  /// Excludes the node with [excludeId] if provided (useful for renaming).
  Future<bool> doesFolderExistInParent(String parentId, String title, {String? excludeId}) async {
    final query = select(nodes)
      ..where((n) {
        var condition = n.parentId.equals(parentId) & n.type.equals('FOLDER') & n.title.lower().equals(title.toLowerCase());
        if (excludeId != null) {
          condition = condition & n.id.isNotValue(excludeId);
        }
        return condition;
      });
    final result = await query.get();
    return result.isNotEmpty;
  }

  /// Check if an exact card already exists in the parent.
  /// Excludes the card with [excludeId] if provided (useful for editing).
  Future<bool> doesCardExistInParent(String parentId, String front, String back, {String? excludeId}) async {
    final query = select(cards)
      ..where((c) {
        var condition = c.parentId.equals(parentId) & c.front.equals(front) & c.back.equals(back);
        if (excludeId != null) {
          condition = condition & c.id.isNotValue(excludeId);
        }
        return condition;
      });
    final result = await query.get();
    return result.isNotEmpty;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'noda.db'));
    return NativeDatabase.createInBackground(file);
  });
}


