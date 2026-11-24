---
id: feature-theme-reward-reveal
title: Earlier theme unlocks and a theme reveal with a one-tap switch on the result card
status: active
owner: games
related_adrs:
  - adr-tiny-mines-crazygames-web
related_contracts:
  - contract-tiny-mines-gameplay
required_evidence:
  - flutter-analyze
  - flutter-tests
  - harness-audit
  - independent-review
---

# Theme reward reveal

## Problem

The user reported on 2026-11-24 that rewards such as themes feel low impact. Two causes:

- **Late first reward.** The first theme (Autumn) needs Lv 3, which is 240 XP. A Garden Run gives 10 XP plus 15 per cleared
  stage, so a new player needs about ten short runs before the first theme arrives. Winter (Lv 6, 900 XP) and Night
  (Lv 10, 2340 XP) are far beyond a first session.
- **Quiet unlock moment.** An unlock shows only as a small "New theme: Autumn" pill on the result card. The player has to
  find the theme picker on their own to see the reward, so most never notice it.

## Scope

- Move the theme unlocks earlier: Autumn at Lv 2 (100 XP), Winter at Lv 4 (420 XP), Night at Lv 6 (900 XP). Spring stays at Lv 1.
- On the result card, a result that unlocks a theme shows a reveal block in place of the small pill. The block has a small
  preview of the theme (sky, grass and flower tiles in its palette), the theme name, and a "Use <theme>" button. The button
  switches the garden to that theme at once and then reads "Using <theme>".

## Constraints

- XP amounts, the level curve, themes' art and their rules stay as they are; themes stay cosmetic. No new dependencies or assets.
- Players who are already past a new requirement simply have the theme unlocked; no saved data changes.
- The result card keeps its primary action (New Run / New Field) focused, and Enter still starts the next play.
- Short screens keep the XP row above the pinned actions (run_first_launch_test).

## Acceptance Criteria

- R1: `GardenTheme` required levels are 1, 2, 4 and 6. A fresh player reaches Autumn with 100 XP.
- R2: When a result unlocks a theme, the card shows the reveal block (key `theme-reveal`) with the theme name and a preview
  once the XP bar has filled. Results that unlock nothing show no block.
- R3: Tapping "Use <theme>" selects and saves the theme, and the button then reads "Using <theme>". If the theme is already
  selected the button reads "Using <theme>" from the start.
- R4: When one result unlocks several themes, the block shows the highest one and the others still appear as pills.
- R5: `flutter analyze` and `flutter test` pass, including the short-screen result card checks.

## Requirement-to-check map

- R1: `test/garden_progress_test.dart`, `test/next_goal_test.dart`.
- R2-R4: `test/theme_reward_reveal_test.dart`.
- R5: CI test command.

## Evidence

- reports/theme-reward-reveal-verification.md
