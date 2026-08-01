## Central game state for the current run.
## Holds assimilation status, gold, items, rust points, and run progression.
extends Node

const ItemData := preload("res://scripts/resources/ItemData.gd")
const CardData := preload("res://scripts/resources/CardData.gd")
const BossFragmentData := preload("res://scripts/resources/BossFragmentData.gd")

# Player state
var gold: int = 0
var assimilation_count: int = 0
const MAX_ASSIMILATION: int = 2

# Current run
var current_stage: int = 0
var current_node_index: int = 0
var stages_cleared: Array[int] = []
var boss_fragments: Array[String] = []
var assimilation_curse: String = ""

# Run stats
var total_assimilations: int = 0
var events_completed: int = 0
var items_used: int = 0
var bosses_defeated: Array[String] = []
var enemies_defeated_this_run: int = 0
var final_stage_reached: int = 0
var final_node_reached: int = 0

var has_cleared_game: bool = false

# Debug: quick-jump from main menu to boss fight
var _debug_jump_boss: bool = false
var persistent_virus: int = 0  # 跨局累积感染次数

# Items
var consumable_items: Array[String] = []
var shop_items: Array = []
var event_notification: String = ""
var _temp_bonus_dice: int = 0
var _seen_events: Array[String] = []
var next_battle_fixed_six: bool = false
var next_boss_dice_penalty: int = 0
var next_boss_start_assimilated: bool = false
var saved_battle_card_ids: Array[String] = []
var _battle_entry_snapshot: Dictionary = {}
var current_battle_seed: int = 0
var stage_node_orders: Dictionary = {}
var current_contract: Dictionary = {}

# ----- Rust Contract system -----
# Card upgrade levels: { card_id: level (0-3) }
var card_levels: Dictionary = {}
# Highest permanently purchased level. Active levels can be freely toggled below it.
var purchased_card_levels: Dictionary = {}
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
const STARTER_ITEMS: Array[String] = [
	"reroll_stone", "full_reroll", "flip_die",
	"see_dark", "emergency_restart", "silent_turn",
	"purge_chip", "gambler_hunch", "payout",
	"freeze_die", "clone_die", "heat_vision", "fate_die",
]

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
		elif not (id in unlocked_cards):
			unlocked_cards.append(id)

func _ensure_starter_items() -> void:
	for item_id in STARTER_ITEMS:
		if item_id not in unlocked_items:
			unlocked_items.append(item_id)

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
		10: return ["item:pair_fix"]
		11: return ["item:borrow_die"]
		12: return ["item:royal_pardon"]
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
var tutorial_completed: bool = false
var tutorial_shop_seen: bool = false
var selected_forbidden_rules: Array[String] = []
var active_forbidden_rules: Array[String] = []

const MAX_CONSUMABLE: int = 3

func get_bonus_dice_count() -> int:
	var b: int = _temp_bonus_dice
	_temp_bonus_dice = 0
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
	if assimilation_count >= MAX_ASSIMILATION:
		return
	if assimilation_count == MAX_ASSIMILATION - 1 and "royal_pardon" in consumable_items:
		use_consumable("royal_pardon")
		EventBus.hint_show.emit("国王赦免生效：免除致死同化", 3.0, Color(0.98, 0.78, 0.29))
		return
	assimilation_count = mini(assimilation_count + 1, MAX_ASSIMILATION)
	total_assimilations += 1
	if assimilation_count == 1:
		EventBus.half_assimilated.emit()
	elif assimilation_count >= MAX_ASSIMILATION:
		EventBus.fully_assimilated.emit()

func force_full_assimilation() -> void:
	if assimilation_count < MAX_ASSIMILATION:
		assimilation_count = MAX_ASSIMILATION
		total_assimilations += 1
	EventBus.fully_assimilated.emit()

func clear_assimilation() -> void:
	assimilation_count = 0
	persistent_virus = 0
	assimilation_curse = ""

func is_half_assimilated() -> bool:
	return assimilation_count >= 1

func choose_assimilation_curse(curse_id: String) -> bool:
	if assimilation_count != 1 or curse_id not in ["double_wild", "growth_cost", "devour_challenge"]:
		return false
	assimilation_curse = curse_id
	return true

func has_boss_fragment(card_id: String) -> bool:
	return card_id in boss_fragments

