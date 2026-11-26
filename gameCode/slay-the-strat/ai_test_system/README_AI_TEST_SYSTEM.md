# slayTheStrat — AI 机器人与输入驱动 QTE 自动化测试系统 (`ai_test_system`)

本模块专为最新版 **StrategemSpiral (`slayTheStrat`, Godot 4.7)** 打造，满足以下严格设计规范：
1. **正常游玩与导出构建完全隔离**：`ai_hud_autoload.gd` 在常规运行（编辑器直接按 `F5`）与任何导出构建（Linux / Windows Release 或 Debug 导出模板）中保持**完全禁用**（不生成任何 UI 节点、不挂载输入监听）。仅在开发测试时显式传入 `-- --ai-overlay` 参数才会启用悬浮面板。
2. **100% Godot 输入管线驱动 WASD QTE**：当终极卡触发 QTE 时，测试控制器通过 `Input.parse_input_event(InputEventKey)` + `Input.flush_buffered_events()` 注入真实的 `W/A/S/D` 按键事件交由 `UltimateCardQTE._unhandled_input` 处理，**绝不直接调用任何 QTE 成功/失败回调**；失败路径通过注入错误按键验证进度归零并等待 `2.0s` 计时器自然到期触发。
3. **严格的 QTE 结算等待同步**：机器人在打出终极卡后严格等待 QTE 与过场动画完全结算完毕，才会评估或选择下一张卡牌或结束回合。
4. **全终极卡成功/失败双路径覆盖**：对全部 4 张终极卡（`adda_swap_health`、`wssws_blood_ritual`、`last_gasp`、`nuke_30_kill_streak`）逐一验证至少一条成功路径（含单次生效校验）与一条错误键重置+超时失败路径，并输出至 `reports/test_report.json` 与 `reports/test_report.md`。

## 快速运行指令

```bash
# 无头批量测试（11 项核心/隔离检查 + 8 条终极卡 QTE 成功/失败路径 + 多策略批量仿真）
godot --headless --path gameCode/slay-the-strat res://ai_test_system/ai_test_runner.tscn -- --games-per-strategy=10 --qte-mode=strategy --auto-quit

# 纯输入驱动 QTE 批量模式（支持 --qte-mode=input|mistake|fail|strategy）
godot --headless --path gameCode/slay-the-strat res://ai_test_system/ai_test_runner.tscn -- --games-per-strategy=5 --qte-mode=input --auto-quit

# 显式开启开发调试 AI 悬浮层进入游戏
godot --path gameCode/slay-the-strat -- --ai-overlay
```
