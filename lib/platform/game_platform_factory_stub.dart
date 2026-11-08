import 'game_platform.dart';

/// Mobile builds: no portal; copied results link to the Pages game.
GamePlatform createGamePlatform() =>
    const NoopGamePlatform(shareLink: pagesShareLink);
