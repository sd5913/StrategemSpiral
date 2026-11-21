class_name AIBot
extends RefCounted

enum Strategy {
	BALANCED,
	AGGRESSIVE,
	DEFENSIVE,
	RANDOM_FUZZ
}

static func get_strategy_name(strat: Strategy) -> String:
	match strat:
		Strategy.BALANCED: return "Balanced (Heuristic)"
		Strategy.AGGRESSIVE: return "Aggressive (Rush)"
		Strategy.DEFENSIVE: return "Defensive (Turtle)"
		Strategy.RANDOM_FUZZ: return "Random Fuzz (Stress)"
		_: return "Unknown"

# Evaluates the current battle state and returns the next best decision
static func evaluate_turn(
	player: Player,
	char_stats: CharacterStats,
	hand_cards: Array,
	enemies: Array,
	drop_area: Area2D,
	strategy: Strategy
) -> Dictionary:
	# Filter valid alive enemies
	var alive_enemies: Array[Enemy] = []
	for e in enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			if e.stats and e.stats.health > 0:
				alive_enemies.append(e)

	if alive_enemies.is_empty():
		return {"action": "WAIT", "reason": "All enemies defeated"}

	# Filter valid playable cards
	var playable: Array[CardUI] = []
	for c in hand_cards:
		if is_instance_valid(c) and not c.is_queued_for_deletion() and c.card:
			if char_stats.can_play_card(c.card):
				playable.append(c)

	if playable.is_empty():
		return {"action": "END_TURN", "reason": "No affordable or playable cards left"}

	# Strategy dispatch
	match strategy:
		Strategy.RANDOM_FUZZ:
			return _evaluate_fuzz(playable, alive_enemies, drop_area)
		Strategy.AGGRESSIVE:
			return _evaluate_aggressive(playable, alive_enemies, char_stats, drop_area)
		Strategy.DEFENSIVE:
			return _evaluate_defensive(playable, alive_enemies, char_stats, drop_area)
		_:
			return _evaluate_balanced(playable, alive_enemies, char_stats, drop_area)

# Strategy: Balanced (Mix of threat mitigation, lethal calculation, and mana efficiency)
static func _evaluate_balanced(
	playable: Array[CardUI],
	enemies: Array[Enemy],
	char_stats: CharacterStats,
	drop_area: Area2D
) -> Dictionary:
	var incoming_dmg := _calc_incoming_damage(enemies)
	var current_block := char_stats.block

	# Check for Protector enemy (e.g. Golem using protect_allies)
	var protector: Enemy = null
	for e in enemies:
		if e.is_protecting_allies:
			protector = e
			break

	# 1. LETHAL CHECK: Can we finish off an enemy with an attack card?
	for c_ui in playable:
		var c := c_ui.card
		var dmg := _get_card_damage(c)
		if dmg > 0:
			for e in enemies:
				var target_for_dmg := protector if protector else e
				var eff_hp := target_for_dmg.stats.health + target_for_dmg.stats.block
				if eff_hp <= dmg:
					var chosen_target = e if c.is_single_targeted() else drop_area
					return {
						"action": "PLAY_CARD",
						"card_ui": c_ui,
						"target": chosen_target,
						"reason": "Lethal on %s (%d dmg vs %d eff HP)" % [_enemy_name(target_for_dmg), dmg, eff_hp]
					}

	# 2. DEFENSE CHECK: If incoming damage will pierce block and we have a block card
	if incoming_dmg > current_block:
		for c_ui in playable:
			if c_ui.card.id == "warrior_block" or c_ui.card.type == Card.Type.SKILL:
				return {
					"action": "PLAY_CARD",
					"card_ui": c_ui,
					"target": drop_area,
					"reason": "Defending: incoming dmg (%d) > current block (%d)" % [incoming_dmg, current_block]
				}

	# 3. AOE SWEEP: If 2 or more enemies are alive, Sweep Attack is huge value
	if enemies.size() >= 2:
		for c_ui in playable:
			if c_ui.card.id == "warrior_sweep" or c_ui.card.target == Card.Target.ALL_ENEMIES:
				return {
					"action": "PLAY_CARD",
					"card_ui": c_ui,
					"target": drop_area,
					"reason": "AoE Sweep: hitting %d enemies simultaneously" % enemies.size()
				}

	# 4. MANA SURGE: Prepare overflow mana if we have breathing room or excess mana
	for c_ui in playable:
		if c_ui.card.id == "mana_surge":
			if incoming_dmg <= current_block or char_stats.mana >= 2:
				return {
					"action": "PLAY_CARD",
					"card_ui": c_ui,
					"target": drop_area,
					"reason": "Mana Surge: buffing next turn mana"
				}

	# 5. SINGLE TARGET ATTACK: Focus on best target (lowest HP or highest threat)
	var best_target := _pick_best_target(enemies)
	for c_ui in playable:
		if c_ui.card.is_single_targeted() and _get_card_damage(c_ui.card) > 0:
			return {
				"action": "PLAY_CARD",
				"card_ui": c_ui,
				"target": best_target,
				"reason": "Focusing %s (HP: %d, Intent: %s)" % [
					_enemy_name(best_target),
					best_target.stats.health,
					_intent_desc(best_target)
				]
			}

	# 6. Fallback: play any remaining card or end turn
	for c_ui in playable:
		var target_node = best_target if c_ui.card.is_single_targeted() else drop_area
		return {
			"action": "PLAY_CARD",
			"card_ui": c_ui,
			"target": target_node,
			"reason": "Playing leftover card %s" % c_ui.card.id
		}

	return {"action": "END_TURN", "reason": "Turn complete"}