## Returns added, duplicate, or full. Full leaves inventory unchanged until UI resolves it.
func add_boss_fragment(card_id: String) -> String:
	if not BossFragmentData.has_definition(card_id):
		return "invalid"
	if card_id in boss_fragments:
		return "duplicate"
	if boss_fragments.size() >= BossFragmentData.MAX_FRAGMENTS:
		return "full"
	boss_fragments.append(card_id)
	_apply_fragment_acquisition_reward(card_id)
	return "added"

func replace_boss_fragment(old_index: int, new_card_id: String) -> bool:
	if old_index < 0 or old_index >= boss_fragments.size() or not BossFragmentData.has_definition(new_card_id):
		return false
	if new_card_id in boss_fragments:
		return false
	boss_fragments[old_index] = new_card_id
	_apply_fragment_acquisition_reward(new_card_id)
	return true

func _apply_fragment_acquisition_reward(card_id: String) -> void:
	pass

func consume_boss_fragment(card_id: String) -> bool:
	var idx: int = boss_fragments.find(card_id)
	if idx < 0: return false
	boss_fragments.remove_at(idx)
	return true

func get_battle_reward_multiplier(cards: Array) -> float:
	if cards.is_empty():
		return 1.0
	const LEVEL_MULTIPLIERS: Array[float] = [1.0, 1.05, 1.12, 1.22]
	var bonus_sum: float = 0.0
	var counted: int = 0
	for card in cards:
		if card == null: continue
		var level: int = clampi(get_card_level(card.card_id), 0, 3)
		bonus_sum += LEVEL_MULTIPLIERS[level] - 1.0
		counted += 1
	var card_multiplier: float = 1.0 + (bonus_sum / float(counted)) if counted > 0 else 1.0
	return card_multiplier * get_forbidden_reward_multiplier()

func get_forbidden_reward_multiplier() -> float:
	var bonus: float = 0.0
	if "forbidden_spread" in active_forbidden_rules: bonus += 0.20
	if "high_pressure" in active_forbidden_rules: bonus += 0.15
	if "short_cup" in active_forbidden_rules: bonus += 0.25
	return 1.0 + bonus

func is_forbidden_rule_active(rule_id: String) -> bool:
	return rule_id in active_forbidden_rules

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
	var active: int = get_card_level(card_id)
	var purchased: int = int(purchased_card_levels.get(card_id, active))
	if active < purchased:
		card_levels[card_id] = active + 1
		save_progress()
		return true
	if purchased >= max_level:
		return false
	var cost: int = purchased + 1
	if rust_points < cost:
		return false
	rust_points -= cost
	purchased += 1
	purchased_card_levels[card_id] = purchased
	card_levels[card_id] = purchased
	save_progress()
	return true

func downgrade_card(card_id: String) -> bool:
	var current: int = get_card_level(card_id)
	if current <= 0:
		return false
	card_levels[card_id] = current - 1
	save_progress()
	return true

func clear_all_levels() -> int:
	for cid in card_levels:
		card_levels[cid] = 0
	save_progress()
	return 0

func get_purchased_card_level(card_id: String) -> int:
	return int(purchased_card_levels.get(card_id, get_card_level(card_id)))

func get_next_card_level_cost(card_id: String) -> int:
	var card := CardData.get_card_by_id(card_id)
	if card == null: return 0
	var purchased: int = get_purchased_card_level(card_id)
	return 0 if get_card_level(card_id) < purchased else mini(3, purchased + 1)

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

## Max levels per card
func _get_max_level(card_id: String) -> int:
	var no_upgrade := ["two_face", "mirror_tech", "dealer", "dice_god", "unknown_mirror", "unknown_chaos", "unknown_abyss"]
	if card_id in no_upgrade:
		return 0
	if card_id == "alliance_oled": return 1
	if card_id in ["table_ghost", "prophet"]: return 2
	return 3

## Rust points for this run
func get_run_rust_points() -> int:
	return _run_rust_points

