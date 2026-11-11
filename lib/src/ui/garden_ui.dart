import 'package:flutter/material.dart';

import '../art/garden_palette.dart';
import '../art/garden_tile_art.dart';
import '../game/difficulty.dart';

/// "m:ss" clock text.
String formatTime(int seconds) {
  final minutes = seconds ~/ 60;
  final remaining = seconds % 60;
  return '$minutes:${remaining.toString().padLeft(2, '0')}';
}

/// Short month-day label, e.g. "Nov 2".
String formatDay(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

/// Rounded card in the theme's panel color with a soft drop shadow.
class GardenPanel extends StatelessWidget {
  const GardenPanel({
    super.key,
    required this.palette,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 20,
  });

  final GardenPalette palette;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: palette.panelBorder, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2A000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Small upper-case caption above panel values.
class PanelCaption extends StatelessWidget {
  const PanelCaption(this.text, {super.key, required this.palette});

  final String text;
  final GardenPalette palette;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: palette.textSecondary,
        fontSize: 11,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

/// Rounded progress bar with an accent fill.
class GardenProgressBar extends StatelessWidget {
  const GardenProgressBar({
    super.key,
    required this.palette,
    required this.value,
    this.height = 10,
  });

  final GardenPalette palette;
  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fill = palette.accent;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: palette.textSecondary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(height),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0),
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(fill, Colors.white, 0.35)!, fill],
            ),
          ),
        ),
      ),
    );
  }
}

/// Round level badge. The text is one widget ("Lv 3") on purpose.
class LevelBadge extends StatelessWidget {
  const LevelBadge({
    super.key,
    required this.palette,
    required this.level,
    this.size = 44,
  });

  final GardenPalette palette;
  final int level;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(palette.accent, Colors.white, 0.3)!,
            palette.accent,
          ],
        ),
        border: Border.all(color: Colors.white, width: size * 0.06),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      padding: EdgeInsets.all(size * 0.1),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'Lv $level',
          maxLines: 1,
          style: TextStyle(
            color: palette.onAccent,
            fontSize: size * 0.3,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

/// Pill button: accent filled (primary) or outlined.
class GardenButton extends StatelessWidget {
  const GardenButton({
    super.key,
    required this.palette,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = true,
    this.focusNode,
    this.height = 50,
  });

  final GardenPalette palette;
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final FocusNode? focusNode;
  final double height;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(height / 2),
    );
    final text = Text(
      label,
      maxLines: 1,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
    );
    final child = FittedBox(
      fit: BoxFit.scaleDown,
      child: icon == null
          ? text
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(icon, size: 20), const SizedBox(width: 8), text],
            ),
    );
    if (primary) {
      return FilledButton(
        focusNode: focusNode,
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.onAccent,
          disabledBackgroundColor: palette.accent.withValues(alpha: 0.45),
          disabledForegroundColor: palette.onAccent.withValues(alpha: 0.8),
          minimumSize: Size(0, height),
          padding: EdgeInsets.symmetric(horizontal: height < 46 ? 12 : 20),
          shape: shape,
          elevation: 3,
        ),
        child: child,
      );
    }
    return OutlinedButton(
      focusNode: focusNode,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.textPrimary,
        backgroundColor: palette.panel,
        minimumSize: Size(0, height),
        padding: EdgeInsets.symmetric(horizontal: height < 46 ? 10 : 16),
        side: BorderSide(color: palette.panelBorder, width: 2),
        shape: shape,
      ),
      child: child,
    );
  }
}

/// Square icon button for the toolbar.
class GardenIconButton extends StatelessWidget {
  const GardenIconButton({
    super.key,
    required this.palette,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 44,
    this.badge,
    this.selected = false,
  });

  final GardenPalette palette;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  /// Accent filled, for icon-only toggles (Dig/Flag on short screens).
  final bool selected;

  /// Small count shown on the corner (hints left); hidden when null or 0.
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final count = badge;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      iconSize: size * 0.5,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        // Small buttons (compact layouts) keep their visual size as the tap
        // target so a row of them fits a slim column.
        tapTargetSize: size < 44 ? MaterialTapTargetSize.shrinkWrap : null,
        foregroundColor: selected ? palette.onAccent : palette.textPrimary,
        backgroundColor: selected ? palette.accent : palette.panel,
        disabledForegroundColor: palette.textSecondary.withValues(alpha: 0.6),
        disabledBackgroundColor: palette.panel.withValues(alpha: 0.6),
        side: BorderSide(
          color: selected ? palette.accent : palette.panelBorder,
          width: 2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Badge(
        label: Text('${count ?? 0}'),
        isLabelVisible: count != null && count > 0,
        backgroundColor: palette.danger,
        child: Icon(icon),
      ),
    );
  }
}

/// Caption over a bold value.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.palette,
    required this.label,
    required this.value,
    this.large = false,
  });

  final GardenPalette palette;
  final String label;
  final String value;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: large ? 8 : 5, horizontal: 4),
      decoration: BoxDecoration(
        color: palette.textSecondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
              color: palette.textSecondary,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: large ? 26 : 17,
                height: 1.15,
                fontWeight: FontWeight.w900,
                color: palette.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three-way difficulty switch. Nothing is selected while [selected] is null
/// (the daily board is up).
class DifficultyPicker extends StatelessWidget {
  const DifficultyPicker({
    super.key,
    required this.palette,
    required this.selected,
    required this.onChanged,
    this.vertical = false,
  });

  final GardenPalette palette;
  final Difficulty? selected;
  final ValueChanged<Difficulty> onChanged;

  /// Stacked segments (short landscape screens, beside the board).
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final segments = [
      for (final option in Difficulty.values)
        _Segment(
          palette: palette,
          label: option.title,
          selected: option == selected,
          onTap: () => onChanged(option),
        ),
    ];
    return Container(
      height: vertical ? 3 * 34 + 10 : 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: palette.panelBorder, width: 2),
      ),
      child: vertical
          ? Column(children: [for (final s in segments) Expanded(child: s)])
          : Row(children: [for (final s in segments) Expanded(child: s)]),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final GardenPalette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? palette.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: selected ? palette.onAccent : palette.textPrimary,
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

/// A painted tile used as an illustration (cards, tutorial, swatches).
class TileArt extends StatelessWidget {
  const TileArt({
    super.key,
    required this.palette,
    required this.look,
    this.size = 56,
    this.nearby = 0,
    this.seed = 3,
  });

  final GardenPalette palette;
  final TileLook look;
  final double size;
  final int nearby;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: GardenTilePainter(
          palette: palette,
          look: look,
          nearby: nearby,
          seed: seed,
        ),
      ),
    );
  }
}
