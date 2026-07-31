## Central game state for the current run.
## Holds assimilation status, gold, items, rust points, and run progression.
extends Node

const ItemData := preload("res://scripts/resources/ItemData.gd")
const CardData := preload("res://scripts/resources/CardData.gd")

# Player state
var gold: int = 0
var assimilation_count: int = 0
const MAX_ASSIMILATION: int = 2

# Current run
var current_stage: int = 0
var current_node_index: int = 0
var stages_cleared: Array[int] = []

# Run stats
var total_assimilations: int = 0
var events_completed: int = 0
var items_used: int = 0
var bosses_defeated: Array[String] = []
var enemies_defeated_this_run: int = 0
var final_stage_reached: int = 0
var final_node_reached: int = 0

# Difficulty - persistent
var has_cleared_game: bool = false
# Per-run toggle
var hardcore_mode: bool = false

# Debug: quick-jump from main menu to boss fight
var _debug_jump_boss: bool = false
var persistent_virus: int = 0  # 跨局累积感染次数

# Items
var consumable_items: Array[String] = []
var shop_items: Array = []
var event_notification: String = ""
var _temp_bonus_dice: int = 0
var _seen_events: Array[String] = []

# ----- Rust Contract system -----
# Card upgrade levels: { card_id: level (0-3) }
var card_levels: Dictionary = {}
# Accumulated rust points
var rust_points: int = 0
# Rust points earned this run
var _run_rust_points: int = 0

# ----- Unlock system -----
var unlocked_cards: Array[String] = []
var unlocked_items: Array[String] = []

# ----- XP / Level system -----
var player_xp: int = 0
var player_level: int = 1
var _run_xp: int = 0
var _pending_xp: int = 0   # XP earned this run, committed on death/victory
var _new_levels: Array[int] = []

const XP_PER_ENEMY: int = 10
const XP_PER_BOSS: int = 25
const XP_FULL_CLEAR: int = 100

func xp_for_next_level() -> int:
	return 50 * player_level

func add_xp(amount: int) -> void:
	var old_level: int = player_level
	player_xp += amount
	_run_xp += amount
	while player_level < 20 and player_xp >= xp_for_next_level():
		player_xp -= xp_for_next_level()
		player_level += 1
		_apply_unlock(player_level)
		_new_levels.append(player_level)
	if player_level > old_level:
		save_progress()

## Get names of items/cards unlocked at given levels, then clear the queue
func pop_new_unlocks() -> Dictionary:
	var result: Dictionary = {}
	for lv in _new_levels:
		var unlocks: Array[String] = _get_unlocks_for_level(lv)
		var names: Array[String] = []
		for id in unlocks:
			if id.begins_with("item:"):
				var it := ItemData.get_by_id(id.substr(5))
				names.append(it.item_name if it else id)
			else:
				var c := CardData.get_card_by_id(id)
				names.append(c.card_name if c else id)
		if not names.is_empty():
			result[lv] = names
	_new_levels.clear()
	return result

func _apply_unlock(level: int) -> void:
	var unlocks: Array[String] = _get_unlocks_for_level(level)
	for id in unlocks:
		if id.begins_with("item:"):
			var item_id: String = id.substr(5)
			if not (item_id in unlocked_items):
				unlocked_items.append(item_id)
		else:
			if not (id in unlocked_cards):
				unlocked_cards.append(id)

func _get_unlocks_for_level(level: int) -> Array[String]:
	match level:
		1: return [
			"jack_crt", "rust_warrior", "battery_kid",
			"cyclops_lcd", "two_face", "chamberlain",
			"table_ghost", "recycler", "lucky_one",
			"casino_owner", "dealer", "prophet",
		]
		2: return ["signal_noise"]
		3: return ["mirror_tech"]
		4: return ["referee"]
		5: return ["alliance_oled"]
		6: return ["item:split_die"]
		7: return ["item:extra_die"]
		8: return ["item:rig_dice"]
		9: return ["item:sabotage"]
	return []

## Commit all XP earned this run (called on death or full clear)
func commit_pending_xp(bonus: int = 0) -> void:
	if _pending_xp + bonus > 0:
		add_xp(_pending_xp + bonus)
		_pending_xp = 0

func get_gold_bonus() -> int:
	return 25 if player_level >= 5 else 0

# ----- Tutorial -----
var tutorial_enabled: bool = true

const MAX_CONSUMABLE: int = 6

func get_bonus_dice_count() -> int:
	var b: int = _temp_bonus_dice
	return b

func set_bonus_dice(count: int) -> void:
	_temp_bonus_dice = count

func add_gold(amount: int) -> void:
	gold += amount
	EventBus.gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		EventBus.gold_changed.emit(gold)
		return true
	return false

func assimilate() -> void:
	assimilation_count += 1
	total_assimilations += 1
	if assimilation_count == 1:
		EventBus.half_assimilated.emit()
	elif assimilation_count >= MAX_ASSIMILATION:
		EventBus.fully_assimilated.emit()

func clear_assimilation() -> void:
	assimilation_count = 0
	persistent_virus = 0

