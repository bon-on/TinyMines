import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../art/garden_palette.dart';
import '../game/garden_tools.dart';
import 'garden_ui.dart';

IconData toolIcon(GardenTool tool) => switch (tool) {
  GardenTool.sunflower => Icons.local_florist_rounded,
  GardenTool.lantern => Icons.lightbulb_rounded,
  GardenTool.clover => Icons.eco_rounded,
  GardenTool.can => Icons.water_drop_rounded,
};

/// Modal card shown between Garden Run stages: pick one of the offered tools
/// (tap, or keys 1-3). Never expires on its own.
class ToolPickerOverlay extends StatelessWidget {
  const ToolPickerOverlay({
    super.key,
    required this.palette,
    required this.tools,
    required this.stage,
    required this.onPick,
  });

  final GardenPalette palette;
  final List<GardenTool> tools;

  /// The stage that was just cleared.
  final int stage;
  final ValueChanged<GardenTool> onPick;

  static const _keys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
  ];

  @override
  Widget build(BuildContext context) {
    return BlockSemantics(
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final i = _keys.indexOf(event.logicalKey);
          if (i < 0 || i >= tools.length) return KeyEventResult.ignored;
          onPick(tools[i]);
          return KeyEventResult.handled;
        },
        child: ColoredBox(
          key: const ValueKey('tool-picker'),
          color: const Color(0xAA000000),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: GardenPanel(
                    palette: palette,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Stage $stage cleared!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pick a garden tool for the rest of the run',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: palette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (var i = 0; i < tools.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          _ToolCard(
                            palette: palette,
                            tool: tools[i],
                            index: i + 1,
                            onTap: () => onPick(tools[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.palette,
    required this.tool,
    required this.index,
    required this.onTap,
  });

  final GardenPalette palette;
  final GardenTool tool;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${tool.label}: ${tool.blurb}',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: palette.accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: ValueKey('tool-${tool.name}'),
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(toolIcon(tool), size: 34, color: palette.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$index  ${tool.label}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: palette.textPrimary,
                        ),
                      ),
                      Text(
                        tool.blurb,
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
