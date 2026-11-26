extends Node

signal card_drag_started(card_ui: CardUI)
signal card_drag_ended(card_ui: CardUI)
signal card_aim_started(card_ui: CardUI)
signal card_aim_ended(card_ui: CardUI)
signal card_played(card: Card)
signal card_tooltip_requested(card: Card)
signal tooltip_hide_requested

#playerRelated
signal player_hand_drawn
signal player_hand_discarded
signal player_turn_ended
signal player_died
signal player_hit

#enemyRelated
signal enemy_action_completed(enemy: Enemy)
signal enemy_turn_ended

#system
signal battle_over_screen_requested(text: String, type: BattleOverPanel.Type)
signal battle_over_resolution_started
signal battle_over_resolution_finished
signal ultimate_card_qte_started(sequence: Array[String], success: Callable, failure: Callable)
