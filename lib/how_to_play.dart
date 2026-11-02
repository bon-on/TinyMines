import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/art/garden_palette.dart';
import 'src/art/garden_tile_art.dart';
import 'src/ui/garden_ui.dart';

/// Remembers whether the first-run tutorial was already shown.
/// Storage failures never break play: unreadable means "not seen" and a failed
/// write is ignored.
class TutorialStore {
  const TutorialStore();

  static const String key = 'tutorial_seen_v1';

  Future<bool> hasSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, true);
    } catch (_) {}
  }
}

class TutorialStep {
  const TutorialStep(this.icon, this.text, {this.art, this.nearby = 0});

  /// Shown when there is no [art].
  final IconData icon;
  final String text;

  /// Garden tile illustration for the step.
  final TileLook? art;

  /// Pebble number for a [TileLook.soil] illustration.
  final int nearby;
}

/// Modal "How to play" card shown over a dimmed game. Swallows pointer and
/// keyboard input so nothing reaches the game underneath.
class HowToPlayOverlay extends StatefulWidget {
  const HowToPlayOverlay({
    super.key,
    required this.steps,
    required this.onClose,
    this.palette = GardenPalette.spring,
  });

  final List<TutorialStep> steps;
  final VoidCallback onClose;
  final GardenPalette palette;

  @override
  State<HowToPlayOverlay> createState() => _HowToPlayOverlayState();
}

class _HowToPlayOverlayState extends State<HowToPlayOverlay> {
  final FocusNode _focus = FocusNode(debugLabel: 'how-to-play');
  int _step = 0;

  @override
  void initState() {
    super.initState();
    // Take keyboard focus from the game underneath so keys stop there.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  bool get _last => _step == widget.steps.length - 1;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _next() {
    if (_last) {
      widget.onClose();
    } else {
      setState(() => _step++);
    }
  }

  void _prev() {
    if (_step > 0) setState(() => _step--);
  }

  static final Set<LogicalKeyboardKey> _handledKeys = {
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.escape,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
  };

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    // Leave browser/OS shortcuts (Ctrl+R, Cmd+L, Alt+Left), Tab and function
    // keys such as F5 alone.
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed ||
        !_handledKeys.contains(key)) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      _next();
    } else if (key == LogicalKeyboardKey.escape) {
      widget.onClose();
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _forward();
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _prev();
    }
    return KeyEventResult.handled;
  }

  // Right arrow only moves forward; it never closes the tutorial.
  void _forward() {
    if (!_last) setState(() => _step++);
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_step];
    final palette = widget.palette;
    final art = step.art;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Stack(
        children: [
          const ModalBarrier(color: Color(0x99101A14), dismissible: false),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Material(
                  type: MaterialType.transparency,
                  child: GardenPanel(
                    palette: palette,
                    radius: 26,
                    padding: EdgeInsets.zero,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'How to play',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (art != null)
                            TileArt(
                              palette: palette,
                              look: art,
                              nearby: step.nearby,
                              size: 64,
                            )
                          else
                            Icon(
                              step.icon,
                              size: 52,
                              color: palette.flowerCenter,
                            ),
                          const SizedBox(height: 12),
                          Text(
                            step.text,
                            key: const ValueKey('how-to-play-text'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0; i < widget.steps.length; i++)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  width: i == _step ? 18 : 8,
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: i == _step
                                        ? palette.accent
                                        : palette.panelBorder,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              TextButton(
                                onPressed: widget.onClose,
                                style: TextButton.styleFrom(
                                  foregroundColor: palette.textSecondary,
                                ),
                                child: const Text(
                                  'Skip',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                              const Spacer(),
                              GardenButton(
                                palette: palette,
                                label: _last ? 'Play' : 'Next',
                                height: 44,
                                onPressed: _next,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
