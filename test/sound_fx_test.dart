import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:tiny_mines/how_to_play.dart';
import 'package:tiny_mines/main.dart';
import 'package:tiny_mines/mine_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_mines/platform/game_platform.dart';
import 'package:tiny_mines/src/audio/sound_fx.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingPlayer implements SoundPlayer {
  final List<String> played = <String>[];
  bool disposed = false;

  @override
  void play(String asset, double volume) => played.add(asset);

  @override
  void dispose() => disposed = true;
}

class _MutedPlatform extends NoopGamePlatform {
  _MutedPlatform();

  bool muted = true;

  @override
  bool get isAudioMuted => muted;
}

class _ThrowingPlatform extends NoopGamePlatform {
  @override
  bool get isAudioMuted => throw StateError('sdk gone');
}

class _SeenStore extends TutorialStore {
  @override
  Future<bool> hasSeen() async => true;

  @override
  Future<void> markSeen() async {}
}

Finder get _tiles =>
    find.descendant(of: find.byType(GridView), matching: find.byType(InkWell));

/// Easy field (6x6, 5 mines) with the seed the screen is given below.
MineField _field() => MineField(size: 6, mineCount: 5, random: math.Random(1));

Future<void> _pump(WidgetTester tester, SoundFx fx) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: TinyMinesScreen(
        random: math.Random(1),
        tutorialStore: _SeenStore(),
        soundFx: fx,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('SoundFx', () {
    test('plays the asset of each effect at a volume', () {
      final player = _RecordingPlayer();
      SoundFx(player: player).play(Sfx.reveal);
      expect(player.played, ['assets/audio/reveal.wav']);
    });

    test('user mute silences effects and platform mute does too', () async {
      final player = _RecordingPlayer();
      final platform = _MutedPlatform()..muted = false;
      final fx = SoundFx(platform: platform, player: player);

      await fx.setUserMuted(true);
      fx.play(Sfx.reveal);
      expect(player.played, isEmpty);

      await fx.setUserMuted(false);
      fx.play(Sfx.reveal);
      expect(player.played, hasLength(1));

      platform.muted = true;
      expect(fx.muted, isTrue);
      expect(fx.userMuted, isFalse);
      fx.play(Sfx.win);
      expect(player.played, hasLength(1));
    });

    test('a failing platform getter counts as not muted', () {
      final player = _RecordingPlayer();
      SoundFx(platform: _ThrowingPlatform(), player: player).play(Sfx.flag);
      expect(player.played, hasLength(1));
    });

    test('mute choice persists under sound_muted_v1', () async {
      final fx = SoundFx(player: _RecordingPlayer());
      await fx.setUserMuted(true);
      expect(
        (await SharedPreferences.getInstance()).getBool('sound_muted_v1'),
        isTrue,
      );

      final reloaded = SoundFx(player: _RecordingPlayer());
      expect(reloaded.userMuted, isFalse);
      await reloaded.load();
      expect(reloaded.userMuted, isTrue);
    });

    test('defaults to sound on when nothing is stored', () async {
      final fx = SoundFx(player: _RecordingPlayer());
      await fx.load();
      expect(fx.userMuted, isFalse);
    });

    test('a toggle made before load finishes is not overwritten', () async {
      SharedPreferences.setMockInitialValues({'sound_muted_v1': true});
      final fx = SoundFx(player: _RecordingPlayer());
      final loading = fx.load();
      await fx.setUserMuted(false);
      await loading;
      expect(fx.userMuted, isFalse);
    });

    test('player and storage failures never throw', () async {
      final fx = SoundFx(
        player: _ThrowingPlayer(),
        preferences: () async => throw StateError('no storage'),
      );
      await fx.load();
      await fx.setUserMuted(true);
      await fx.setUserMuted(false);
      fx.play(Sfx.reveal);
    });

    test('the platform player tolerates a missing native channel', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final player = PlatformSoundPlayer();
      player.play(Sfx.reveal.asset, 0.5);
      player.dispose();
      await Future<void>.delayed(Duration.zero);
    });

    test('dispose releases the player and later calls are harmless', () async {
      final player = _RecordingPlayer();
      final fx = SoundFx(player: player)..dispose();
      expect(player.disposed, isTrue);
      fx.play(Sfx.reveal);
      await fx.setUserMuted(true);
      expect(player.played, isEmpty);
    });
  });

  group('music', () {
    late _RecordingMusic music;
    late _MutedPlatform platform;
    SoundFx make({bool web = true}) {
      music = _RecordingMusic();
      platform = _MutedPlatform()..muted = false;
      return SoundFx(
        platform: platform,
        player: _RecordingPlayer(),
        music: music,
        requiresUserInput: web,
      );
    }

    test('web waits for the first user input', () async {
      final fx = make();
      fx.startMusic();
      await pumpEventQueue();
      expect(music.log, isEmpty);
      fx.onUserInput();
      await pumpEventQueue();
      expect(music.log, ['start ${SoundFx.musicAsset}']);
      expect(fx.isMusicPlaying, isTrue);
    });

    test('native starts at once; mute, hidden tab and stop hold it', () async {
      final fx = make(web: false);
      fx.startMusic();
      await pumpEventQueue();
      expect(music.log, ['start ${SoundFx.musicAsset}']);

      await fx.setUserMuted(true);
      await pumpEventQueue();
      expect(music.log.last, 'pause');
      await fx.setUserMuted(false);
      await pumpEventQueue();
      expect(music.log.last, 'resume');

      fx.setAppVisible(false);
      expect(music.log.last, 'pause');
      fx.setAppVisible(true);
      await pumpEventQueue();
      expect(music.log.last, 'resume');

      platform.muted = true;
      fx.refreshMute();
      expect(music.log.last, 'pause');
      platform.muted = false;
      fx.refreshMute();
      await pumpEventQueue();
      expect(music.log.last, 'resume');

      fx.stopMusic();
      expect(music.log.last, 'stop');
      expect(fx.isMusicPlaying, isFalse);
      fx.dispose();
    });

    test('a refused start is retried on the next input', () async {
      final fx = make();
      music.refuse = true;
      fx.startMusic();
      fx.onUserInput();
      await pumpEventQueue();
      expect(fx.isMusicPlaying, isFalse);
      music.refuse = false;
      fx.onUserInput();
      await pumpEventQueue();
      expect(fx.isMusicPlaying, isTrue);
    });

    test('dispose stops the loop and later calls are harmless', () async {
      final fx = make(web: false);
      fx.startMusic();
      await pumpEventQueue();
      fx.dispose();
      expect(music.log.last, 'stop');
      fx.startMusic();
      await pumpEventQueue();
      expect(music.log.last, 'stop');
    });

    test('the platform music player tolerates a missing channel', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final player = PlatformMusicPlayer();
      expect(await player.start(SoundFx.musicAsset, 0.4), isFalse);
      player.pause();
      expect(await player.resume(), isFalse);
      player.stop();
    });
  });

  group('assets', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    test('pubspec bundles the audio directory', () {
      expect(pubspec, contains('- assets/audio/'));
    });

    for (final sfx in Sfx.values) {
      test('${sfx.name} exists on disk and is small', () {
        final file = File(sfx.asset);
        expect(file.existsSync(), isTrue, reason: sfx.asset);
        expect(file.lengthSync(), lessThan(40 * 1024));
      });
    }

    test('every asset used in lib/ is covered by Sfx', () {
      final used = <String>{};
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        used.addAll(
          RegExp(
            r'assets/audio/[a-z_]+\.wav',
          ).allMatches(entity.readAsStringSync()).map((m) => m.group(0)!),
        );
      }
      // Effects come from the Sfx.asset template; the music loop is the only
      // literal asset path in code.
      expect(used, {SoundFx.musicAsset});
      final onDisk = Directory(
        'assets/audio',
      ).listSync().map((e) => e.path).where((p) => p.endsWith('.wav')).toSet();
      expect(onDisk, {...Sfx.values.map((s) => s.asset), SoundFx.musicAsset});
    });

    test('music loop is 16 kHz mono 16-bit and under 1 MB', () {
      final bytes = File(SoundFx.musicAsset).readAsBytesSync();
      expect(bytes.length, lessThan(1024 * 1024));
      final header = ByteData.sublistView(bytes, 0, 44);
      expect(header.getUint16(22, Endian.little), 1, reason: 'mono');
      expect(header.getUint32(24, Endian.little), 16000);
      expect(header.getUint16(34, Endian.little), 16);
    });
  });

  group('game hooks', () {
    testWidgets('revealing plays one sound, flags and chords stay accurate', (
      tester,
    ) async {
      final player = _RecordingPlayer();
      await _pump(tester, SoundFx(player: player));
      final reference = _field()..reveal(0);

      // A cascade reveals many tiles but is one action, one sound.
      await tester.tap(_tiles.at(0));
      await tester.pump();
      expect(player.played, ['assets/audio/reveal.wav']);

      // A revealed number with no flags around it does nothing.
      final number = reference.cells.indexWhere(
        (c) => c.revealed && c.nearby > 0,
      );
      player.played.clear();
      await tester.tap(_tiles.at(number));
      await tester.pump();
      expect(player.played, isEmpty);
    });

    testWidgets('flagging and unflagging each play the flag sound', (
      tester,
    ) async {
      final player = _RecordingPlayer();
      await _pump(tester, SoundFx(player: player));
      final reference = _field()..reveal(0);
      final hidden = reference.cells.indexWhere((c) => !c.revealed);

      await tester.tap(_tiles.at(0));
      await tester.pump();
      player.played.clear();
      await tester.longPress(_tiles.at(hidden));
      await tester.pump();
      await tester.longPress(_tiles.at(hidden));
      await tester.pump();
      expect(player.played, ['assets/audio/flag.wav', 'assets/audio/flag.wav']);

      // Long pressing a revealed tile cannot flag it: no sound.
      player.played.clear();
      await tester.longPress(_tiles.at(0));
      await tester.pump();
      expect(player.played, isEmpty);
    });

    testWidgets('hitting a mine plays boom once, then the field is inert', (
      tester,
    ) async {
      final player = _RecordingPlayer();
      await _pump(tester, SoundFx(player: player));
      final mine = (_field()..reveal(0)).cells.indexWhere((c) => c.mine);

      await tester.tap(_tiles.at(0));
      await tester.pump();
      player.played.clear();
      await tester.tap(_tiles.at(mine));
      await tester.pump();
      expect(player.played, ['assets/audio/boom.wav']);

      await tester.tap(_tiles.at(1));
      await tester.pump();
      expect(player.played, hasLength(1));
    });

    testWidgets('clearing the field plays win instead of reveal', (
      tester,
    ) async {
      final player = _RecordingPlayer();
      await _pump(tester, SoundFx(player: player));
      final reference = _field()..reveal(0);
      final safe = <int>[
        for (var i = 0; i < 36; i++)
          if (!reference.cells[i].mine) i,
      ];
      final replay = _field();
      for (final index in safe) {
        if (replay.cells[index].revealed) continue;
        replay.reveal(index);
        await tester.tap(_tiles.at(index));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.textContaining('Field cleared'), findsOneWidget);
      expect(player.played.last, 'assets/audio/win.wav');
      expect(player.played.where((a) => a.endsWith('win.wav')), hasLength(1));
      expect(player.played.where((a) => a.endsWith('boom.wav')), isEmpty);
    });

    testWidgets('a chord plays one reveal, or one boom on a wrong flag', (
      tester,
    ) async {
      final reference = _field()..reveal(0);
      // A revealed number with a hidden mine and a hidden safe tile around it.
      bool hidden(int n, {required bool mine}) =>
          !reference.cells[n].revealed && reference.cells[n].mine == mine;
      final number = [for (var i = 0; i < reference.cells.length; i++) i]
          .firstWhere(
            (i) =>
                reference.cells[i].revealed &&
                reference.cells[i].nearby > 0 &&
                reference.neighbors(i).any((n) => hidden(n, mine: true)) &&
                reference.neighbors(i).any((n) => hidden(n, mine: false)),
          );
      final around = reference.neighbors(number).toList();
      final mines = around.where((n) => reference.cells[n].mine).toList();
      final safeHidden = around
          .where(
            (n) => !reference.cells[n].mine && !reference.cells[n].revealed,
          )
          .toList();

      for (final wrong in <bool>[false, true]) {
        final player = _RecordingPlayer();
        await _pump(tester, SoundFx(player: player));
        await tester.tap(_tiles.at(0));
        await tester.pump();
        final flags = [...mines];
        if (wrong) {
          if (safeHidden.isEmpty) continue;
          flags[0] = safeHidden.first;
        }
        for (final f in flags) {
          await tester.longPress(_tiles.at(f));
          await tester.pump();
        }
        player.played.clear();
        await tester.tap(_tiles.at(number));
        await tester.pump();
        expect(player.played, [
          wrong ? 'assets/audio/boom.wav' : 'assets/audio/reveal.wav',
        ], reason: 'wrong flag: $wrong');
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('timer ticks and the tutorial card make no sound', (
      tester,
    ) async {
      final player = _RecordingPlayer();
      await _pump(tester, SoundFx(player: player));
      await tester.tap(_tiles.at(0));
      await tester.pump();
      player.played.clear();
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.byTooltip('How to play'));
      await tester.pump();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(player.played, isEmpty);
    });

    testWidgets('a hint plays the reveal sound once', (tester) async {
      final player = _RecordingPlayer();
      await _pump(tester, SoundFx(player: player));

      await tester.tap(_tiles.at(0));
      await tester.pump();
      player.played.clear();
      await tester.tap(find.byIcon(Icons.lightbulb));
      await tester.pump();
      expect(player.played, ['assets/audio/reveal.wav']);
    });

    testWidgets('muted game stays silent', (tester) async {
      final player = _RecordingPlayer();
      final fx = SoundFx(player: player);
      await fx.setUserMuted(true);
      await _pump(tester, fx);

      await tester.tap(_tiles.at(0));
      await tester.pump();
      await tester.longPress(_tiles.at(35));
      await tester.pump();
      expect(player.played, isEmpty);
    });

    testWidgets('the toggle flips icon, tooltip and stored state', (
      tester,
    ) async {
      final fx = SoundFx(player: _RecordingPlayer());
      await _pump(tester, fx);

      expect(find.byTooltip('Sound on'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

      await tester.tap(find.byTooltip('Sound on'));
      await tester.pump();
      expect(fx.userMuted, isTrue);
      expect(find.byTooltip('Sound off'), findsOneWidget);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getBool('sound_muted_v1'),
        isTrue,
      );

      await tester.tap(find.byTooltip('Sound off'));
      await tester.pump();
      expect(fx.userMuted, isFalse);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    });

    testWidgets('a stored mute choice is applied on launch', (tester) async {
      SharedPreferences.setMockInitialValues({
        'sound_muted_v1': true,
        'tutorial_seen_v1': true,
      });
      await tester.pumpWidget(const TinyMinesApp());
      await tester.pumpAndSettle();
      expect(find.byTooltip('Sound off'), findsOneWidget);
    });

    testWidgets('the toggle is blocked while the tutorial card is open', (
      tester,
    ) async {
      final fx = SoundFx(player: _RecordingPlayer());
      await _pump(tester, fx);
      await tester.tap(find.byTooltip('How to play'));
      await tester.pump();
      await tester.tap(find.byTooltip('Sound on'), warnIfMissed: false);
      await tester.pump();
      expect(fx.userMuted, isFalse);
    });
  });
}

class _RecordingMusic implements MusicPlayer {
  final List<String> log = <String>[];
  bool refuse = false;

  @override
  Future<bool> start(String asset, double volume) async {
    if (refuse) return false;
    log.add('start $asset');
    return true;
  }

  @override
  void pause() => log.add('pause');

  @override
  Future<bool> resume() async {
    log.add('resume');
    return true;
  }

  @override
  void stop() => log.add('stop');
}

class _ThrowingPlayer implements SoundPlayer {
  @override
  void play(String asset, double volume) => throw StateError('boom');

  @override
  void dispose() => throw StateError('boom');
}
