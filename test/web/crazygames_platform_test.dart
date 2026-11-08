// Run with: flutter test --platform chrome test/web
@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_mines/platform/crazygames_platform.dart';

/// Installs a fake `window.CrazyGames.SDK` and records the calls it receives.
class _FakeSdk {
  _FakeSdk({
    this.environment = 'local',
    this.initResult,
    bool withListener = false,
    String? link,
  }) {
    settings.setProperty('muteAudio'.toJS, false.toJS);
    final game = JSObject()
      ..setProperty('settings'.toJS, settings)
      ..setProperty(
        'gameplayStart'.toJS,
        (() => calls.add('gameplayStart')).toJS,
      )
      ..setProperty(
        'gameplayStop'.toJS,
        (() => calls.add('gameplayStop')).toJS,
      );
    if (link != null) game.setProperty('link'.toJS, link.toJS);
    if (withListener) {
      game.setProperty(
        'addSettingsChangeListener'.toJS,
        ((JSFunction listener) => listeners.add(listener)).toJS,
      );
    }
    final sdk = JSObject()
      ..setProperty('environment'.toJS, environment.toJS)
      ..setProperty('game'.toJS, game)
      ..setProperty(
        'init'.toJS,
        (() => (initResult ?? Future<void>.value()).toJS).toJS,
      );
    globalContext.setProperty(
      'CrazyGames'.toJS,
      JSObject()..setProperty('SDK'.toJS, sdk),
    );
  }

  final String environment;
  final Future<void>? initResult;
  final JSObject settings = JSObject();

  set muteAudio(bool value) =>
      settings.setProperty('muteAudio'.toJS, value.toJS);

  final List<String> calls = <String>[];
  final List<JSFunction> listeners = <JSFunction>[];

  void fireSettingsChanged() {
    for (final listener in listeners) {
      listener.callAsFunction(null, settings);
    }
  }
}

void _removeSdk() => globalContext.delete('CrazyGames'.toJS);

void main() {
  tearDown(_removeSdk);

  test('missing SDK falls back to no-op', () async {
    _removeSdk();
    final platform = CrazyGamesPlatform();
    await platform.initialize();

    platform.gameplayStart();
  });

  test('disabled environment never calls the SDK', () async {
    final sdk = _FakeSdk(environment: 'disabled');
    final platform = CrazyGamesPlatform();
    await platform.initialize();

    platform.gameplayStart();
    expect(sdk.calls, isEmpty);
  });

  test('rejected init falls back to no-op', () async {
    final sdk = _FakeSdk(initResult: Future<void>.error('init failed'));
    final platform = CrazyGamesPlatform();
    await platform.initialize();

    platform.gameplayStart();
    expect(sdk.calls, isEmpty);
  });

  test('hung init times out and falls back to no-op', () async {
    final sdk = _FakeSdk(initResult: Completer<void>().future);
    final platform = CrazyGamesPlatform();
    await platform.initialize();

    platform.gameplayStart();
    expect(sdk.calls, isEmpty);
  });

  test('CrazyGames builds never offer leaderboard registration', () {
    expect(CrazyGamesPlatform().allowsResultRegistration, isFalse);
  });

  test('gameplay events reach the SDK', () async {
    final sdk = _FakeSdk();
    final platform = CrazyGamesPlatform();
    await platform.initialize();

    platform.gameplayStart();
    platform.gameplayStop();
    expect(sdk.calls, <String>['gameplayStart', 'gameplayStop']);
  });

  test('isAudioMuted follows the SDK muteAudio setting', () async {
    final sdk = _FakeSdk();
    final platform = CrazyGamesPlatform();
    expect(platform.isAudioMuted, isFalse);
    await platform.initialize();

    expect(platform.isAudioMuted, isFalse);
    sdk.muteAudio = true;
    expect(platform.isAudioMuted, isTrue);
    sdk.muteAudio = false;
    expect(platform.isAudioMuted, isFalse);
  });

  test('settings changes notify the mute listener', () async {
    final sdk = _FakeSdk(withListener: true);
    final platform = CrazyGamesPlatform();
    await platform.initialize();
    var notified = 0;
    platform.setAudioMuteListener(() => notified++);
    sdk.muteAudio = true;
    sdk.fireSettingsChanged();
    expect(notified, 1);
    expect(platform.isAudioMuted, isTrue);
    platform.setAudioMuteListener(null);
    sdk.fireSettingsChanged();
    expect(notified, 1);
  });

  test('an SDK without the settings listener still works', () async {
    final sdk = _FakeSdk();
    final platform = CrazyGamesPlatform();
    await platform.initialize();
    platform.gameplayStart();
    expect(sdk.calls, <String>['gameplayStart']);
  });

  test('share link: only a valid https CrazyGames game.link', () async {
    final none = CrazyGamesPlatform();
    _removeSdk();
    await none.initialize();
    expect(none.shareLink, isNull, reason: 'no SDK');

    _FakeSdk();
    final missing = CrazyGamesPlatform();
    await missing.initialize();
    expect(missing.shareLink, isNull, reason: 'no game.link');

    _FakeSdk(link: 'https://www.crazygames.com/game/tiny-mines');
    final good = CrazyGamesPlatform();
    await good.initialize();
    expect(good.shareLink, 'https://www.crazygames.com/game/tiny-mines');

    for (final bad in const [
      'http://www.crazygames.com/game/tiny-mines',
      'https://bon-on.github.io/TinyMines/',
      'https://crazygames.com.evil.example/x',
      'javascript:alert(1)',
    ]) {
      _FakeSdk(link: bad);
      final platform = CrazyGamesPlatform();
      await platform.initialize();
      expect(platform.shareLink, isNull, reason: bad);
    }
  });
}
