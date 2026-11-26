class_name AIBotBrain
extends RefCounted

enum Strategy {
	TACTICAL_PRO,
	AGGRESSIVE,
	DEFENSIVE,
	HUMAN_SIM,
	RANDOM_FUZZ
}

class Decision extends RefCounted:
	var action: String = "END_TURN" # "PLAY_CARD" or "END_TURN"
	var card_ui: CardUI = null
	var target_enemy: Enemy = null
	var score: float = 0.0
	var reason: String = ""


static func get_strategy_name(strategy: Strategy) -> String:
	match strategy:
		Strategy.TACTICAL_PRO:
			return "Tactical_Pro"
		Strategy.AGGRESSIVE:
			return "Aggressive"
		Strategy.DEFENSIVE:
			return "Defensive"
		Strategy.HUMAN_SIM:
			return "Human_Sim_70QTE"
		Strategy.RANDOM_FUZZ:
			return "Random_Fuzz"
	return "Unknown"


static func get_default_qte_accuracy(strategy: Strategy) -> float:
	match strategy:
		Strategy.TACTICAL_PRO:
			return 1.0
		Strategy.AGGRESSIVE:
			return 0.95
		Strategy.DEFENSIVE:
			return 0.95
		Strategy.HUMAN_SIM:
			return 0.70
		Strategy.RANDOM_FUZZ:
			return 0.45
	return 1.0


static func identify_enemy_type(enemy: Enemy) -> String:
	if not is_instance_valid(enemy) or not enemy.stats:
		return "Unknown"
	if enemy.stats.ai:
		var ai_path: String = enemy.stats.ai.resource_path.to_lower()
		if ai_path.contains("ghost"):
			return "Ghost"
		if ai_path.contains("gob"):
			return "Gob"
		if ai_path.contains("golem"):
			return "Golem"
		if ai_path.contains("wolf"):
			return "Wolf"
	return enemy.name


static func analyze_enemy_intent(enemy: Enemy) -> Dictionary:
	var info: Dictionary = {
		"action_id": "none",
		"incoming_damage": 0,
		"self_destruct": false,
		"heals_self": 0,
		"grants_taunt": false,
		"grants_team_block": 0
	}
	if not is_instance_valid(enemy) or not enemy.current_action:
		return info

	var script_obj: Script = enemy.current_action.get_script() as Script
	if not script_obj:
		return info

	var path: String = script_obj.resource_path.to_lower()
	if path.ends_with("ghost_attack_action.gd"):
		info["action_id"] = "ghost_attack"
		info["incoming_damage"] = int(enemy.current_action.get("damage"))
	elif path.ends_with("ghost_block_action.gd"):
		info["action_id"] = "ghost_block"
	elif path.ends_with("ghost_mega_block_action.gd"):
		info["action_id"] = "ghost_mega_block"
	elif path.ends_with("gob_attack_action.gd"):
		info["action_id"] = "gob_kamikaze"
		info["incoming_damage"] = int(enemy.current_action.get("damage"))
		info["self_destruct"] = true
	elif path.ends_with("gob_block_action.gd"):
		info["action_id"] = "gob_block"
	elif path.ends_with("golem_attack_action.gd"):
		info["action_id"] = "golem_attack"
		info["incoming_damage"] = int(enemy.current_action.get("damage"))
		info["grants_team_block"] = int(enemy.current_action.get("block_amount"))
	elif path.ends_with("golem_block_action.gd"):
		info["action_id"] = "golem_taunt"
		info["grants_taunt"] = true
	elif path.ends_with("wolf_attack_action.gd"):
		info["action_id"] = "wolf_double_bite"
		var hit_dmg: int = int(enemy.current_action.get("damage"))
		info["incoming_damage"] = hit_dmg * 2
		info["heals_self"] = int(hit_dmg * 0.5) * 2
	return info


