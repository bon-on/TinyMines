import 'crazygames_platform.dart';
import 'game_platform.dart';
import 'gamepix_platform.dart';

const bool _crazyGamesBuild = bool.fromEnvironment('CRAZYGAMES');
const bool _gamePixBuild = bool.fromEnvironment('GAMEPIX');

/// Picks the portal adapter. CrazyGames wins over GamePix
/// (feature-gamepix-sdk).
GamePlatform selectGamePlatform({
  required bool crazyGames,
  required bool gamePix,
}) {
  if (crazyGames) return CrazyGamesPlatform();
  if (gamePix) return GamePixPlatform();
  return const NoopGamePlatform(shareLink: pagesShareLink);
}

/// One conditional expression over compile-time constants, so the unused
/// branches (the CrazyGames adapter, the Pages link) are tree-shaken from
/// portal bundles (adr-share-link-per-flavor; checked by the build scripts).
GamePlatform createGamePlatform() => _crazyGamesBuild
    ? CrazyGamesPlatform()
    : _gamePixBuild
    ? GamePixPlatform()
    : const NoopGamePlatform(shareLink: pagesShareLink);
