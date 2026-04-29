import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/database_provider.dart';
import '../../core/theme/app_typography.dart';
import '../../screens/hierarchy_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_highlighting/flutter_highlighting.dart';
import 'package:flutter_highlighting/themes/dracula.dart';
import 'package:flutter_highlighting/themes/github.dart';

class NodaMarkdown extends ConsumerWidget {
  final String data;
  final bool selectable;
  final MarkdownStyleSheet? styleSheet;
  final EdgeInsets padding;

  const NodaMarkdown({
    super.key,
    required this.data,
    this.selectable = true,
    this.styleSheet,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // High-stability layout-based centering:
    // Split the data into chunks of "normal markdown" and "centered markdown".
    final lines = data.split('\n');
    final List<Widget> chunks = [];
    String currentMarkdown = "";

    void flushMarkdown() {
      if (currentMarkdown.trim().isNotEmpty) {
        chunks.add(_buildMarkdownChunk(context, ref, currentMarkdown.trim(), colorScheme));
        currentMarkdown = "";
      }
    }

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('->')) {
        flushMarkdown();
        var content = trimmed.substring(2).trim();
        if (content.endsWith('<-')) {
          content = content.substring(0, content.length - 2).trim();
        }
        chunks.add(_buildCenteredChunk(context, ref, content, colorScheme));
      } else {
        currentMarkdown += "$line\n";
      }
    }
    flushMarkdown();

    if (chunks.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: chunks,
      ),
    );
  }

  Widget _buildCenteredChunk(BuildContext context, WidgetRef ref, String content, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: _buildMarkdownChunk(
          context, 
          ref, 
          content, 
          colorScheme, 
          textAlign: WrapAlignment.center,
        ),
      ),
    );
  }

  Widget _buildMarkdownChunk(BuildContext context, WidgetRef ref, String mdData, ColorScheme colorScheme, {WrapAlignment textAlign = WrapAlignment.start}) {
    return MarkdownBody(
      data: mdData,
      selectable: selectable,
      imageBuilder: (uri, title, alt) {
        if (uri == null) return const SizedBox.shrink();
        if (uri.scheme == 'file') {
          final path = uri.toFilePath();
          final file = File(path);
          if (!file.existsSync()) {
             return Text('File not found: $path', style: const TextStyle(color: Colors.red));
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              file,
              width: double.infinity,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image_rounded, color: colorScheme.error),
                      const SizedBox(height: 8),
                      Text('Image not found', style: TextStyle(color: colorScheme.error, fontSize: 12)),
                    ],
                  ),
                );
              },
            ),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(uri.toString()),
        );
      },
      extensionSet: md.ExtensionSet(
        [
          ...md.ExtensionSet.gitHubFlavored.blockSyntaxes,
          const md.TableSyntax(),
        ],
        [
          StyleTagSyntax(),
          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
          StaticHighlightSyntax(),
          WikiLinkSyntax(),
        ],

      ),
      builders: {

        'wikilink': WikiLinkBuilder(
          onTap: (title) async {
            final db = ref.read(databaseProvider);
            final node = await db.getNodeByTitle(title);
            if (node != null && context.mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HierarchyScreen(
                    rootNodeId: node.id,
                    rootNodeTitle: node.title,
                  ),
                ),
              );
            }
          },
        ),
        'blockquote': CalloutBuilder(colorScheme: colorScheme),
        'span': StyleBuilder(),
        'noda-highlight': StaticHighlightBuilder(
          color: colorScheme.brightness == Brightness.light
              ? const Color(0xFFE0E7FF) // Soft Lavender (Light)
              : colorScheme.primary.withOpacity(0.25), // Translucent Sapphire (Dark)
        ),
        'code': CodeElementBuilder(colorScheme: colorScheme),
      },
      styleSheet: styleSheet ?? MarkdownStyleSheet(
        textAlign: textAlign,
        h1Align: textAlign,
        h2Align: textAlign,
        h3Align: textAlign,
        p: AppTypography.bodyLarge(color: colorScheme.onSurface.withValues(alpha: 0.9)),
        h1: AppTypography.headingLarge(color: colorScheme.primary).copyWith(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
        h2: AppTypography.headingMedium(color: colorScheme.onSurface).copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
        h3: AppTypography.headingSmall(color: colorScheme.onSurface).copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        h1Padding: const EdgeInsets.only(top: 12, bottom: 8),
        h2Padding: const EdgeInsets.only(top: 10, bottom: 6),
        h3Padding: const EdgeInsets.only(top: 8, bottom: 4),
        blockSpacing: 20,
        listBullet: AppTypography.bodyLarge(color: colorScheme.primary).copyWith(
          fontWeight: FontWeight.w900,
        ),
        strong: const TextStyle(fontWeight: FontWeight.w800),
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
        codeblockPadding: const EdgeInsets.all(0),
        codeblockDecoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(left: BorderSide(color: colorScheme.primary.withOpacity(0.4), width: 8)),
          color: colorScheme.primary.withOpacity(0.05),
          borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class CalloutBuilder extends MarkdownElementBuilder {
  final ColorScheme colorScheme;

  CalloutBuilder({required this.colorScheme});

  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final text = element.textContent;
    
    // Check for Obsidian callout syntax: [!TYPE]
    final match = RegExp(r'^\[!(.*?)\]').firstMatch(text);
    if (match != null) {
      final type = (match[1] ?? 'QUOTE').toUpperCase();
      final content = text.substring(match.end).trim();
      
      Color color;
      IconData icon;
      
      switch (type) {
        case 'INFO':
        case 'NOTE':
          color = Colors.blueAccent;
          icon = Icons.info_outline_rounded;
          break;
        case 'WARNING':
        case 'CAUTION':
        case 'ATTENTION':
          color = Colors.orangeAccent;
          icon = Icons.warning_amber_rounded;
          break;
        case 'ERROR':
        case 'DANGER':
        case 'FAILURE':
          color = Colors.redAccent;
          icon = Icons.error_outline_rounded;
          break;
        case 'SUCCESS':
        case 'TIP':
        case 'CHECK':
          color = Colors.greenAccent;
          icon = Icons.check_circle_outline_rounded;
          break;
        default:
          color = colorScheme.primary;
          icon = Icons.format_quote_rounded;
      }

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  type,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(content, style: preferredStyle),
          ],
        ),
      );
    }

    // Default blockquote
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.05),
        border: Border(left: BorderSide(
          color: colorScheme.primary.withOpacity(0.4), 
          width: 8
        )),
        borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
      ),
      child: Text(text, style: preferredStyle?.copyWith(
        fontStyle: FontStyle.italic,
        fontSize: 17,
        height: 1.6,
        color: colorScheme.onSurface.withValues(alpha: 0.85),
      )),
    );
  }
}

