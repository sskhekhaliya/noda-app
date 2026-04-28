import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;

import '../widgets/common/noda_markdown.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../data/database/app_database.dart';
import '../providers/database_provider.dart';

class CreateCardScreen extends ConsumerStatefulWidget {
  const CreateCardScreen({
    super.key,
    required this.parentId,
    this.cardId,
    this.initialFront,
    this.initialBack,
  });

  final String parentId;
  final String? cardId;
  final String? initialFront;
  final String? initialBack;

  @override
  ConsumerState<CreateCardScreen> createState() => _CreateCardScreenState();
}

class _CreateCardScreenState extends ConsumerState<CreateCardScreen> {
  late final TextEditingController _frontController;
  late final TextEditingController _backController;
  late final PageController _pageController;
  late final FocusNode _frontFocusNode;
  late final FocusNode _backFocusNode;
  bool _isPreviewMode = false;
  int _currentIndex = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _frontController = TextEditingController(text: widget.initialFront);
    _backController = TextEditingController(text: widget.initialBack);
    _pageController = PageController();
    _frontFocusNode = FocusNode();
    _backFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _frontController.dispose();
    _backController.dispose();
    _pageController.dispose();
    _frontFocusNode.dispose();
    _backFocusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final front = _frontController.text.trim();
    final back = _backController.text.trim();

    if (front.isEmpty || back.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both question and answer.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = ref.read(databaseProvider);
      
      // Uniqueness check
      final exists = await db.doesCardExistInParent(widget.parentId, front, back, excludeId: widget.cardId);
      if (exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This exact card already exists in this topic.')),
          );
        }
        return;
      }

      if (widget.cardId == null) {
        await db.insertCard(CardsCompanion(
          id: Value(const Uuid().v4()),
          parentId: Value(widget.parentId),
          front: Value(front),
          back: Value(back),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ));
      } else {
        await db.updateCard(widget.cardId!, CardsCompanion(
          front: Value(front),
          back: Value(back),
          updatedAt: Value(DateTime.now()),
        ));
      }

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: _buildSegmentedControl(colorScheme),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isPreviewMode ? Icons.edit_note_outlined : Icons.remove_red_eye_outlined,
              color: _isPreviewMode ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            tooltip: _isPreviewMode ? 'Switch to Edit' : 'Switch to Preview',
            onPressed: () => setState(() => _isPreviewMode = !_isPreviewMode),
          ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            IconButton(
              icon: Icon(Icons.check_rounded, color: colorScheme.primary),
              tooltip: 'Save Card',
              onPressed: _save,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          children: [
            _buildCardPage(
              controller: _frontController,
              hintText: 'Type question here...',
              isFront: true,
            ),
            _buildCardPage(
              controller: _backController,
              hintText: 'Type answer here...',
              isFront: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedControl(ColorScheme colorScheme) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _pageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: _currentIndex == 0 ? colorScheme.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: _currentIndex == 0 ? [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                  ] : [],
                ),
                alignment: Alignment.center,
                child: Text('FRONT', style: AppTypography.caption().copyWith(
                  fontWeight: _currentIndex == 0 ? FontWeight.bold : FontWeight.normal,
                  color: _currentIndex == 0 ? colorScheme.primary : colorScheme.onSurfaceVariant,
                )),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _pageController.animateToPage(1, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: _currentIndex == 1 ? colorScheme.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: _currentIndex == 1 ? [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                  ] : [],
                ),
                alignment: Alignment.center,
                child: Text('BACK', style: AppTypography.caption().copyWith(
                  fontWeight: _currentIndex == 1 ? FontWeight.bold : FontWeight.normal,
                  color: _currentIndex == 1 ? colorScheme.primary : colorScheme.onSurfaceVariant,
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardPage({
    required TextEditingController controller,
    required String hintText,
    required bool isFront,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!_isPreviewMode) {
            FocusScope.of(context).requestFocus(isFront ? _frontFocusNode : _backFocusNode);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: isFront ? colorScheme.surfaceContainerLowest : colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFront ? 'QUESTION' : 'ANSWER',
                style: AppTypography.caption(
                  color: colorScheme.primary.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isPreviewMode
                    ? SingleChildScrollView(child: _buildMarkdownPreview(controller.text, isFront))
                    : TextField(
                        controller: controller,
                        focusNode: isFront ? _frontFocusNode : _backFocusNode,
                        expands: true,
                        maxLines: null,
                        textAlign: TextAlign.start,
                        textAlignVertical: TextAlignVertical.top,
                        style: AppTypography.bodyLarge(),
                        decoration: InputDecoration(
                          hintText: hintText,
                          hintStyle: TextStyle(color: colorScheme.outline.withOpacity(0.4)),
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                        autofocus: isFront && controller.text.isEmpty,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarkdownPreview(String text, bool isFront) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (text.trim().isEmpty) {
      return Text(
        '*Empty*',
        style: AppTypography.bodyMedium(color: colorScheme.outline.withOpacity(0.5)),
      );
    }

    return NodaMarkdown(
      data: text,
      selectable: true,
    );
  }
}

