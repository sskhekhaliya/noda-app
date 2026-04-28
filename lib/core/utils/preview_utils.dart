import 'dart:convert';

/// Utilities for processing markdown and Quill JSON content for previews.
class PreviewUtils {
  /// Strips markdown syntax and converts Quill Delta JSON to plain text.
  static String stripMarkdown(String? content) {
    if (content == null || content.isEmpty) return '';

    // Handle Quill Delta JSON
    if (content.trim().startsWith('[{"insert":')) {
      try {
        final List<dynamic> json = jsonDecode(content);
        return json.map((part) => part['insert'] ?? '').join().trim();
      } catch (_) {}
    }

    // Handle raw Markdown
    return content
        // 0. Remove Centering markers (-> text <-)
        .replaceAll(RegExp(r'->|<-'), '')
        // 1. Remove Horizontal Rules
        .replaceAll(RegExp(r'^\s*[-*_]{3,}\s*$', multiLine: true), '')
        // 2. Remove Headers (# Header)
        .replaceAll(RegExp(r'^#+\s+', multiLine: true), '')
        // 3. Remove Images (![alt](url))
        .replaceAll(RegExp(r'!\[.*?\]\(.*?\)', multiLine: true), '')
        // 4. Remove Links but keep text ([text](url))
        .replaceAllMapped(RegExp(r'\[(.*?)\]\(.*?\)'), (m) => m[1] ?? '')
        // 5. Remove Bold/Italic (***bolditalic***, **bold**, *italic*)
        .replaceAllMapped(RegExp(r'[*_]{1,3}([^*_]+)[*_]{1,3}'), (m) => m[1] ?? '')
        // 6. Remove Highlights (==text==)
        .replaceAllMapped(RegExp(r'==([^=]+)=='), (m) => m[1] ?? '')
        // 7. Remove Custom Highlight tags (<highlight>...</highlight>)
        .replaceAllMapped(RegExp(r'<highlight>(.*?)</highlight>'), (m) => m[1] ?? '')
        // 8. Remove Inline Code (`code`)
        .replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m[1] ?? '')
        // 9. Remove Code Blocks (```code```)
        .replaceAll(RegExp(r'```[\s\S]*?```'), '')
        // 10. Remove Blockquotes (> text)
        .replaceAll(RegExp(r'^>\s+', multiLine: true), '')
        // 11. Remove HTML tags
        .replaceAll(RegExp(r'<[^>]*>'), '')
        // 12. Remove List markers (*, -, 1.)
        .replaceAll(RegExp(r'^[*-]\s+', multiLine: true), '')
        .replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '')
        // 13. Convert newlines to spaces
        .replaceAll(RegExp(r'\n+'), ' ')
        // 14. Collapse multiple spaces
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