# Strategy: Aggressive (Prioritize max damage)
static func _evaluate_aggressive(
	playable: Array[CardUI],
	enemies: Array[Enemy],
	_char_stats: CharacterStats,
	drop_area: Area2D
) -> Dictionary:
	var best_target := _pick_best_target(enemies)

	# 1. Play AoE Sweep if multiple enemies
	if enemies.size() >= 2:
		for c_ui in playable:
			if c_ui.card.target == Card.Target.ALL_ENEMIES:
				return {"action": "PLAY_CARD", "card_ui": c_ui, "target": drop_area, "reason": "Aggressive AoE"}

	# 2. Play Single Target Attacks
	for c_ui in playable:
		if c_ui.card.is_single_targeted() and _get_card_damage(c_ui.card) > 0:
			return {"action": "PLAY_CARD", "card_ui": c_ui, "target": best_target, "reason": "Aggressive Strike"}

	# 3. Mana Surge
	for c_ui in playable:
		if c_ui.card.id == "mana_surge":
			return {"action": "PLAY_CARD", "card_ui": c_ui, "target": drop_area, "reason": "Aggressive Surge"}

	# 4. Block cards last
	for c_ui in playable:
		var target_node = best_target if c_ui.card.is_single_targeted() else drop_area
		return {"action": "PLAY_CARD", "card_ui": c_ui, "target": target_node, "reason": "Leftover play"}

	return {"action": "END_TURN", "reason": "Turn complete"}

# Strategy: Defensive (Prioritize block and survival)
static func _evaluate_defensive(
	playable: Array[CardUI],
	enemies: Array[Enemy],
	char_stats: CharacterStats,
	drop_area: Area2D
) -> Dictionary:
	var incoming_dmg := _calc_incoming_damage(enemies)
	var current_block := char_stats.block

	# 1. Play Block cards until safe
	if incoming_dmg > current_block or char_stats.health < 20:
		for c_ui in playable:
			if c_ui.card.id == "warrior_block" or c_ui.card.type == Card.Type.SKILL:
				return {"action": "PLAY_CARD", "card_ui": c_ui, "target": drop_area, "reason": "Defensive Turtle"}

	# 2. Mana Surge
	for c_ui in playable:
		if c_ui.card.id == "mana_surge":
			return {"action": "PLAY_CARD", "card_ui": c_ui, "target": drop_area, "reason": "Defensive Surge"}

	# 3. Attacks with leftover mana
	var best_target := _pick_best_target(enemies)
	for c_ui in playable:
		var target_node = best_target if c_ui.card.is_single_targeted() else drop_area
		return {"action": "PLAY_CARD", "card_ui": c_ui, "target": target_node, "reason": "Leftover attack"}

	return {"action": "END_TURN", "reason": "Turn complete"}

# Strategy: Random Fuzz (Stress test robustness)
static func _evaluate_fuzz(
	playable: Array[CardUI],
	enemies: Array[Enemy],
	drop_area: Area2D
) -> Dictionary:
	var c_ui: CardUI = playable[randi() % playable.size()]
	var target_node: Node = drop_area
	if c_ui.card.is_single_targeted():
		target_node = enemies[randi() % enemies.size()]

	return {
		"action": "PLAY_CARD",
		"card_ui": c_ui,
		"target": target_node,
		"reason": "Random Fuzz Play: %s" % c_ui.card.id
	}

# Helpers
static func _calc_incoming_damage(enemies: Array[Enemy]) -> int:
	var total := 0
	for e in enemies:
		if is_instance_valid(e) and e.current_action:
			if "damage" in e.current_action:
				total += e.current_action.damage
	return total

static func _get_card_damage(card: Card) -> int:
	match card.id:
		"warrior_axe_attack": return 6
		"warrior_sweep": return 3
		_: return 0

static func _pick_best_target(enemies: Array[Enemy]) -> Enemy:
	# If any enemy is protecting allies, damage redirects there anyway
	for e in enemies:
		if e.is_protecting_allies:
			return e

	# Prioritize by lowest HP or highest incoming threat
	var best: Enemy = enemies[0]
	var min_hp := 9999
	for e in enemies:
		var hp := e.stats.health + e.stats.block
		# Give bonus priority to Gob (deals 14 damage)
		var threat := 0
		if e.current_action and "damage" in e.current_action:
			threat = e.current_action.damage
		var score := hp - (threat / 2)
		if score < min_hp:
			min_hp = score
			best = e
	return best

static func _enemy_name(enemy: Enemy) -> String:
	if not is_instance_valid(enemy):
		return "Unknown"
	return enemy.name

static func _intent_desc(enemy: Enemy) -> String:
	if not is_instance_valid(enemy) or not enemy.current_action:
		return "None"
	if enemy.current_action.intent:
		return "%s (%s)" % [enemy.current_action.name, enemy.current_action.intent.number]
	return enemy.current_action.name
