import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;

import '../data/database/app_database.dart';
import '../providers/database_provider.dart';

enum ImportStrategy { overwrite, appendUpdate, appendSkip, rename }

class ImportAnalysis {
  final bool isNpack;
  final bool subjectExists;
  final Node? existingSubject;
  final int incomingTopicsCount;
  final int incomingCardsCount;
  final int existingTopicsCount;
  final int existingCardsCount;
  final String title;

  ImportAnalysis({
    this.isNpack = false,
    required this.subjectExists,
    this.existingSubject,
    required this.incomingTopicsCount,
    required this.incomingCardsCount,
    required this.existingTopicsCount,
    required this.existingCardsCount,
    required this.title,
  });
}

class ImportExportService {
  final AppDatabase db;
  ImportExportService(this.db);

  // ──────────────────────────────────────────
  // FORMAT DETECTION
  // ──────────────────────────────────────────

  /// Detects whether JSON is the new simple format or the legacy internal format.
  /// Simple format has a top-level "subject" with "name" or "title" + nested "nodes".
  /// Legacy format has "version", "type": "noda_subject", flat "nodes" and "cards" arrays.
  bool _isSimpleFormat(Map<String, dynamic> data) {
    // Simple format: has "subject" key with nested structure, no "version"/"type" keys
    if (data.containsKey('subject') && !data.containsKey('version') && !data.containsKey('type')) {
      return true;
    }
    return false;
  }

  /// Converts the simple human-friendly format into the internal flat format
  /// that the existing import logic already understands.
  Map<String, dynamic> _convertSimpleToInternal(Map<String, dynamic> simpleData) {
    final subjectJson = simpleData['subject'] as Map<String, dynamic>;
    final uuid = const Uuid();

    final String subjectId = uuid.v4();
    final now = DateTime.now().toIso8601String();

    // Build the subject node
    final subjectNode = {
      'id': subjectId,
      'parentId': null,
      'type': 'FOLDER',
      'title': (subjectJson['title'] ?? "Untitled") ?? subjectJson['name'] ?? 'Untitled',
      'content': subjectJson['description'] ?? '',
      'icon': subjectJson['icon'],
      'colorValue': subjectJson['colorValue'],
      'orderIndex': 0,
      'createdAt': now,
      'updatedAt': now,
    };

    final List<Map<String, dynamic>> flatNodes = [];
    final List<Map<String, dynamic>> flatCards = [];

    // If subject has a note, create a child NOTE node for it
    final subjectNote = subjectJson['note'] ?? '';
    if (subjectNote is String && subjectNote.trim().isNotEmpty) {
      flatNodes.add({
        'id': uuid.v4(),
        'parentId': subjectId,
        'type': 'NOTE',
        'title': '',
        'content': subjectNote,
        'icon': null,
        'colorValue': null,
        'orderIndex': 0,
        'createdAt': now,
        'updatedAt': now,
      });
    }

    // Process cards directly on the subject
    _processCards(subjectJson['cards'], subjectId, flatCards, uuid, now);

    // Recursively process nested nodes
    _processNodes(subjectJson['nodes'], subjectId, flatNodes, flatCards, uuid, now);

    return {
      'version': 1,
      'type': 'noda_subject',
      'subject': subjectNode,
      'nodes': flatNodes,
      'cards': flatCards,
    };
  }

  void _processCards(dynamic cardsJson, String parentId, List<Map<String, dynamic>> flatCards, Uuid uuid, String now) {
    if (cardsJson == null || cardsJson is! List) return;
    for (int i = 0; i < cardsJson.length; i++) {
      final c = cardsJson[i] as Map<String, dynamic>;
      flatCards.add({
        'id': uuid.v4(),
        'parentId': parentId,
        'front': c['front'] ?? '',
        'back': c['back'] ?? '',
        'upvotes': 0,
        'downvotes': 0,
        'createdAt': now,
        'updatedAt': now,
      });
    }
  }

