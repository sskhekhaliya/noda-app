import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:drift/drift.dart';
import 'database/app_database.dart';

class ImportExportService {
  final AppDatabase _db;
  ImportExportService(this._db);

  Future<void> exportAll() async {
    final nodes = await (_db.select(_db.nodes)).get();
    final cards = await (_db.select(_db.cards)).get();

    final data = {
      'nodes': nodes.map((n) => {
        'id': n.id,
        'parentId': n.parentId,
        'type': n.type,
        'title': n.title,
        'content': n.content,
        'icon': n.icon,
        'colorValue': n.colorValue,
        'orderIndex': n.orderIndex,
      }).toList(),
      'cards': cards.map((c) => {
        'id': c.id,
        'parentId': c.parentId,
        'front': c.front,
        'back': c.back,
        'upvotes': c.upvotes,
        'downvotes': c.downvotes,
      }).toList(),
    };

    final jsonString = jsonEncode(data);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/noda_backup.json');
    await file.writeAsString(jsonString);

    await Share.shareXFiles([XFile(file.path)], text: 'Noda Backup');
  }

  Future<void> importAll() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null) {
      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final Map<String, dynamic> data = jsonDecode(jsonString);

      await _db.transaction(() async {
        // Clear existing data (optional, but cleaner for a pivot)
        await (_db.delete(_db.cards)).go();
        await (_db.delete(_db.nodes)).go();

        for (final nData in data['nodes']) {
          await _db.into(_db.nodes).insert(NodesCompanion(
            id: Value(nData['id']),
            parentId: Value(nData['parentId']),
            type: Value(nData['type']),
            title: Value(nData['title']),
            content: Value(nData['content'] ?? ''),
            icon: Value(nData['icon']),
            colorValue: Value(nData['colorValue']),
            orderIndex: Value(nData['orderIndex'] ?? 0),
          ));
        }

        for (final cData in data['cards']) {
          await _db.into(_db.cards).insert(CardsCompanion(
            id: Value(cData['id']),
            parentId: Value(cData['parentId']),
            front: Value(cData['front']),
            back: Value(cData['back']),
            upvotes: Value(cData['upvotes'] ?? 0),
            downvotes: Value(cData['downvotes'] ?? 0),
          ));
        }
      });
    }
  }
}

