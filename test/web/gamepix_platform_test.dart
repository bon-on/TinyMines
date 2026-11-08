// Run with: flutter test --platform chrome test/web
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_mines/platform/crazygames_platform.dart';
import 'package:tiny_mines/platform/game_platform.dart';
import 'package:tiny_mines/platform/game_platform_factory_web.dart'
    as web_factory;

void main() {
  test('default web build keeps the no-op platform with registration', () {
    final platform = web_factory.selectGamePlatform(
      crazyGames: false,
      gamePix: false,
    );
    expect(platform, isA<NoopGamePlatform>());
    expect(platform.allowsResultRegistration, isTrue);
    expect(platform.shareLink, pagesShareLink);
  });

  test('GamePix build is a no-op without result registration', () {
    final platform = web_factory.selectGamePlatform(
      crazyGames: false,
      gamePix: true,
    );
    expect(platform, isA<NoopGamePlatform>());
    expect(platform.allowsResultRegistration, isFalse);
    expect(platform.shareLink, isNull, reason: 'GamePix: no outbound link');
  });

  test('the running test build has the Pages link', () {
    expect(
      web_factory.createGamePlatform().shareLink,
      'https://bon-on.github.io/TinyMines/',
    );
  });

  test('CrazyGames adapter is only selected for CRAZYGAMES', () {
    expect(
      web_factory.selectGamePlatform(crazyGames: true, gamePix: false),
      isA<CrazyGamesPlatform>(),
    );
    expect(
      web_factory.selectGamePlatform(crazyGames: false, gamePix: true),
      isNot(isA<CrazyGamesPlatform>()),
    );
  });
}