## ---- Setup ----
func setup_new_run() -> void:
	gold = 0
	assimilation_count = 0
	current_stage = 0
	current_node_index = 0
	_run_rust_points = 0
	_run_xp = 0
	_pending_xp = 0
	_new_levels.clear()
	stages_cleared.clear()
	bosses_defeated.clear()
	enemies_defeated_this_run = 0
	final_stage_reached = 0
	final_node_reached = 0
	consumable_items.clear()
	boss_fragments.clear()
	assimilation_curse = ""
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
	_temp_bonus_dice = 0
	next_battle_fixed_six = false
	next_boss_dice_penalty = 0
	next_boss_start_assimilated = false
	saved_battle_card_ids.clear()
	_battle_entry_snapshot.clear()
	current_battle_seed = 0
	stage_node_orders.clear()
	current_contract.clear()
	active_forbidden_rules = selected_forbidden_rules.duplicate() if has_cleared_game else []
	_clear_save()

## Freeze the run at the moment after opponents are chosen but before battle setup
## consumes one-shot modifiers. Pausing during the battle always returns here.
func capture_battle_entry(cards: Array) -> void:
	if current_battle_seed == 0:
		current_battle_seed = randi_range(1, 2147483646)
	saved_battle_card_ids.clear()
	for card in cards:
		if card != null:
			saved_battle_card_ids.append(str(card.card_id))
	_battle_entry_snapshot = {
		"gold": gold,
		"assimilation_count": assimilation_count,
		"current_stage": current_stage,
		"current_node_index": current_node_index,
		"stages_cleared": stages_cleared.duplicate(),
		"consumable_items": consumable_items.duplicate(),
		"boss_fragments": boss_fragments.duplicate(),
		"assimilation_curse": assimilation_curse,
		"temp_bonus_dice": _temp_bonus_dice,
		"next_battle_fixed_six": next_battle_fixed_six,
		"next_boss_dice_penalty": next_boss_dice_penalty,
		"next_boss_start_assimilated": next_boss_start_assimilated,
		"total_assimilations": total_assimilations,
		"events_completed": events_completed,
		"items_used": items_used,
		"bosses_defeated": bosses_defeated.duplicate(),
		"enemies_defeated_this_run": enemies_defeated_this_run,
		"final_stage_reached": final_stage_reached,
		"final_node_reached": final_node_reached,
		"run_rust_points": _run_rust_points,
		"run_xp": _run_xp,
		"pending_xp": _pending_xp,
		"card_ids": saved_battle_card_ids.duplicate(),
		"battle_seed": current_battle_seed,
		"stage_node_orders": stage_node_orders.duplicate(true),
		"current_contract": current_contract.duplicate(true),
		"active_forbidden_rules": active_forbidden_rules.duplicate(),
	}

func clear_battle_entry() -> void:
	_battle_entry_snapshot.clear()
	saved_battle_card_ids.clear()
	current_battle_seed = 0
	current_contract.clear()

func _restore_battle_entry(snapshot: Dictionary) -> void:
	gold = int(snapshot.get("gold", gold))
	assimilation_count = int(snapshot.get("assimilation_count", assimilation_count))
	current_stage = int(snapshot.get("current_stage", current_stage))
	current_node_index = int(snapshot.get("current_node_index", current_node_index))
	stages_cleared.assign(snapshot.get("stages_cleared", stages_cleared))
	consumable_items.assign(snapshot.get("consumable_items", consumable_items))
	boss_fragments.assign(snapshot.get("boss_fragments", boss_fragments))
	assimilation_curse = str(snapshot.get("assimilation_curse", assimilation_curse))
	_temp_bonus_dice = int(snapshot.get("temp_bonus_dice", 0))
	next_battle_fixed_six = bool(snapshot.get("next_battle_fixed_six", false))
	next_boss_dice_penalty = int(snapshot.get("next_boss_dice_penalty", 0))
	next_boss_start_assimilated = bool(snapshot.get("next_boss_start_assimilated", false))
	total_assimilations = int(snapshot.get("total_assimilations", total_assimilations))
	events_completed = int(snapshot.get("events_completed", events_completed))
	items_used = int(snapshot.get("items_used", items_used))
	bosses_defeated.assign(snapshot.get("bosses_defeated", bosses_defeated))
	enemies_defeated_this_run = int(snapshot.get("enemies_defeated_this_run", enemies_defeated_this_run))
	final_stage_reached = int(snapshot.get("final_stage_reached", final_stage_reached))
	final_node_reached = int(snapshot.get("final_node_reached", final_node_reached))
	_run_rust_points = int(snapshot.get("run_rust_points", _run_rust_points))
	_run_xp = int(snapshot.get("run_xp", _run_xp))
	_pending_xp = int(snapshot.get("pending_xp", _pending_xp))
	saved_battle_card_ids.assign(snapshot.get("card_ids", []))
	current_battle_seed = int(snapshot.get("battle_seed", 0))
	stage_node_orders = (snapshot.get("stage_node_orders", {}) as Dictionary).duplicate(true)
	current_contract = (snapshot.get("current_contract", {}) as Dictionary).duplicate(true)
	active_forbidden_rules.assign(snapshot.get("active_forbidden_rules", []))

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