func is_half_assimilated() -> bool:
	return assimilation_count >= 1

func add_consumable_item(item_id: String) -> bool:
	if consumable_items.size() < MAX_CONSUMABLE:
		consumable_items.append(item_id)
		EventBus.item_acquired.emit(item_id)
		return true
	EventBus.discard_prompt.emit(item_id)
	return false

func force_swap_consumable(new_id: String, old_idx: int) -> void:
	if old_idx >= 0 and old_idx < consumable_items.size():
		consumable_items[old_idx] = new_id
		EventBus.item_acquired.emit(new_id)

func use_consumable(item_id: String) -> void:
	var idx: int = consumable_items.find(item_id)
	if idx != -1:
		consumable_items.remove_at(idx)
		items_used += 1
		EventBus.item_used.emit(item_id)

func clear_virus() -> void:
	persistent_virus = 0

func get_item_info(item_id: String) -> ItemData:
	return ItemData.get_by_id(item_id)

func refresh_shop(count: int = 6) -> void:
	shop_items = ItemData.get_random_shop_items(count)
	# Defensive dedup — guarantee no duplicate item_ids in shop
	var seen: Dictionary = {}
	var deduped: Array = []
	for item in shop_items:
		if item == null or seen.has(item.item_id):
			continue
		seen[item.item_id] = true
		deduped.append(item)
	shop_items = deduped

## ---- Rust point helpers ----
func add_rust_points(amount: int) -> void:
	rust_points += amount
	_run_rust_points += amount

func get_card_level(card_id: String) -> int:
	return card_levels.get(card_id, 0)

func upgrade_card(card_id: String) -> bool:
	var card := CardData.get_card_by_id(card_id)
	if card == null:
		return false
	var max_level: int = get_max_level_for_card(card_id)
	var current: int = get_card_level(card_id)
	if current >= max_level:
		return false
	var cost: int = get_upgrade_cost_for_rarity(card.rarity) + current
	if rust_points < cost:
		return false
	rust_points -= cost
	card_levels[card_id] = current + 1
	save_progress()
	return true

func downgrade_card(card_id: String) -> bool:
	var card := CardData.get_card_by_id(card_id)
	if card == null:
		return false
	var current: int = get_card_level(card_id)
	if current <= 0:
		return false
	var refund: int = get_upgrade_cost_for_rarity(card.rarity) + (current - 1)
	rust_points += refund
	card_levels[card_id] = current - 1
	save_progress()
	return true

func clear_all_levels() -> int:
	var refund: int = 0
	for cid in card_levels:
		var lv: int = card_levels[cid]
		if lv <= 0: continue
		var card := CardData.get_card_by_id(cid)
		if card == null: continue
		for i in range(lv):
			refund += get_upgrade_cost_for_rarity(card.rarity) + i
	card_levels.clear()
	rust_points += refund
	save_progress()
	return refund

func get_max_level_for_card(card_id: String) -> int:
	return _get_max_level(card_id)

func get_upgrade_cost_for_rarity(rarity: int) -> int:
	return _get_upgrade_cost(rarity)

func _get_upgrade_cost(rarity: int) -> int:
	match rarity:
		CardData.Rarity.COMMON: return 1
		CardData.Rarity.RARE: return 2
		CardData.Rarity.EPIC: return 3
		CardData.Rarity.LEGENDARY: return 4
		CardData.Rarity.GENESIS: return 5
		CardData.Rarity.UNKNOWN: return 5
	return 1

## Max levels per card (from design doc)
func _get_max_level(card_id: String) -> int:
	var no_upgrade := ["two_face", "mirror_tech", "dealer", "dice_god", "unknown_mirror", "unknown_chaos", "unknown_abyss"]
	if card_id in no_upgrade:
		return 0
	var lv1_max := ["alliance_oled"]
	if card_id in lv1_max:
		return 1
	var lv2_max := ["table_ghost", "prophet"]
	if card_id in lv2_max:
		return 2
	return 3

## Rust points for this run
func get_run_rust_points() -> int:
	return _run_rust_points

## ---- Setup ----
func setup_new_run() -> void:
	gold = 999
	assimilation_count = 0
	current_stage = 0
	current_node_index = 0
	_run_rust_points = 0
	_run_xp = 0
	_pending_xp = 0
	_new_levels.clear()
	# Lv.18+ starts with 1 random common item
	if player_level >= 18:
		var gifts: Array[String] = ["reroll_stone", "flip_die", "full_reroll", "see_dark", "silent_turn", "purge_chip", "gambler_hunch", "payout"]
		consumable_items.append(gifts[randi() % gifts.size()])

## 骰子之神快速测试 (F6键已删除)
	stages_cleared.clear()
	bosses_defeated.clear()
	enemies_defeated_this_run = 0
	final_stage_reached = 0
	final_node_reached = 0
	consumable_items.clear()
	shop_items.clear()
	_debug_jump_boss = false
	persistent_virus = 0
	total_assimilations = 0
	events_completed = 0
	items_used = 0
	_seen_events.clear()
	_run_rust_points = 0
	_run_xp = 0
	_pending_xp = 0
	_new_levels.clear()
	_clear_save()

