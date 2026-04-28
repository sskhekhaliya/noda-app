import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
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

    // Process notes (supports legacy "note" and new "notes" array)
    _extractNotes(subjectJson, subjectId, flatNodes, uuid, now);

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

      // Process notes (supports legacy "note" and new "notes" array)
      _extractNotes(n, nodeId, flatNodes, uuid, now);

      // Process cards on this node
      _processCards(n['cards'], nodeId, flatCards, uuid, now);

      // Recursively process child nodes
      _processNodes(n['nodes'], nodeId, flatNodes, flatCards, uuid, now);
    }
  }

  void _extractNotes(Map<String, dynamic> json, String parentId, List<Map<String, dynamic>> flatNodes, Uuid uuid, String now) {
    // 1. Handle legacy "note" field (string)
    final legacyNote = json['note'];
    if (legacyNote is String && legacyNote.trim().isNotEmpty) {
      flatNodes.add({
        'id': uuid.v4(),
        'parentId': parentId,
        'type': 'NOTE',
        'title': '',
        'content': legacyNote,
        'icon': null,
        'colorValue': null,
        'orderIndex': 0,
        'createdAt': now,
        'updatedAt': now,
      });
    }

    // 2. Handle new "notes" field (List of strings or objects)
    final notes = json['notes'];
    if (notes is List) {
      for (final n in notes) {
        String t = '';
        String c = '';
        if (n is String) {
          c = n;
        } else if (n is Map<String, dynamic>) {
          t = n['title'] ?? '';
          c = n['content'] ?? n['note'] ?? '';
        }

        if (c.trim().isNotEmpty || t.trim().isNotEmpty) {
          flatNodes.add({
            'id': uuid.v4(),
            'parentId': parentId,
            'type': 'NOTE',
            'title': t,
            'content': c,
            'icon': null,
            'colorValue': null,
            'orderIndex': 0,
            'createdAt': now,
            'updatedAt': now,
          });
        }
      }
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

  // ──────────────────────────────────────────
  // EXPORT — Simple Format
  // ──────────────────────────────────────────

  Future<void> exportSubjectAsNoda(String subjectId, {bool saveToDevice = false}) async {
    final subject = await db.getNodeById(subjectId);
    if (subject == null) return;

    final simpleSubject = await _buildSimpleNode(subject, isRoot: true);
    final data = {'subject': simpleSubject};
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    final fileName = '${subject.title.replaceAll(' ', '_')}.noda';

    if (saveToDevice || Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      await _saveToDevice(fileName, jsonStr);
    } else {
      await _shareFile(fileName, jsonStr, 'Exported Noda Subject: ${subject.title}');
    }
  }

  /// Recursively build a simple nested representation of a node.
  Future<Map<String, dynamic>> _buildSimpleNode(Node node, {bool isRoot = false}) async {
    final children = await db.getChildrenOf(node.id);
    final cards = await db.getCardsOf(node.id);

    final Map<String, dynamic> result = {};

    // Find child NOTE nodes
    final childNotes = children.where((c) => c.type == 'NOTE').toList();

    if (isRoot) {
      result['title'] = node.title;
      if (node.content.isNotEmpty) result['description'] = node.content;
      if (node.icon != null) result['icon'] = node.icon;
      if (node.colorValue != null) result['colorValue'] = node.colorValue;
    } else {
      result['name'] = node.title;
    }

    // Include notes
    if (childNotes.length == 1 && childNotes.first.title.isEmpty) {
      // Legacy compatibility: single untitled note
      result['note'] = childNotes.first.content;
    } else if (childNotes.isNotEmpty) {
      // Modern format: multiple notes and/or titled notes
      result['notes'] = childNotes.map((n) {
        final noteMap = <String, dynamic>{'content': n.content};
        if (n.title.isNotEmpty) noteMap['title'] = n.title;
        return noteMap;
      }).toList();
    }

    if (cards.isNotEmpty) {
      result['cards'] = cards.map((c) => {
        'front': c.front,
        'back': c.back,
      }).toList();
    }

    // Only include child FOLDER nodes (not NOTEs, which are represented by "note"/"notes" field)
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

  Future<void> exportFullBackupAsNpack({bool saveToDevice = false}) async {
    final rootNodes = await db.watchRootNodes().first;
    List<Node> allNodes = List.from(rootNodes);
    List<Card> allCards = [];

    for (var root in rootNodes) {
      allNodes.addAll(await db.getRecursiveDescendants(root.id));
      allCards.addAll(await db.getRecursiveCards(root.id));
    }

    final universalNotes = await db.watchUniversalNotes().first;
    allNodes.addAll(universalNotes);

    final data = {
      'version': 1,
      'type': 'noda_backup',
      'nodes': allNodes.map((n) => _nodeToJson(n)).toList(),
      'cards': allCards.map((c) => _cardToJson(c, stripProgress: false)).toList(),
    };

    final jsonStr = jsonEncode(data);
    final dateStr = DateTime.now().toIso8601String().split('T').first;
    final fileName = 'Noda_Backup_$dateStr.npack';

    if (saveToDevice || Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      await _saveToDevice(fileName, jsonStr);
    } else {
      await _shareFile(fileName, jsonStr, 'Noda Full Backup');
    }
  }

  Future<void> _shareFile(String fileName, String content, String shareText) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(content);
    await Share.shareXFiles([XFile(file.path)], text: shareText);
  }

  Future<void> _saveToDevice(String fileName, String content) async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save File',
        fileName: fileName,
      );
      if (outputPath != null) {
        await File(outputPath).writeAsString(content);
      }
    } else {
      // Mobile: Pick directory and save
      final selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null) {
        final file = File('$selectedDirectory/$fileName');
        await file.writeAsString(content);
      }
    }
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

    await db.transaction(() async {
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
    });
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

    await _mergeFolderContent(existingSubject.id, data['nodes'] ?? [], data['cards'] ?? [], idMap, updateNotes);
  }

  Future<void> _mergeFolderContent(String targetParentId, List<dynamic> incomingNodes, List<dynamic> incomingCards, Map<String, String> idMap, bool updateNotes) async {
    final now = DateTime.now();
    
    for (var n in incomingNodes) {
      final oldId = n['id'];
      final oldParentId = n['parentId'];
      final currentTargetParentId = idMap[oldParentId] ?? targetParentId;

      if (n['type'] == 'FOLDER') {
        final title = n['title'];
        final exists = await db.doesFolderExistInParent(currentTargetParentId, title);
        if (exists) {
          final existingFolders = await db.getChildrenOf(currentTargetParentId);
          final match = existingFolders.firstWhere((e) => e.type == 'FOLDER' && e.title.toLowerCase() == title.toLowerCase());
          idMap[oldId] = match.id;
          if (updateNotes) {
            await db.updateNode(match.id, NodesCompanion(updatedAt: Value(now)));
          }
        } else {
          final newId = const Uuid().v4();
          idMap[oldId] = newId;
          await db.insertNode(_jsonToNodeCompanion(n, newId: newId, newParentId: currentTargetParentId));
        }
      } else if (n['type'] == 'NOTE') {
        final incomingTitle = n['title'] ?? '';
        final incomingContent = n['content'] ?? '';
        final existingChildren = await db.getChildrenOf(currentTargetParentId);
        final existingNotes = existingChildren.where((e) => e.type == 'NOTE').toList();

        Node? match;
        if (incomingTitle.isNotEmpty) {
          try {
            match = existingNotes.firstWhere((e) => e.title.toLowerCase() == incomingTitle.toLowerCase());
          } catch (_) { match = null; }
        } else if (existingNotes.length == 1 && existingNotes.first.title.isEmpty) {
          match = existingNotes.first;
        }

        if (match != null) {
          idMap[oldId] = match.id;
          if (updateNotes) {
            await db.updateNode(match.id, NodesCompanion(
              title: Value(incomingTitle),
              content: Value(incomingContent),
              updatedAt: Value(now),
            ));
          }
        } else {
          final newId = const Uuid().v4();
          idMap[oldId] = newId;
          await db.insertNode(_jsonToNodeCompanion(n, newId: newId, newParentId: currentTargetParentId));
        }
      }
    }

    for (var c in incomingCards) {
      final oldParentId = c['parentId'];
      final currentTargetParentId = idMap[oldParentId] ?? targetParentId;
      final front = c['front'];
      final back = c['back'];

      final exists = await db.doesCardExistInParent(currentTargetParentId, front, back);
      if (!exists) {
        await db.insertCard(_jsonToCardCompanion(c, newId: const Uuid().v4(), newParentId: currentTargetParentId));
      }
    }
  }

  /// Specialized import for a specific folder.
  Future<void> importFolderData(String parentId, String jsonStr, ImportStrategy strategy) async {
    final Map<String, dynamic> data = jsonDecode(jsonStr);
    final uuid = const Uuid();
    final now = DateTime.now().toIso8601String();

    await db.transaction(() async {
      final Map<String, String> idMap = {};
      final List<Map<String, dynamic>> incomingNodes = [];
      final List<Map<String, dynamic>> incomingCards = [];

      // 1. Handle Notes (Treated as child nodes)
      if (data.containsKey('notes')) {
        // OVERWRITE or UPDATE: If key is present, we clear existing notes in this folder first
        // to sync with the incoming list (even if it's empty).
        final children = await db.getChildrenOf(parentId);
        final existingNotes = children.where((n) => n.type == 'NOTE').toList();
        for (var en in existingNotes) {
          await db.deleteNodeRecursive(en.id);
        }
        
        _extractNotes(data, parentId, incomingNodes, uuid, now);
      }

      // 2. Handle Sub-folders (nodes)
      if (data.containsKey('nodes')) {
        final nodesJson = data['nodes'];
        
        // If OVERWRITE mode and key is present, clear existing folders
        if (strategy == ImportStrategy.overwrite) {
          final children = await db.getChildrenOf(parentId);
          final existingFolders = children.where((n) => n.type == 'FOLDER').toList();
          for (var ef in existingFolders) {
            await db.deleteNodeRecursive(ef.id);
          }
        } 
        // In UPDATE mode, we MERGE folders (don't clear).
        // Except if nodes: [] is explicitly provided, user wants them gone.
        else if (strategy == ImportStrategy.appendUpdate && nodesJson is List && nodesJson.isEmpty) {
          final children = await db.getChildrenOf(parentId);
          final existingFolders = children.where((n) => n.type == 'FOLDER').toList();
          for (var ef in existingFolders) {
            await db.deleteNodeRecursive(ef.id);
          }
        }
        
        _processNodes(nodesJson, parentId, incomingNodes, incomingCards, uuid, now);
      }

      // 3. Handle Cards
      if (data.containsKey('cards')) {
        final cardsJson = data['cards'];
        
        // If OVERWRITE mode and key is present, clear existing cards
        if (strategy == ImportStrategy.overwrite) {
          final cards = await db.getCardsOf(parentId);
          for (var c in cards) {
            await db.deleteCard(c.id);
          }
        }
        // In UPDATE mode, we MERGE cards.
        // Except if cards: [] is explicitly provided.
        else if (strategy == ImportStrategy.appendUpdate && cardsJson is List && cardsJson.isEmpty) {
          final cards = await db.getCardsOf(parentId);
          for (var c in cards) {
            await db.deleteCard(c.id);
          }
        }
        
        _processCards(cardsJson, parentId, incomingCards, uuid, now);
      }

      // Perform the merge/insert
      await _mergeFolderContent(parentId, incomingNodes, incomingCards, idMap, strategy == ImportStrategy.appendUpdate);
    });
  }
}

final importExportServiceProvider = Provider<ImportExportService>((ref) {
  return ImportExportService(ref.watch(databaseProvider));
});


