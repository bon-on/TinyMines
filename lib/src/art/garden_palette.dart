import 'package:flutter/painting.dart';

import '../meta/garden_theme.dart';

/// Every color the garden art and the UI chrome use for one [GardenTheme].
class GardenPalette {
  const GardenPalette({
    required this.skyTop,
    required this.skyBottom,
    required this.sun,
    required this.cloud,
    required this.hillFar,
    required this.hillMid,
    required this.hillNear,
    required this.fence,
    required this.bush,
    required this.bushDark,
    required this.grassTop,
    required this.grassBottom,
    required this.grassBlade,
    required this.grassShadow,
    required this.soil,
    required this.soilDark,
    required this.soilSpeck,
    required this.boardFrame,
    required this.boardBed,
    required this.flagPole,
    required this.flagCloth,
    required this.petal,
    required this.petalAlt,
    required this.flowerCenter,
    required this.moleFur,
    required this.moleBelly,
    required this.moleNose,
    required this.panel,
    required this.panelBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.onAccent,
    required this.danger,
    required this.sparkle,
    required this.decor,
    this.isFrost = false,
    this.isNight = false,
  });

  final Color skyTop;
  final Color skyBottom;

  /// Sun (or moon at night).
  final Color sun;
  final Color cloud;
  final Color hillFar;
  final Color hillMid;
  final Color hillNear;
  final Color fence;
  final Color bush;
  final Color bushDark;

  /// Covered tile: a tuft of grass.
  final Color grassTop;
  final Color grassBottom;
  final Color grassBlade;
  final Color grassShadow;

  /// Revealed tile: dug soil.
  final Color soil;
  final Color soilDark;
  final Color soilSpeck;

  /// Wooden planter frame around the board and the bed behind the tiles.
  final Color boardFrame;
  final Color boardBed;

  final Color flagPole;
  final Color flagCloth;
  final Color petal;
  final Color petalAlt;
  final Color flowerCenter;
  final Color moleFur;
  final Color moleBelly;
  final Color moleNose;

  final Color panel;
  final Color panelBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color onAccent;
  final Color danger;
  final Color sparkle;

  /// Theme decoration color: blossoms, falling leaves, snow, fireflies.
  final Color decor;

  /// Winter: snow caps on grass tufts, hills and the frame.
  final bool isFrost;

  /// Night: moon, stars and fireflies instead of sun and clouds.
  final bool isNight;

  /// Pebble color behind the number [n] (1..8).
  Color pebble(int n) => _pebbles[(n - 1).clamp(0, 7)];

  /// Ink color of the number [n] on its pebble.
  Color pebbleInk(int n) => _pebbleInk[(n - 1).clamp(0, 7)];

  static const List<Color> _pebbles = <Color>[
    Color(0xFFBFE3F5), // 1 sky blue
    Color(0xFFC6EBC0), // 2 mint
    Color(0xFFF8E0A2), // 3 butter
    Color(0xFFF6C1B4), // 4 peach
    Color(0xFFE2C8F0), // 5 lilac
    Color(0xFFB8E6DE), // 6 teal
    Color(0xFFE9D3C0), // 7 sand
    Color(0xFFD9D9D9), // 8 grey
  ];

  static const List<Color> _pebbleInk = <Color>[
    Color(0xFF1F5F8B),
    Color(0xFF2D7A2D),
    Color(0xFFA0661A),
    Color(0xFFB3412E),
    Color(0xFF7A3E99),
    Color(0xFF14786C),
    Color(0xFF6E4A2E),
    Color(0xFF4A4A4A),
  ];

  static GardenPalette of(GardenTheme theme) => switch (theme) {
    GardenTheme.spring => spring,
    GardenTheme.autumn => autumn,
    GardenTheme.winter => winter,
    GardenTheme.night => night,
  };

