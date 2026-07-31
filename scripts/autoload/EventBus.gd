## Global event bus for cross-scene, decoupled communication.
## Only signals that genuinely span multiple scenes belong here.
@warning_ignore("unused_signal")
extends Node

# Dice game signals
signal dice_rolled(results: Array)  # Array[int] - 5 dice values
signal bid_made(player: String, count: int, value: int)
signal challenged(challenger: String, target: String)
signal challenge_result(winner: String, loser: String, actual_count: int, bid_count: int)
signal round_ended

# Assimilation signals
signal half_assimilated  # 1st infection
signal fully_assimilated  # 2nd infection = game over

# Card system signals
signal card_skill_triggered(card_id: String, skill_name: String, target: String)
signal card_eliminated(card_id: String, card_name: String)
signal unknown_card_drawn(card_id: String)

# Game flow signals
signal node_entered(node_type: String, node_data: Dictionary)
signal node_completed(node_type: String)
signal stage_changed(stage_id: int, stage_name: String)
signal run_started
signal run_ended(victory: bool)

# UI signals
signal gold_changed(new_amount: int)
signal item_acquired(item_id: String)
signal item_used(item_id: String)
signal discard_prompt(new_item_id: String)
signal shop_entered
signal shop_exited
signal hint_show(message: String, duration: float, color: Color)
