# 🤖 slayTheStrat AI 机器人与输入驱动 QTE 自动化测试报告

- **测试项目**: `StrategemSpiral / slayTheStrat (Godot 4.7)`
- **生成时间**: `2026-11-26T21:19:25`
- **总执行耗时**: `119.48 秒`
- **核心机制与导出门控检查**: **11 / 11** (`100%`)
- **终极卡 WASD QTE 成功/失败双路径检查**: **8 / 8** (`100%`，纯 `InputEventKey` 输入注入，零直接回调调用)
- **AI 模拟对战总局数**: **50 局**（胜率 **72.0%**，同归于尽 `OBLITERATED` **1 局**，运行时不变式异常 **0 项**）

## 1. 终极卡牌 WASD QTE 成功与失败全路径验证 (Ultimate Card QTE Matrix)

| 编号 | 终极卡 ID | 路径类型 | 注入按键序列 / 触发方式 | 错误键重置校验 | 单次生效校验 | 状态 | 详细验证结果 |
| :--- | :--- | :---: | :--- | :---: | :---: | :---: | :--- |
| `QTE-01` | `adda_swap_health` | **SUCCESS** | `A D D A D D` | - | YES | **PASS** | WASD completed QTE once: Player HP 12->40 (expected 40), Enemies [20,10,10]->[4,4,4] (true) |
| `QTE-02` | `adda_swap_health` | **FAILURE** | `A D -> W(reset) -> Timeout` | YES | YES | **PASS** | Progress 2->0 on wrong key W, timer expired -> Enemies healed +5 ([20,4,4]->[25,9,9]) |
| `QTE-03` | `wssws_blood_ritual` | **SUCCESS** | `W S -> D(reset) -> W S S W S` | YES | YES | **PASS** | Reset 2->0 then completed once: Player HP 18->36 (expected 36), bleed=7/turn |
| `QTE-04` | `wssws_blood_ritual` | **FAILURE** | `W -> A(reset) -> Timeout` | YES | YES | **PASS** | Progress 1->0 on wrong key A, timer expired -> Block 5->0, HP halved 21->11 (expected 11) |
| `QTE-05` | `last_gasp` | **SUCCESS** | `D S D S D S` | - | YES | **PASS** | WASD completed QTE once: HP 30->5 (expected 5), damage_multiplier=3x (expected 3x) |
| `QTE-06` | `last_gasp` | **FAILURE** | `D S D -> W(reset) -> Timeout` | YES | YES | **PASS** | Progress 3->0 on wrong key W, timer expired -> HP 30->5 (5), damage_multiplier stayed 1x (no buff) |
| `QTE-07` | `nuke_30_kill_streak` | **SUCCESS** | `S W A S W D S W` | - | YES | **PASS** | WASD completed Nuke once: Player HP 42->12 (-30), Golem HP 40->10 (-30, block cleared), 2 enemies defeated |
| `QTE-08` | `nuke_30_kill_streak` | **FAILURE** | `S W -> D(reset) -> Timeout` | YES | YES | **PASS** | Progress 2->0 on wrong key D, timer expired -> Block cleared & lethal self-damage triggered LOSE=true |

## 2. 核心机制与发布版隔离确定性验证 (Functional & Release Gating Checks)

| 编号 | 测试项 | 状态 | 详细验证结果 |
| :--- | :--- | :---: | :--- |
| `FT-01` | StartScreen UI & Battle Scene Link | **PASS** | StartScreen loaded title='Strategem-Spiral', float_y=19.0, target='res://scenes/battle/battle.tscn' exists=true |
| `FT-02` | 3-of-4 Randomized Enemy Pool (Ghost/Gob/Golem/Wolf) | **PASS** | Observed distinct 3-enemy lineups across pool: ["Ghost", "Gob", "Golem", "Wolf"] |
| `FT-03` | Warrior Block (+5) & Axe Attack (6 Dmg + Lunge) | **PASS** | Block=5 (true), Target HP 10 -> 4 (true) |
| `FT-04` | Mana Surge Next-Turn Overflow (3 -> 5 Mana) | **PASS** | Next turn starting mana after 1x Mana Surge = 5 (expected 5) |
| `FT-05` | Single Ultimate-in-Hand Draw Constraint | **PASS** | From 4 Ultimates + 2 Basics, drew 3 total cards with 1 Ultimate (expected 3 total, 1 Ultimate) |
| `FT-06` | Golem Ally Protection Taunt Redirect | **PASS** | Gob HP 7->7 (untouched), Protecting Golem HP 40->34 (-6) |
| `FT-07` | Wolf Double-Bite (4x2 Dmg) & Lifesteal (+2x2 HP) | **PASS** | Player HP 40->32 (expected 32), Wolf HP 5->9 (expected 9) |
| `FT-08` | Ghost Conditional Mega-Block (<=6 HP -> +15 Block) | **PASS** | Intent switched=true, Ghost block after action=15 (expected 15) |
| `FT-09` | Gob Kamikaze Attack (14 Player Dmg + Self-Kill) | **PASS** | Player HP 40->26 (-14), Gob self-destructed=true |
| `FT-10` | Nuke Mutual Destruction -> OBLITERATED State | **PASS** | Player (25 HP) & all enemies (10 HP) wiped via WASD Nuke -> OBLITERATED=true |
| `FT-11` | AI Overlay Disabled in Normal Gameplay & Exported Builds | **PASS** | NormalOff=true, ExportBlocked=true, ExplicitFlagOn=true, RuntimeTreeClean=true |

