class_name AIReportGenerator
extends RefCounted


static func build_full_report(
	functional_results: Array[Dictionary],
	match_records: Array[Dictionary],
	elapsed_seconds: float
) -> Dictionary:
	var ft_passed: int = 0
	for ft in functional_results:
		if bool(ft.get("passed", false)):
			ft_passed += 1

	var total_matches: int = match_records.size()
	var total_wins: int = 0
	var total_losses: int = 0
	var total_obliterated: int = 0
	var total_timeouts: int = 0
	var all_invariant_errors: Array[String] = []

	var by_strategy: Dictionary = {}
	var by_encounter: Dictionary = {}
	var card_stats: Dictionary = {}

	for idx in range(match_records.size()):
		var m: Dictionary = match_records[idx]
		var strat: String = str(m.get("strategy", "Unknown"))
		var outcome: String = str(m.get("outcome", "LOSE"))
		var enc: String = str(m.get("encounter_signature", "Unknown"))
		var turns: int = int(m.get("turns", 1))
		var final_hp: int = int(m.get("player_final_hp", 0))

		if outcome == "WIN":
			total_wins += 1
		elif outcome == "OBLITERATED":
			total_obliterated += 1
		elif outcome == "TIMEOUT":
			total_timeouts += 1
		else:
			total_losses += 1

		var inv_list: Array = m.get("invariant_errors", [])
		for err in inv_list:
			all_invariant_errors.append("[Match #%d %s] %s" % [idx + 1, strat, str(err)])

		# Aggregate by strategy
		if not by_strategy.has(strat):
			by_strategy[strat] = {
				"matches": 0,
				"wins": 0,
				"losses": 0,
				"obliterated": 0,
				"timeouts": 0,
				"total_turns": 0,
				"win_turns_sum": 0,
				"win_hp_sum": 0,
				"cards_played_sum": 0
			}
		var s_rec: Dictionary = by_strategy[strat]
		s_rec["matches"] = int(s_rec["matches"]) + 1
		s_rec["total_turns"] = int(s_rec["total_turns"]) + turns
		s_rec["cards_played_sum"] = int(s_rec["cards_played_sum"]) + int(m.get("cards_played_total", 0))
		if outcome == "WIN":
			s_rec["wins"] = int(s_rec["wins"]) + 1
			s_rec["win_turns_sum"] = int(s_rec["win_turns_sum"]) + turns
			s_rec["win_hp_sum"] = int(s_rec["win_hp_sum"]) + final_hp
		elif outcome == "OBLITERATED":
			s_rec["obliterated"] = int(s_rec["obliterated"]) + 1
		elif outcome == "TIMEOUT":
			s_rec["timeouts"] = int(s_rec["timeouts"]) + 1
		else:
			s_rec["losses"] = int(s_rec["losses"]) + 1

		# Aggregate by enemy encounter composition
		if not by_encounter.has(enc):
			by_encounter[enc] = {
				"matches": 0,
				"wins": 0,
				"losses": 0,
				"obliterated": 0,
				"total_turns": 0,
				"win_hp_sum": 0
			}
		var e_rec: Dictionary = by_encounter[enc]
		e_rec["matches"] = int(e_rec["matches"]) + 1
		e_rec["total_turns"] = int(e_rec["total_turns"]) + turns
		if outcome == "WIN":
			e_rec["wins"] = int(e_rec["wins"]) + 1
			e_rec["win_hp_sum"] = int(e_rec["win_hp_sum"]) + final_hp
		elif outcome == "OBLITERATED":
			e_rec["obliterated"] = int(e_rec["obliterated"]) + 1
		else:
			e_rec["losses"] = int(e_rec["losses"]) + 1

		# Aggregate card telemetry
		var drawn_map: Dictionary = m.get("cards_drawn_by_id", {})
		for cid in drawn_map.keys():
			_ensure_card_stat(card_stats, str(cid))
			card_stats[str(cid)]["drawn"] = int(card_stats[str(cid)]["drawn"]) + int(drawn_map[cid])

		var played_map: Dictionary = m.get("cards_played_by_id", {})
		for cid in played_map.keys():
			var key: String = str(cid)
			_ensure_card_stat(card_stats, key)
			var cnt: int = int(played_map[cid])
			card_stats[key]["played"] = int(card_stats[key]["played"]) + cnt
			card_stats[key]["matches_played_in"] = int(card_stats[key]["matches_played_in"]) + 1
			if outcome == "WIN":
				card_stats[key]["wins_when_played"] = int(card_stats[key]["wins_when_played"]) + 1

		var qte_map: Dictionary = m.get("qte_stats_by_id", {})
		for cid in qte_map.keys():
			var key: String = str(cid)
			_ensure_card_stat(card_stats, key)
			var q: Dictionary = qte_map[cid]
			card_stats[key]["qte_attempts"] = int(card_stats[key]["qte_attempts"]) + int(q.get("attempts", 0))
			card_stats[key]["qte_successes"] = int(card_stats[key]["qte_successes"]) + int(q.get("successes", 0))
			card_stats[key]["qte_failures"] = int(card_stats[key]["qte_failures"]) + int(q.get("failures", 0))

	# Finalize derived percentages
	var strategy_summary: Dictionary = {}
	for strat in by_strategy.keys():
		var sr: Dictionary = by_strategy[strat]
		var m_cnt: int = maxi(1, int(sr["matches"]))
		var w_cnt: int = int(sr["wins"])
		strategy_summary[strat] = {
			"matches": int(sr["matches"]),
			"wins": w_cnt,
			"losses": int(sr["losses"]),
			"obliterated": int(sr["obliterated"]),
			"timeouts": int(sr["timeouts"]),
			"win_rate_pct": snappedf(float(w_cnt) / float(m_cnt) * 100.0, 0.1),
			"avg_turns": snappedf(float(sr["total_turns"]) / float(m_cnt), 0.1),
			"avg_win_turns": snappedf(float(sr["win_turns_sum"]) / float(maxi(1, w_cnt)), 0.1) if w_cnt > 0 else 0.0,
			"avg_win_hp": snappedf(float(sr["win_hp_sum"]) / float(maxi(1, w_cnt)), 0.1) if w_cnt > 0 else 0.0,
			"avg_cards_played": snappedf(float(sr["cards_played_sum"]) / float(m_cnt), 0.1)
		}

	var encounter_summary: Dictionary = {}
	for enc in by_encounter.keys():
		var er: Dictionary = by_encounter[enc]
		var m_cnt: int = maxi(1, int(er["matches"]))
		var w_cnt: int = int(er["wins"])
		encounter_summary[enc] = {
			"matches": int(er["matches"]),
			"wins": w_cnt,
			"losses": int(er["losses"]),
			"obliterated": int(er["obliterated"]),
			"win_rate_pct": snappedf(float(w_cnt) / float(m_cnt) * 100.0, 0.1),
			"avg_turns": snappedf(float(er["total_turns"]) / float(m_cnt), 0.1),
			"avg_win_hp": snappedf(float(er["win_hp_sum"]) / float(maxi(1, w_cnt)), 0.1) if w_cnt > 0 else 0.0
		}

	var card_summary: Dictionary = {}
	for cid in card_stats.keys():
		var cs: Dictionary = card_stats[cid]
		var mp: int = int(cs["matches_played_in"])
		var drawn: int = int(cs["drawn"])
		var played: int = int(cs["played"])
		card_summary[cid] = {
			"drawn": drawn,
			"played": played,
			"play_rate_when_drawn_pct": snappedf(float(played) / float(maxi(1, drawn)) * 100.0, 0.1),
			"matches_played_in": mp,
			"win_rate_when_played_pct": snappedf(float(cs["wins_when_played"]) / float(maxi(1, mp)) * 100.0, 0.1) if mp > 0 else 0.0,
			"qte_attempts": int(cs["qte_attempts"]),
			"qte_successes": int(cs["qte_successes"]),
			"qte_failures": int(cs["qte_failures"])
		}

	var code_audit_findings: Array[Dictionary] = [
		{
			"id": "BUG-01",
			"severity": "HIGH (Fixed in Branch)",
			"location": "global/shaker.gd:shake()",
			"description": "Shaker.shake() previously bound tweens to the Shaker autoload without checking is_instance_valid(thing) on completion. Killing an enemy during a 2.0s Ultimate shake (e.g. adda_swap_health followed by Axe Attack) triggered freed-object errors. Fixed by binding shake tween to thing.create_tween() with validity guards."
		},
		{
			"id": "BUG-02",
			"severity": "HIGH (Fixed in Branch)",
			"location": "global/shaker.gd:shake_loop()",
			"description": "Shaker.shake_loop() (triggered by Last Gasp Ultimate) created an infinite set_loops() tween on the global Shaker autoload instead of thing.create_tween(). When Player was freed on scene reload or battle cleanup without battle_over_screen_requested, Godot spammed 'Lambda capture at index 0 was freed' at 20Hz indefinitely. Fixed by binding shake_loop to thing.create_tween().set_loops()."
		},
		{
			"id": "BUG-03",
			"severity": "CRITICAL (Fixed in Branch)",
			"location": "scenes/ui/battle_ui.gd:_ready()",
			"description": "EndTurnButton started enabled (disabled=false) during the initial 1.0s opening hand draw animation. Clicking End Turn during the opening draw launched Enemy Turn #1 concurrently with Player Turn #1, causing double signal connections on Golem actions, freed-card discard errors, and state race conditions. Fixed by initializing end_turn_button.disabled = true until player_hand_drawn."
		},
		{
			"id": "BUG-04",
			"severity": "MEDIUM (Fixed in Branch)",
			"location": "characters/warrior/cards/warrior_nuke.gd:_play_nuclear_cutscene()",
			"description": "Nuclear whiteout and fade tweens were bound to Player instead of Arena, risking an unresolving await if Player node was freed mid-cutscene (leaving battle_over_resolution_in_progress stuck true). Fixed by binding cutscene tweens to Arena."
		},
		{
			"id": "NOTE-01",
			"severity": "DESIGN / INFO",
			"location": "scenes/battle/battle.gd:_shuffle_enemy_types()",
			"description": "Enemy nodes keep static scene names (GhostEnemy, GobEnemy, GolemEnemy) when EnemyStats are shuffled across the 4-enemy pool (including Wolf). Tools and future UI scripts must inspect enemy.stats.ai rather than node.name."
		},
		{
			"id": "NOTE-02",
			"severity": "BALANCE / INFO",
			"location": "characters/warrior/cards/warrior_blood_ritual.gd",
			"description": "Stats.set_health() clamps health to max_health (45). Playing Blood Ritual above 23 HP caps healing at 45 while still applying -7 HP/turn bleed, making it a high-skill situational comeback card."
		}
	]

	return {
		"project": "StrategemSpiral / slayTheStrat (Godot 4.7)",
		"generated_at": Time.get_datetime_string_from_system(),
		"duration_seconds": snappedf(elapsed_seconds, 0.01),
		"functional_suite": {
			"total": functional_results.size(),
			"passed": ft_passed,
			"failed": functional_results.size() - ft_passed,
			"results": functional_results
		},
		"simulation_overview": {
			"total_matches": total_matches,
			"wins": total_wins,
			"losses": total_losses,
			"obliterated": total_obliterated,
			"timeouts": total_timeouts,
			"overall_win_rate_pct": snappedf(float(total_wins) / float(maxi(1, total_matches)) * 100.0, 0.1),
			"invariant_errors_count": all_invariant_errors.size(),
			"invariant_errors": all_invariant_errors
		},
		"strategy_breakdown": strategy_summary,
		"encounter_breakdown": encounter_summary,
		"card_telemetry": card_summary,
		"code_audit_findings": code_audit_findings,
		"match_history": match_records
	}


