---
id: feature-retention-polish
title: Tiny Mines 정원 테마 시각 개편, 손맛 연출, 재플레이 동기(XP 레벨, 테마, 데일리, 연속 기록)
status: active
owner: games
related_adrs:
  - adr-tiny-mines-crazygames-web
related_contracts:
  - contract-tiny-mines-gameplay
  - contract-tiny-mines-crazygames
  - contract-how-to-play-tutorial
required_evidence:
  - flutter-analyze
  - flutter-tests
  - flutter-web-build
  - crazygames-web-build
  - gamepix-web-build
  - harness-audit
---

# 기능 명세: Tiny Mines 정원 테마 시각 개편, 손맛 연출, 재플레이 동기

## Problem
CrazyGames가 같은 계열 게임(MergeCamp)을 "The overall quality of the game does not yet meet the expectations of our
platform"으로 거절했다. Tiny Mines도 회색 사각형 타일, Material 아이콘, 기본 SegmentedButton만 있어 시제품처럼 보이고,
칸을 열거나 깃발을 꽂거나 지뢰를 밟는 순간의 연출이 없으며, 배경음악이 없다. 판이 끝나면 난이도별 최고 기록 하나만 남고
다시 플레이할 이유(성장, 꾸미기, 매일 목표)가 없다. 또한 "첫 클릭이 무시되었다"는 재현되지 않은 제보가 있었다.

## Scope
1. 시각 개편(정원/굴 파기 테마)
   - 외부 에셋 없이 `CustomPainter`로 그린다. 덮인 칸은 풀숲(잔디 덤불), 열린 칸은 흙, 숫자는 색깔 조약돌 위에 쓴다.
     지뢰는 잠자는 두더지(밟은 칸은 놀란 두더지와 붉은 흙), 깃발은 작은 정원 깃발, 잘못 꽂은 깃발은 X 표시다.
     클리어하면 지뢰 칸에 꽃이 핀다.
   - 테마별 배경(하늘, 해/달, 구름, 언덕, 울타리, 덤불)을 그린다. 테마: Spring(기본), Autumn, Winter, Night.
   - 넓은 화면(가로 760 이상이고 가로/세로 1.25 이상, 예: 1280x720, 1366x768 iframe)은 보드를 가운데 두고 왼쪽에 제목,
     정원 레벨, 테마, 데일리 카드, 오른쪽에 시간/깃발/최고 기록, 도구 버튼, 난이도별 기록을 둔다. 좁은 화면(390x844)은
     위아래로 쌓는다. 어느 크기에서도 오버플로가 없어야 한다. 보드의 칸 영역(그리드)은 최대 560px이다(나무 틀 포함 580px).
   - 패널, 버튼, 난이도 선택, 튜토리얼 카드를 새 테마로 다시 꾸민다. 제목, 수치, 캡션의 글꼴 위계를 둔다(번들 Roboto).
2. 손맛 연출(규칙은 즉시 적용, 연출은 뒤따름, 입력을 막지 않음)
   - 칸 열기: 누른 칸에서 바깥으로 거리 순서대로 풀숲이 튀어 오르며 사라지는 물결 연출과 풀잎 파티클.
   - 깃발: 꽂을 때 튀어 오르는 바운스와 흙먼지, 뽑을 때 줄어드는 연출.
   - 지뢰: 밟은 칸에서 폭발 링과 흙 파티클, 화면 흔들림, 나머지 두더지가 거리 순서로 튀어나온다.
   - 클리어: 지뢰 칸에 꽃이 차례로 피고 꽃잎/색종이가 터진다.
   - 힌트: 열린 칸에 반짝임.
   - 연출은 하나의 Ticker와 하나의 오버레이 페인터로 처리하고, 연출이 없으면 Ticker를 멈춘다. 끝없는(상시) 애니메이션은 두지 않는다.
3. 재플레이 동기
   - 난이도별 최고 기록(기존 `best_time_<difficulty>` 값을 손실 없이 이전), 승/플레이 횟수, 정원 XP, 선택 테마, 데일리 결과,
     최고 연속 기록을 `shared_preferences` 키 `garden_progress_v1`(JSON)에 저장한다.
   - 이전: 불러올 때 기존 키 `best_time_easy|normal|hard`를 읽어 저장값과 비교해 더 빠른 기록을 쓴다(멱등). 기존 키는
     지우지 않고, 새 최고 기록이 나오면 기존 키에도 같이 기록한다(되돌려도 기록이 보존된다).
   - 손상되었거나 없는 값은 기본값으로 대체하고 플레이를 막지 않는다. 저장값을 읽기 전에는 저장하지 않는다(그 사이 끝난 판은
     읽은 뒤 합쳐서 저장한다).
   - 판이 끝나면(클리어 또는 지뢰) 결과 화면을 보여준다: 결과, 시간, 최고 기록, "New best!", 획득 XP, 레벨 진행 바, 새로 열린
     테마, 데일리 결과와 연속 기록, "New Field"(다시 하기, Enter), 클리어 시 다음 난이도 버튼, "View board"(Esc로 닫고 보드 보기).
   - XP: 클리어 시 난이도별 기본값(Easy 30, Normal 70, Hard 150), 실패 시 연 칸 비율에 따른 일부(최소 3), 데일리는 참여/클리어
     보너스. 첫 수 전에 재시작하거나 판 도중 재시작하면 XP가 없다. 레벨 L에서 다음 레벨까지 100 + 40*(L-1) XP.
   - 테마는 레벨로 열린다(Spring Lv1, Autumn Lv3, Winter Lv6, Night Lv10). 꾸미기 전용이며 규칙에 영향이 없다. 열린 테마만
     고를 수 있다.
   - 데일리 챌린지: 날짜(로컬 날짜)로 시드를 정한 Normal 9x9 보드. 같은 날은 같은 지뢰 배치이고 시작 칸이 미리 열려 있다.
     결과(클리어/실패, 시간)는 하루에 한 번만 저장되고, 저장된 뒤에는 그날 다시 도전할 수 없다(완료 표시). 판 도중 나가면 저장하지
     않는다. 연속 기록은 데일리를 끝까지 마친 날이 이어진 일수다(오늘 아직 안 했으면 어제까지의 연속이 유지된다).
