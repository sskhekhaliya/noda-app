import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// State class for TTS playback and highlighting.
class TtsState {
  final String? currentText;
  final int? start;
  final int? end;
  final bool isPlaying;

  TtsState({
    this.currentText,
    this.start,
    this.end,
    this.isPlaying = false,
  });

  TtsState copyWith({
    String? currentText,
    int? start,
    int? end,
    bool? isPlaying,
  }) {
    return TtsState(
      currentText: currentText ?? this.currentText,
      start: start ?? this.start,
      end: end ?? this.end,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}

/// Provider for managing TTS across the app.
final ttsProvider = StateNotifierProvider<TtsNotifier, TtsState>((ref) {
  return TtsNotifier();
});

class TtsNotifier extends StateNotifier<TtsState> {
  final FlutterTts _flutterTts = FlutterTts();

  TtsNotifier() : super(TtsState()) {
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      state = state.copyWith(isPlaying: true);
    });

    _flutterTts.setCompletionHandler(() {
      state = state.copyWith(isPlaying: false, start: null, end: null);
    });

    _flutterTts.setCancelHandler(() {
      state = state.copyWith(isPlaying: false, start: null, end: null);
    });

    _flutterTts.setErrorHandler((msg) {
      state = state.copyWith(isPlaying: false, start: null, end: null);
    });

    _flutterTts.setProgressHandler((String text, int start, int end, String word) {
      state = state.copyWith(start: start, end: end);
    });
  }

  Future<void> speak(String text) async {
    if (state.isPlaying) {
      await _flutterTts.stop();
    }

    final cleanText = _cleanMarkdownForSpeech(text);
    state = state.copyWith(currentText: text, isPlaying: true);
    await _flutterTts.speak(cleanText);
  }

  String _cleanMarkdownForSpeech(String raw) {
    // 1. Replace Markdown markers with spaces to preserve character indices for highlighting
    String cleaned = raw.replaceAllMapped(RegExp(r'([#*_~`\[\]\(\)])'), (match) {
      return ' ' * match.group(0)!.length;
    });

    // 2. Replace Emojis with spaces to silence them without breaking character offsets
    // This covers most common emoji ranges in Unicode.
    return cleaned.replaceAllMapped(
      RegExp(
        r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{2702}-\u{27B0}\u{24C2}-\u{1F251}\u{1F900}-\u{1F9FF}\u{1FA70}-\u{1FAFF}]',
        unicode: true,
      ),
      (match) => ' ' * match.group(0)!.length,
    );
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    state = state.copyWith(isPlaying: false, start: null, end: null);
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }
}