static func choose_next_action(
	strategy: Strategy,
	player: Player,
	hand: Hand,
	enemies: Array[Enemy]
) -> Decision:
	var decision := Decision.new()
	if not is_instance_valid(player) or not player.stats or player.stats.health <= 0:
		return decision
	if enemies.is_empty():
		return decision

	var playable_cards: Array[CardUI] = []
	for child in hand.get_children():
		var card_ui := child as CardUI
		if not is_instance_valid(card_ui) or card_ui.is_queued_for_deletion():
			continue
		if not card_ui.card or card_ui.disabled:
			continue
		if player.stats.can_play_card(card_ui.card):
			playable_cards.append(card_ui)

	if playable_cards.is_empty():
		decision.reason = "No playable cards with remaining mana (%d)" % player.stats.mana
		return decision

	if strategy == Strategy.RANDOM_FUZZ:
		var picked: CardUI = playable_cards[randi() % playable_cards.size()]
		decision.action = "PLAY_CARD"
		decision.card_ui = picked
		if picked.card.is_single_targeted():
			decision.target_enemy = enemies[randi() % enemies.size()]
		decision.score = 1.0
		decision.reason = "Random fuzz pick: %s" % picked.card.id
		return decision

	# Compute battlefield context
	var total_incoming_damage: int = 0
	var enemy_hp_sum: int = 0
	var max_enemy_hp: int = 0
	var protecting_enemy: Enemy = null

	for e in enemies:
		var intent_info: Dictionary = analyze_enemy_intent(e)
		total_incoming_damage += int(intent_info["incoming_damage"])
		enemy_hp_sum += e.stats.health
		if e.stats.health > max_enemy_hp:
			max_enemy_hp = e.stats.health
		if e.is_protecting_allies and e.stats.health > 0:
			protecting_enemy = e

	var unblocked_damage: int = maxi(0, total_incoming_damage - player.stats.block)
	var next_turn_bleed: int = player.stats.blood_ritual_loss_per_turn
	var effective_danger: int = unblocked_damage + next_turn_bleed

	# Estimate total attack burst currently playable in hand with remaining mana
	var potential_normal_damage: int = _estimate_hand_attack_damage(
		playable_cards,
		player.stats.mana,
		player.stats.damage_multiplier,
		enemies.size()
	)
	var potential_triple_damage: int = _estimate_hand_attack_damage(
		playable_cards,
		player.stats.mana,
		3,
		enemies.size()
	)

	var best_score: float = -99999.0
	var best_card: CardUI = null
	var best_target: Enemy = null
	var best_reason: String = ""

	for card_ui in playable_cards:
		var card: Card = card_ui.card
		if card.is_single_targeted():
			for candidate in enemies:
				var eval_res: Dictionary = _score_single_target_card(
					strategy,
					card,
					candidate,
					protecting_enemy,
					player,
					enemies,
					unblocked_damage
				)
				var sc: float = float(eval_res["score"])
				if strategy == Strategy.HUMAN_SIM:
					sc += randf_range(-6.0, 6.0)
				if sc > best_score:
					best_score = sc
					best_card = card_ui
					best_target = candidate
					best_reason = str(eval_res["reason"])
		else:
			var eval_res: Dictionary = _score_non_targeted_card(
				strategy,
				card,
				protecting_enemy,
				player,
				enemies,
				enemy_hp_sum,
				max_enemy_hp,
				unblocked_damage,
				effective_danger,
				potential_normal_damage,
				potential_triple_damage
			)
			var sc: float = float(eval_res["score"])
			if strategy == Strategy.HUMAN_SIM:
				sc += randf_range(-6.0, 6.0)
			if sc > best_score:
				best_score = sc
				best_card = card_ui
				best_target = null
				best_reason = str(eval_res["reason"])

	if best_card != null and best_score > 0.0:
		decision.action = "PLAY_CARD"
		decision.card_ui = best_card
		decision.target_enemy = best_target
		decision.score = best_score
		decision.reason = best_reason
	else:
		decision.action = "END_TURN"
		decision.reason = "Remaining playable cards have negative tactical value (best=%.1f)" % best_score

	return decision


static func _estimate_hand_attack_damage(
	playable_cards: Array[CardUI],
	available_mana: int,
	dmg_mult: int,
	enemy_count: int
) -> int:
	# Sort attack efficiencies greedily
	var axe_count: int = 0
	var sweep_count: int = 0
	for c in playable_cards:
		if c.card.id == "warrior_axe_attack":
			axe_count += 1
		elif c.card.id == "warrior_sweep":
			sweep_count += 1

	var mana_left: int = available_mana
	var total_dmg: int = 0
	while sweep_count > 0 and mana_left >= 2 and enemy_count >= 3:
		sweep_count -= 1
		mana_left -= 2
		total_dmg += 3 * dmg_mult * enemy_count
	while axe_count > 0 and mana_left >= 1:
		axe_count -= 1
		mana_left -= 1
		total_dmg += 6 * dmg_mult
	while sweep_count > 0 and mana_left >= 2:
		sweep_count -= 1
		mana_left -= 2
		total_dmg += 3 * dmg_mult * enemy_count
	return total_dmg