  void _processNodes(dynamic nodesJson, String parentId, List<Map<String, dynamic>> flatNodes, List<Map<String, dynamic>> flatCards, Uuid uuid, String now) {
    if (nodesJson == null || nodesJson is! List) return;
    for (int i = 0; i < nodesJson.length; i++) {
      final n = nodesJson[i] as Map<String, dynamic>;
      final nodeId = uuid.v4();

      flatNodes.add({
        'id': nodeId,
        'parentId': parentId,
        'type': 'FOLDER',
        'title': n['name'] ?? n['title'] ?? 'Untitled',
        'content': '',
        'icon': n['icon'],
        'colorValue': n['colorValue'],
        'orderIndex': i,
        'createdAt': now,
        'updatedAt': now,
      });

      // If node has a note, create a child NOTE node for it
      final nodeNote = n['note'] ?? '';
      if (nodeNote is String && nodeNote.trim().isNotEmpty) {
        flatNodes.add({
          'id': uuid.v4(),
          'parentId': nodeId,
          'type': 'NOTE',
          'title': '',
          'content': nodeNote,
          'icon': null,
          'colorValue': null,
          'orderIndex': 0,
          'createdAt': now,
          'updatedAt': now,
        });
      }

      // Process cards on this node
      _processCards(n['cards'], nodeId, flatCards, uuid, now);

      // Recursively process child nodes
      _processNodes(n['nodes'], nodeId, flatNodes, flatCards, uuid, now);
    }
  }

  // ──────────────────────────────────────────
  // INTERNAL FORMAT HELPERS
  // ──────────────────────────────────────────