func save_run(_dice_game_virus: int = 0, temporarily_disabled_items: Array = [], restart_modifiers: Dictionary = {}) -> void:
	var snapshot: Dictionary = _battle_entry_snapshot.duplicate(true)
	if snapshot.is_empty():
		var saved_items: Array[String] = consumable_items.duplicate()
		for item_id in temporarily_disabled_items:
			saved_items.append(str(item_id))
		snapshot = {
			"gold": gold, "assimilation_count": clampi(maxi(assimilation_count, _dice_game_virus), 0, MAX_ASSIMILATION),
			"current_stage": current_stage, "current_node_index": current_node_index,
			"stages_cleared": stages_cleared.duplicate(), "consumable_items": saved_items,
			"boss_fragments": boss_fragments.duplicate(), "assimilation_curse": assimilation_curse,
			"temp_bonus_dice": maxi(_temp_bonus_dice, int(restart_modifiers.get("bonus_dice", 0))),
			"next_battle_fixed_six": next_battle_fixed_six or bool(restart_modifiers.get("fixed_six", false)),
			"next_boss_dice_penalty": maxi(next_boss_dice_penalty, int(restart_modifiers.get("boss_dice_penalty", 0))),
			"next_boss_start_assimilated": next_boss_start_assimilated,
			"card_ids": saved_battle_card_ids.duplicate(),
			"battle_seed": current_battle_seed,
			"stage_node_orders": stage_node_orders.duplicate(true),
			"current_contract": current_contract.duplicate(true),
			"active_forbidden_rules": active_forbidden_rules.duplicate(),
		}
	var f := FileAccess.open("user://save_game.dat", FileAccess.WRITE)
	if not f:
		return
	f.store_32(int(snapshot.get("gold", gold)))
	f.store_32(int(snapshot.get("assimilation_count", assimilation_count)))
	f.store_32(int(snapshot.get("current_stage", current_stage)))
	f.store_32(int(snapshot.get("current_node_index", current_node_index)))
	var snap_stages: Array = snapshot.get("stages_cleared", stages_cleared)
	f.store_32(snap_stages.size())
	for s in snap_stages:
		f.store_32(s)
	var saved_items: Array = snapshot.get("consumable_items", consumable_items)
	f.store_32(saved_items.size())
	for item in saved_items:
		f.store_pascal_string(item)
	f.store_32(int(snapshot.get("assimilation_count", assimilation_count)))
	f.store_32(int(snapshot.get("temp_bonus_dice", 0)))
	f.store_32(1 if bool(snapshot.get("next_battle_fixed_six", false)) else 0)
	f.store_32(int(snapshot.get("next_boss_dice_penalty", 0)))
	f.store_32(1 if bool(snapshot.get("next_boss_start_assimilated", false)) else 0)
	var snap_fragments: Array = snapshot.get("boss_fragments", boss_fragments)
	f.store_32(snap_fragments.size())
	for fragment_id in snap_fragments:
		f.store_pascal_string(fragment_id)
	f.store_pascal_string(str(snapshot.get("assimilation_curse", "")))
	f.store_pascal_string("BATTLE_ENTRY_V2")
	f.store_var(snapshot, true)
	f.close()

func has_saved_game() -> bool:
	return FileAccess.file_exists("user://save_game.dat")