static func _score_single_target_card(
	strategy: Strategy,
	card: Card,
	raw_target: Enemy,
	protecting_enemy: Enemy,
	player: Player,
	_enemies: Array[Enemy],
	unblocked_damage: int
) -> Dictionary:
	# Account for Golem ally protection redirect
	var actual_target: Enemy = raw_target
	if protecting_enemy != null and raw_target != protecting_enemy:
		actual_target = protecting_enemy

	var mult: int = player.stats.damage_multiplier
	var dmg: int = 6 * mult
	var effective_hp: int = actual_target.stats.health + actual_target.stats.block
	var kills_target: bool = dmg >= effective_hp
	var enemy_type: String = identify_enemy_type(actual_target)
	var intent_info: Dictionary = analyze_enemy_intent(actual_target)
	var incoming_from_target: int = int(intent_info["incoming_damage"])
	var is_kamikaze: bool = bool(intent_info["self_destruct"])

	var score: float = 32.0
	var reason: String = "Axe %d dmg -> %s" % [dmg, enemy_type]

	# Avoid redundant targeting of non-protecting allies when Golem redirects anyway
	if actual_target != raw_target:
		score -= 2.0
		reason += " (redirected to Taunt Golem)"

	if kills_target:
		score += 45.0 + float(incoming_from_target) * 2.5
		reason += " [LETHAL]"
	else:
		# If Gob is already going to blow itself up this turn and we CANNOT kill it now,
		# hitting it wastes damage!
		if is_kamikaze and strategy == Strategy.TACTICAL_PRO:
			score -= 28.0
			reason += " [Kamikaze Gob won't die, deprioritize]"
		else:
			if enemy_type == "Wolf":
				score += 16.0 # High priority: Wolf heals + deals 8
			elif enemy_type == "Ghost":
				# Watch out for Ghost <=6 HP conditional 15-block if we just poke it without follow-up
				var post_hp: int = actual_target.stats.health - maxi(0, dmg - actual_target.stats.block)
				if actual_target.stats.health > 6 and post_hp <= 6 and player.stats.mana < 2 and strategy == Strategy.TACTICAL_PRO:
					score -= 4.0
				else:
					score += 12.0
			elif enemy_type == "Gob":
				score += 14.0
			elif enemy_type == "Golem":
				score += 4.0

	match strategy:
		Strategy.AGGRESSIVE:
			score += 22.0
		Strategy.DEFENSIVE:
			if unblocked_damage > 0 and not kills_target:
				score -= 12.0

	return {"score": score, "reason": reason}


