import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/app_database.dart';
import 'database_provider.dart';

/// Revision mode type.
enum RevisionMode { linear, shuffle }

/// State for the revision feed.
class RevisionState {
  final List<Node> notes;
  final int currentIndex;
  final RevisionMode mode;
  final String startNodeId;
  final String startNodeTitle;
  final bool isLoading;

  const RevisionState({
    this.notes = const [],
    this.currentIndex = 0,
    this.mode = RevisionMode.linear,
    this.startNodeId = '',
    this.startNodeTitle = '',
    this.isLoading = false,
  });

  bool get isEmpty => notes.isEmpty;
  bool get isNotEmpty => notes.isNotEmpty;
  int get totalCount => notes.length;
  Node? get currentNote => notes.isNotEmpty ? notes[currentIndex] : null;
  bool get hasNext => currentIndex < notes.length - 1;
  bool get hasPrevious => currentIndex > 0;
  double get progress => notes.isEmpty ? 0 : (currentIndex + 1) / notes.length;

  RevisionState copyWith({
    List<Node>? notes,
    int? currentIndex,
    RevisionMode? mode,
    String? startNodeId,
    String? startNodeTitle,
    bool? isLoading,
  }) {
    return RevisionState(
      notes: notes ?? this.notes,
      currentIndex: currentIndex ?? this.currentIndex,
      mode: mode ?? this.mode,
      startNodeId: startNodeId ?? this.startNodeId,
      startNodeTitle: startNodeTitle ?? this.startNodeTitle,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Controls the revision feed queue and playback.
class RevisionNotifier extends StateNotifier<RevisionState> {
  final AppDatabase _db;

  RevisionNotifier(this._db) : super(const RevisionState());

  /// Start linear revision — DFS-ordered playback.
  Future<void> startLinear(String nodeId, String title) async {
    state = state.copyWith(isLoading: true, startNodeId: nodeId, startNodeTitle: title);

    final notes = await _db.getRecursiveChildNotes(nodeId);

    state = state.copyWith(
      notes: notes,
      currentIndex: 0,
      mode: RevisionMode.linear,
      isLoading: false,
    );
  }

  /// Start shuffle revision — randomized playback.
  Future<void> startShuffle(String nodeId, String title) async {
    state = state.copyWith(isLoading: true, startNodeId: nodeId, startNodeTitle: title);

    final notes = await _db.getRecursiveChildNotes(nodeId);
    final shuffled = List<Node>.from(notes)..shuffle(Random());

    state = state.copyWith(
      notes: shuffled,
      currentIndex: 0,
      mode: RevisionMode.shuffle,
      isLoading: false,
    );
  }

  /// Move to next note.
  void next() {
    if (state.hasNext) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    }
  }

  /// Move to previous note.
  void previous() {
    if (state.hasPrevious) {
      state = state.copyWith(currentIndex: state.currentIndex - 1);
    }
  }

  /// Jump to a specific index.
  void goToIndex(int index) {
    if (index >= 0 && index < state.notes.length) {
      state = state.copyWith(currentIndex: index);
    }
  }

  /// Re-shuffle the current queue.
  void reshuffle() {
    final shuffled = List<Node>.from(state.notes)..shuffle(Random());
    state = state.copyWith(
      notes: shuffled,
      currentIndex: 0,
      mode: RevisionMode.shuffle,
    );
  }

  /// Clear the revision queue.
  void clear() {
    state = const RevisionState();
  }
}

final revisionProvider =
    StateNotifierProvider<RevisionNotifier, RevisionState>((ref) {
  final db = ref.watch(databaseProvider);
  return RevisionNotifier(db);
});
