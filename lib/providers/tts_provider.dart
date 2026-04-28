import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';

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
    // 1. First extract plain text if it's Quill JSON
    String text = raw;
    if (raw.startsWith('[{"insert":')) {
      try {
        final List<dynamic> json = jsonDecode(raw);
        text = json.map((part) => part['insert'] ?? '').join();
      } catch (_) {}
    }

    // 2. Remove HTML tags
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');

    // 3. Remove Markdown markers but keep the content inside
    text = text
        .replaceAll(RegExp(r'#+\s+'), '') // Headers
        .replaceAllMapped(RegExp(r'(\*\*|__|==|~~|\*|_)(.*?)\1'), (m) => m[2]!) // Bold/Italic/etc
        .replaceAllMapped(RegExp(r'!?\[(.*?)\]\(.*?\)?'), (m) => m[1]!) // Links/Images
        .replaceAllMapped(RegExp(r'`{1,3}(.*?)`{1,3}'), (m) => m[1]!) // Code
        .replaceAll(RegExp(r'^\s*([\*\-\+>]|\d+\.)\s+', multiLine: true), '') // Lists/Quotes
        .replaceAll(RegExp(r'^\s*([=\-\*_]){3,}\s*$', multiLine: true), '') // HRs
        .replaceAll(RegExp(r'[-=]>|<[-=]'), ' '); // Arrows

    return text.trim();
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
