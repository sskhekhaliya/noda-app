import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../data/database/app_database.dart';
import '../../providers/database_provider.dart';

/// Full-screen modal for picking a parent folder from the hierarchy.
class HierarchyPickerModal {
  HierarchyPickerModal._();

  static void show({
    required BuildContext context,
    required WidgetRef ref,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _PickerContent(
          ref: ref,
          scrollController: scrollController,
          onSelected: (id) {
            Navigator.pop(context);
            onSelected(id);
          },
        ),
      ),
    );
  }
}

class _PickerContent extends StatefulWidget {
  const _PickerContent({
    required this.ref,
    required this.scrollController,
    required this.onSelected,
  });

  final WidgetRef ref;
  final ScrollController scrollController;
  final ValueChanged<String> onSelected;

  @override
  State<_PickerContent> createState() => _PickerContentState();
}

class _PickerContentState extends State<_PickerContent> {
  final _searchController = TextEditingController();
  List<Node> _searchResults = [];
  bool _isSearching = false;
  List<Node> _rootNodes = [];
  bool _isLoading = true;

  // Expanded state for folders
  final Map<String, List<Node>> _expandedChildren = {};
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    _loadRoots();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadRoots() async {
    final db = widget.ref.read(databaseProvider);
    final roots = await db.watchRootNodes().first;
    if (mounted) {
      setState(() {
        _rootNodes = roots;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);
    final db = widget.ref.read(databaseProvider);
    db.searchFolders(query).then((results) {
      if (mounted) {
        setState(() => _searchResults = results);
      }
    });
  }

  Future<void> _toggleExpand(String nodeId) async {
    if (_expandedIds.contains(nodeId)) {
      setState(() => _expandedIds.remove(nodeId));
      return;
    }

    final db = widget.ref.read(databaseProvider);
    final children = await db.getChildrenOf(nodeId);
    setState(() {
      _expandedIds.add(nodeId);
      _expandedChildren[nodeId] = children;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle + title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select Parent Module',
                  style: AppTypography.headingSmall(
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search modules...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _isSearching
                    ? _buildSearchResults()
                    : _buildTree(widget.scrollController),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'No modules found.',
          style: AppTypography.bodyMedium(
            color: Theme.of(context)
                .extension<NodaThemeExtension>()!
                .textSecondary,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: widget.scrollController,
      itemCount: _searchResults.length,
      itemBuilder: (ctx, i) {
        final node = _searchResults[i];
        return _FolderTile(
          node: node,
          depth: 0,
          isExpanded: false,
          onTap: () => widget.onSelected(node.id),
          onExpand: null,
        );
      },
    );
  }

  Widget _buildTree(ScrollController scrollController) {
    return ListView.builder(
      controller: scrollController,
      itemCount: _rootNodes.length,
      itemBuilder: (ctx, i) => _buildNodeTree(_rootNodes[i], 0),
    );
  }

  Widget _buildNodeTree(Node node, int depth) {
    final isFolder = node.type == 'FOLDER';
    final isExpanded = _expandedIds.contains(node.id);
    final children = _expandedChildren[node.id] ?? [];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FolderTile(
          node: node,
          depth: depth,
          isExpanded: isExpanded,
          onTap: isFolder ? () => widget.onSelected(node.id) : null,
          onExpand: isFolder ? () => _toggleExpand(node.id) : null,
        ),
        if (isExpanded)
          ...children.map((child) => _buildNodeTree(child, depth + 1)),
      ],
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.node,
    required this.depth,
    required this.isExpanded,
    this.onTap,
    this.onExpand,
  });

  final Node node;
  final int depth;
  final bool isExpanded;
  final VoidCallback? onTap;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final noda = Theme.of(context).extension<NodaThemeExtension>()!;
    final isFolder = node.type == 'FOLDER';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16.0 + (depth * 24.0),
          right: 16,
          top: 10,
          bottom: 10,
        ),
        child: Row(
          children: [
            if (isFolder && onExpand != null) ...[
              GestureDetector(
                onTap: onExpand,
                child: AnimatedRotation(
                  turns: isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: noda.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(
              isFolder ? Icons.view_module_rounded : Icons.description_rounded,
              size: 20,
              color: isFolder ? noda.iconActive : noda.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                node.title,
                style: AppTypography.subtitle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isFolder)
              Icon(
                Icons.add_circle_outline_rounded,
                size: 20,
                color: noda.iconActive,
              ),
          ],
        ),
      ),
    );
  }
}
