# Verification: TinyMines CrazyGames web distribution

- Spec: `harness/specs/feature-tiny-mines-crazygames.md`
- ADR: `harness/adrs/adr-tiny-mines-crazygames-web.md`
- Contract: `harness/contracts/contract-tiny-mines-crazygames.md`
- Environment: Flutter 3.41.7, macOS, headless Chrome for web tests

| Check | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | 39 passed (was 29 before this change) |
| `flutter test --platform chrome test/web` | 6 passed (SDK missing, disabled, init rejected, init timeout, gameplay events, leaderboard off) |
| `tool/build_crazygames.sh` | passed; 32 files, about 28MB; zip `build/tiny-mines-crazygames.zip` |
| Bundle `index.html` | `<base href="./">`, SDK script once before the Flutter loader, no hub nav bar or bon-on link, nav height 0px |
| `flutter build web --release --base-href /TinyMines/` | passed; no SDK script, hub nav bar kept |
| harness audit | Critical 0, Blocked no |

Not verified: upload to the CrazyGames portal and the portal QA tool (needs a developer account).