class WikiLinkSyntax extends md.InlineSyntax {
  WikiLinkSyntax() : super(r'\[\[(.*?)\]\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final title = match[1] ?? '';
    final element = md.Element.text('wikilink', title);
    parser.addNode(element);
    return true;
  }
}

class WikiLinkBuilder extends MarkdownElementBuilder {
  final Function(String) onTap;

  WikiLinkBuilder({required this.onTap});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final title = element.textContent;
    return InkWell(
      onTap: () => onTap(title),
      child: Text(
        title,
        style: preferredStyle?.copyWith(
          color: Colors.blueAccent,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}

class StyleTagSyntax extends md.InlineSyntax {
  StyleTagSyntax() : super(r'<span\b([^>]*?)>([\s\S]*?)</span>', caseSensitive: false);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final attributesStr = match[1] ?? '';
    final content = match[2] ?? '';
    
    // Extract style attribute specifically
    final styleMatch = RegExp(r'''style=["']([^"']*)["']''', caseSensitive: false).firstMatch(attributesStr);
    final styleStr = styleMatch?.group(1) ?? '';



    final element = md.Element('span', md.InlineParser(content, parser.document).parse());
    element.attributes['style'] = styleStr;
    parser.addNode(element);
    return true;
  }
}


class StyleBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final styleStr = element.attributes['style'] ?? '';
    final styles = _parseStyle(styleStr);
    final textContent = element.textContent;
    
    TextStyle base = (preferredStyle ?? const TextStyle());
    
    // Font Properties
    if (styles.containsKey('font-size')) {
      final size = double.tryParse((styles['font-size'] ?? "").replaceAll('px', '').trim());
      if (size != null) base = base.copyWith(fontSize: size);
    }
    
    if (styles.containsKey('font-weight')) {
      final weight = (styles['font-weight'] ?? "").trim();
      if (weight == 'bold' || weight == '900') base = base.copyWith(fontWeight: FontWeight.w900);
      else if (weight == '800') base = base.copyWith(fontWeight: FontWeight.w800);
      else if (weight == '700') base = base.copyWith(fontWeight: FontWeight.w700);
    }

    if (styles.containsKey('color')) {
      base = base.copyWith(color: _parseColor(styles['color'] ?? ""));
    }

    if (styles.containsKey('letter-spacing')) {
      final spacing = double.tryParse((styles['letter-spacing'] ?? "").replaceAll('px', '').trim());
      if (spacing != null) base = base.copyWith(letterSpacing: spacing);
    }

    if (styles.containsKey('line-height')) {
      final height = double.tryParse((styles['line-height'] ?? "").trim());
      if (height != null) base = base.copyWith(height: height);
    }

    if (styles.containsKey('font-style')) {
      if (styles['font-style'] == 'italic') base = base.copyWith(fontStyle: FontStyle.italic);
    }

    if (styles.containsKey('text-decoration')) {
      final dec = (styles['text-decoration'] ?? "").trim();
      if (dec == 'underline') base = base.copyWith(decoration: TextDecoration.underline);
      else if (dec == 'line-through') base = base.copyWith(decoration: TextDecoration.lineThrough);
    }

    // Layout Properties
    Color? bgColor;
    if (styles.containsKey('background-color')) {
      bgColor = _parseColor(styles['background-color'] ?? "");
    }

    double? padding;
    if (styles.containsKey('padding')) {
      padding = double.tryParse((styles['padding'] ?? "").replaceAll('px', '').trim());
    }

    double? radius;
    if (styles.containsKey('border-radius')) {
      radius = double.tryParse((styles['border-radius'] ?? "").replaceAll('px', '').trim());
    }

    // Deep parsing for highlights and bold within style tag
    final parts = textContent.split('==');
    final List<TextSpan> finalChildren = [];

    for (int i = 0; i < parts.length; i++) {
      final isHighlight = i % 2 == 1;
      final partText = parts[i];
      
      final boldParts = partText.split('**');
      for (int j = 0; j < boldParts.length; j++) {
        final isBold = j % 2 == 1;
        TextStyle segmentStyle = isHighlight 
          ? base.copyWith(
              backgroundColor: (base.color ?? Colors.amber).withOpacity(0.15),
              fontWeight: FontWeight.w900,
            ) 
          : base;
        
        if (isBold) {
          segmentStyle = segmentStyle.copyWith(fontWeight: FontWeight.w900);
        }

        finalChildren.add(TextSpan(
          text: boldParts[j],
          style: segmentStyle,
        ));
      }
    }

    Widget content = Text.rich(
      TextSpan(children: finalChildren),
      textAlign: styles['text-align'] == 'center' ? TextAlign.center : TextAlign.left,
    );

    if (bgColor != null || padding != null || radius != null || styles['text-align'] == 'center') {
      return Container(
        width: styles['text-align'] == 'center' ? double.infinity : null,
        alignment: styles['text-align'] == 'center' ? Alignment.center : null,
        padding: EdgeInsets.all(padding ?? 0),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(radius ?? 0),
        ),
        child: content,
      );
    }