  static const GardenPalette spring = GardenPalette(
    skyTop: Color(0xFF8FD3F4),
    skyBottom: Color(0xFFDDF3E4),
    sun: Color(0xFFFFE27A),
    cloud: Color(0xFFFFFFFF),
    hillFar: Color(0xFFA8D99C),
    hillMid: Color(0xFF86C77A),
    hillNear: Color(0xFF6DB563),
    fence: Color(0xFFF3E3C3),
    bush: Color(0xFF5AA650),
    bushDark: Color(0xFF3F8A3C),
    grassTop: Color(0xFF8BD06A),
    grassBottom: Color(0xFF5FAE4B),
    grassBlade: Color(0xFFB5E58D),
    grassShadow: Color(0xFF3E8A36),
    soil: Color(0xFFC89B6D),
    soilDark: Color(0xFFA77B52),
    soilSpeck: Color(0xFF8E6440),
    boardFrame: Color(0xFFB07A48),
    boardBed: Color(0xFF7A5232),
    flagPole: Color(0xFF6B4A2B),
    flagCloth: Color(0xFFF2545B),
    petal: Color(0xFFFF9EC4),
    petalAlt: Color(0xFFFFE066),
    flowerCenter: Color(0xFFFFC23D),
    moleFur: Color(0xFF6E5A57),
    moleBelly: Color(0xFFC9A99C),
    moleNose: Color(0xFFFF8FA3),
    panel: Color(0xF2FFFCF2),
    panelBorder: Color(0xFFE7D9B8),
    textPrimary: Color(0xFF3B2E22),
    textSecondary: Color(0xFF8A7558),
    accent: Color(0xFF4FAE5A),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFE5484D),
    sparkle: Color(0xFFFFF4B0),
    decor: Color(0xFFFFB3D1),
  );

  static const GardenPalette autumn = GardenPalette(
    skyTop: Color(0xFFF6C58F),
    skyBottom: Color(0xFFFCEBD0),
    sun: Color(0xFFFFD27A),
    cloud: Color(0xFFFFF5E6),
    hillFar: Color(0xFFE2B36C),
    hillMid: Color(0xFFD08E4A),
    hillNear: Color(0xFFB8733A),
    fence: Color(0xFFF1DDBA),
    bush: Color(0xFFC9572E),
    bushDark: Color(0xFF9E3F24),
    grassTop: Color(0xFFE2B04A),
    grassBottom: Color(0xFFC08533),
    grassBlade: Color(0xFFF4D27B),
    grassShadow: Color(0xFF8F5E22),
    soil: Color(0xFFB78559),
    soilDark: Color(0xFF946642),
    soilSpeck: Color(0xFF7A5133),
    boardFrame: Color(0xFF8E5A33),
    boardBed: Color(0xFF5E3B22),
    flagPole: Color(0xFF5A3A20),
    flagCloth: Color(0xFF4D8FD6),
    petal: Color(0xFFFF8A3D),
    petalAlt: Color(0xFFE84A3C),
    flowerCenter: Color(0xFF7A3E1D),
    moleFur: Color(0xFF6A5048),
    moleBelly: Color(0xFFD3AF95),
    moleNose: Color(0xFFFF8F8F),
    panel: Color(0xF2FFF8EC),
    panelBorder: Color(0xFFEBCFA3),
    textPrimary: Color(0xFF45291A),
    textSecondary: Color(0xFF94673F),
    accent: Color(0xFFD9692E),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFD63B3B),
    sparkle: Color(0xFFFFE9A8),
    decor: Color(0xFFE0612F),
  );

  static const GardenPalette winter = GardenPalette(
    skyTop: Color(0xFFAFCDEB),
    skyBottom: Color(0xFFEAF3FB),
    sun: Color(0xFFFFF3C4),
    cloud: Color(0xFFFFFFFF),
    hillFar: Color(0xFFDDE9F5),
    hillMid: Color(0xFFC9DBEE),
    hillNear: Color(0xFFB6CDE6),
    fence: Color(0xFFE9E1D4),
    bush: Color(0xFF3F7E6A),
    bushDark: Color(0xFF2E6153),
    grassTop: Color(0xFF7FB89A),
    grassBottom: Color(0xFF4F8F73),
    grassBlade: Color(0xFFB2DCC6),
    grassShadow: Color(0xFF356B57),
    soil: Color(0xFFC3B3A3),
    soilDark: Color(0xFFA39280),
    soilSpeck: Color(0xFF85725F),
    boardFrame: Color(0xFF8F7B6A),
    boardBed: Color(0xFF5E5047),
    flagPole: Color(0xFF5B4636),
    flagCloth: Color(0xFFE2434B),
    petal: Color(0xFFFFFFFF),
    petalAlt: Color(0xFFBFE1FF),
    flowerCenter: Color(0xFFFFD45E),
    moleFur: Color(0xFF66595A),
    moleBelly: Color(0xFFD2BFB8),
    moleNose: Color(0xFFFF9AAE),
    panel: Color(0xF2F8FBFF),
    panelBorder: Color(0xFFCADBEE),
    textPrimary: Color(0xFF243447),
    textSecondary: Color(0xFF6A7F96),
    accent: Color(0xFF3F8FD2),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFE0454D),
    sparkle: Color(0xFFFFFFFF),
    decor: Color(0xFFFFFFFF),
    isFrost: true,
  );

  static const GardenPalette night = GardenPalette(
    skyTop: Color(0xFF14204A),
    skyBottom: Color(0xFF34407A),
    sun: Color(0xFFFFF1C2),
    cloud: Color(0xFF4A578F),
    hillFar: Color(0xFF2B3A68),
    hillMid: Color(0xFF233259),
    hillNear: Color(0xFF1B2948),
    fence: Color(0xFF6E6A86),
    bush: Color(0xFF1E4A45),
    bushDark: Color(0xFF153833),
    grassTop: Color(0xFF3F8A6E),
    grassBottom: Color(0xFF2A6553),
    grassBlade: Color(0xFF69B391),
    grassShadow: Color(0xFF1C4A3D),
    soil: Color(0xFF7D6A5E),
    soilDark: Color(0xFF64544A),
    soilSpeck: Color(0xFF4C3F37),
    boardFrame: Color(0xFF4E3F55),
    boardBed: Color(0xFF2C2333),
    flagPole: Color(0xFFC9B8A0),
    flagCloth: Color(0xFFFFC94D),
    petal: Color(0xFFB9A4FF),
    petalAlt: Color(0xFF8FE3FF),
    flowerCenter: Color(0xFFFFF1A8),
    moleFur: Color(0xFF7A6A6E),
    moleBelly: Color(0xFFC7B2AE),
    moleNose: Color(0xFFFF9AB0),
    panel: Color(0xF0222A4A),
    panelBorder: Color(0xFF3E4A7A),
    textPrimary: Color(0xFFF1EEFF),
    textSecondary: Color(0xFFA9B0D6),
    accent: Color(0xFFF2B33D),
    onAccent: Color(0xFF2A1D05),
    danger: Color(0xFFFF6B6B),
    sparkle: Color(0xFFFFF6C8),
    decor: Color(0xFFE8FF8A),
    isNight: true,
  );
}