## 3. 多人格 AI 策略对战统计 (Multi-Strategy AI Benchmarks)

| AI 策略人格 | 对局数 | 胜场 (WIN) | 败场 (LOSE) | 同归于尽 (OBLITERATED) | 胜率 | 获胜平均回合 | 获胜平均剩余 HP |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `Aggressive` | 10 | 7 | 3 | 0 | **70.0%** | 5.3 | 18.9 / 45 |
| `Defensive` | 10 | 9 | 1 | 0 | **90.0%** | 3.4 | 18.8 / 45 |
| `Human_Sim_70QTE` | 10 | 9 | 1 | 0 | **90.0%** | 5.1 | 8.8 / 45 |
| `Random_Fuzz` | 10 | 1 | 8 | 1 | **10.0%** | 3.0 | 1.0 / 45 |
| `Tactical_Pro` | 10 | 10 | 0 | 0 | **100.0%** | 4.5 | 9.8 / 45 |

## 4. 随机敌人阵容难度矩阵 (3-of-4 Enemy Encounter Balance)

| 敌人组合 (Encounter Lineup) | 出现次数 | 玩家胜场 | 玩家败场 | 同归于尽 | 玩家胜率 | 平均回合数 | 获胜剩余 HP |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `Ghost + Gob + Golem` | 13 | 8 | 5 | 0 | **61.5%** | 3.7 | 8.5 |
| `Ghost + Gob + Wolf` | 12 | 9 | 3 | 0 | **75.0%** | 4.3 | 13.4 |
| `Ghost + Golem + Wolf` | 12 | 10 | 2 | 0 | **83.3%** | 4.4 | 18.1 |
| `Gob + Golem + Wolf` | 13 | 9 | 3 | 1 | **69.2%** | 4.2 | 12.1 |

## 5. 全卡牌抽用与 QTE 表现遥测 (Card & Ultimate QTE Telemetry)

| 卡牌 ID | 抽到次数 | 打出次数 | 出牌转化率 | 参战局胜率 | QTE 触发 | QTE 成功 / 失败 |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| `adda_swap_health` | 31 | 15 | 48.4% | 66.7% | 15 | 13 / 2 |
| `last_gasp` | 39 | 18 | 46.2% | 77.8% | 18 | 14 / 4 |
| `mana_surge` | 132 | 67 | 50.8% | 68.4% | 0 | - |
| `nuke_30_kill_streak` | 44 | 23 | 52.3% | 69.6% | 23 | 17 / 6 |
| `warrior_axe_attack` | 210 | 189 | 90.0% | 75.0% | 0 | - |
| `warrior_block` | 167 | 93 | 55.7% | 77.5% | 0 | - |
| `warrior_sweep` | 160 | 83 | 51.9% | 78.4% | 0 | - |
| `wssws_blood_ritual` | 33 | 15 | 45.5% | 80.0% | 15 | 12 / 3 |

## 6. 代码审计与缺陷修复记录 (Code Audit & Bug Report)

- **[BUG-01] (HIGH (Fixed in Branch))** `global/shaker.gd:shake()`: Shaker.shake() previously bound tweens to the Shaker autoload without checking is_instance_valid(thing) on completion. Fixed by binding shake tween to thing.create_tween() with validity guards.
- **[BUG-02] (HIGH (Fixed in Branch))** `global/shaker.gd:shake_loop()`: Shaker.shake_loop() created an infinite set_loops() tween on the global Shaker autoload instead of thing.create_tween(), causing freed lambda errors on cleanup. Fixed by binding shake_loop to thing.create_tween().set_loops().
- **[BUG-03] (CRITICAL (Fixed in Branch))** `scenes/ui/battle_ui.gd:_ready()`: EndTurnButton started enabled during the initial 1.0s opening hand draw animation, allowing concurrent turns. Fixed by disabling EndTurnButton until player_hand_drawn and during nuclear cutscene resolution.
- **[BUG-04] (MEDIUM (Fixed in Branch))** `characters/warrior/cards/warrior_nuke.gd:_play_nuclear_cutscene()`: Nuclear whiteout and fade tweens were bound to Player instead of Arena. Fixed by binding cutscene tweens to Arena.

> **运行时稳定性结论**：全部 50 场对局、8 项终极卡 WASD QTE 路径及 11 项核心机制验证均完成闭环，零死锁、零负法力值、零越界生命值、零释放对象崩溃。
