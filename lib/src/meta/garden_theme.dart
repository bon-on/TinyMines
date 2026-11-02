/// Cosmetic garden themes, unlocked by garden level. Themes never change rules.
enum GardenTheme {
  spring(requiredLevel: 1, label: 'Spring'),
  autumn(requiredLevel: 3, label: 'Autumn'),
  winter(requiredLevel: 6, label: 'Winter'),
  night(requiredLevel: 10, label: 'Night');

  const GardenTheme({required this.requiredLevel, required this.label});

  /// Garden level at which the theme becomes selectable.
  final int requiredLevel;

  /// Short English name shown in the UI.
  final String label;

  /// Parses a stored theme name; unknown values fall back to [spring].
  static GardenTheme fromName(String? name) {
    for (final theme in values) {
      if (theme.name == name) return theme;
    }
    return spring;
  }
}
