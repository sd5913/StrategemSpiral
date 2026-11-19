extends GutTest

const WARRIOR := preload("res://characters/warrior/warrior.tres")
const ATTACK := preload("res://characters/warrior/cards/warrior_axe_attack.tres")
const SWEEP := preload("res://characters/warrior/cards/warrior_sweep_attack.tres")

var stats: Stats


func before_each() -> void:
	stats = Stats.new()
	stats.max_health = 10
	stats.health = 10


func test_block_absorbs_damage_before_health() -> void:
	stats.block = 5
	stats.take_damage(3)
	assert_eq(stats.health, 10)
	assert_eq(stats.block, 2)


func test_damage_overflow_reaches_health() -> void:
	stats.block = 5
	stats.take_damage(6)
	assert_eq(stats.health, 9)
	assert_eq(stats.block, 0)


func test_negative_damage_leaves_health_and_block_intact() -> void:
	stats.block = 3
	stats.take_damage(-5)
	assert_eq(stats.health, 10)
	assert_eq(stats.block, 3)


func test_lethal_damage_clamps_health_at_zero() -> void:
	stats.take_damage(50)
	assert_eq(stats.health, 0)


func test_healing_restores_health_up_to_maximum() -> void:
	stats.health = 3
	stats.heal(4)
	assert_eq(stats.health, 7)
	stats.heal(20)
	assert_eq(stats.health, 10)


func test_new_battle_restores_health_block_and_mana() -> void:
	var character := WARRIOR.create_instance() as CharacterStats
	character.health = 5
	character.block = 7
	character.mana = 0

	var next_battle := character.create_instance() as CharacterStats
	assert_eq(next_battle.health, 35)
	assert_eq(next_battle.block, 0)
	assert_eq(next_battle.mana, 3)


func test_card_is_playable_with_exact_cost_and_rejected_below_cost() -> void:
	var character := WARRIOR.create_instance() as CharacterStats
	character.mana = 2
	assert_true(character.can_play_card(SWEEP))
	character.mana = 1
	assert_false(character.can_play_card(SWEEP))
	assert_true(character.can_play_card(ATTACK))


func test_battles_have_independent_decks_and_discard_piles() -> void:
	var template := CharacterStats.new()
	template.starting_deck = CardPile.new()
	template.starting_deck.add_card(ATTACK)
	template.starting_deck.add_card(SWEEP)
	var first := template.create_instance() as CharacterStats
	var second := template.create_instance() as CharacterStats
	first.discard.add_card(first.deck.draw_card())

	assert_eq(first.deck.cards.size(), 1)
	assert_eq(second.deck.cards.size(), 2, "Another battle retains its full deck")
	assert_eq(template.starting_deck.cards.size(), 2, "Drawing leaves the template intact")
	assert_true(second.discard.empty())


func test_pile_draws_in_order_and_emits_remaining_count() -> void:
	var pile := CardPile.new()
	pile.add_card(ATTACK)
	pile.add_card(SWEEP)
	watch_signals(pile)

	assert_same(pile.draw_card(), ATTACK)
	assert_signal_emitted_with_parameters(pile, "card_pile_size_changed", [1])
	assert_same(pile.draw_card(), SWEEP)
	assert_signal_emitted_with_parameters(pile, "card_pile_size_changed", [0])
	assert_true(pile.empty())


func test_shuffle_preserves_all_cards_including_duplicates() -> void:
	var pile := CardPile.new()
	pile.add_card(ATTACK)
	pile.add_card(SWEEP)
	pile.add_card(ATTACK)
	pile.shuffle()

	assert_eq(pile.cards.size(), 3)
	assert_eq(pile.cards.count(ATTACK), 2)
	assert_eq(pile.cards.count(SWEEP), 1)


func test_clearing_a_pile_signals_that_it_is_empty() -> void:
	var pile := CardPile.new()
	pile.add_card(ATTACK)
	watch_signals(pile)
	pile.clear()

	assert_true(pile.empty())
	assert_signal_emitted_with_parameters(pile, "card_pile_size_changed", [0])