static func _ensure_card_stat(card_stats: Dictionary, cid: String) -> void:
	if not card_stats.has(cid):
		card_stats[cid] = {
			"drawn": 0,
			"played": 0,
			"matches_played_in": 0,
			"wins_when_played": 0,
			"qte_attempts": 0,
			"qte_successes": 0,
			"qte_failures": 0
		}


static func save_reports(report: Dictionary, json_path: String, md_path: String, html_path: String) -> void:
	var dir_path: String = ProjectSettings.globalize_path(json_path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(dir_path)

	var jf := FileAccess.open(json_path, FileAccess.WRITE)
	if jf:
		jf.store_string(JSON.stringify(report, "  "))
		jf.close()

	var mf := FileAccess.open(md_path, FileAccess.WRITE)
	if mf:
		mf.store_string(_render_markdown(report))
		mf.close()

	var hf := FileAccess.open(html_path, FileAccess.WRITE)
	if hf:
		hf.store_string(_render_html(report))
		hf.close()


static func _render_markdown(report: Dictionary) -> String:
	var ft: Dictionary = report["functional_suite"]
	var sim: Dictionary = report["simulation_overview"]
	var md: String = ""

	md += "# 🤖 slayTheStrat AI 机器人自动化测试与平衡性分析报告\n\n"
	md += "- **测试项目**: `%s`\n" % str(report["project"])
	md += "- **生成时间**: `%s`\n" % str(report["generated_at"])
	md += "- **总执行耗时**: `%.2f 秒`\n" % float(report["duration_seconds"])
	md += "- **核心机制单元测试通过率**: **%d / %d** (`%.0f%%`)\n" % [
		int(ft["passed"]), int(ft["total"]),
		float(ft["passed"]) / float(maxi(1, int(ft["total"]))) * 100.0
	]
	md += "- **AI 模拟对战总局数**: **%d 局**（胜率 **%.1f%%**，同归于尽 `OBLITERATED` **%d 局**，运行时不变式异常 **%d 项**）\n\n" % [
		int(sim["total_matches"]), float(sim["overall_win_rate_pct"]),
		int(sim["obliterated"]), int(sim["invariant_errors_count"])
	]

	md += "## 1. 核心机制确定性验证 (Functional Mechanics Verification)\n\n"
	md += "| 编号 | 测试项 | 状态 | 详细验证结果 |\n"
	md += "| :--- | :--- | :---: | :--- |\n"
	var ft_list: Array = ft["results"]
	for item in ft_list:
		var status_str: String = "PASS" if bool(item["passed"]) else "FAIL"
		md += "| `%s` | %s | **%s** | %s |\n" % [
			str(item["id"]), str(item["title"]), status_str, str(item["details"])
		]

	md += "\n## 2. 多人格 AI 策略对战统计 (Multi-Strategy AI Benchmarks)\n\n"
	md += "| AI 策略人格 | 对局数 | 胜场 (WIN) | 败场 (LOSE) | 同归于尽 (OBLITERATED) | 胜率 | 获胜平均回合 | 获胜平均剩余 HP |\n"
	md += "| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |\n"
	var strat_map: Dictionary = report["strategy_breakdown"]
	var strat_keys: Array = strat_map.keys()
	strat_keys.sort()
	for sk in strat_keys:
		var s: Dictionary = strat_map[sk]
		md += "| `%s` | %d | %d | %d | %d | **%.1f%%** | %.1f | %.1f / 45 |\n" % [
			str(sk), int(s["matches"]), int(s["wins"]), int(s["losses"]), int(s["obliterated"]),
			float(s["win_rate_pct"]), float(s["avg_win_turns"]), float(s["avg_win_hp"])
		]

	md += "\n## 3. 随机敌人阵容难度矩阵 (3-of-4 Enemy Encounter Balance)\n\n"
	md += "| 敌人组合 (Encounter Lineup) | 出现次数 | 玩家胜场 | 玩家败场 | 同归于尽 | 玩家胜率 | 平均回合数 | 获胜剩余 HP |\n"
	md += "| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |\n"
	var enc_map: Dictionary = report["encounter_breakdown"]
	var enc_keys: Array = enc_map.keys()
	enc_keys.sort()
	for ek in enc_keys:
		var e: Dictionary = enc_map[ek]
		md += "| `%s` | %d | %d | %d | %d | **%.1f%%** | %.1f | %.1f |\n" % [
			str(ek), int(e["matches"]), int(e["wins"]), int(e["losses"]), int(e["obliterated"]),
			float(e["win_rate_pct"]), float(e["avg_turns"]), float(e["avg_win_hp"])
		]

	md += "\n## 4. 全卡牌抽用与 QTE 表现遥测 (Card & Ultimate QTE Telemetry)\n\n"
	md += "| 卡牌 ID | 抽到次数 | 打出次数 | 出牌转化率 | 参战局胜率 | QTE 触发 | QTE 成功 / 失败 |\n"
	md += "| :--- | :---: | :---: | :---: | :---: | :---: | :---: |\n"
	var card_map: Dictionary = report["card_telemetry"]
	var card_keys: Array = card_map.keys()
	card_keys.sort()
	for ck in card_keys:
		var c: Dictionary = card_map[ck]
		var qte_col: String = "-"
		if int(c["qte_attempts"]) > 0:
			qte_col = "%d / %d" % [int(c["qte_successes"]), int(c["qte_failures"])]
		md += "| `%s` | %d | %d | %.1f%% | %.1f%% | %d | %s |\n" % [
			str(ck), int(c["drawn"]), int(c["played"]),
			float(c["play_rate_when_drawn_pct"]), float(c["win_rate_when_played_pct"]),
			int(c["qte_attempts"]), qte_col
		]

	md += "\n## 5. 代码审计与缺陷发现记录 (Code Audit & Bug Report)\n\n"
	var findings: Array = report["code_audit_findings"]
	for f in findings:
		md += "- **[%s] (%s)** `%s`: %s\n" % [
			str(f["id"]), str(f["severity"]), str(f["location"]), str(f["description"])
		]

	var inv_errs: Array = sim["invariant_errors"]
	if not inv_errs.is_empty():
		md += "\n## 6. 运行时不变式告警\n\n"
		for err in inv_errs:
			md += "- %s\n" % str(err)
	else:
		md += "\n> **运行时稳定性结论**：全部 %d 场对局与 %d 项核心机制验证均完成闭环，零死锁、零负法力值、零越界生命值、零释放对象崩溃。\n" % [
			int(sim["total_matches"]), int(ft["total"])
		]

	return md


static func _render_html(report: Dictionary) -> String:
	var ft: Dictionary = report["functional_suite"]
	var sim: Dictionary = report["simulation_overview"]

	var ft_rows: String = ""
	for item in ft["results"]:
		var badge: String = "<span class='ok'>PASS</span>" if bool(item["passed"]) else "<span class='fail'>FAIL</span>"
		ft_rows += "<tr><td><code>%s</code></td><td>%s</td><td>%s</td><td>%s</td></tr>\n" % [
			str(item["id"]), str(item["title"]), badge, str(item["details"])
		]

	var strat_rows: String = ""
	var strat_map: Dictionary = report["strategy_breakdown"]
	var strat_keys: Array = strat_map.keys()
	strat_keys.sort()
	for sk in strat_keys:
		var s: Dictionary = strat_map[sk]
		strat_rows += "<tr><td><code>%s</code></td><td>%d</td><td>%d</td><td>%d</td><td>%d</td><td><b>%.1f%%</b></td><td>%.1f</td><td>%.1f / 45</td></tr>\n" % [
			str(sk), int(s["matches"]), int(s["wins"]), int(s["losses"]), int(s["obliterated"]),
			float(s["win_rate_pct"]), float(s["avg_win_turns"]), float(s["avg_win_hp"])
		]

	var enc_rows: String = ""
	var enc_map: Dictionary = report["encounter_breakdown"]
	var enc_keys: Array = enc_map.keys()
	enc_keys.sort()
	for ek in enc_keys:
		var e: Dictionary = enc_map[ek]
		enc_rows += "<tr><td><code>%s</code></td><td>%d</td><td>%d</td><td>%d</td><td>%d</td><td><b>%.1f%%</b></td><td>%.1f</td><td>%.1f</td></tr>\n" % [
			str(ek), int(e["matches"]), int(e["wins"]), int(e["losses"]), int(e["obliterated"]),
			float(e["win_rate_pct"]), float(e["avg_turns"]), float(e["avg_win_hp"])
		]

	var card_rows: String = ""
	var card_map: Dictionary = report["card_telemetry"]
	var card_keys: Array = card_map.keys()
	card_keys.sort()
	for ck in card_keys:
		var c: Dictionary = card_map[ck]
		var qte_str: String = "-" if int(c["qte_attempts"]) == 0 else ("%d (%d ok / %d fail)" % [int(c["qte_attempts"]), int(c["qte_successes"]), int(c["qte_failures"])])
		card_rows += "<tr><td><code>%s</code></td><td>%d</td><td>%d</td><td>%.1f%%</td><td>%.1f%%</td><td>%s</td></tr>\n" % [
			str(ck), int(c["drawn"]), int(c["played"]),
			float(c["play_rate_when_drawn_pct"]), float(c["win_rate_when_played_pct"]), qte_str
		]

	var html: String = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<title>slayTheStrat AI Test Report Dashboard</title>
<style>
  body { font-family: system-ui, -apple-system, sans-serif; background: #0f111a; color: #e2e8f0; margin: 0; padding: 28px; }
  .wrap { max-width: 1120px; margin: 0 auto; }
  h1 { color: #c4b5fd; margin-bottom: 6px; }
  h2 { color: #93c5fd; margin-top: 28px; border-bottom: 1px solid #262b40; padding-bottom: 6px; }
  .meta { color: #94a3b8; font-size: 14px; margin-bottom: 20px; }
  .cards { display: grid; grid-template-columns: repeat(4, 1fr); gap: 14px; margin-bottom: 20px; }
  .card { background: #181c2a; border: 1px solid #2a314d; border-radius: 10px; padding: 16px; }
  .card .k { font-size: 12px; color: #94a3b8; text-transform: uppercase; }
  .card .v { font-size: 26px; font-weight: 700; margin-top: 4px; color: #f8fafc; }
  table { width: 100%%; border-collapse: collapse; background: #181c2a; border-radius: 8px; overflow: hidden; font-size: 14px; }
  th, td { padding: 10px 12px; border-bottom: 1px solid #252b42; text-align: left; }
  th { background: #1f2538; color: #cbd5e1; }
  code { background: #0f1320; padding: 2px 6px; border-radius: 4px; color: #a5b4fc; }
  .ok { background: #064e3b; color: #6ee7b7; padding: 2px 8px; border-radius: 99px; font-weight: 600; font-size: 12px; }
  .fail { background: #7f1d1d; color: #fca5a5; padding: 2px 8px; border-radius: 99px; font-weight: 600; font-size: 12px; }
</style>
</head>
<body>
<div class="wrap">
  <h1>slayTheStrat — AI 机器人自动化测试报告</h1>
  <div class="meta">生成时间: %s | 执行耗时: %.2fs | 引擎: Godot 4.7</div>
  <div class="cards">
    <div class="card"><div class="k">核心机制验证</div><div class="v">%d / %d</div></div>
    <div class="card"><div class="k">模拟总场次</div><div class="v">%d 场</div></div>
    <div class="card"><div class="k">总体胜率 / 同归于尽</div><div class="v">%.1f%% / %d</div></div>
    <div class="card"><div class="k">运行时不变式异常</div><div class="v">%d</div></div>
  </div>
  <h2>1. 核心机制单元测试 (Functional Verification)</h2>
  <table><thead><tr><th>ID</th><th>测试名称</th><th>结果</th><th>详情</th></tr></thead><tbody>%s</tbody></table>
  <h2>2. 多策略 AI 机器人基准测试 (Strategy Benchmarks)</h2>
  <table><thead><tr><th>AI 策略</th><th>场次</th><th>胜</th><th>负</th><th>OBLITERATED</th><th>胜率</th><th>平均获胜回合</th><th>获胜剩余 HP</th></tr></thead><tbody>%s</tbody></table>
  <h2>3. 随机敌人组合难度矩阵 (Encounter Balance)</h2>
  <table><thead><tr><th>敌人阵容</th><th>场次</th><th>胜</th><th>负</th><th>OBLITERATED</th><th>胜率</th><th>平均回合</th><th>获胜剩余 HP</th></tr></thead><tbody>%s</tbody></table>
  <h2>4. 卡牌与终极技能 QTE 遥测 (Card Telemetry)</h2>
  <table><thead><tr><th>卡牌 ID</th><th>抽到</th><th>打出</th><th>出牌率</th><th>打出胜率</th><th>QTE 统计</th></tr></thead><tbody>%s</tbody></table>
</div>
</body>
</html>
""" % [
		str(report["generated_at"]),
		float(report["duration_seconds"]),
		int(ft["passed"]), int(ft["total"]),
		int(sim["total_matches"]),
		float(sim["overall_win_rate_pct"]), int(sim["obliterated"]),
		int(sim["invariant_errors_count"]),
		ft_rows,
		strat_rows,
		enc_rows,
		card_rows
	]
	return html
