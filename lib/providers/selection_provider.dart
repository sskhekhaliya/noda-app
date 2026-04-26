import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectionProvider = StateNotifierProvider<SelectionNotifier, Set<String>>((ref) {
  return SelectionNotifier();
});

class SelectionNotifier extends StateNotifier<Set<String>> {
  SelectionNotifier() : super({});

  void toggle(String id) {
    if (state.contains(id)) {
      state = {...state}..remove(id);
    } else {
      state = {...state, id};
    }
  }

  void select(String id) {
    if (!state.contains(id)) {
      state = {...state, id};
    }
  }

  void clear() {
    state = {};
  }

  bool isSelected(String id) => state.contains(id);
  bool get hasSelection => state.isNotEmpty;
  int get count => state.length;
}
