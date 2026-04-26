import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

class IconPickerGrid extends StatelessWidget {
  final String? selectedIcon;
  final ValueChanged<String> onIconSelected;

  const IconPickerGrid({
    super.key,
    required this.selectedIcon,
    required this.onIconSelected,
  });

  static const List<String> curatedIcons = [
    '🧬', '📚', '💻', '🌍', '🧪', '🎨', '🎭', '🎬', '🚀', '💡',
    '📝', '🗝️', '🛡️', '🏹', '🧘', '☕', '🌲', '🏛️', '🎻', '🛰️',
    '🔬', '🔭', '📐', '📒', '📖', '🔖', '📎', '📌', '📍', '📅',
    '🗓️', '⏰', '⏳', '⌛', '📡', '🔋', '🔌', '🖥️', '⌨️', '🖱️',
    '📷', '📹', '📻', '📺', '⌚', '📱', '☎️', '🔢', '⚙️', '🛠️',
  ];

  static void showFullEmojiPicker(BuildContext context, ValueChanged<String> onIconSelected) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Symbol Library',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: curatedIcons.length,
                itemBuilder: (context, index) {
                  final icon = curatedIcons[index];
                  return GestureDetector(
                    onTap: () {
                      onIconSelected(icon);
                      Navigator.pop(context);
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(icon, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final initialIcons = curatedIcons.take(7).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: initialIcons.length + 1,
      itemBuilder: (context, index) {
        if (index == initialIcons.length) {
          return GestureDetector(
            onTap: () => showFullEmojiPicker(context, onIconSelected),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  style: BorderStyle.solid,
                ),
              ),
              child: Icon(Icons.add_rounded, color: colorScheme.outline),
            ),
          );
        }

        final icon = initialIcons[index];
        final isSelected = selectedIcon == icon;

        return GestureDetector(
          onTap: () => onIconSelected(icon),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? colorScheme.primaryContainer : colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : null,
            ),
            child: Text(
              icon,
              style: const TextStyle(fontSize: 28),
            ),
          ),
        );
      },
    );
  }
}

class ColorPickerGrid extends StatelessWidget {
  final int? selectedColor;
  final ValueChanged<int> onColorSelected;

  const ColorPickerGrid({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
  });

  static const List<int> colors = [
    0xFF004F56, // brandOcean
    0xFF14B8A6, // brandTeal
    0xFF38BDF8, // brandBlue
    0xFF85D3DD,
    0xFFAFDDFE,
    0xFFF48FB1,
    0xFFC7E7FF,
  ];

  void _showColorPickerDialog(BuildContext context) {
    Color pickerColor = Color(selectedColor ?? 0xFF004F56);
    final hexController = TextEditingController(
      text: '#${pickerColor.value.toRadixString(16).toUpperCase().substring(2)}',
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Theme Tone'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ColorPicker(
                  pickerColor: pickerColor,
                  onColorChanged: (color) {
                    setDialogState(() {
                      pickerColor = color;
                      hexController.text = '#${color.value.toRadixString(16).toUpperCase().substring(2)}';
                    });
                  },
                  pickerAreaHeightPercent: 0.8,
                  enableAlpha: false,
                  displayThumbColor: true,
                  showLabel: false, // Remove confusing labels & dropdown
                  paletteType: PaletteType.hsvWithHue,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: hexController,
                  onChanged: (value) {
                    try {
                      final str = value.replaceAll('#', '');
                      if (str.length == 6) {
                        final color = Color(int.parse('FF$str', radix: 16));
                        setDialogState(() => pickerColor = color);
                      }
                    } catch (_) {}
                  },
                  decoration: InputDecoration(
                    labelText: 'Hex Code',
                    hintText: '#000000',
                    prefixIcon: const Icon(Icons.tag_rounded),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                onColorSelected(pickerColor.value);
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final noda = theme.extension<NodaThemeExtension>()!;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: colors.length + 1,
      itemBuilder: (context, index) {
        if (index == colors.length) {
          return GestureDetector(
            onTap: () => _showColorPickerDialog(context),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Icon(Icons.colorize_rounded, size: 16, color: colorScheme.outline),
            ),
          );
        }

        final colorValue = colors[index];
        final isSelected = selectedColor == colorValue;
        final isGradient = index == 0;

        return GestureDetector(
          onTap: () => onColorSelected(colorValue),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: isSelected ? (Matrix4.identity()..scale(1.1)) : Matrix4.identity(),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isGradient ? noda.brandGradient : null,
              color: isGradient ? null : Color(colorValue),
              border: isSelected
                  ? Border.all(
                      color: isGradient ? colorScheme.primary : Color(colorValue),
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignOutside,
                    )
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: (isGradient ? colorScheme.primary : Color(colorValue)).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                : null,
          ),
        );
      },
    );
  }
}