static func _score_non_targeted_card(
	strategy: Strategy,
	card: Card,
	protecting_enemy: Enemy,
	player: Player,
	enemies: Array[Enemy],
	enemy_hp_sum: int,
	max_enemy_hp: int,
	unblocked_damage: int,
	effective_danger: int,
	_potential_normal_damage: int,
	potential_triple_damage: int
) -> Dictionary:
	var hp: int = player.stats.health
	var max_hp: int = player.stats.max_health
	var mult: int = player.stats.damage_multiplier
	var enemy_count: int = enemies.size()

	match card.id:
		"warrior_sweep":
			var per_hit: int = 3 * mult
			var total_effective_dmg: int = 0
			var kills_any: int = 0
			if protecting_enemy != null:
				# All hits redirect onto protecting Golem!
				var redirected_total: int = per_hit * enemy_count
				total_effective_dmg = redirected_total
				if redirected_total >= protecting_enemy.stats.health + protecting_enemy.stats.block:
					kills_any += 1
			else:
				for e in enemies:
					total_effective_dmg += per_hit
					if per_hit >= e.stats.health + e.stats.block:
						kills_any += 1
			var score: float = float(total_effective_dmg) * 3.8 + float(kills_any) * 35.0
			if enemy_count == 1 and mult == 1:
				score -= 10.0 # Less mana-efficient than Axe vs single target
			if strategy == Strategy.AGGRESSIVE:
				score += 18.0
			elif strategy == Strategy.DEFENSIVE and unblocked_damage > 0 and kills_any == 0:
				score -= 14.0
			return {"score": score, "reason": "Sweep AoE (%d total dmg, %d kills)" % [total_effective_dmg, kills_any]}

		"warrior_block":
			if unblocked_damage <= 0:
				if strategy == Strategy.DEFENSIVE and player.stats.block == 0:
					return {"score": 2.0, "reason": "Defensive precaution block"}
				return {"score": -25.0, "reason": "No unblocked incoming damage"}
			var prevented: int = mini(5, unblocked_damage)
			var score: float = float(prevented) * 7.5
			if hp <= effective_danger + 6:
				score += 45.0 # Emergency survival block
			if strategy == Strategy.DEFENSIVE:
				score += 30.0
			elif strategy == Strategy.AGGRESSIVE:
				score -= 15.0
			return {"score": score, "reason": "Block %d incoming damage (unblocked=%d)" % [prevented, unblocked_damage]}

		"mana_surge":
			var all_low: bool = enemy_hp_sum <= 12 * mult
			if all_low:
				return {"score": -10.0, "reason": "Enemies nearly dead, skip setup"}
			var score: float = 28.0
			if effective_danger >= hp:
				score -= 60.0 # Don't spend mana on next turn if dying this turn!
			elif unblocked_damage == 0:
				score += 20.0 # Free turn to bank +2 mana!
			if strategy == Strategy.DEFENSIVE:
				score += 10.0
			return {"score": score, "reason": "Bank +2 overflow mana for next turn"}

		"adda_swap_health":
			var new_player_hp: int = mini(max_hp, enemy_hp_sum)
			var new_each_enemy_hp: int = ceili(float(hp) / float(enemy_count))
			var new_enemy_sum: int = new_each_enemy_hp * enemy_count
			var player_gain: int = new_player_hp - hp
			var enemy_loss: int = enemy_hp_sum - new_enemy_sum
			var net_swing: int = player_gain + enemy_loss
			if net_swing <= 8:
				return {"score": -100.0, "reason": "Swap HP unfavorable (swing=%d)" % net_swing}
			var score: float = float(net_swing) * 2.8
			if hp <= 20 and new_player_hp >= 30:
				score += 50.0
			return {
				"score": score,
				"reason": "Swap HP Ult (Player %d->%d, Enemies sum %d->%d)" % [hp, new_player_hp, enemy_hp_sum, new_enemy_sum]
			}

		"wssws_blood_ritual":
			if player.stats.blood_ritual_loss_per_turn > 0:
				return {"score": -120.0, "reason": "Blood Ritual already active"}
			var doubled_hp: int = mini(max_hp, hp * 2)
			var gained_hp: int = doubled_hp - hp
			if gained_hp < 12:
				return {"score": -90.0, "reason": "Blood Ritual heals too little (+%d) for -7/turn bleed" % gained_hp}
			var score: float = float(gained_hp) * 2.2 - 12.0
			if hp <= unblocked_damage and doubled_hp > unblocked_damage:
				score += 55.0 # Saves from lethal this turn!
			if strategy == Strategy.DEFENSIVE and hp <= 20:
				score += 20.0
			return {"score": score, "reason": "Blood Ritual Ult (+%d HP, -7/turn)" % gained_hp}

		"last_gasp":
			if mult >= 3:
				return {"score": -150.0, "reason": "Triple damage already active"}
			# Check if 3x damage lets us wipe or nearly wipe the board immediately, or if already at <=8 HP
			var enemy_total_eff_hp: int = enemy_hp_sum
			for e in enemies:
				enemy_total_eff_hp += e.stats.block
			if potential_triple_damage >= enemy_total_eff_hp and enemy_count <= 2:
				return {"score": 110.0, "reason": "Last Gasp Ult enables immediate 3x LETHAL"}
			if hp <= 9 and unblocked_damage == 0:
				return {"score": 85.0, "reason": "Low HP (%d->5) safe Last Gasp 3x power spike" % hp}
			if strategy == Strategy.AGGRESSIVE and hp <= 22 and unblocked_damage <= 4 and player.stats.mana >= 2:
				return {"score": 65.0, "reason": "Aggressive Last Gasp 3x burst"}
			return {"score": -110.0, "reason": "Too risky to drop %d HP -> 5 HP right now" % hp}

		"nuke_30_kill_streak":
			if hp > 30:
				if enemy_hp_sum >= 18 or enemy_count >= 2:
					return {"score": 130.0, "reason": "Tactical Nuke Ult! Player survives (%d->%d HP) & deals 30 AoE true dmg" % [hp, hp - 30]}
				return {"score": -20.0, "reason": "Save HP, enemies already weak"}
			else:
				# Player <= 30 HP: Nuke kills player too! Only use if guaranteed death anyway AND kills all enemies (OBLITERATED > LOSE)
				if effective_danger >= hp and player.stats.mana == 0 and max_enemy_hp <= 30:
					return {"score": 40.0, "reason": "Desperation Nuke for mutual OBLITERATION instead of defeat"}
				return {"score": -200.0, "reason": "Nuke would kill player (%d <= 30 HP)" % hp}

	return {"score": 5.0, "reason": "Fallback play %s" % card.id}
