import 'game_platform_factory_stub.dart'
    if (dart.library.js_interop) 'game_platform_factory_web.dart'
    as platform_factory;

/// Hooks a distribution portal needs from the game loop.
///
/// Mobile and plain web builds use [NoopGamePlatform]; CrazyGames web builds
/// (`--dart-define=CRAZYGAMES=true`) use the SDK-backed implementation and
/// GamePix builds (`--dart-define=GAMEPIX=true`) a no-op without result upload.
abstract class GamePlatform {
  const GamePlatform();

  Future<void> initialize();

  /// The player is actively playing (no overlay, run not over).
  void gameplayStart();

  /// The player stopped playing (overlay open, run over).
  void gameplayStop();

  /// Whether the post-game prompt to submit results to the Bon-on leaderboard
  /// may be shown. Portal builds keep players on the portal.
  bool get allowsResultRegistration;

  /// Whether the portal asks the game to stay silent (CrazyGames audio
  /// setting). Checked on every sound; false where no portal layer exists.
  bool get isAudioMuted => false;

  /// Registers a callback for when [isAudioMuted] may have changed (portal
  /// mute setting). Platforms without such events ignore it.
  void setAudioMuteListener(void Function()? listener) {}

  /// Public game page appended to copied results (feature-next-goal-share,
  /// adr-share-link-per-flavor); null copies text only. It is only text:
  /// the game never opens it.
  String? get shareLink => null;
}

/// GitHub Pages game page used in copied results of the Pages and mobile
/// builds. Referenced only from non-portal factory branches, so neither the
/// GamePix nor the CrazyGames bundle contains it.
const String pagesShareLink = 'https://bon-on.github.io/TinyMines/';

class NoopGamePlatform extends GamePlatform {
  /// [allowsResultRegistration] is false for portal builds without an SDK
  /// (GamePix, `--dart-define=GAMEPIX=true`): no external network calls.
  const NoopGamePlatform({
    this.allowsResultRegistration = true,
    this.shareLink,
  });

  @override
  final String? shareLink;

  @override
  Future<void> initialize() async {}

  @override
  void gameplayStart() {}

  @override
  void gameplayStop() {}

  @override
  final bool allowsResultRegistration;
}

GamePlatform createGamePlatform() => platform_factory.createGamePlatform();