4. 첫 클릭 경로 점검
   - 첫 클릭은 지뢰를 심은 뒤(누른 칸과 이웃 제외) 바로 열리고 시계가 시작되어야 한다. 튜토리얼 확인 응답을 기다리는 동안 보드를
     누르면 지금은 조용히 버려졌다(제보된 증상의 유력한 원인). 이제 그 동안의 마지막 보드 입력을 기억했다가, 튜토리얼이 열리지 않으면
     응답 직후 적용한다. 튜토리얼이 열리면 버린다(카드가 덮기 때문).
5. 소리
   - 밝고 장난스러운 배경음악 루프(코드 합성, 서드파티 오디오 없음, 16000 Hz 모노 16비트, 1 MB 이하, 이음새 없는 루프)를
     `tool/generate_sounds.py`(표준 라이브러리, 결정적 출력)에 추가한다. 웹은 첫 사용자 입력 뒤 시작, 탭이 숨겨지면 멈춘다.
     사용자 음소거, CrazyGames `muteAudio`(설정 변경 리스너 포함)를 따른다. 하나의 소리 토글이 효과음과 음악을 모두 끈다.
   - 새 효과음: 레벨 업, 새 최고 기록, 데일리 완료. 기존 reveal/flag/boom/win은 그대로다.
   - iOS/Android 네이티브 채널 `tiny_mines/audio`에 `startLoop`/`stopLoop`를 추가한다(iOS는 전화 등 인터럽트 후 재개).
   - Tiny Mines에는 광고가 없으므로 광고 중 음악 정지는 해당 없음이다.

## Acceptance Criteria
- 모든 칸 상태(덮임, 깃발, 열린 0~8, 두더지, 밟은 두더지, 잘못된 깃발, 꽃)가 4개 테마 모두에서 예외 없이 그려진다.
- 칸 열기, 깃발, 지뢰, 클리어, 힌트 연출이 재생되고, 연출 중에도 다음 입력이 바로 처리된다.
- 판이 끝나면 결과 화면이 열려 보드 입력을 막고, Enter로 새 판, Esc로 닫힌다. 클리어 시 "New best!"가 첫 기록/더 빠른 기록에서만 보인다.
- 기존 `best_time_easy` 등의 값이 HUD 최고 기록과 기록 목록에 그대로 보이고, 손상된 `garden_progress_v1`은 기본값(기존 키 이전 포함)으로 대체된다.
- XP가 쌓여 레벨이 오르고, 요구 레벨에 도달한 테마만 고를 수 있으며 선택이 유지된다.
- 데일리 보드는 같은 날짜에서 같은 배치이고, 결과가 저장된 뒤에는 그날 다시 시작할 수 없다. 연속 기록이 날짜에 따라 계산된다.
- 튜토리얼 확인 대기 중 누른 보드 칸은 튜토리얼이 안 열리면 적용되고, 열리면 버려진다. 첫 클릭은 항상 안전하게 열리고 시계를 시작한다.
- 배경음악은 음소거(사용자/플랫폼) 시 멈추고, 탭이 숨겨지면 멈췄다가 돌아오면 다시 재생된다. 웹은 첫 입력 전에는 재생하지 않는다.
- 튜토리얼, CrazyGames gameplayStart/Stop, GamePix 흐름, GitHub Pages 전용 결과 등록 문구는 기존대로 동작한다.
- 1280x720, 1366x768, 390x844(및 360x760, 844x390)에서 오버플로 없이 표시된다.
- 기존 테스트(UI가 바뀐 부분만 수정)와 CrazyGames/GamePix 빌드 자체 검사가 통과한다.

## Constraints
- 새 패키지 의존성을 추가하지 않는다. 그림은 코드로, 소리는 생성기로 만든다.
- 지뢰 규칙(첫 칸 안전, 코드, 깃발, 힌트 벌점 10초, 승패 판정)과 난이도(6x6/5, 9x9/12, 12x12/26)는 바꾸지 않는다. 데일리는 같은
  `MineField`를 시드 난수와 미리 연 시작 칸으로 만든다.
- lib/ 문자열은 영어 ASCII다(GamePix 빌드 검사). 단, GitHub Pages 전용 결과 등록 문구(`result_registration.dart`)는 기존 그대로 둔다.
- GamePix: 외부 요청 없음, 모든 자산 번들.

## Evidence
- `flutter analyze`, `flutter test`, `flutter test --platform chrome test/web`
- `flutter build web --release --base-href /TinyMines/`, `tool/build_crazygames.sh`, `tool/build_gamepix.sh`
- 임시 골든 테스트로 1280x720, 390x844, 결과 화면, 타일 아트를 PNG로 렌더링해 확인(테스트는 확인 후 삭제)
- `node <harness-lab>/dist/index.js audit . --format md`

## Quality recovery refinement

`feature-crazygames-quality-recovery` supersedes the generation-preservation restriction for regular Easy only: dimensions/mine count and reveal/flag/chord rules are unchanged; Normal/Hard and fixed DailyChallenge layouts are preserved.