func load_run() -> bool:
	var f := FileAccess.open("user://save_game.dat", FileAccess.READ)
	if not f: return false
	_battle_entry_snapshot.clear()
	saved_battle_card_ids.clear()
	current_battle_seed = 0
	current_contract.clear()
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
	# Older saves may not contain the trailing battle-virus field.
	if f.get_position() < f.get_length():
		var saved_virus: int = f.get_32()
		assimilation_count = clampi(maxi(assimilation_count, saved_virus), 0, MAX_ASSIMILATION)
	if f.get_position() < f.get_length(): _temp_bonus_dice = f.get_32()
	if f.get_position() < f.get_length(): next_battle_fixed_six = f.get_32() == 1
	if f.get_position() < f.get_length(): next_boss_dice_penalty = f.get_32()
	if f.get_position() < f.get_length(): next_boss_start_assimilated = f.get_32() == 1
	boss_fragments.clear()
	if f.get_position() < f.get_length():
		var fragment_count: int = f.get_32()
		for _i in range(fragment_count):
			if f.get_position() < f.get_length(): boss_fragments.append(f.get_pascal_string())
	if f.get_position() < f.get_length(): assimilation_curse = f.get_pascal_string()
	if f.get_position() < f.get_length():
		var marker: String = f.get_pascal_string()
		if marker == "BATTLE_ENTRY_V2" and f.get_position() < f.get_length():
			var loaded_snapshot: Variant = f.get_var(true)
			if loaded_snapshot is Dictionary:
				_battle_entry_snapshot = loaded_snapshot
				_restore_battle_entry(_battle_entry_snapshot)
	f.close()
	return true

func delete_run_save() -> void:
	if FileAccess.file_exists("user://save_game.dat"):
		DirAccess.remove_absolute("user://save_game.dat")

func _clear_save() -> void:
	delete_run_save()
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
	f.store_32(purchased_card_levels.size())
	for cid in purchased_card_levels:
		f.store_pascal_string(cid)
		f.store_32(purchased_card_levels[cid])
	f.store_32(1 if tutorial_completed else 0)
	f.store_32(selected_forbidden_rules.size())
	for rule_id in selected_forbidden_rules:
		f.store_pascal_string(rule_id)
	f.store_32(1 if tutorial_shop_seen else 0)
	f.close()

func load_progress() -> void:
	if not FileAccess.file_exists("user://progress.dat"):
		# No save file — still apply Lv.1 starter unlocks so the card pool isn't empty.
		_apply_unlock(1)
		_ensure_starter_items()
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
	purchased_card_levels.clear()
	if f.get_position() < f.get_length():
		var purchased_count: int = f.get_32()
		for _i in range(purchased_count):
			purchased_card_levels[f.get_pascal_string()] = f.get_32()
	else:
		purchased_card_levels = card_levels.duplicate()
	if f.get_position() < f.get_length():
		tutorial_completed = f.get_32() == 1
	selected_forbidden_rules.clear()
	if f.get_position() < f.get_length():
		var forbidden_count: int = f.get_32()
		for _i in range(forbidden_count):
			if f.get_position() < f.get_length(): selected_forbidden_rules.append(f.get_pascal_string())
	if f.get_position() < f.get_length(): tutorial_shop_seen = f.get_32() == 1
	f.close()
	var upgrade_data_migrated: bool = _migrate_three_level_upgrades()
	# Rebuild all level-based unlocks so older saves with an empty card list migrate safely.
	for level in range(1, player_level + 1):
		_apply_unlock(level)
	_ensure_starter_items()
	if upgrade_data_migrated:
		save_progress()

func _migrate_three_level_upgrades() -> bool:
	var changed: bool = false
	var all_ids: Array = purchased_card_levels.keys()
	for card_id in card_levels.keys():
		if card_id not in all_ids: all_ids.append(card_id)
	for raw_id in all_ids:
		var card_id: String = str(raw_id)
		var maximum: int = _get_max_level(card_id)
		var purchased: int = int(purchased_card_levels.get(card_id, card_levels.get(card_id, 0)))
		if purchased > maximum:
			for removed_level in range(maximum + 1, purchased + 1):
				rust_points += removed_level
			purchased_card_levels[card_id] = maximum
			changed = true
		var active: int = int(card_levels.get(card_id, 0))
		var clamped_active: int = clampi(active, 0, mini(maximum, int(purchased_card_levels.get(card_id, purchased))))
		if clamped_active != active:
			card_levels[card_id] = clamped_active
			changed = true
	return changed

## Stage gold payout per layer
static func get_stage_gold(stage: int) -> int:
	var base: int
	match stage:
		0: base = 30
		1: base = 45
		2: base = 65
		3: base = 90
		_: base = 30
	return base
