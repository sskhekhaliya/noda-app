import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';

/// State class for TTS playback and highlighting.
class TtsState {
  final String? currentText;
  final String? cleanedText;
  final int? start;
  final int? end;
  final int? mappedStart; // Offset in raw text
  final int? mappedEnd;   // Offset in raw text
  final int lastProgress; // Last character offset spoken
  final bool isPlaying;

  TtsState({
    this.currentText,
    this.cleanedText,
    this.start,
    this.end,
    this.mappedStart,
    this.mappedEnd,
    this.lastProgress = 0,
    this.isPlaying = false,
  });

  TtsState copyWith({
    String? currentText,
    String? cleanedText,
    int? start,
    int? end,
    int? mappedStart,
    int? mappedEnd,
    int? lastProgress,
    bool? isPlaying,
  }) {
    return TtsState(
      currentText: currentText ?? this.currentText,
      cleanedText: cleanedText ?? this.cleanedText,
      start: start ?? this.start,
      end: end ?? this.end,
      mappedStart: mappedStart ?? this.mappedStart,
      mappedEnd: mappedEnd ?? this.mappedEnd,
      lastProgress: lastProgress ?? this.lastProgress,
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
      final actualStart = start + state.lastProgress;
      final actualEnd = end + state.lastProgress;
      
      state = state.copyWith(
        start: actualStart, 
        end: actualEnd,
        mappedStart: _mapOffset(state.currentText ?? "", actualStart),
        mappedEnd: _mapOffset(state.currentText ?? "", actualEnd),
      );
    });
  }

  int _mapOffset(String raw, int cleanOffset) {
    if (cleanOffset <= 0) return 0;
    int cleanIdx = 0;
    int rawIdx = 0;
    
    final markers = RegExp(r'^(\*\*|__|==|~~|\*|_|#+|`+|!?\[|\]\(.*?\)|>|^\s*([\*\-\+]|\d+\.)\s+)');
    
    while (rawIdx < raw.length && cleanIdx < cleanOffset) {
      final remaining = raw.substring(rawIdx);
      final match = markers.firstMatch(remaining);
      
      if (match != null) {
        rawIdx += match.end;
      } else {
        rawIdx++;
        cleanIdx++;
      }
    }
    return rawIdx;
  }

  Future<void> speak(String text, {bool resume = false}) async {
    if (state.isPlaying) {
      await _flutterTts.stop();
    }

    final isSameText = state.currentText == text;
    final startOffset = (resume && isSameText) ? state.start ?? 0 : 0;
    
    final fullCleanText = _cleanMarkdownForSpeech(text);
    final textToSpeak = startOffset < fullCleanText.length ? fullCleanText.substring(startOffset) : fullCleanText;

    state = state.copyWith(
      currentText: text, 
      cleanedText: fullCleanText,
      isPlaying: true, 
      lastProgress: startOffset,
      start: startOffset,
      end: startOffset,
    );
    await _flutterTts.speak(textToSpeak);
  }

  String _cleanMarkdownForSpeech(String raw) {
    String text = raw;
    if (raw.startsWith('[{"insert":')) {
      try {
        final List<dynamic> json = jsonDecode(raw);
        text = json.map((part) => part['insert'] ?? '').join();
      } catch (_) {}
    }

    // Explicitly remove markers in order of complexity
    text = text

        .replaceAll(RegExp(r'<(?:.|\n)*?>'), '') // Remove all HTML tags including multi-line
        .replaceAllMapped(RegExp(r'!?\[(.*?)\]\(.*?\)?'), (m) => m[1]!) // Links
        .replaceAll(RegExp(r'\*\*|__|==|~~'), '') // 2-char markers
        .replaceAll(RegExp(r'\*|_|#|`|>'), '') // 1-char markers
        .replaceAll(RegExp(r'^\s*([\*\-\+]|\d+\.)\s+', multiLine: true), '') // Lists
        .replaceAll(RegExp(r'^\s*([=\-\*_]){3,}\s*$', multiLine: true), '') // HRs
        .replaceAll(RegExp(r'[-=]>|<[-=]'), ' ') // Arrows
        .replaceAll(RegExp(r'&[a-z]+;|&#[0-9]+;'), ''); // HTML entities


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
