# slayTheStrat — AI 机器人自动化测试与报告系统 (`ai_test_system`)

本模块专为最新版 **StrategemSpiral (`slayTheStrat`, Godot 4.7)** 打造，覆盖开始界面流转、4 选 3 随机敌人遭遇（含狼人双段吸血、戈仑护卫嘲讽、亡灵残血巨盾、哥布林自爆）、法力涌动隔回合溢出及 4 张 WASD 终极 QTE 卡牌的完整测试闭环。

## 1. 模块架构

- `ai_bot_brain.gd` (`AIBotBrain`)：多策略战术决策大脑，内置 5 类测试人格：
  - `Tactical_Pro`：精确解析敌人意图脚本与戈仑嘲讽状态，计算斩杀线、自爆规避与 4 张终极卡牌净收益（QTE 准确率 100%）。
  - `Aggressive`：激进抢血与高风险终极技爆发（QTE 准确率 95%）。
  - `Defensive`：优先全额护盾防御与法力积攒运营（QTE 准确率 95%）。
  - `Human_Sim_70QTE`：模拟普通人类玩家的评估波动与 70% WASD QTE 成功率，用于评估上手门槛与惩罚平衡性。
  - `Random_Fuzz`：随机出牌与随机 QTE 按键压力测试，用于挖掘状态机死锁与空指针异常。
- `ai_battle_agent.gd` (`AIBattleAgent`)：实时接管对局控制器，通过真实 `InputEventKey` 驱动 `UltimateCardQTE` WASD 输入，并实时监控法力、血量、护盾、单终极卡手牌上限与超时死锁不变式。
- `ai_mechanics_verifier.gd` (`AIMechanicsVerifier`)：10 项核心机制确定性回归测试（`FT-01` ~ `FT-10`）。
- `ai_report_generator.gd` (`AIReportGenerator`)：自动汇总并输出三格式测试报告：
  - `reports/test_report.json`（结构化机器可读数据）
  - `reports/test_report.md`（Markdown 详细评估与平衡性表格）
  - `reports/test_report_dashboard.html`（可视化网页仪表盘）
- `ai_hud_autoload.gd` (`AITestSystem` Autoload)：游戏内轻量悬浮控制面板。

## 2. 使用方式

### 方式 A：在 Godot 编辑器内正常运行时交互测试（按 `F5`）
左上角点击 `AI[F1]` 或使用快捷键：
- **`F1`**：展开 / 收起 AI 控制面板
- **`F2`**：开启 / 关闭 AI 自动托管对战（支持从标题界面自动进战斗并循环连战）
- **`F3`**：实时切换 AI 策略人格（`Pro` / `Aggro` / `Def` / `Human` / `Fuzz`）
- **`F4`**：一键进入完整批量自动化测试并生成最新报告

### 方式 B：一键无头高速跑批并导出报告
双击运行 `run_ai_test_headless.bat`，或执行命令行：
```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path "gameCode/slay-the-strat" res://ai_test_system/ai_test_runner.tscn -- --games-per-strategy=10 --speed=8.0 --auto-quit
```