func calculate_score() -> Dictionary:
	var boss_bonus: int = bosses_defeated.size() * 100
	var gold_bonus: int = gold / 4
	var assimilation_penalty: int = total_assimilations * 50
	var event_bonus: int = events_completed * 25
	var total: int = boss_bonus + gold_bonus - assimilation_penalty + event_bonus
	var tier: String = "C"
	if total >= 480: tier = "S"
	elif total >= 350: tier = "A"
	elif total >= 220: tier = "B"
	return {"score": total, "tier": tier, "boss_bonus": boss_bonus, "gold_bonus": gold_bonus, "assimilation_penalty": assimilation_penalty, "event_bonus": event_bonus}

func save_run(_dice_game_virus: int = 0) -> void:
	var f := FileAccess.open("user://save_game.dat", FileAccess.WRITE)
	if not f:
		return
	f.store_32(gold)
	f.store_32(assimilation_count)
	f.store_32(current_stage)
	f.store_32(current_node_index)
	f.store_32(stages_cleared.size())
	for s in stages_cleared:
		f.store_32(s)
	f.store_32(consumable_items.size())
	for item in consumable_items:
		f.store_pascal_string(item)
	f.store_32(_dice_game_virus)
	f.close()

func has_saved_game() -> bool:
	return FileAccess.file_exists("user://save_game.dat")

func load_run() -> bool:
	var f := FileAccess.open("user://save_game.dat", FileAccess.READ)
	if not f: return false
	gold = f.get_32()
	assimilation_count = f.get_32()
	current_stage = f.get_32()
	current_node_index = f.get_32()
	var sc: int = f.get_32()
	stages_cleared.clear()
	for _i in range(sc):
		stages_cleared.append(f.get_32())
	var ic: int = f.get_32()
	consumable_items.clear()
	for _i in range(ic):
		consumable_items.append(f.get_pascal_string())
	f.close()
	return true

func _clear_save() -> void:
	if FileAccess.file_exists("user://save_game.dat"):
		DirAccess.remove_absolute("user://save_game.dat")
	refresh_shop(6)
	EventBus.run_started.emit()

func save_progress() -> void:
	var f := FileAccess.open("user://progress.dat", FileAccess.WRITE)
	if not f: return
	f.store_32(1 if has_cleared_game else 0)
	f.store_32(rust_points)
	# card levels
	f.store_32(card_levels.size())
	for cid in card_levels:
		f.store_pascal_string(cid)
		f.store_32(card_levels[cid])
	# unlocked cards
	f.store_32(unlocked_cards.size())
	for cid in unlocked_cards:
		f.store_pascal_string(cid)
	# unlocked items
	f.store_32(unlocked_items.size())
	for iid in unlocked_items:
		f.store_pascal_string(iid)
	# tutorial
	f.store_32(1 if tutorial_enabled else 0)
	f.store_32(player_xp)
	f.store_32(player_level)
	f.close()

func load_progress() -> void:
	if not FileAccess.file_exists("user://progress.dat"):
		# No save file — still apply Lv.1 starter unlocks so the card pool isn't empty.
		_apply_unlock(1)
		if unlocked_items.is_empty():
			unlocked_items = [
				"reroll_stone", "full_reroll", "flip_die",
				"see_dark", "emergency_restart", "silent_turn",
				"purge_chip", "gambler_hunch", "payout",
				"freeze_die", "clone_die", "heat_vision",
				"fate_die",
			]
		return
	var f := FileAccess.open("user://progress.dat", FileAccess.READ)
	if not f: return
	has_cleared_game = f.get_32() == 1
	rust_points = f.get_32()
	card_levels.clear()
	var cl_count: int = f.get_32()
	for _i in range(cl_count):
		var cid: String = f.get_pascal_string()
		card_levels[cid] = f.get_32()
	unlocked_cards.clear()
	var uc_count: int = f.get_32()
	for _i in range(uc_count):
		unlocked_cards.append(f.get_pascal_string())
	unlocked_items.clear()
	var ui_count: int = f.get_32()
	for _i in range(ui_count):
		unlocked_items.append(f.get_pascal_string())
	tutorial_enabled = f.get_32() == 1
	if f.get_position() < f.get_length():
		player_xp = f.get_32()
		player_level = max(1, f.get_32())
	f.close()
	# Ensure starter cards + items are always unlocked (idempotent — handles save migration)
	_apply_unlock(1)
	if unlocked_items.is_empty():
		unlocked_items = [
			"reroll_stone", "full_reroll", "flip_die",
			"see_dark", "emergency_restart", "silent_turn",
			"purge_chip", "gambler_hunch", "payout",
			"freeze_die", "clone_die", "heat_vision",
			"fate_die",
		]

## Stage gold payout per layer
static func get_stage_gold(stage: int) -> int:
	var base: int
	match stage:
		0: base = 30
		1: base = 45
		2: base = 65
		3: base = 90
		_: base = 30
	return base + GameState.get_gold_bonus()
