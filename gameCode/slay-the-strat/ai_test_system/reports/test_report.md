# 🤖 slayTheStrat AI 机器人自动化测试与平衡性分析报告

- **测试项目**: `StrategemSpiral / slayTheStrat (Godot 4.7)`
- **生成时间**: `2026-11-26T18:52:39`
- **总执行耗时**: `140.75 秒`
- **核心机制单元测试通过率**: **10 / 10** (`100%`)
- **AI 模拟对战总局数**: **60 局**（胜率 **70.0%**，同归于尽 `OBLITERATED` **2 局**，运行时不变式异常 **0 项**）

## 1. 核心机制确定性验证 (Functional Mechanics Verification)

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
| `FT-10` | Ultimate WASD QTE Input & Nuke OBLITERATED Outcome | **PASS** | LastGasp WASD->3x mult (true), Nuke WASD->OBLITERATED (true) |

## 2. 多人格 AI 策略对战统计 (Multi-Strategy AI Benchmarks)

| AI 策略人格 | 对局数 | 胜场 (WIN) | 败场 (LOSE) | 同归于尽 (OBLITERATED) | 胜率 | 获胜平均回合 | 获胜平均剩余 HP |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `Aggressive` | 12 | 10 | 1 | 1 | **83.3%** | 3.5 | 11.5 / 45 |
| `Defensive` | 12 | 9 | 3 | 0 | **75.0%** | 3.7 | 15.4 / 45 |
| `Human_Sim_70QTE` | 12 | 10 | 2 | 0 | **83.3%** | 5.3 | 9.3 / 45 |
| `Random_Fuzz` | 12 | 2 | 9 | 1 | **16.7%** | 3.0 | 25.0 / 45 |
| `Tactical_Pro` | 12 | 11 | 1 | 0 | **91.7%** | 5.5 | 12.5 / 45 |

## 3. 随机敌人阵容难度矩阵 (3-of-4 Enemy Encounter Balance)

| 敌人组合 (Encounter Lineup) | 出现次数 | 玩家胜场 | 玩家败场 | 同归于尽 | 玩家胜率 | 平均回合数 | 获胜剩余 HP |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `Ghost + Gob + Golem` | 18 | 13 | 5 | 0 | **72.2%** | 4.4 | 12.4 |
| `Ghost + Gob + Wolf` | 16 | 11 | 4 | 1 | **68.8%** | 3.6 | 13.2 |
| `Ghost + Golem + Wolf` | 9 | 6 | 3 | 0 | **66.7%** | 6.1 | 14.2 |
| `Gob + Golem + Wolf` | 17 | 12 | 4 | 1 | **70.6%** | 3.7 | 12.0 |

## 4. 全卡牌抽用与 QTE 表现遥测 (Card & Ultimate QTE Telemetry)

| 卡牌 ID | 抽到次数 | 打出次数 | 出牌转化率 | 参战局胜率 | QTE 触发 | QTE 成功 / 失败 |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| `adda_swap_health` | 41 | 15 | 36.6% | 60.0% | 15 | 14 / 1 |
| `last_gasp` | 36 | 10 | 27.8% | 60.0% | 10 | 7 / 3 |
| `mana_surge` | 160 | 75 | 46.9% | 70.3% | 0 | - |
| `nuke_30_kill_streak` | 56 | 34 | 60.7% | 67.6% | 34 | 26 / 8 |
| `warrior_axe_attack` | 255 | 228 | 89.4% | 76.9% | 0 | - |
| `warrior_block` | 195 | 116 | 59.5% | 71.1% | 0 | - |
| `warrior_sweep` | 216 | 114 | 52.8% | 74.5% | 0 | - |
| `wssws_blood_ritual` | 40 | 18 | 45.0% | 77.8% | 18 | 16 / 2 |

## 5. 代码审计与缺陷发现记录 (Code Audit & Bug Report)

- **[BUG-01] (HIGH (Fixed in Branch))** `global/shaker.gd:shake()`: Shaker.shake() previously bound tweens to the Shaker autoload without checking is_instance_valid(thing) on completion. Killing an enemy during a 2.0s Ultimate shake (e.g. adda_swap_health followed by Axe Attack) triggered freed-object errors. Fixed by binding shake tween to thing.create_tween() with validity guards.
- **[BUG-02] (HIGH (Fixed in Branch))** `global/shaker.gd:shake_loop()`: Shaker.shake_loop() (triggered by Last Gasp Ultimate) created an infinite set_loops() tween on the global Shaker autoload instead of thing.create_tween(). When Player was freed on scene reload or battle cleanup without battle_over_screen_requested, Godot spammed 'Lambda capture at index 0 was freed' at 20Hz indefinitely. Fixed by binding shake_loop to thing.create_tween().set_loops().
- **[BUG-03] (CRITICAL (Fixed in Branch))** `scenes/ui/battle_ui.gd:_ready()`: EndTurnButton started enabled (disabled=false) during the initial 1.0s opening hand draw animation. Clicking End Turn during the opening draw launched Enemy Turn #1 concurrently with Player Turn #1, causing double signal connections on Golem actions, freed-card discard errors, and state race conditions. Fixed by initializing end_turn_button.disabled = true until player_hand_drawn.
- **[BUG-04] (MEDIUM (Fixed in Branch))** `characters/warrior/cards/warrior_nuke.gd:_play_nuclear_cutscene()`: Nuclear whiteout and fade tweens were bound to Player instead of Arena, risking an unresolving await if Player node was freed mid-cutscene (leaving battle_over_resolution_in_progress stuck true). Fixed by binding cutscene tweens to Arena.
- **[NOTE-01] (DESIGN / INFO)** `scenes/battle/battle.gd:_shuffle_enemy_types()`: Enemy nodes keep static scene names (GhostEnemy, GobEnemy, GolemEnemy) when EnemyStats are shuffled across the 4-enemy pool (including Wolf). Tools and future UI scripts must inspect enemy.stats.ai rather than node.name.
- **[NOTE-02] (BALANCE / INFO)** `characters/warrior/cards/warrior_blood_ritual.gd`: Stats.set_health() clamps health to max_health (45). Playing Blood Ritual above 23 HP caps healing at 45 while still applying -7 HP/turn bleed, making it a high-skill situational comeback card.

> **运行时稳定性结论**：全部 60 场对局与 10 项核心机制验证均完成闭环，零死锁、零负法力值、零越界生命值、零释放对象崩溃。