  Map<String, dynamic> _nodeToJson(Node node) {
    return {
      'id': node.id,
      'parentId': node.parentId,
      'type': node.type,
      'title': node.title,
      'content': node.content,
      'icon': node.icon,
      'colorValue': node.colorValue,
      'orderIndex': node.orderIndex,
      'createdAt': node.createdAt.toIso8601String(),
      'updatedAt': node.updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _cardToJson(Card card, {bool stripProgress = false}) {
    return {
      'id': card.id,
      'parentId': card.parentId,
      'front': card.front,
      'back': card.back,
      'upvotes': stripProgress ? 0 : card.upvotes,
      'downvotes': stripProgress ? 0 : card.downvotes,
      'createdAt': card.createdAt.toIso8601String(),
      'updatedAt': card.updatedAt.toIso8601String(),
    };
  }

  // ──────────────────────────────────────────
  // EXPORT — Simple Format
  // ──────────────────────────────────────────

  Future<void> exportSubjectAsNoda(String subjectId) async {
    final subject = await db.getNodeById(subjectId);
    if (subject == null) return;

    // Build the simple nested structure
    final simpleSubject = await _buildSimpleNode(subject, isRoot: true);

    final data = {'subject': simpleSubject};

    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/${subject.title.replaceAll(' ', '_')}.noda');
    await file.writeAsString(jsonStr);

    await Share.shareXFiles([XFile(file.path)], text: 'Exported Noda Subject: ${subject.title}');
  }

  /// Recursively build a simple nested representation of a node.
  Future<Map<String, dynamic>> _buildSimpleNode(Node node, {bool isRoot = false}) async {
    final children = await db.getChildrenOf(node.id);
    final cards = await db.getCardsOf(node.id);

    final Map<String, dynamic> result = {};

    // Find child NOTE node (the app stores notes as child nodes with type 'NOTE')
    final childNotes = children.where((c) => c.type == 'NOTE').toList();
    final noteContent = childNotes.isNotEmpty ? childNotes.first.content : '';

    if (isRoot) {
      result['title'] = node.title;
      if (node.content.isNotEmpty) result['description'] = node.content;
      if (node.icon != null) result['icon'] = node.icon;
      if (node.colorValue != null) result['colorValue'] = node.colorValue;
      if (noteContent.isNotEmpty) result['note'] = noteContent;
    } else {
      result['name'] = node.title;
      if (noteContent.isNotEmpty) result['note'] = noteContent;
    }

    if (cards.isNotEmpty) {
      result['cards'] = cards.map((c) => {
        'front': c.front,
        'back': c.back,
      }).toList();
    }

    // Only include child FOLDER nodes (not NOTEs, which are represented by "note" field)
    final childFolders = children.where((c) => c.type == 'FOLDER').toList();
    if (childFolders.isNotEmpty) {
      final nodesList = <Map<String, dynamic>>[];
      for (final child in childFolders) {
        nodesList.add(await _buildSimpleNode(child));
      }
      result['nodes'] = nodesList;
    }

    return result;
  }

  Future<void> exportFullBackupAsNpack() async {
    final rootNodes = await db.watchRootNodes().first;
    List<Node> allNodes = List.from(rootNodes);
    List<Card> allCards = [];

    for (var root in rootNodes) {
      allNodes.addAll(await db.getRecursiveDescendants(root.id));
      allCards.addAll(await db.getRecursiveCards(root.id));
    }

    // Also get universal notes (no parent)
    final universalNotes = await db.watchUniversalNotes().first;
    allNodes.addAll(universalNotes);

    final data = {
      'version': 1,
      'type': 'noda_backup',
      'nodes': allNodes.map((n) => _nodeToJson(n)).toList(),
      'cards': allCards.map((c) => _cardToJson(c, stripProgress: false)).toList(),
    };

    final jsonStr = jsonEncode(data);
    
    final tempDir = await getTemporaryDirectory();
    final dateStr = DateTime.now().toIso8601String().split('T').first;
    final file = File('${tempDir.path}/Noda_Backup_$dateStr.npack');
    await file.writeAsString(jsonStr);

    await Share.shareXFiles([XFile(file.path)], text: 'Noda Full Backup');
  }

  // ──────────────────────────────────────────
  // IMPORT ANALYSIS
  // ──────────────────────────────────────────

  Future<ImportAnalysis> analyzeImport(String jsonStr) async {
    Map<String, dynamic> data = jsonDecode(jsonStr);

    // Convert simple format to internal if needed
    if (_isSimpleFormat(data)) {
      data = _convertSimpleToInternal(data);
    }

    final String type = data['type'] ?? '';

    if (type == 'noda_backup') {
      return ImportAnalysis(
        isNpack: true,
        subjectExists: false,
        incomingTopicsCount: (data['nodes'] as List).length,
        incomingCardsCount: (data['cards'] as List).length,
        existingTopicsCount: 0,
        existingCardsCount: 0,
        title: 'Full Backup',
      );
    } else if (type == 'noda_subject') {
      final subjectJson = data['subject'] as Map<String, dynamic>;
      final String title = (subjectJson['title'] ?? "Untitled");

      final existingSubjects = await db.searchNodes(title);
      Node? existingSubject;
      for (var s in existingSubjects) {
        if (s.parentId == null && s.title.toLowerCase() == title.toLowerCase()) {
          existingSubject = s;
          break;
        }
      }

      int existingTopics = 0;
      int existingCards = 0;

      if (existingSubject != null) {
        final descendants = await db.getRecursiveDescendants(existingSubject.id);
        existingTopics = descendants.where((n) => n.type == 'FOLDER').length;
        final cards = await db.getRecursiveCards(existingSubject.id);
        existingCards = cards.length;
      }

      final incomingNodes = data['nodes'] as List;
      final incomingCards = data['cards'] as List;

      return ImportAnalysis(
        isNpack: false,
        subjectExists: existingSubject != null,
        existingSubject: existingSubject,
        incomingTopicsCount: incomingNodes.where((n) => n['type'] == 'FOLDER').length,
        incomingCardsCount: incomingCards.length,
        existingTopicsCount: existingTopics,
        existingCardsCount: existingCards,
        title: title,
      );
    } else {
      throw FormatException('Invalid file format');
    }
  }

  // ──────────────────────────────────────────
  // IMPORT EXECUTION
  // ──────────────────────────────────────────

  Future<void> executeImport(String jsonStr, ImportStrategy strategy, ImportAnalysis analysis, {String? newName}) async {
    Map<String, dynamic> data = jsonDecode(jsonStr);

    // Convert simple format to internal if needed
    if (_isSimpleFormat(data)) {
      data = _convertSimpleToInternal(data);
    }

    final String type = data['type'] ?? '';

    if (type == 'noda_backup') {
      // Overwrite entirely
      // First wipe DB
      final rootNodes = await db.watchRootNodes().first;
      for (var root in rootNodes) {
        await db.deleteNodeRecursive(root.id);
      }
      final universalNotes = await db.watchUniversalNotes().first;
      for (var un in universalNotes) {
        await db.deleteNodeRecursive(un.id);
      }

      // Insert all
      final nodes = data['nodes'] as List;
      for (var n in nodes) {
        await db.insertNode(_jsonToNodeCompanion(n));
      }
      final cards = data['cards'] as List;
      for (var c in cards) {
        await db.insertCard(_jsonToCardCompanion(c));
      }
    } else if (type == 'noda_subject') {
      if (strategy == ImportStrategy.overwrite && analysis.existingSubject != null) {
        // Delete existing subject first
        await db.deleteNodeRecursive((analysis.existingSubject?.id ?? ""));
        // Then insert exactly as is
        await _insertSubjectRaw(data);
      } else if (strategy == ImportStrategy.rename) {
        // Remap IDs and change subject name
        await _insertSubjectMapped(data, newName ?? '${analysis.title} (Imported)');
      } else if (strategy == ImportStrategy.appendUpdate && analysis.existingSubject != null) {
        await _mergeSubject(data, analysis.existingSubject!, updateNotes: true);
      } else if (strategy == ImportStrategy.appendSkip && analysis.existingSubject != null) {
        await _mergeSubject(data, analysis.existingSubject!, updateNotes: false);
      } else {
        // No conflict, just insert
        await _insertSubjectRaw(data);
      }
    }
  }

  NodesCompanion _jsonToNodeCompanion(Map<String, dynamic> json, {String? newId, String? newParentId, String? newTitle}) {
    final now = DateTime.now();
    return NodesCompanion.insert(
      id: newId ?? json['id'],
      type: json['type'],
      title: newTitle ?? json['title'],
      content: Value(json['content'] ?? ''),
      icon: Value(json['icon']),
      colorValue: Value(json['colorValue']),
      parentId: Value(newParentId ?? json['parentId']),
      orderIndex: Value(json['orderIndex'] ?? 0),
      createdAt: Value(json['createdAt'] != null ? DateTime.parse(json['createdAt']) : now),
      updatedAt: Value(json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : now),
    );
  }

  CardsCompanion _jsonToCardCompanion(Map<String, dynamic> json, {String? newId, String? newParentId}) {
    final now = DateTime.now();
    return CardsCompanion.insert(
      id: newId ?? json['id'],
      parentId: newParentId ?? json['parentId'],
      front: json['front'],
      back: json['back'],
      upvotes: Value(json['upvotes'] ?? 0),
      downvotes: Value(json['downvotes'] ?? 0),
      createdAt: Value(json['createdAt'] != null ? DateTime.parse(json['createdAt']) : now),
      updatedAt: Value(json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : now),
    );
  }

  Future<void> _insertSubjectRaw(Map<String, dynamic> data) async {
    await db.insertNode(_jsonToNodeCompanion(data['subject']));
    for (var n in data['nodes'] as List) {
      await db.insertNode(_jsonToNodeCompanion(n));
    }
    for (var c in data['cards'] as List) {
      await db.insertCard(_jsonToCardCompanion(c));
    }
  }

  Future<void> _insertSubjectMapped(Map<String, dynamic> data, String newTitle) async {
    final Map<String, String> idMap = {}; // oldId -> newId

    final subjectJson = data['subject'] as Map<String, dynamic>;
    final newSubjectId = const Uuid().v4();
    idMap[subjectJson['id']] = newSubjectId;

    await db.insertNode(_jsonToNodeCompanion(subjectJson, newId: newSubjectId, newTitle: newTitle));

    for (var n in data['nodes'] as List) {
      final oldId = n['id'];
      final oldParentId = n['parentId'];
      final newId = const Uuid().v4();
      idMap[oldId] = newId;

      await db.insertNode(_jsonToNodeCompanion(n, newId: newId, newParentId: idMap[oldParentId]));
    }

    for (var c in data['cards'] as List) {
      final oldParentId = c['parentId'];
      final newId = const Uuid().v4();
      await db.insertCard(_jsonToCardCompanion(c, newId: newId, newParentId: idMap[oldParentId]));
    }
  }

  Future<void> _mergeSubject(Map<String, dynamic> data, Node existingSubject, {required bool updateNotes}) async {
    final Map<String, String> idMap = {}; // oldId -> newId (or existingId)
    final now = DateTime.now();
    
    final subjectJson = data['subject'] as Map<String, dynamic>;
    idMap[subjectJson['id']] = existingSubject.id;

    if (updateNotes) {
      // Update the root subject's updatedAt
      await db.updateNode(existingSubject.id, NodesCompanion(updatedAt: Value(now)));
    }

    for (var n in data['nodes'] as List) {
      final oldId = n['id'];
      final oldParentId = n['parentId'];
      final targetParentId = idMap[oldParentId] ?? existingSubject.id;

      if (n['type'] == 'FOLDER') {
        final title = n['title'];
        final exists = await db.doesFolderExistInParent(targetParentId, title);
        if (exists) {
          // Folder already exists — map the ID so child items land in the right place
          final existingFolders = await db.getChildrenOf(targetParentId);
          final match = existingFolders.firstWhere((e) => e.type == 'FOLDER' && e.title.toLowerCase() == title.toLowerCase());
          idMap[oldId] = match.id;
          
          if (updateNotes) {
            // Update the folder's updatedAt to reflect new content activity
            await db.updateNode(match.id, NodesCompanion(updatedAt: Value(now)));
          }
        } else {
          // New folder — insert it
          final newId = const Uuid().v4();
          idMap[oldId] = newId;
          await db.insertNode(_jsonToNodeCompanion(n, newId: newId, newParentId: targetParentId));
        }
      } else if (n['type'] == 'NOTE') {
        // Check if this parent already has a NOTE child
        final existingChildren = await db.getChildrenOf(targetParentId);
        final existingNote = existingChildren.where((e) => e.type == 'NOTE').toList();

        if (existingNote.isNotEmpty) {
          idMap[oldId] = existingNote.first.id;
          if (updateNotes) {
            // Update mode: overwrite the existing note content
            await db.updateNode(
              existingNote.first.id,
              NodesCompanion(
                content: Value(n['content'] ?? ''),
                updatedAt: Value(now),
              ),
            );
          }
          // Append mode: skip — keep original note
        } else {
          // No existing note — insert it
          final newId = const Uuid().v4();
          idMap[oldId] = newId;
          await db.insertNode(_jsonToNodeCompanion(n, newId: newId, newParentId: targetParentId));
        }
      }
    }

    // Cards: always add new ones, always skip duplicates (never touch progress)
    for (var c in data['cards'] as List) {
      final oldParentId = c['parentId'];
      final targetParentId = idMap[oldParentId] ?? existingSubject.id;
      final front = c['front'];
      final back = c['back'];

      final exists = await db.doesCardExistInParent(targetParentId, front, back);
      if (!exists) {
        await db.insertCard(_jsonToCardCompanion(c, newId: const Uuid().v4(), newParentId: targetParentId));
      }
      // Duplicate cards are always skipped — study progress is never touched
    }
  }
}

final importExportServiceProvider = Provider<ImportExportService>((ref) {
  return ImportExportService(ref.watch(databaseProvider));
});


