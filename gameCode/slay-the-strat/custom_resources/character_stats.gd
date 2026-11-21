class_name CharacterStats
extends Stats

@export var starting_deck: CardPile
@export var cards_per_turn: int
@export var max_mana: int

var mana: int : set = set_mana
var deck: CardPile
var discard: CardPile
var draw_pile: CardPile
var damage_multiplier := 1
var blood_ritual_loss_per_turn := 0

func set_mana(value: int) -> void:
	mana = value
	stats_changed.emit()
	
func reset_mana() -> void:
	self.mana = max_mana
	
func can_play_card(card: Card) -> bool:
	return mana >= card.cost
	
func take_damage(damage: int) -> void:
	var initial_health := health
	super.take_damage(damage)
	if initial_health > health:
		Events.player_hit.emit()
	
func create_instance() -> Resource:
	var instance: CharacterStats = self. duplicate()
	instance.health = max_health
	instance.block = 0
	instance.reset_mana()
	instance.damage_multiplier = 1
	instance.blood_ritual_loss_per_turn = 0
	instance.deck = instance.starting_deck.duplicate()
	instance.draw_pile = CardPile.new()
	instance.discard = CardPile.new()
	return instance