    return content;
  }

  Color? _parseColor(String colorStr) {
    colorStr = colorStr.trim();
    if (colorStr.startsWith('#')) {
      final colorHex = int.tryParse(colorStr.substring(1), radix: 16);
      if (colorHex != null) return Color(0xFF000000 | colorHex);
    }
    return null;
  }

  Map<String, String> _parseStyle(String style) {
    final Map<String, String> result = {};
    final parts = style.split(';');
    for (var part in parts) {
      final kv = part.split(':');
      if (kv.length == 2) {
        result[kv[0].trim().toLowerCase()] = kv[1].trim();
      }
    }
    return result;
  }
}

class StaticHighlightSyntax extends md.InlineSyntax {
  StaticHighlightSyntax() : super(r'==(.+?)==');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final content = match[1] ?? '';
    parser.addNode(md.Element('noda-highlight', md.InlineParser(content, parser.document).parse()));
    return true;
  }
}

class StaticHighlightBuilder extends MarkdownElementBuilder {
  final Color color;

  StaticHighlightBuilder({required this.color});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return Text.rich(
      TextSpan(
        text: element.textContent,
        style: (preferredStyle ?? const TextStyle()).copyWith(
          backgroundColor: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class CodeElementBuilder extends MarkdownElementBuilder {
  final ColorScheme colorScheme;
  CodeElementBuilder({required this.colorScheme});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final String content = element.textContent;
    final bool isBlock = content.contains('\n') || (element.attributes['class']?.startsWith('language-') ?? false);
    
    if (!isBlock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          content,
          style: GoogleFonts.firaCode(
            fontSize: 13,
            color: colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    String language = 'plaintext';
    final String? className = element.attributes['class'];
    if (className != null && className.startsWith('language-')) {
      language = className.replaceFirst('language-', '').trim().toLowerCase();
    }
    
    // Workaround: Use xml highlighter for html to avoid specific null-check crashes
    if (language == 'html') language = 'xml';
    
    if (language.isEmpty) language = 'plaintext';


    final Map<String, TextStyle> activeTheme = colorScheme.brightness == Brightness.dark 
        ? draculaTheme 
        : Map<String, TextStyle>.from(githubTheme);

    if (colorScheme.brightness == Brightness.light) {
      final rootStyle = activeTheme['root'] ?? const TextStyle();
      activeTheme['root'] = rootStyle.copyWith(
        backgroundColor: const Color(0xFFF1F5F9),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: HighlightView(
          content.trim(),
          languageId: language,
          theme: activeTheme,
          padding: const EdgeInsets.all(20),
          textStyle: GoogleFonts.firaCode(
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

