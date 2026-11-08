import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_mines/platform/crazygames_link.dart';
import 'package:tiny_mines/platform/game_platform.dart';
import 'package:tiny_mines/src/art/garden_palette.dart';
import 'package:tiny_mines/src/game/difficulty.dart';
import 'package:tiny_mines/src/meta/garden_progress.dart';
import 'package:tiny_mines/src/share/result_copy.dart';
import 'package:tiny_mines/src/share/result_text.dart';
import 'package:tiny_mines/src/ui/run_summary_overlay.dart';

class _Copier extends ResultCopier {
  _Copier({this.ok = true, this.throws = false});
  final bool ok;
  final bool throws;
  final List<String> copied = <String>[];

  @override
  Future<bool> copyText(String text) async {
    if (throws) throw StateError('clipboard blocked');
    copied.add(text);
    return ok;
  }
}

RunReport _regular({required bool won, int seconds = 83}) {
  final outcome =
      GardenProgress.fromJson({
        'bestTimes': {'normal': 70},
      }).applyRun(
        RunResult(
          difficulty: Difficulty.normal,
          won: won,
          seconds: seconds,
          revealedFraction: won ? 1 : 0.5,
        ),
      );
  return RunReport(
    won: won,
    difficulty: Difficulty.normal,
    seconds: seconds,
    outcome: outcome,
  );
}

RunReport _daily({bool practice = false}) {
  const day = '2026-11-09';
  final outcome = const GardenProgress.initial().applyRun(
    RunResult(
      difficulty: Difficulty.normal,
      won: true,
      seconds: 65,
      revealedFraction: 1,
      dailyDay: day,
      practice: practice,
    ),
  );
  return RunReport(
    won: true,
    difficulty: Difficulty.normal,
    seconds: 65,
    outcome: outcome,
    daily: true,
    practice: practice,
    dailyDay: day,
  );
}

RunReport _garden({int healed = 1}) {
  final outcome = const GardenProgress.initial().applyGardenRun(
    const GardenRunResult(
      stageReached: 7,
      stagesCleared: 6,
      participated: true,
    ),
  );
  return RunReport.garden(
    stageReached: 7,
    stagesCleared: 6,
    seconds: 252,
    outcome: outcome,
    heartsHealed: healed,
  );
}

bool _ascii(String text) => text.codeUnits.every((c) => c < 128);

Future<void> _show(
  WidgetTester tester,
  RunReport report, {
  required ResultCopier copier,
  String? link,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RunSummaryOverlay(
          report: report,
          palette: GardenPalette.spring,
          onPlayAgain: () {},
          onClose: () {},
          shareLink: link,
          copier: copier,
          delay: Duration.zero,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('crazyGamesLinkOrNull', () {
    test('accepts https CrazyGames hosts only', () {
      for (final good in const [
        'https://www.crazygames.com/game/tiny-mines',
        'https://crazygames.com/game/tiny-mines',
        'https://www.crazygames.fr/game/tiny-mines',
        'https://www.crazygames.co.uk/game/tiny-mines',
        ' https://games.crazygames.com/en_US/tiny-mines/index.html ',
      ]) {
        expect(crazyGamesLinkOrNull(good), isNotNull, reason: good);
      }
      for (final bad in const [
        null,
        '',
        'http://www.crazygames.com/game/tiny-mines',
        'https://www.crazygames.com:8443/game/tiny-mines',
        'https://user@www.crazygames.com/game/tiny-mines',
        'https://crazygames.com.evil.example/x',
        'https://notcrazygames.com/x',
        'https://bon-on.github.io/TinyMines/',
        'javascript:alert(1)',
        '/game/tiny-mines',
      ]) {
        expect(crazyGamesLinkOrNull(bad), isNull, reason: '$bad');
      }
    });
  });

  group('resultShareText', () {
    test('regular win and loss, with and without a link', () {
      expect(
        resultShareText(_regular(won: true, seconds: 65), link: pagesShareLink),
        'Tiny Mines - Normal 9x9\n'
        'Cleared in 1:05 (best 1:05)\n'
        'Garden Lv 1\n'
        'https://bon-on.github.io/TinyMines/',
      );
      expect(
        resultShareText(_regular(won: false)),
        'Tiny Mines - Normal 9x9\nA mole won this time.\nGarden Lv 1',
      );
    });

    test('daily text has the date and the streak', () {
      expect(
        resultShareText(_daily()),
        'Tiny Mines - Daily Garden 2026-11-09\nCleared in 1:05\nStreak: 1 day',
      );
    });

    test('Garden Run text has the stage reached and the hearts', () {
      final text = resultShareText(_garden(), link: '  ');
      expect(
        text,
        'Tiny Mines - Garden Run\n'
        'Reached stage 7, cleared 6 gardens in 4:12\n'
        'Hearts: 3 + 1 from bosses | Best stage: 7',
      );
      expect(
        resultShareText(_garden(healed: 0)).split('\n').last,
        'Hearts: 3 | Best stage: 7',
      );
    });

    test('every text is ASCII', () {
      for (final report in [
        _regular(won: true),
        _regular(won: false),
        _daily(),
        _garden(),
      ]) {
        expect(_ascii(resultShareText(report, link: pagesShareLink)), isTrue);
      }
    });
  });

  group('Copy result button', () {
    testWidgets('copies the text with the link and says Copied!', (
      tester,
    ) async {
      final copier = _Copier();
      await _show(tester, _garden(), copier: copier, link: pagesShareLink);
      await tester.tap(find.byKey(const ValueKey('copy-result')));
      await tester.pump();
      expect(copier.copied, hasLength(1));
      expect(copier.copied.single, contains('Reached stage 7'));
      expect(copier.copied.single, endsWith(pagesShareLink));
      expect(find.text('Copied!'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Copy result'), findsOneWidget);
    });

    testWidgets('no link: text only', (tester) async {
      final copier = _Copier();
      await _show(tester, _regular(won: true), copier: copier);
      await tester.tap(find.byKey(const ValueKey('copy-result')));
      await tester.pump();
      expect(copier.copied.single, isNot(contains('http')));
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('a failing or throwing clipboard says Could not copy', (
      tester,
    ) async {
      for (final copier in [_Copier(ok: false), _Copier(throws: true)]) {
        await _show(tester, _regular(won: true), copier: copier);
        await tester.tap(find.byKey(const ValueKey('copy-result')));
        await tester.pump();
        expect(find.text('Could not copy'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 3));
      }
    });

    testWidgets('daily practice has no copy button', (tester) async {
      await _show(tester, _daily(practice: true), copier: _Copier());
      expect(find.byKey(const ValueKey('copy-result')), findsNothing);
      expect(find.byKey(const ValueKey('next-goal')), findsOneWidget);
    });
  });
}
