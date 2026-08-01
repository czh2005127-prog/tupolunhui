## Core liar's dice game controller — supports 2 or 3 AIs (boss mode).
class_name DiceGame
extends Node

signal game_over(winner: String)
signal turn_changed(current_player: String)
signal bid_updated(count: int, value: int, player: String)
signal challenge_happened(challenger: String, target: String, actual: int, bid: int)
signal dice_revealed(player_vals: Array, ai1_vals: Array, ai2_vals: Array, ai3_vals: Array, is_final: bool, player_involved: bool, ai1_was_dead: bool, ai2_was_dead: bool)
signal round_started
signal boss_mode_changed(is_boss: bool)
signal boss_skill_effect(effect: String, detail: String)

var forbidden_number: int = 0
var boss_forbidden_number: int = 0
var infectious_number: int = 0
var _pending_dice: Dictionary = {}  # 加骰队列 {target_id: count}
var player_shield: bool = false  # 赌桌幽灵: 免疫下一次伤害
var _ai_shields: Dictionary = {}  # AI幽灵护盾 {ai_id: bool}

var player_cup: RefCounted
var ai_cup_1: RefCounted
var ai_cup_2: RefCounted
var ai_cup_3: RefCounted
var ai_controller_1: RefCounted
var ai_controller_2: RefCounted
var ai_controller_3: RefCounted

var current_bid_count: int = 0
var current_bid_value: int = 1
var current_player: String = "player"
var last_bidder: String = ""
var game_active: bool = false
var round_number: int = 0
var is_boss_mode: bool = false
var _noise_removed_items: Array[String] = []  # 信号噪音暂时移除的道具，对局结束归还
var _mirror_present: bool = false  # 镜像·广播 在场
var _twoface_present: bool = false  # 双面人: ①和⑥都是万能骰
var _cyclops_lock: int = 0  # 独眼龙LCD: 本局锁定点数, 0=未触发
var _cyclops_locks: Array[int] = []  # 独眼龙LCD: Lv.1+ 锁多个点数
var _chaos_real_bid: Dictionary = {}  # 混沌真实叫法 {count, value}
var _chaos_fake_bid: Dictionary = {}  # 混沌虚假显示 {count, value}
var _casino_hidden: int = 0  # 所有赌场主叠加产生的暗骰数
var _round_count: int = 0  # 裁判长用
var _card_levels: Dictionary = {}  # {card_id: int} upgrade levels from GameState
var _table_ghost_active: Dictionary = {}  # 幽灵附身 {ai_id: bool}
var _alliance_target: String = ""  # 同盟选中者
var _ghost_target: String = ""  # 幽灵附身目标 (免疫1次伤害)
var _challenge_immunity_until: Dictionary = {}
var _card_ais: Dictionary = {}  # card_id -> Array[String], preserves duplicate card instances
var _referee_uses: Dictionary = {}  # ai_id -> uses spent this battle
var _chamberlain_items_by_ai: Dictionary = {}  # ai_id -> Array[String]
var _chaos_bids_by_ai: Dictionary = {}  # ai_id -> {real, fake}
var _casino_see_all_ais: Array[String] = []
var _ai_fate_effects: Dictionary = {}  # ai_id -> {index, value, rounds_left}
var _skip_ai_turns: Dictionary = {}  # ai_id -> pending skipped turns
var _boss_card_id: String = ""
var _boss_ai_id: String = ""
var _boss_referee_shield_used: bool = false
var _dice_god_phase: int = 0
var _fragment_referee_used: bool = false
var _fragment_ghost_used: bool = false

const SELF_ONLY_ITEM_IDS: Array[String] = [
	"reroll_stone", "full_reroll", "flip_die", "freeze_die",
	"clone_die", "split_die", "pair_fix", "purge_chip", "silent_turn",
	"royal_pardon", "extra_die", "fate_die", "rig_dice",
]

var player_virus: int = 0  # 0=2HP, 2=1HP, 4=dead
var ai1_virus: int = 0
var ai2_virus: int = 0
var ai3_virus: int = 0
const AI_MAX_VIRUS: int = 1
const PLAYER_MAX_VIRUS: int = 2
var _bonus_dice: int = 0
var _boss_dice_penalty_applied: int = 0
var _was_elimination: bool = false
var _fixed_six_active: bool = false
var _fate_active: bool = false
var _fate_index: int = 0
var _fate_value: int = 0
var _fate_rounds_left: int = 0
var _pending_payout_gold: int = 0
var _growth_dice_added: int = 0
var _contract_start_items_used: int = 0
var _contract_bold_bid: bool = false
var _contract_five_twos: bool = false
var _contract_bid_faces: Array[int] = []
var _public_player_items_used: Array[String] = []
var _tutorial_active: bool = false
var _tutorial_forced_bids_remaining: int = 0
var _tutorial_opening_done: bool = false

func start_game(card1: Resource, card2: Resource, has_dark_die: bool = false, card3: Resource = null, _is_boss: bool = false) -> void:
	if GameState.current_battle_seed != 0:
		seed(GameState.current_battle_seed)
	_contract_start_items_used = GameState.items_used
	_public_player_items_used.clear()
	if not EventBus.item_used.is_connected(_on_public_player_item_used):
		EventBus.item_used.connect(_on_public_player_item_used)
	_tutorial_active = GameState.tutorial_enabled and not GameState.tutorial_completed and GameState.current_stage == 0
	if has_dark_die and GameState.mark_tutorial_topic("dark_dice"):
		EventBus.tutorial_hint_show.emit("暗骰不会向持有者显示点数，但仍参与开骰统计。", 7.0)
	_bonus_dice = GameState.get_bonus_dice_count()
	is_boss_mode = _is_boss
	_boss_card_id = card3.card_id if is_boss_mode and card3 else ""
	_boss_ai_id = "ai3" if not _boss_card_id.is_empty() else ""
	_dice_god_phase = 1 if _boss_card_id == "dice_god" else 0
	var fragment_start_dice: int = 1 if GameState.has_boss_fragment("dealer") else 0
	var base_player_dice: int = 4 if GameState.is_forbidden_rule_active("short_cup") else 5
	var total: int = base_player_dice + _bonus_dice + fragment_start_dice
	player_cup = preload("res://scripts/dice/DiceCup.gd").new(total)
	ai_cup_1 = preload("res://scripts/dice/DiceCup.gd").new(5)
	ai_cup_2 = preload("res://scripts/dice/DiceCup.gd").new(5)
	ai_cup_3 = preload("res://scripts/dice/DiceCup.gd").new(5)
	_fixed_six_active = GameState.next_battle_fixed_six
	if _fixed_six_active:
		GameState.next_battle_fixed_six = false
	ai_controller_1 = preload("res://scripts/ai/AiController.gd").new(card1, ai_cup_1)
	ai_controller_1.set_dice_game(self); ai_controller_1.set_ai_id("ai1")
	if card2:
		ai_controller_2 = preload("res://scripts/ai/AiController.gd").new(card2, ai_cup_2)
		ai_controller_2.set_dice_game(self); ai_controller_2.set_ai_id("ai2")
	else:
		ai2_virus = AI_MAX_VIRUS  # 直接标记出局
	if card3:
		ai_controller_3 = preload("res://scripts/ai/AiController.gd").new(card3, ai_cup_3)
		ai_controller_3.set_dice_game(self); ai_controller_3.set_ai_id("ai3")
		ai3_virus = 0
	else:
		ai_controller_3 = null
		ai3_virus = AI_MAX_VIRUS  # dead by default in non-boss mode
	if is_boss_mode and GameState.next_boss_dice_penalty > 0:
		_boss_dice_penalty_applied = GameState.next_boss_dice_penalty
		for cup: RefCounted in [ai_cup_1, ai_cup_2, ai_cup_3]:
			for _i in range(GameState.next_boss_dice_penalty):
				if cup.dice.size() > 1:
					cup.dice.pop_back()
					cup.dice_count -= 1
		GameState.next_boss_dice_penalty = 0
	if is_boss_mode and GameState.next_boss_start_assimilated:
		if GameState.assimilation_count == 0:
			GameState.assimilate()
		GameState.next_boss_start_assimilated = false

	# 设置动态开局数值：存活人数 + 1
	var opening_min: int = get_min_opening()
	if ai_controller_1: ai_controller_1.min_opening = opening_min
	if ai_controller_2: ai_controller_2.min_opening = opening_min
	if ai_controller_3: ai_controller_3.min_opening = opening_min

	# Detect card skills
	_twoface_present = false; _casino_hidden = 0; _alliance_target = ""
	_chaos_real_bid.clear(); _chaos_fake_bid.clear()
	player_shield = false; _ai_shields.clear(); _ghost_target = ""; _table_ghost_active.clear()
	_challenge_immunity_until.clear()
	_card_ais.clear(); _referee_uses.clear(); _chamberlain_items_by_ai.clear()
	_chaos_bids_by_ai.clear(); _casino_see_all_ais.clear(); _ai_fate_effects.clear(); _skip_ai_turns.clear()
	_boss_referee_shield_used = false; _fragment_referee_used = false; _fragment_ghost_used = false
	for ai_info in [["ai1", card1], ["ai2", card2], ["ai3", card3]]:
		if ai_info[1] == null: continue
		var ai_id: String = ai_info[0]
		var detected_card_id: String = ai_info[1].card_id
		var holders: Array = _card_ais.get(detected_card_id, [])
		holders.append(ai_id)
		_card_ais[detected_card_id] = holders
		if ai_info[1].card_id == "two_face": _twoface_present = true; EventBus.hint_show.emit("双面人: ①和⑥都是万能骰", 4.0, Color(0.98, 0.85, 0.50))
		if detected_card_id == "unknown_chaos": EventBus.hint_show.emit("混沌·乱码: 它的叫牌可能被篡改", 4.0, Color(0.85, 0.6, 0.2))
		if detected_card_id == "recycler": var rec_lv_hint: int = 2 if GameState.get_card_level("recycler") >= 1 else 1; EventBus.hint_show.emit("回收商·捡骰: 有人质疑失败时+%d骰" % rec_lv_hint, 4.0, Color(0.52, 0.72, 0.92))
		if detected_card_id == "lucky_one": var lucky_hint: int = 2 if GameState.get_card_level("lucky_one") >= 1 else 1; EventBus.hint_show.emit("幸运儿·骰神眷顾: 永远多%d个①" % lucky_hint, 4.0, Color(0.98, 0.78, 0.29))
		if detected_card_id == "referee": _referee_uses[ai_id] = 0; var rrlv: int = GameState.get_card_level("referee"); EventBus.hint_show.emit("裁判长·强制执行: 本局可用%d次" % clampi(rrlv, 1, 3), 4.0, Color(0.98, 0.78, 0.29))
		if detected_card_id == "mirror_tech": EventBus.hint_show.emit("镜面技师·镜像: 复制玩家骰子", 4.0, Color(0.75, 0.45, 0.85))
		if detected_card_id == "casino_owner": var cas_hint: int = 2 if GameState.get_card_level("casino_owner") >= 1 else 1; EventBus.hint_show.emit("赌场主·暗骰加码: 每人+%d暗骰" % cas_hint, 4.0, Color(0.52, 0.72, 0.92))
		if detected_card_id == "prophet": EventBus.hint_show.emit("算法先知·重算: 每轮重掷骰子", 4.0, Color(0.98, 0.78, 0.29))
		if detected_card_id == "dice_god": EventBus.hint_show.emit("骰子之神·禁忌变更: 每轮换禁忌点数", 4.0, Color(0.98, 0.35, 0.35))
		if detected_card_id == "unknown_abyss": EventBus.hint_show.emit("深渊·吞噬: 每轮结束吞1骰", 4.0, Color(0.55, 0.35, 0.65))
		if ai_info[1].card_id == "table_ghost": EventBus.card_skill_triggered.emit("table_ghost", "附身就绪", ai_info[0])
		if ai_info[1].card_id == "chamberlain":
			var chamberlain_items: Array[String] = []
			var chamber_lv: int = GameState.get_card_level("chamberlain")
			var chamber_count: int = 3
			var chamber_rare: int = 0
			if chamber_lv >= 1: chamber_count = 5
			if chamber_lv >= 2: chamber_rare = 1
			if chamber_lv >= 3: chamber_count = 6; chamber_rare = 2
			# Generate rare-guaranteed items first
			var all_items: Array = []
			for candidate in ItemData.get_consumable_pool():
				if candidate.item_id in SELF_ONLY_ITEM_IDS:
					all_items.append(candidate)
			all_items.shuffle()
			var rares: Array = []
			for it in all_items:
				if it.rarity >= ItemData.Rarity.RARE:
					rares.append(it)
			# Add guaranteed rare-or-higher items, then fill remaining slots randomly.
			for _guaranteed in range(chamber_rare):
				if rares.is_empty(): break
				chamberlain_items.append(rares[randi() % rares.size()].item_id)
			while chamberlain_items.size() < chamber_count and not all_items.is_empty():
				chamberlain_items.append(all_items[randi() % all_items.size()].item_id)
			_chamberlain_items_by_ai[ai_id] = chamberlain_items
			EventBus.hint_show.emit("侍从长·军械库: 获得%d个自身道具!" % chamberlain_items.size(), 4.0, Color(0.52, 0.72, 0.92))

	# Read card upgrade levels for all drawn cards
	_card_levels.clear()
	for ai_info in [["ai1", card1], ["ai2", card2], ["ai3", card3]]:
		if ai_info[1] == null: continue
		var cid: String = ai_info[1].card_id
		_card_levels[cid] = GameState.get_card_level(cid)

	# === 赌场主: 每人+暗骰 (Lv.1=2颗, Lv.2=自己能看, Lv.3=3颗+全看到) ===
	var casino_ais: Array = _get_card_ais("casino_owner")
	if not casino_ais.is_empty():
		var casino_lv: int = GameState.get_card_level("casino_owner")
		var hidden_per_owner: int = mini(3, 1 + casino_lv)
		if casino_lv >= 2:
			hidden_per_owner = 3 if casino_lv >= 3 else 2
		_casino_hidden = hidden_per_owner * casino_ais.size()
		for _i in range(_casino_hidden):
			player_cup.add_hidden_die()
			if ai1_virus < AI_MAX_VIRUS: ai_cup_1.add_hidden_die()
			if ai2_virus < AI_MAX_VIRUS: ai_cup_2.add_hidden_die()
			if ai3_virus < AI_MAX_VIRUS: ai_cup_3.add_hidden_die()
		# Lv.2: 赌场主能看到自己的暗骰，Lv.3: 看到所有人的暗骰
		for casino_id in casino_ais:
			var casino_ctrl: RefCounted = _get_ai_controller(casino_id)
			if casino_ctrl:
				casino_ctrl.own_hidden_visible = casino_lv >= 2
				if casino_lv >= 3: _casino_see_all_ais.append(casino_id)
		EventBus.card_skill_triggered.emit("casino_owner", "暗骰", "全场")
	if _boss_card_id == "casino_owner":
		_casino_hidden += 2
		for boss_casino_cup: RefCounted in [player_cup, ai_cup_1, ai_cup_2, ai_cup_3]:
			boss_casino_cup.add_hidden_die(); boss_casino_cup.add_hidden_die()
		if ai_controller_3:
			ai_controller_3.own_hidden_visible = true
	# === 同盟OLED: targets are selected after each roll ===
	for alliance_id in _get_card_ais("alliance_oled"):
		EventBus.card_skill_triggered.emit("alliance_oled", "全知就绪", alliance_id)

	for dealer_id in _get_card_ais("dealer"):
		var dealer_cup: RefCounted = _get_ai_cup(dealer_id)
		if dealer_cup:
			for _i in range(3):
				dealer_cup.add_die()
		EventBus.hint_show.emit("庄家·开盘: %s 开局拥有8颗骰子" % get_ai_name_for_id(dealer_id), 4.0, Color(0.52, 0.72, 0.92))
	if _boss_card_id == "dealer":
		ai_cup_3.add_die()
	if _boss_card_id == "table_ghost":
		if ai1_virus < AI_MAX_VIRUS: _ai_shields["ai1"] = true
		if ai2_virus < AI_MAX_VIRUS: _ai_shields["ai2"] = true
	if GameState.has_boss_fragment("casino_owner"):
		player_cup.add_die()
	if not _boss_card_id.is_empty():
		var boss_skill_name: String = preload("res://scripts/resources/BossFragmentData.gd").get_boss_skill_name(_boss_card_id)
		EventBus.hint_show.emit("Boss技能·%s" % boss_skill_name, 4.0, Color(0.98, 0.35, 0.35))

	# 信号噪音: disable consumable items (本局生效, 结束归还)
	_noise_removed_items.clear()
	for noise_id in _get_card_ais("signal_noise"):
		if GameState.consumable_items.is_empty(): break
		var noise_lv: int = GameState.get_card_level("signal_noise")
		var disabled_count: int = 1 + noise_lv
		for _i in range(disabled_count):
			if GameState.consumable_items.size() > 0:
				var remove_idx: int = randi() % GameState.consumable_items.size()
				var removed: String = GameState.consumable_items[remove_idx]
				GameState.consumable_items.remove_at(remove_idx)
				_noise_removed_items.append(removed)
				EventBus.item_used.emit(removed)
		EventBus.card_skill_triggered.emit("signal_noise", "干扰", noise_id)
		EventBus.hint_show.emit("信号噪音干扰：你的 %d 个道具被禁用" % _noise_removed_items.size(), 4.0, Color(0.85, 0.6, 0.2))

	# 镜像·广播: 揭示全场最多的点数 (ON_GAME_START)
	_mirror_present = false
	if card1.card_id == "unknown_mirror" or (card2 and card2.card_id == "unknown_mirror") or (card3 and card3.card_id == "unknown_mirror"):
		_mirror_present = true
		EventBus.card_skill_triggered.emit("unknown_mirror", "广播", "全场")

	# Dark dice are set per-round in _start_round via boss_skill
	ai1_virus = 0; ai2_virus = 0
	player_virus = clampi(GameState.assimilation_count, 0, PLAYER_MAX_VIRUS)
	game_active = true; round_number = 0
	boss_mode_changed.emit(is_boss_mode)
	_start_round()

func _get_ai_cup(ai_id: String) -> RefCounted:
	match ai_id:
		"ai1": return ai_cup_1
		"ai2": return ai_cup_2
		"ai3": return ai_cup_3
	return null

func _get_ai_controller(ai_id: String) -> RefCounted:
	match ai_id:
		"ai1": return ai_controller_1
		"ai2": return ai_controller_2
		"ai3": return ai_controller_3
	return null

func _get_card_ais(card_id: String) -> Array:
	return (_card_ais.get(card_id, []) as Array).duplicate()

func _is_ai_alive(ai_id: String) -> bool:
	match ai_id:
		"ai1": return ai1_virus < AI_MAX_VIRUS
		"ai2": return ai2_virus < AI_MAX_VIRUS
		"ai3": return ai3_virus < AI_MAX_VIRUS
	return false

func _living_card_ais(card_id: String) -> Array[String]:
	var result: Array[String] = []
	for ai_id in _get_card_ais(card_id):
		if _is_ai_alive(ai_id): result.append(ai_id)
	return result

func _share_public_values(values: Array, source_ai: String = "") -> void:
	for ai_id in ["ai1", "ai2", "ai3"]:
		if ai_id == source_ai or not _is_ai_alive(ai_id): continue
		var ctrl: RefCounted = _get_ai_controller(ai_id)
		if ctrl: ctrl.player_full_values.append_array(values)

func _copy_player_dice_to_mirror() -> void:
	var player_values: Array = player_cup.get_all_values()
	for mirror_id in _living_card_ais("mirror_tech"):
		var mirror_cup: RefCounted = _get_ai_cup(mirror_id)
		if mirror_cup == null: continue
		while mirror_cup.dice.size() < player_values.size():
			mirror_cup.add_die()
		while mirror_cup.dice.size() > player_values.size():
			mirror_cup.dice.pop_back()
			mirror_cup.dice_count -= 1
		for i in range(player_values.size()):
			mirror_cup.dice[i].value = player_values[i]
		EventBus.card_skill_triggered.emit("mirror_tech", "镜像", mirror_id)

func _apply_player_round_effects() -> void:
	if GameState.assimilation_curse == "growth_cost":
		if _growth_dice_added < 3:
			player_cup.add_die()
			_growth_dice_added += 1
		var one_indices: Array[int] = []
		for i in range(player_cup.dice.size()):
			if player_cup.dice[i].value == 1: one_indices.append(i)
		if not one_indices.is_empty():
			var changed_idx: int = one_indices[randi() % one_indices.size()]
			player_cup.dice[changed_idx].value = randi_range(2, 6)
	if GameState.has_boss_fragment("lucky_one"):
		var lucky_indices: Array[int] = []
		for lucky_index in range(player_cup.dice.size()):
			lucky_indices.append(lucky_index)
		lucky_indices.shuffle()
		for i in range(mini(2, lucky_indices.size())):
			if randf() < 0.5: player_cup.dice[lucky_indices[i]].value = 1
	if GameState.has_boss_fragment("mirror_tech") and round_number == 1 and not player_cup.dice.is_empty():
		player_cup.clone_at(randi() % player_cup.dice.size())
	if GameState.has_boss_fragment("prophet"):
		var lowest_idx: int = -1
		var lowest_value: int = 7
		for i in range(player_cup.dice.size()):
			var value: int = player_cup.dice[i].value
			if value != 1 and value < lowest_value:
				lowest_value = value; lowest_idx = i
		if lowest_idx >= 0:
			var new_value: int = randi_range(1, 6)
			player_cup.dice[lowest_idx].value = maxi(lowest_value, new_value)
	if GameState.has_boss_fragment("alliance_oled"):
		var candidates: Array[String] = []
		for ai_id in ["ai1", "ai2", "ai3"]:
			if _is_ai_alive(ai_id): candidates.append(ai_id)
		if not candidates.is_empty():
			var target_id: String = candidates[randi() % candidates.size()]
			var target_cup: RefCounted = _get_ai_cup(target_id)
			var visible_values: Array[int] = []
			for die in target_cup.dice:
				if not die.is_hidden: visible_values.append(die.value)
			if not visible_values.is_empty():
				visible_values.shuffle()
				var revealed: Array = visible_values.slice(0, mini(2, visible_values.size()))
				EventBus.hint_show.emit("同盟碎片公开 %s 的骰子：%s" % [get_ai_name_for_id(target_id), str(revealed)], 4.0, Color(0.36, 0.79, 0.65))

func _apply_boss_round_effects() -> void:
	if _boss_card_id.is_empty() or not _is_ai_alive(_boss_ai_id): return
	var boss_cup: RefCounted = _get_ai_cup(_boss_ai_id)
	if _boss_card_id == "lucky_one":
		var changed: int = 0
		for die in boss_cup.dice:
			if die.value != 1 and changed < 2:
				die.value = 1; changed += 1
	elif _boss_card_id == "mirror_tech" and not player_cup.dice.is_empty():
		var counts: Dictionary = {}
		for die in player_cup.dice: counts[die.value] = int(counts.get(die.value, 0)) + 1
		var best_value: int = player_cup.dice[0].value
		for value in counts:
			if int(counts[value]) > int(counts.get(best_value, 0)): best_value = value
		boss_cup.add_die_with_value(best_value)
	elif _boss_card_id == "prophet" and boss_cup.dice.size() >= 2:
		var counts: Dictionary = {}
		for die in boss_cup.dice: counts[die.value] = int(counts.get(die.value, 0)) + 1
		var best_value: int = boss_cup.dice[0].value
		for value in counts:
			if int(counts[value]) > int(counts.get(best_value, 0)): best_value = value
		boss_cup.dice[0].value = best_value; boss_cup.dice[1].value = best_value
	elif _boss_card_id == "alliance_oled":
		var normal_values: Array[int] = []
		for die in player_cup.dice:
			if not die.is_hidden: normal_values.append(die.value)
		normal_values.shuffle()
		var exposed: Array = normal_values.slice(0, mini(2, normal_values.size()))
		var boss_ctrl: RefCounted = _get_ai_controller(_boss_ai_id)
		if boss_ctrl: boss_ctrl.player_full_values.append_array(exposed)
		_share_public_values(exposed, _boss_ai_id)
		if not exposed.is_empty(): EventBus.hint_show.emit("Boss·公开审判：你的骰子 %s 被公开" % str(exposed), 4.0, Color(0.98, 0.35, 0.35))

func _start_round() -> void:
	if not game_active: return
	while GameState.assimilation_count == 1 and GameState.assimilation_curse.is_empty():
		await get_tree().process_frame
		if not game_active: return
	round_number += 1
	_round_count += 1
	# Clear per-round knowledge while keeping per-battle skill usage counters.
	for ctrl: RefCounted in [ai_controller_1, ai_controller_2, ai_controller_3]:
		if ctrl:
			ctrl.player_full_values.clear()
	player_cup.roll_new_round()
	if ai1_virus < AI_MAX_VIRUS: ai_cup_1.roll_new_round()
	if ai2_virus < AI_MAX_VIRUS: ai_cup_2.roll_new_round()
	if ai3_virus < AI_MAX_VIRUS: ai_cup_3.roll_new_round()
	_apply_player_round_effects()
	for fate_ai in _ai_fate_effects.keys():
		if not _is_ai_alive(fate_ai):
			_ai_fate_effects.erase(fate_ai)
			continue
		var effect: Dictionary = _ai_fate_effects[fate_ai]
		var fate_cup: RefCounted = _get_ai_cup(fate_ai)
		var fate_idx: int = int(effect.get("index", -1))
		if fate_cup and fate_idx >= 0 and fate_idx < fate_cup.dice.size():
			fate_cup.dice[fate_idx].value = int(effect.get("value", 1))
		effect["rounds_left"] = int(effect.get("rounds_left", 0)) - 1
		if int(effect["rounds_left"]) <= 0:
			_ai_fate_effects.erase(fate_ai)
		else:
			_ai_fate_effects[fate_ai] = effect
	if _fixed_six_active and player_cup.dice.size() > 0:
		player_cup.dice[0].value = 6
	if _fate_active and _fate_index < player_cup.dice.size():
		player_cup.dice[_fate_index].value = _fate_value
		_fate_rounds_left -= 1
		if _fate_rounds_left <= 0:
			_fate_active = false
	_copy_player_dice_to_mirror()
	for alliance_id in _living_card_ais("alliance_oled"):
		var alliance_ctrl: RefCounted = _get_ai_controller(alliance_id)
		if alliance_ctrl:
			var knowledge_targets: Array[String] = ["player"]
			if alliance_id != "ai1" and ai1_virus < AI_MAX_VIRUS: knowledge_targets.append("ai1")
			if alliance_id != "ai2" and ai2_virus < AI_MAX_VIRUS: knowledge_targets.append("ai2")
			if alliance_id != "ai3" and ai3_virus < AI_MAX_VIRUS: knowledge_targets.append("ai3")
			knowledge_targets.shuffle()
			var living_count: int = knowledge_targets.size() + 1
			var know_count: int = living_count - (1 if GameState.get_card_level("alliance_oled") >= 1 else 2)
			alliance_ctrl.player_full_values.clear()
			var selected_targets: Array[String] = []
			for i in range(mini(know_count, knowledge_targets.size())):
				var target_id: String = knowledge_targets[i]
				selected_targets.append(target_id)
				var known_cup: RefCounted = player_cup if target_id == "player" else _get_ai_cup(target_id)
				alliance_ctrl.player_full_values.append_array(known_cup.get_all_values())
			_alliance_target = ",".join(selected_targets)
			EventBus.card_skill_triggered.emit("alliance_oled", "全知", _alliance_target)
	for casino_id in _casino_see_all_ais:
		if not _is_ai_alive(casino_id): continue
		var casino_ctrl: RefCounted = _get_ai_controller(casino_id)
		if casino_ctrl:
			casino_ctrl.player_full_values.clear()
			for target_id in ["player", "ai1", "ai2", "ai3"]:
				if target_id == casino_id: continue
				var known_cup: RefCounted = player_cup if target_id == "player" else _get_ai_cup(target_id)
				if known_cup: casino_ctrl.player_full_values.append_array(known_cup.get_all_values())
	current_bid_count = 0; current_bid_value = 1; last_bidder = ""
	# Stage 2: exactly one dark die per person.
	if GameState.current_stage == 1:
		# Card-created dark dice stack with the stage mutation.
		var hc: int = 1 + _casino_hidden
		player_cup.set_all_visible(); player_cup.hide_random_dice(hc)
		ai_cup_1.set_all_visible(); ai_cup_1.hide_random_dice(hc)
		ai_cup_2.set_all_visible(); ai_cup_2.hide_random_dice(hc)
		if ai3_virus < AI_MAX_VIRUS:
			ai_cup_3.set_all_visible()
			ai_cup_3.hide_random_dice(hc)
		boss_skill_effect.emit("dark", "每人 %d 颗暗骰" % hc)
	# === 幸运儿: 每轮保证额外的① ===
	for lucky_id in _living_card_ais("lucky_one"):
		var lucky_lv: int = GameState.get_card_level("lucky_one")
		var lucky_count: int = mini(3, 1 + lucky_lv)
		var cup: RefCounted = _get_ai_cup(lucky_id)
		if cup:
			for i in range(mini(lucky_count, cup.dice.size())):
				cup.dice[i].value = 1
	# === 算法先知: 每轮可重掷 (Lv.1=重掷后+1骰, Lv.2=可重掷2次) ===
	for prophet_id in _living_card_ais("prophet"):
		var prop_lv: int = GameState.get_card_level("prophet")
		var reroll_count: int = 2 if prop_lv >= 2 else 1
		var cup: RefCounted = null
		cup = _get_ai_cup(prophet_id)
		if cup:
			var rerolled: int = 0
			for _attempt in range(reroll_count):
				var candidates: Array[int] = []
				for i in range(cup.dice.size()):
					if not cup.dice[i].is_hidden and cup.dice[i].value != 1:
						candidates.append(i)
				for idx in candidates:
					cup.dice[idx].value = randi() % 6 + 1
					rerolled += 1
			if rerolled > 0:
				EventBus.card_skill_triggered.emit("prophet", "重算", "%d颗" % rerolled)
			# Lv.1: gain +1 die after reroll
			if prop_lv >= 1:
				cup.add_die()
	_apply_boss_round_effects()
	# Stage 3: one infectious face; a bid on it forces the next bid to keep that face.
	if GameState.current_stage == 2:
		infectious_number = randi() % 6 + 1
		EventBus.hint_show.emit("传染骰点数: %d，叫到后下家必须跟叫该点数" % infectious_number, 4.0, Color(0.75, 0.45, 0.85))
		if GameState.mark_tutorial_topic("infectious_face"):
			EventBus.tutorial_hint_show.emit("传染点数被叫出后，下一名角色必须继续叫同一个点数。", 7.0)
	else:
		infectious_number = 0
	# Stage 4 or the optional rule: one forbidden face.
	if GameState.current_stage == 3 or GameState.is_forbidden_rule_active("forbidden_spread"):
		if forbidden_number == 0 or not _living_card_ais("dice_god").is_empty():
			var previous_forbidden: int = forbidden_number
			while forbidden_number == 0 or forbidden_number == previous_forbidden:
				forbidden_number = randi() % 6 + 1
		boss_forbidden_number = 0
		if _boss_card_id == "dice_god" and _is_ai_alive(_boss_ai_id) and _dice_god_phase >= 2:
			boss_forbidden_number = randi() % 6 + 1
			while boss_forbidden_number == forbidden_number:
				boss_forbidden_number = randi() % 6 + 1
			EventBus.hint_show.emit("双重禁忌: %d / %d，叫到任意点数扣1骰" % [forbidden_number, boss_forbidden_number], 4.0, Color(0.98, 0.35, 0.35))
		else:
			EventBus.hint_show.emit("禁忌点数: %d，叫到者立即扣1颗骰子" % forbidden_number, 4.0, Color(0.98, 0.35, 0.35))
		if GameState.mark_tutorial_topic("forbidden_face"):
			EventBus.tutorial_hint_show.emit("禁忌点数不能安全叫出：叫到者会立刻失去1颗骰子，归零则淘汰。", 8.0)
	else:
		forbidden_number = 0; boss_forbidden_number = 0
	var tf_ai1: bool = ai1_virus < AI_MAX_VIRUS and card_has("ai1", "two_face")
	var tf_ai2: bool = ai2_virus < AI_MAX_VIRUS and card_has("ai2", "two_face")
	var tf_ai3: bool = ai3_virus < AI_MAX_VIRUS and card_has("ai3", "two_face")
	_twoface_present = tf_ai1 or tf_ai2 or tf_ai3
	ai_controller_1.set_six_wild(_twoface_present)
	if ai_controller_2:
		ai_controller_2.set_six_wild(_twoface_present)
	if ai_controller_3:
		ai_controller_3.set_six_wild(_twoface_present)
	# 独眼龙LCD: trigger once per battle, not once per round.
	if not _get_card_ais("cyclops_lcd").is_empty() and _cyclops_locks.is_empty():
		var cl_lv: int = GameState.get_card_level("cyclops_lcd")
		for cyclops_id in _living_card_ais("cyclops_lcd"):
			var lock_count: int = mini(3, 1 + cl_lv)
			var local_locks: Array[int] = []
			for _i in range(lock_count):
				var new_lock: int = randi() % 6 + 1
				var tries: int = 0
				while new_lock in local_locks and tries < 20:
					new_lock = randi() % 6 + 1; tries += 1
				if new_lock not in local_locks:
					local_locks.append(new_lock)
				if new_lock not in _cyclops_locks and _cyclops_locks.size() < 5:
					_cyclops_locks.append(new_lock)
		if _cyclops_locks.size() > 0:
			_cyclops_lock = _cyclops_locks[0]
			EventBus.hint_show.emit("独眼龙·锁定: 本局不能叫 %s" % str(_cyclops_locks), 4.0, Color(0.52, 0.72, 0.92))
			if cl_lv >= 3:
				var exposure_values: Array[int] = []
				for exposed_cup in [player_cup, ai_cup_1, ai_cup_2, ai_cup_3]:
					for die in exposed_cup.dice:
						if not die.is_hidden and die.value in _cyclops_locks:
							exposure_values.append(die.value)
				var exposure_count: int = mini(exposure_values.size(), _living_card_ais("cyclops_lcd").size())
				for _exposure in range(exposure_count):
					var exposed_value: int = exposure_values[randi() % exposure_values.size()]
					exposure_values.erase(exposed_value)
					_share_public_values([exposed_value])
					EventBus.hint_show.emit("独眼龙公开了一颗普通骰子: %d" % exposed_value, 4.0, Color(0.52, 0.72, 0.92))
	if _mirror_present:
		var counts: Array[int] = [0, 0, 0, 0, 0, 0, 0]
		if player_virus < PLAYER_MAX_VIRUS:
			for v in player_cup.get_all_values(): counts[v] += 1
		if ai1_virus < AI_MAX_VIRUS:
			for v in ai_cup_1.get_all_values(): counts[v] += 1
		if ai2_virus < AI_MAX_VIRUS:
			for v in ai_cup_2.get_all_values(): counts[v] += 1
		if ai3_virus < AI_MAX_VIRUS:
			for v in ai_cup_3.get_all_values(): counts[v] += 1
		var best_val: int = 1; var best_cnt: int = 0
		for i in range(1, 7):
			if counts[i] > best_cnt: best_cnt = counts[i]; best_val = i
		EventBus.hint_show.emit("镜像·广播: 全场最多点数 %d" % best_val, 5.0, Color(0.65, 0.5, 0.85))
	var pm: int = get_min_opening()
	if ai_controller_1: ai_controller_1.min_opening = pm
	if ai_controller_2: ai_controller_2.min_opening = pm
	if ai_controller_3: ai_controller_3.min_opening = pm
	# === 回收商 Lv.3: after each completed round, gain one die ===
	if round_number > 1 and GameState.get_card_level("recycler") >= 3:
		for recycler_id in _living_card_ais("recycler"):
			_get_ai_cup(recycler_id).add_die()
	round_started.emit()
	var alive: Array[String] = []
	if player_virus < PLAYER_MAX_VIRUS: alive.append("player")
	if ai1_virus < AI_MAX_VIRUS: alive.append("ai1")
	if ai2_virus < AI_MAX_VIRUS: alive.append("ai2")
	if ai3_virus < AI_MAX_VIRUS: alive.append("ai3")
	# 庄家在场且存活时，每轮都由庄家起叫。
	var starter: String = alive[randi() % alive.size()]
	var living_dealers: Array[String] = _living_card_ais("dealer")
	if not living_dealers.is_empty():
		starter = living_dealers[randi() % living_dealers.size()]
	if _tutorial_active and round_number == 1:
		starter = "player"
		EventBus.tutorial_hint_show.emit("先看自己的骰子：①可以代替其他点数。然后从存活人数＋1开始叫牌。", 8.0)
	current_player = starter

	turn_changed.emit(current_player)
	if starter != "player":
		await get_tree().create_timer(_think_delay(starter, false, true)).timeout
		if game_active: _ai_turn(starter)

## Bid validation
func _is_valid_bid(count: int, value: int) -> bool:
	if value < 1 or value > 6 or count < 1: return false
	if _cyclops_lock > 0 and value in _cyclops_locks: return false
	if current_bid_count == 0: return count >= get_min_opening()
	if GameState.current_stage == 2 and current_bid_value == infectious_number and value != infectious_number:
		return false
	return count > current_bid_count or (count == current_bid_count and value > current_bid_value)

func _infect_player() -> bool:
	if GameState.has_boss_fragment("table_ghost") and not _fragment_ghost_used:
		_fragment_ghost_used = true
		GameState.consume_boss_fragment("table_ghost")
		EventBus.hint_show.emit("幽灵碎片抵挡同化后消失", 3.0, Color(0.75, 0.45, 0.85))
		return false
	var pardon_count_before: int = GameState.consumable_items.count("royal_pardon")
	GameState.assimilate()
	if GameState.consumable_items.count("royal_pardon") < pardon_count_before:
		mirror_item("royal_pardon")
	player_virus = clampi(GameState.assimilation_count, 0, PLAYER_MAX_VIRUS)
	return player_virus >= PLAYER_MAX_VIRUS

func _infect_ai_immediately(ai_id: String) -> bool:
	var ctrl: RefCounted = _get_ai_controller(ai_id)
	if ctrl == null: return false
	var eliminated: bool = ctrl.infect()
	if ctrl._bk_saved:
		ctrl._bk_saved = false
		var saved_cup: RefCounted = _get_ai_cup(ai_id)
		if saved_cup: saved_cup.add_die()
	if eliminated:
		match ai_id:
			"ai1": ai1_virus = AI_MAX_VIRUS
			"ai2": ai2_virus = AI_MAX_VIRUS
			"ai3": ai3_virus = AI_MAX_VIRUS
		_apply_rust_warrior_skill(ai_id)
	return eliminated

func _try_advance_dice_god_phase(ai_id: String) -> bool:
	if ai_id != _boss_ai_id or _boss_card_id != "dice_god" or _dice_god_phase != 1:
		return false
	var ctrl: RefCounted = _get_ai_controller(ai_id)
	var cup: RefCounted = _get_ai_cup(ai_id)
	if ctrl:
		ctrl.is_eliminated = false
		ctrl.virus_count = 0
	if cup:
		while cup.dice.size() > 3:
			cup.dice.pop_back()
			cup.dice_count -= 1
		while cup.dice.size() < 3:
			cup.add_die()
	_dice_god_phase = 2
	EventBus.hint_show.emit("骰子之神粉碎并重组骰杯，以3颗骰子进入第二阶段：每轮出现两个禁忌点数", 5.0, Color(0.98, 0.2, 0.2))
	boss_skill_effect.emit("phase", "第二阶段：双重禁忌")
	return true

func _apply_forbidden_penalty(bidder: String) -> bool:
	if (GameState.current_stage != 3 and not GameState.is_forbidden_rule_active("forbidden_spread")) or current_bid_value not in [forbidden_number, boss_forbidden_number]:
		return false
	var cup: RefCounted = player_cup if bidder == "player" else _get_ai_cup(bidder)
	if cup and cup.dice.size() > 0:
		cup.dice.pop_back()
		cup.dice_count -= 1
	EventBus.hint_show.emit("%s 叫到禁忌点数，扣除1颗骰子" % bidder, 3.0, Color(0.98, 0.35, 0.35))
	if cup == null or cup.dice.size() > 0:
		return false
	EventBus.hint_show.emit("%s 的骰子归零，立即淘汰" % ("你" if bidder == "player" else get_ai_name_for_id(bidder)), 3.0, Color(0.98, 0.2, 0.2))
	if bidder == "player":
		GameState.force_full_assimilation()
		player_virus = PLAYER_MAX_VIRUS
		game_active = false
		_restore_noise_items()
		game_over.emit("ai")
		return true
	var ctrl: RefCounted = _get_ai_controller(bidder)
	if ctrl: ctrl.is_eliminated = true
	match bidder:
		"ai1": ai1_virus = AI_MAX_VIRUS
		"ai2": ai2_virus = AI_MAX_VIRUS
		"ai3": ai3_virus = AI_MAX_VIRUS
	_apply_rust_warrior_skill(bidder)
	if _living_ai_count() == 0:
		game_active = false
		_restore_noise_items()
		game_over.emit("player")
	else:
		_continue_round()
	return true

func _living_ai_count() -> int:
	var count: int = 0
	if ai1_virus < AI_MAX_VIRUS: count += 1
	if ai2_virus < AI_MAX_VIRUS: count += 1
	if ai3_virus < AI_MAX_VIRUS: count += 1
	return count

func _restore_noise_items() -> void:
	if _noise_removed_items.is_empty(): return
	for item_id in _noise_removed_items:
		GameState.add_consumable_item(item_id)
	_noise_removed_items.clear()

func _sanitize_ai_bid(proposed: Dictionary) -> Dictionary:
	var proposed_count: int = int(proposed.get("count", 0))
	var proposed_value: int = int(proposed.get("value", 1))
	if _is_valid_bid(proposed_count, proposed_value):
		return {"count": proposed_count, "value": proposed_value}
	if current_bid_count > 0:
		for value in range(current_bid_value + 1, 7):
			if _is_valid_bid(current_bid_count, value):
				return {"count": current_bid_count, "value": value}
	var next_count: int = get_min_opening() if current_bid_count == 0 else current_bid_count + 1
	for value in range(1, 7):
		if _is_valid_bid(next_count, value):
			return {"count": next_count, "value": value}
	return {"count": next_count + 1, "value": 1}

## Player actions
func player_bid(count: int, value: int) -> bool:
	if not game_active or current_player != "player": return false
	if GameState.assimilation_curse == "double_wild" and value in [1, 3]: return false
	if not _is_valid_bid(count, value): return false
	if _tutorial_active and not _tutorial_opening_done:
		_tutorial_opening_done = true
		_tutorial_forced_bids_remaining = _living_ai_count()
		EventBus.tutorial_hint_show.emit("很好。后续必须增加数量，或数量相同时提高点数。留意明显超过全桌骰子数的叫牌。", 7.0)
	var alive_at_bid: int = _living_ai_count() + (1 if player_virus < PLAYER_MAX_VIRUS else 0)
	if count >= alive_at_bid + 4:
		_contract_bold_bid = true
	if count >= 5 and value == 2:
		_contract_five_twos = true
	if value not in _contract_bid_faces:
		_contract_bid_faces.append(value)
	current_bid_count = count; current_bid_value = value; last_bidder = "player"
	bid_updated.emit(count, value, "你")
	if _apply_forbidden_penalty("player"): return true
	_next_player()
	return true

func player_challenge() -> bool:
	if not game_active or current_player != "player": return false
	if current_bid_count == 0: return false
	if int(_challenge_immunity_until.get(last_bidder, -1)) >= round_number: return false
	_resolve_challenge("player", last_bidder)
	return true

## Next player rotation
func _next_player() -> void:
	var alive: Array = []
	var order: Array[String] = ["player", "ai1", "ai2", "ai3"]
	var start_idx: int = order.find(current_player)
	for i in range(1, 5):
		var next: String = order[(start_idx + i) % 4]
		if next == current_player: continue
		match next:
			"player": if player_virus < PLAYER_MAX_VIRUS: alive.append("player")
			"ai1": if ai1_virus < AI_MAX_VIRUS: alive.append("ai1")
			"ai2": if ai2_virus < AI_MAX_VIRUS: alive.append("ai2")
			"ai3": if ai3_virus < AI_MAX_VIRUS: alive.append("ai3")
		if not alive.is_empty(): break
	if alive.is_empty(): return
	current_player = alive[0]
	turn_changed.emit(current_player)
	if current_player != "player":
		await get_tree().create_timer(_think_delay(current_player, false, false)).timeout
		if game_active: _ai_turn(current_player)

## AI turn
func _on_public_player_item_used(item_id: String) -> void:
	if item_id not in _public_player_items_used:
		_public_player_items_used.append(item_id)
	if item_id in ["reroll_stone", "full_reroll"]:
		_public_player_items_used.erase("rig_dice")

func _build_public_ai_context(ai_id: String) -> Dictionary:
	var active_cards: Array[String] = []
	for card_id in _card_ais:
		if not _living_card_ais(str(card_id)).is_empty():
			active_cards.append(str(card_id))
	var last_bidder_shielded: bool = player_shield if last_bidder == "player" else bool(_ai_shields.get(last_bidder, false))
	var own_ctrl: RefCounted = _get_ai_controller(ai_id)
	var own_shielded: bool = bool(_ai_shields.get(ai_id, false))
	if own_ctrl and own_ctrl.card and own_ctrl.card.card_id == "battery_kid" and own_ctrl.virus_count < mini(3, 1 + GameState.get_card_level("battery_kid")):
		own_shielded = true
	return {
		"active_cards": active_cards,
		"player_items": GameState.consumable_items.duplicate(),
		"player_items_used": _public_player_items_used.duplicate(),
		"player_fragments": GameState.boss_fragments.duplicate(),
		"player_dice_count": player_cup.dice.size() if player_cup else 0,
		"own_shielded": own_shielded,
		"last_bidder_shielded": last_bidder_shielded,
		"last_bidder_is_player": last_bidder == "player",
		"forbidden_numbers": [forbidden_number, boss_forbidden_number],
	}

func _ai_turn(ai_id: String) -> void:
	if not game_active: return
	var ctrl = null; var cup = null
	match ai_id:
		"ai1": ctrl = ai_controller_1; cup = ai_cup_1
		"ai2": ctrl = ai_controller_2; cup = ai_cup_2
		"ai3": ctrl = ai_controller_3; cup = ai_cup_3
		_: return
	if ctrl == null or cup == null: return
	if ctrl.is_eliminated:
		_next_player(); return
	# 裁判长：消耗自己的行动，指定一名存活对手立即按当前局面行动。
	if card_has(ai_id, "referee"):
		var ref_lv: int = GameState.get_card_level("referee")
		var use_limit: int = clampi(ref_lv, 1, 3)
		var used: int = int(_referee_uses.get(ai_id, 0))
		if used < use_limit:
			var forced_targets: Array[String] = []
			if player_virus < PLAYER_MAX_VIRUS: forced_targets.append("player")
			if ai_id != "ai1" and ai1_virus < AI_MAX_VIRUS and not card_has("ai1", "referee"): forced_targets.append("ai1")
			if ai_id != "ai2" and ai2_virus < AI_MAX_VIRUS and not card_has("ai2", "referee"): forced_targets.append("ai2")
			if ai_id != "ai3" and ai3_virus < AI_MAX_VIRUS and not card_has("ai3", "referee"): forced_targets.append("ai3")
			if not forced_targets.is_empty():
				_referee_uses[ai_id] = used + 1
				var forced_id: String = forced_targets[randi() % forced_targets.size()]
				EventBus.card_skill_triggered.emit("referee", "强制执行", forced_id)
				EventBus.hint_show.emit("裁判长强制 %s 立即质疑或叫牌" % ("你" if forced_id == "player" else get_ai_name_for_id(forced_id)), 3.0, Color(0.98, 0.78, 0.29))
				current_player = forced_id
				turn_changed.emit(current_player)
				if forced_id != "player":
					await get_tree().create_timer(_think_delay(forced_id, false, current_bid_count == 0)).timeout
					if game_active: _ai_turn(forced_id)
				return
	# 老杰克 偷窥: 偷玩家的可见骰子（Lv.1=2颗, Lv.2=2次, Lv.3=3颗+公开）
	if ctrl.card.card_id == "jack_crt" and not ctrl._peek_initialized:
		var jack_lv: int = GameState.get_card_level("jack_crt")
		ctrl._peek_uses = 2 if jack_lv >= 2 else 1
		ctrl._peek_initialized = true
	var jack_lv: int = GameState.get_card_level("jack_crt")
	var peek_count: int = 3 if jack_lv >= 3 else (2 if jack_lv >= 1 else 1)
	if ctrl.card.card_id == "jack_crt" and ctrl._peek_uses > 0:
		var peeked: Array = ctrl.peek_player_dice(peek_count, player_cup.get_all_values())
		if peeked.size() > 0:
			ctrl.player_full_values = peeked.duplicate()
			var msg: String = "老杰克偷窥了你的 %d 颗骰子" % peeked.size()
			if jack_lv >= 3:
				msg += ": " + str(peeked)
				_share_public_values(peeked, ai_id)
			EventBus.card_skill_triggered.emit("jack_crt", "偷窥(%d颗)" % peeked.size(), "player")
			EventBus.hint_show.emit(msg, 3.0, Color(0.36, 0.5, 0.84))
	ctrl.current_bid_count = current_bid_count
	ctrl.current_bid_value = current_bid_value
	ctrl.set_public_context(_build_public_ai_context(ai_id))
	ctrl.total_other_dice = 0
	if ai_id != "ai1" and ai1_virus < AI_MAX_VIRUS: ctrl.total_other_dice += ai_cup_1.dice.size()
	if ai_id != "ai2" and ai2_virus < AI_MAX_VIRUS: ctrl.total_other_dice += ai_cup_2.dice.size()
	if ai_id != "ai3" and ai3_virus < AI_MAX_VIRUS: ctrl.total_other_dice += ai_cup_3.dice.size()
	if ai_id != "player": ctrl.total_other_dice += player_cup.dice.size()
	var action: String = ctrl.decide_action()
	if _tutorial_active and _tutorial_forced_bids_remaining > 0:
		action = "tutorial_false_bid"
	if int(_skip_ai_turns.get(ai_id, 0)) > 0:
		_skip_ai_turns[ai_id] = int(_skip_ai_turns[ai_id]) - 1
		EventBus.hint_show.emit("%s 的静默回合生效" % get_ai_name_for_id(ai_id), 2.0, Color(0.52, 0.72, 0.92))
		_next_player()
		return
	if action == "challenge" and int(_challenge_immunity_until.get(last_bidder, -1)) >= round_number:
		action = "bid"
	if action == "challenge":
		_resolve_challenge(ai_id, last_bidder); return
	elif action in ["bid", "tutorial_false_bid"]:
		var bid: Dictionary
		if action == "tutorial_false_bid":
			var total_dice_now: int = player_cup.dice.size()
			if ai1_virus < AI_MAX_VIRUS: total_dice_now += ai_cup_1.dice.size()
			if ai2_virus < AI_MAX_VIRUS: total_dice_now += ai_cup_2.dice.size()
			if ai3_virus < AI_MAX_VIRUS: total_dice_now += ai_cup_3.dice.size()
			bid = _sanitize_ai_bid({"count": maxi(current_bid_count + 1, total_dice_now + 1), "value": 2})
			_tutorial_forced_bids_remaining -= 1
		else:
			bid = _sanitize_ai_bid(ctrl.make_bid())
		current_bid_count = bid["count"]; current_bid_value = bid["value"]; last_bidder = ai_id
		var nm := get_ai_name()
		if card_has(ai_id, "unknown_chaos") and not _tutorial_active:
			_chaos_real_bid = {"count": current_bid_count, "value": current_bid_value}
			var fake_count: int = clampi(current_bid_count + randi() % 3 - 1, 1, 15)
			var fake_value: int = clampi(randi() % 6 + 1, 1, 6)
			_chaos_fake_bid = {"count": fake_count, "value": fake_value}
			_chaos_bids_by_ai[ai_id] = {"real": _chaos_real_bid.duplicate(), "fake": _chaos_fake_bid.duplicate()}
			bid_updated.emit(fake_count, fake_value, nm + " [?]")
		else:
			bid_updated.emit(current_bid_count, current_bid_value, nm)
		if _apply_forbidden_penalty(ai_id): return
		_next_player()

func get_ai_name() -> String:
	if current_player == "ai1" and ai_controller_1: return ai_controller_1.get_name_str()
	elif current_player == "ai2" and ai_controller_2: return ai_controller_2.get_name_str()
	elif current_player == "ai3" and ai_controller_3: return ai_controller_3.get_name_str()
	return ""

func get_all_ai_names() -> Array:
	var names: Array = []
	if ai_controller_1: names.append(ai_controller_1.get_name_str())
	if ai_controller_2: names.append(ai_controller_2.get_name_str())
	if ai_controller_3: names.append(ai_controller_3.get_name_str())
	return names

## Resolve challenge
func _resolve_challenge(challenger: String, target: String) -> void:
	var target_value: int = current_bid_value
	var total_match: int = 0
	var six_wild: bool = _twoface_present
	if player_virus < PLAYER_MAX_VIRUS: total_match += player_cup.count_matches_revealing(target_value, six_wild)
	if player_virus < PLAYER_MAX_VIRUS and GameState.assimilation_curse == "double_wild" and target_value not in [1, 3]:
		for die in player_cup.dice:
			if die.value == 3: total_match += 1
	if ai1_virus < AI_MAX_VIRUS: total_match += ai_cup_1.count_matches_revealing(target_value, six_wild)
	if ai2_virus < AI_MAX_VIRUS: total_match += ai_cup_2.count_matches_revealing(target_value, six_wild)
	if ai3_virus < AI_MAX_VIRUS: total_match += ai_cup_3.count_matches_revealing(target_value, six_wild)
	# 幸运儿 Lv.3: 他的①不能当万能
	if target_value != 1 and GameState.get_card_level("lucky_one") >= 3:
		for lucky_id in _living_card_ais("lucky_one"):
			var lucky_cup: RefCounted = _get_ai_cup(lucky_id)
			if lucky_cup:
				for die in lucky_cup.dice:
					if die.value == 1:
						total_match -= 1  # 他的①不算万能
	var bid_true: bool = total_match >= current_bid_count
	if challenger == "player" and not bid_true:
		if _tutorial_active:
			GameState.tutorial_completed = true
			GameState.save_progress()
			_tutorial_active = false
			EventBus.tutorial_hint_show.emit("质疑成功：实际数量少于叫牌数量时，被质疑者失败。教学完成，接下来按正常规则战斗。", 8.0)
	if target == "player":
		for observer in [ai_controller_1, ai_controller_2, ai_controller_3]:
			if observer and observer.has_method("observe_player_bid"):
				observer.observe_player_bid(bid_true)
	var loser: String = target if not bid_true else challenger
	var winner: String = challenger if not bid_true else target
	# Save pre-infection state for dice display
	var was_player_dead: bool = player_virus >= PLAYER_MAX_VIRUS
	var was_ai1_dead: bool = ai1_virus >= AI_MAX_VIRUS
	var was_ai2_dead: bool = ai2_virus >= AI_MAX_VIRUS
	challenge_happened.emit(challenger, target, total_match, current_bid_count)
	if loser == "player":
		if player_shield:
			player_shield = false
			EventBus.hint_show.emit("幽灵附身免疫了一次伤害!", 3.0, Color(0.75, 0.45, 0.85))
		elif challenger == "player" and GameState.has_boss_fragment("referee") and not _fragment_referee_used:
			_fragment_referee_used = true
			EventBus.hint_show.emit("裁判碎片改判：本局第一次质疑失败不产生同化", 3.0, Color(0.98, 0.78, 0.29))
		else:
			_infect_player()
	elif loser == "ai1":
		if _ai_shields.get("ai1", false):
			_ai_shields["ai1"] = false; EventBus.card_skill_triggered.emit("table_ghost", "免疫", "ai1")
		elif ai_controller_1.infect():
			ai1_virus = AI_MAX_VIRUS
			_apply_rust_warrior_skill("ai1", winner)
		elif ai_controller_1._bk_saved:
			ai_controller_1._bk_saved = false; ai_cup_1.add_die()
			EventBus.hint_show.emit("电池小子备用电源: +1骰!", 3.0, Color(0.52, 0.72, 0.92))
	elif loser == "ai2":
		if _ai_shields.get("ai2", false):
			_ai_shields["ai2"] = false; EventBus.card_skill_triggered.emit("table_ghost", "免疫", "ai2")
		elif ai_controller_2 and ai_controller_2.infect():
			ai2_virus = AI_MAX_VIRUS
			_apply_rust_warrior_skill("ai2", winner)
		elif ai_controller_2 and ai_controller_2._bk_saved:
			ai_controller_2._bk_saved = false; ai_cup_2.add_die()
			EventBus.hint_show.emit("电池小子备用电源: +1骰!", 3.0, Color(0.52, 0.72, 0.92))
	elif loser == "ai3":
		if _ai_shields.get("ai3", false):
			_ai_shields["ai3"] = false; EventBus.card_skill_triggered.emit("table_ghost", "免疫", "ai3")
		elif _boss_card_id == "referee" and not _boss_referee_shield_used:
			_boss_referee_shield_used = true
			EventBus.hint_show.emit("Boss·终审豁免：免疫本局第一次淘汰", 3.0, Color(0.98, 0.35, 0.35))
		elif ai_controller_3 and ai_controller_3.infect():
			if not _try_advance_dice_god_phase("ai3"):
				ai3_virus = AI_MAX_VIRUS
				_apply_rust_warrior_skill("ai3", winner)
		elif ai_controller_3 and ai_controller_3._bk_saved:
			ai_controller_3._bk_saved = false; ai_cup_3.add_die()
			EventBus.hint_show.emit("电池小子备用电源: +1骰!", 3.0, Color(0.52, 0.72, 0.92))
	var player_dead: bool = player_virus >= PLAYER_MAX_VIRUS
	var ai1_dead: bool = ai1_virus >= AI_MAX_VIRUS
	var ai2_dead: bool = ai2_virus >= AI_MAX_VIRUS
	var ai3_dead: bool = ai3_virus >= AI_MAX_VIRUS
	if challenger == "player" and not bid_true and target.begins_with("ai"):
		var devour_count: int = 0
		if GameState.assimilation_curse == "devour_challenge": devour_count += 2
		if GameState.has_boss_fragment("recycler"): devour_count += 1
		var devour_target: RefCounted = _get_ai_cup(target)
		var stolen: int = 0
		while stolen < devour_count and devour_target and devour_target.dice.size() > 1:
			devour_target.dice.pop_back(); devour_target.dice_count -= 1
			player_cup.add_die(); stolen += 1
		if stolen > 0:
			EventBus.hint_show.emit("吞噬成功：从%s夺取%d颗骰子" % [get_ai_name_for_id(target), stolen], 3.0, Color(0.36, 0.79, 0.65))
	if _boss_card_id == "recycler" and _is_ai_alive(_boss_ai_id) and loser != _boss_ai_id:
		var loser_cup: RefCounted = player_cup if loser == "player" else _get_ai_cup(loser)
		if loser_cup and loser_cup.dice.size() > 1:
			loser_cup.dice.pop_back(); loser_cup.dice_count -= 1
			ai_cup_3.add_die()
			EventBus.hint_show.emit("Boss·强制回收：从本轮失败者处夺取1颗骰子", 3.0, Color(0.98, 0.35, 0.35))
	if loser == _boss_ai_id and _boss_card_id == "table_ghost" and ai3_dead:
		_ai_shields["ai1"] = false; _ai_shields["ai2"] = false
	# === 回收商: 质疑失败（叫牌为真）时，每名存活回收商独立触发。 ===
	if bid_true:
		var rec_lv: int = GameState.get_card_level("recycler")
		var dice_bonus: int = 2 if rec_lv >= 1 else 1
		for recycler_id in _living_card_ais("recycler"):
			var recycler_cup: RefCounted = _get_ai_cup(recycler_id)
			for _j in range(dice_bonus): recycler_cup.add_die()
			# Lv.2+: 被质疑者额外失去1骰，由本次触发的回收商吸收。
			if rec_lv >= 2 and target != recycler_id:
				var challenged_cup: RefCounted = player_cup if target == "player" else _get_ai_cup(target)
				if challenged_cup and challenged_cup.dice.size() > 1:
					challenged_cup.dice.pop_back(); challenged_cup.dice_count -= 1
					recycler_cup.add_die()
					EventBus.hint_show.emit("回收商吸走了被质疑者的1颗骰子!", 3.0, Color(0.52, 0.72, 0.92))
			EventBus.card_skill_triggered.emit("recycler", "捡骰", recycler_id)
	# 揭示时放开所有骰子
	player_cup.reveal_all()
	if ai1_virus < AI_MAX_VIRUS: ai_cup_1.reveal_all()
	if ai2_virus < AI_MAX_VIRUS: ai_cup_2.reveal_all()
	if ai3_virus < AI_MAX_VIRUS: ai_cup_3.reveal_all()
	dice_revealed.emit(
		player_cup.get_all_values(), ai_cup_1.get_all_values(), ai_cup_2.get_all_values(), ai_cup_3.get_all_values(),
		true, true, was_ai1_dead, was_ai2_dead)
	_flush_pending_dice()
	# 赌场主: 恢复暗骰（揭示后需要重新隐藏）
	_rehide_casino_dice()
	# === 赌桌幽灵: 淘汰时附身 (Lv.1=附身2人, Lv.2=一轮不可被质疑) ===
	if loser.begins_with("ai") and card_has(loser, "table_ghost"):
		var ghost_lv: int = GameState.get_card_level("table_ghost")
		var ghost_count: int = 2 if ghost_lv >= 1 else 1
		var g_candidates: Array[String] = []
		if player_virus < PLAYER_MAX_VIRUS: g_candidates.append("player")
		if ai1_virus < AI_MAX_VIRUS and loser != "ai1": g_candidates.append("ai1")
		if ai2_virus < AI_MAX_VIRUS and loser != "ai2": g_candidates.append("ai2")
		if ai3_virus < AI_MAX_VIRUS and loser != "ai3": g_candidates.append("ai3")
		g_candidates.shuffle()
		var gifted: int = 0
		for g_target in g_candidates:
			if gifted >= ghost_count: break
			match g_target:
				"player": player_cup.add_die()
				"ai1": ai_cup_1.add_die()
				"ai2": ai_cup_2.add_die()
				"ai3": ai_cup_3.add_die()
			if ghost_lv >= 2:
				_challenge_immunity_until[g_target] = round_number + 1
			gifted += 1
		if gifted > 0:
			EventBus.card_skill_triggered.emit("table_ghost", "附身(%d人)" % gifted, "")
			EventBus.hint_show.emit("赌桌幽灵附身 %d 人：各获得1颗骰子" % gifted, 3.0, Color(0.75, 0.45, 0.85))
	_apply_abyss_round_end()
	if player_dead and game_active:
		game_active = false
		if _noise_removed_items.size() > 0:
			for item_id in _noise_removed_items:
				GameState.add_consumable_item(item_id)
		game_over.emit("ai"); return
	var alive_ai_count: int = 0
	if not ai1_dead: alive_ai_count += 1
	if not ai2_dead: alive_ai_count += 1
	if not ai3_dead: alive_ai_count += 1
	if alive_ai_count == 0 and game_active:
		game_active = false
		if _noise_removed_items.size() > 0:
			for item_id in _noise_removed_items:
				GameState.add_consumable_item(item_id)
		game_over.emit("player"); return
	_continue_round()

func _apply_abyss_round_end() -> void:
	for abyss_id in _living_card_ais("unknown_abyss"):
		var targets: Array[String] = []
		if player_virus < PLAYER_MAX_VIRUS and player_cup.dice.size() >= 2: targets.append("player")
		if abyss_id != "ai1" and ai1_virus < AI_MAX_VIRUS and ai_cup_1.dice.size() >= 2: targets.append("ai1")
		if abyss_id != "ai2" and ai2_virus < AI_MAX_VIRUS and ai_cup_2.dice.size() >= 2: targets.append("ai2")
		if abyss_id != "ai3" and ai3_virus < AI_MAX_VIRUS and ai_cup_3.dice.size() >= 2: targets.append("ai3")
		if targets.is_empty(): continue
		var victim: String = targets[randi() % targets.size()]
		var victim_cup: RefCounted = player_cup if victim == "player" else _get_ai_cup(victim)
		victim_cup.dice.pop_back(); victim_cup.dice_count -= 1
		_get_ai_cup(abyss_id).add_die()
		EventBus.card_skill_triggered.emit("abyss", "每轮吞噬", victim)
		EventBus.hint_show.emit("深渊吞噬了%s的1颗骰子" % ("你" if victim == "player" else get_ai_name_for_id(victim)), 3.0, Color(0.55, 0.35, 0.65))

## Apply rust_warrior skill on elimination (Lv.1=2人, Lv.2=对手-1骰, Lv.3=全生存+对手扣骰)
func _apply_rust_warrior_skill(eliminated_ai: String, attacker: String = "") -> void:
	var ctrl = null
	match eliminated_ai:
		"ai1": ctrl = ai_controller_1
		"ai2": ctrl = ai_controller_2
		"ai3": ctrl = ai_controller_3
	if ctrl == null or ctrl.card == null: return
	if ctrl.card.card_id != "rust_warrior": return
	var rw_lv: int = GameState.get_card_level("rust_warrior")
	var survivors: Array = []
	if eliminated_ai != "ai1" and ai1_virus < AI_MAX_VIRUS: survivors.append("ai1")
	if eliminated_ai != "ai2" and ai2_virus < AI_MAX_VIRUS: survivors.append("ai2")
	if eliminated_ai != "ai3" and ai3_virus < AI_MAX_VIRUS: survivors.append("ai3")
	if eliminated_ai != "player" and player_virus < PLAYER_MAX_VIRUS: survivors.append("player")
	if survivors.is_empty(): return
	# Lv.3: all survivors get +1①; Lv.1=2人, Lv.0=1人
	var gift_count: int = 1
	if rw_lv >= 3: gift_count = survivors.size()
	elif rw_lv >= 1: gift_count = 2
	gift_count = mini(gift_count, survivors.size())
	survivors.shuffle()
	for i in range(gift_count):
		var pick: String = survivors[i]
		match pick:
			"player": player_cup.add_die_with_value(1)
			"ai1": ai_cup_1.add_die_with_value(1)
			"ai2": ai_cup_2.add_die_with_value(1)
			"ai3": ai_cup_3.add_die_with_value(1)
	# Lv.2+: attacker loses 1 die
	if rw_lv >= 2 and attacker != "" and attacker != eliminated_ai:
		var atk_cup: RefCounted = null
		match attacker:
			"player": atk_cup = player_cup
			"ai1": atk_cup = ai_cup_1
			"ai2": atk_cup = ai_cup_2
			"ai3": atk_cup = ai_cup_3
		if atk_cup and atk_cup.dice.size() > 1:
			atk_cup.dice.pop_back(); atk_cup.dice_count -= 1
			EventBus.hint_show.emit("锈铁战士意志反噬: %s 被扣1骰!" % attacker, 3.0, Color(0.6, 0.4, 0.4))
	EventBus.card_skill_triggered.emit("rust_warrior", "意志依存", "%d人" % gift_count)
	EventBus.hint_show.emit("锈铁战士的意志: %d 颗 ① 已送出" % gift_count, 4.0, Color(0.6, 0.4, 0.4))

## Continue round after elimination
func _continue_round() -> void:
	var alive_count: int = 0
	if player_virus < PLAYER_MAX_VIRUS: alive_count += 1
	if ai1_virus < AI_MAX_VIRUS: alive_count += 1
	if ai2_virus < AI_MAX_VIRUS: alive_count += 1
	if ai3_virus < AI_MAX_VIRUS: alive_count += 1
	if alive_count <= 1:
		_continue_round_final()
	else:
		_start_round()

func _continue_round_final() -> void:
	current_bid_count = 0; current_bid_value = 1; last_bidder = ""
	if player_virus < PLAYER_MAX_VIRUS:
		current_player = "player"
	elif ai1_virus < AI_MAX_VIRUS:
		current_player = "ai1"
	elif ai2_virus < AI_MAX_VIRUS:
		current_player = "ai2"
	else:
		current_player = "ai3"
	turn_changed.emit(current_player)
	if current_player != "player":
		await get_tree().create_timer(_think_delay(current_player, false, true)).timeout
		if game_active: _ai_turn(current_player)

func _dice_str(vals: Array) -> String:
	var s: String = ""
	for v: int in vals:
		s += str(v) + " "
	return s.strip_edges()

func get_min_opening() -> int:
	var alive_count: int = 0
	if player_virus < PLAYER_MAX_VIRUS: alive_count += 1
	if ai1_virus < AI_MAX_VIRUS: alive_count += 1
	if ai2_virus < AI_MAX_VIRUS: alive_count += 1
	if ai3_virus < AI_MAX_VIRUS: alive_count += 1
	return alive_count + 1 + (1 if GameState.is_forbidden_rule_active("high_pressure") else 0)

## Think delay based on rarity
func _think_delay(ai_id: String, is_challenge: bool, is_opening: bool) -> float:
	var base: float = 1.2
	if is_challenge: base = 2.5
	elif is_opening: base = 1.8
	else: base = 1.5
	var ctrl = null
	match ai_id:
		"ai1": ctrl = ai_controller_1
		"ai2": ctrl = ai_controller_2
		"ai3": ctrl = ai_controller_3
	var rarity: int = 0
	if ctrl and ctrl.card: rarity = ctrl.card.rarity
	if rarity == 0: base *= 0.7
	elif rarity == 1: base *= 1.3
	elif rarity == 4: base *= 1.5
	else: base *= 1.0
	base += randf() * 0.8
	return base

## Collude enrage check (stage 2)
func _collude_enrage_check() -> void:
	var dead_count: int = 0
	if ai1_virus >= AI_MAX_VIRUS: dead_count += 1
	if ai2_virus >= AI_MAX_VIRUS: dead_count += 1
	if ai3_virus >= AI_MAX_VIRUS: dead_count += 1
	if dead_count == 0: return
	var boost: float = dead_count * 0.25
	if ai_controller_1 and ai1_virus < AI_MAX_VIRUS:
		ai_controller_1.challenge_certainty = clampf(ai_controller_1.challenge_certainty + boost, 0, 0.95)
		ai_controller_1.bluff_frequency = clampf(ai_controller_1.bluff_frequency + boost * 0.5, 0, 0.9)
	if ai_controller_2 and ai2_virus < AI_MAX_VIRUS:
		ai_controller_2.challenge_certainty = clampf(ai_controller_2.challenge_certainty + boost, 0, 0.95)
		ai_controller_2.bluff_frequency = clampf(ai_controller_2.bluff_frequency + boost * 0.5, 0, 0.9)
	if ai_controller_3 and ai3_virus < AI_MAX_VIRUS:
		ai_controller_3.challenge_certainty = clampf(ai_controller_3.challenge_certainty + boost, 0, 0.95)
		ai_controller_3.bluff_frequency = clampf(ai_controller_3.bluff_frequency + boost * 0.5, 0, 0.9)

func _on_game_over(winner: String) -> void:
	game_active = false
	game_over.emit(winner)

# ===== Item effect methods (called from HUD) =====

func flip_die_at(idx: int) -> void:
	if player_virus >= PLAYER_MAX_VIRUS: return
	if idx >= 0 and idx < player_cup.dice.size():
		player_cup.flip_at(idx)

func lock_player_die(idx: int) -> void:
	if player_virus >= PLAYER_MAX_VIRUS: return
	if idx >= 0 and idx < player_cup.dice.size():
		player_cup.lock_die(idx)

func clone_player_die(idx: int) -> void:
	if player_virus >= PLAYER_MAX_VIRUS: return
	player_cup.clone_at(idx)

func split_player_die(idx: int) -> void:
	if player_virus >= PLAYER_MAX_VIRUS: return
	player_cup.split_at(idx)

func rig_player_dice(idx: int) -> void:
	if player_virus >= PLAYER_MAX_VIRUS: return
	if idx >= 0 and idx < player_cup.dice.size():
		player_cup.dice[idx].value = 1
	# Also flip a second die to 1 (next index, wrap if needed)
	var n: int = player_cup.dice.size()
	var idx2: int = (idx + 1) % n
	player_cup.dice[idx2].value = 1

func reroll_player_dice(_specific_only: bool = false) -> void:
	if player_virus >= PLAYER_MAX_VIRUS: return
	player_cup.roll_all()

func reroll_selected_dice(indices: Array) -> void:
	if player_virus >= PLAYER_MAX_VIRUS: return
	player_cup.roll_indices(indices)

func queue_payout_reward(amount: int = 15) -> void:
	_pending_payout_gold += maxi(0, amount)

func claim_payout_reward() -> int:
	var result: int = _pending_payout_gold
	_pending_payout_gold = 0
	return result

func contract_was_completed() -> bool:
	var contract_id: String = str(GameState.current_contract.get("id", ""))
	match contract_id:
		"no_item": return GameState.items_used == _contract_start_items_used
		"bold_bid": return _contract_bold_bid
		"five_twos": return _contract_five_twos
		"three_faces": return _contract_bid_faces.size() >= 3
		"three_rounds": return round_number >= 3
	return false

func set_player_die_value(idx: int, val: int) -> void:
	if player_virus >= PLAYER_MAX_VIRUS: return
	if idx >= 0 and idx < player_cup.dice.size():
		player_cup.dice[idx].value = clamp(val, 1, 6)

func activate_fate_die(idx: int) -> void:
	if idx < 0 or idx >= player_cup.dice.size(): return
	_fate_active = true
	_fate_index = idx
	_fate_value = player_cup.dice[idx].value
	# 使用当轮计为第1轮，之后两个新回合继续固定；不跨对局。
	_fate_rounds_left = 2

func apply_pair_fix() -> bool:
	return _apply_pair_fix_to_cup(player_cup)

func _apply_pair_fix_to_cup(cup: RefCounted) -> bool:
	if cup == null or cup.has_pairs() or cup.dice.size() < 2: return false
	var lowest_index: int = -1
	var lowest_value: int = 7
	var highest_value: int = 0
	for i in range(cup.dice.size()):
		var die = cup.dice[i]
		if die.is_hidden: continue
		if die.value < lowest_value:
			lowest_value = die.value
			lowest_index = i
		highest_value = maxi(highest_value, die.value)
	if lowest_index < 0 or highest_value <= 0: return false
	cup.dice[lowest_index].value = highest_value
	return true

func _apply_self_item_to_ai(ai_id: String, item_id: String, context: Dictionary = {}) -> bool:
	if not _is_ai_alive(ai_id) or item_id not in SELF_ONLY_ITEM_IDS: return false
	var cup: RefCounted = _get_ai_cup(ai_id)
	if cup == null: return false
	var preferred_idx: int = int(context.get("index", -1))
	match item_id:
		"reroll_stone", "full_reroll":
			var indices: Array = context.get("indices", [])
			if item_id == "reroll_stone" and not indices.is_empty():
				cup.roll_indices(indices)
			else:
				cup.roll_all()
		"flip_die":
			var idx: int = preferred_idx if preferred_idx >= 0 and preferred_idx < cup.dice.size() else randi() % cup.dice.size()
			cup.flip_at(idx)
		"freeze_die":
			var idx: int = preferred_idx if preferred_idx >= 0 and preferred_idx < cup.dice.size() else randi() % cup.dice.size()
			cup.lock_die(idx)
		"clone_die":
			var candidates: Array[int] = cup.get_pair_indices()
			if candidates.is_empty(): return false
			var idx: int = preferred_idx if preferred_idx in candidates else candidates[randi() % candidates.size()]
			cup.clone_at(idx)
		"split_die":
			var candidates: Array[int] = []
			for i in range(cup.dice.size()):
				if cup.dice[i].value >= 4: candidates.append(i)
			if candidates.is_empty(): return false
			var idx: int = preferred_idx if preferred_idx in candidates else candidates[randi() % candidates.size()]
			cup.split_at(idx)
		"pair_fix":
			return _apply_pair_fix_to_cup(cup)
		"purge_chip":
			var ctrl: RefCounted = _get_ai_controller(ai_id)
			if ctrl: ctrl.virus_count = 0
			match ai_id:
				"ai1": ai1_virus = 0
				"ai2": ai2_virus = 0
				"ai3": ai3_virus = 0
		"silent_turn":
			_skip_ai_turns[ai_id] = int(_skip_ai_turns.get(ai_id, 0)) + 1
		"royal_pardon":
			_ai_shields[ai_id] = true
		"extra_die":
			cup.add_die()
		"fate_die":
			var idx: int = preferred_idx if preferred_idx >= 0 and preferred_idx < cup.dice.size() else randi() % cup.dice.size()
			_ai_fate_effects[ai_id] = {"index": idx, "value": cup.dice[idx].value, "rounds_left": 2}
		"rig_dice":
			if cup.dice.is_empty(): return false
			var indices: Array[int] = []
			for raw_idx in context.get("indices", []):
				var context_idx: int = int(raw_idx)
				if context_idx >= 0 and context_idx < cup.dice.size() and context_idx not in indices:
					indices.append(context_idx)
			while indices.size() < mini(2, cup.dice.size()):
				var random_idx: int = randi() % cup.dice.size()
				if random_idx not in indices: indices.append(random_idx)
			for idx in indices: cup.dice[idx].value = 1
		_: return false
	return true

func borrow_visible_die(ai_id: String, idx: int) -> bool:
	var cup: RefCounted = _get_ai_cup(ai_id)
	if cup == null or idx < 0 or idx >= cup.dice.size() or cup.dice[idx].is_hidden:
		return false
	player_cup.add_die_with_value(cup.dice[idx].value)
	return true

func skip_player_turn() -> void:
	if not game_active: return
	# Player skips their bid; advance to next AI directly
	if current_player == "player":
		_next_player()

func sabotage_enemy_dice(ai_id: String) -> bool:
	var cup: RefCounted = _get_ai_cup(ai_id)
	if cup == null or cup.dice.size() < 2: return false
	var i1: int = randi() % cup.dice.size()
	var i2: int = (i1 + 1 + randi() % max(1, cup.dice.size() - 1)) % cup.dice.size()
	cup.dice[i1].value = 1
	cup.dice[i2].value = 1
	return true

func peek_ai_die(ai_id: String, idx: int) -> int:
	var cup = null
	if ai_id == "ai1": cup = ai_cup_1
	elif ai_id == "ai2": cup = ai_cup_2
	elif ai_id == "ai3": cup = ai_cup_3
	if cup == null: return -1
	if idx >= 0 and idx < cup.dice.size():
		var d = cup.dice[idx]
		return d.value
	return -1

func get_player_has_pairs() -> bool:
	if player_virus >= PLAYER_MAX_VIRUS: return false
	return player_cup.has_pairs()

func get_player_paired_dice() -> Array[int]:
	if player_virus >= PLAYER_MAX_VIRUS: return []
	return player_cup.get_pair_indices()

func get_player_lowest_indices() -> Array:
	if player_virus >= PLAYER_MAX_VIRUS: return []
	var vals: Array = player_cup.get_values()
	if vals.is_empty(): return []
	var min_val: int = 99
	for v: int in vals:
		if v >= 1 and v < min_val: min_val = v
	if min_val == 99: return []
	var result: Array = []
	for i: int in range(vals.size()):
		if vals[i] == min_val: result.append(i)
	return result

func card_has(ai_id: String, card_id: String) -> bool:
	match ai_id:
		"ai1": return ai_controller_1 and ai_controller_1.card and ai_controller_1.card.card_id == card_id
		"ai2": return ai_controller_2 and ai_controller_2.card and ai_controller_2.card.card_id == card_id
		"ai3": return ai_controller_3 and ai_controller_3.card and ai_controller_3.card.card_id == card_id
	return false

func get_ai_dice_values(ai_idx: int = 0) -> Array:
	var cup = null
	if ai_idx == 0: cup = ai_cup_1
	elif ai_idx == 1: cup = ai_cup_2
	elif ai_idx == 2: cup = ai_cup_3
	if cup == null: return []
	return cup.get_values()

func continue_after_challenge() -> void:
	# Advance the game after challenge resolution
	_continue_round()

func get_chamberlain_items(ai_id: String) -> Array:
	return (_chamberlain_items_by_ai.get(ai_id, []) as Array).duplicate()

func get_temporarily_disabled_player_items() -> Array:
	return _noise_removed_items.duplicate()

func get_battle_restart_modifiers() -> Dictionary:
	return {
		"bonus_dice": _bonus_dice,
		"fixed_six": _fixed_six_active,
		"boss_dice_penalty": _boss_dice_penalty_applied,
	}

func get_chaos_reveal_text() -> String:
	var lines: Array[String] = []
	for chaos_id in _chaos_bids_by_ai:
		var bids: Dictionary = _chaos_bids_by_ai[chaos_id]
		var real_bid: Dictionary = bids.get("real", {})
		var fake_bid: Dictionary = bids.get("fake", {})
		lines.append("混沌 %s: 显示 %d个%s, 实际 %d个%s" % [
			get_ai_name_for_id(chaos_id),
			fake_bid.get("count", 0), _num_to_die(fake_bid.get("value", 1)),
			real_bid.get("count", 0), _num_to_die(real_bid.get("value", 1))
		])
	return "\n".join(lines)

func _num_to_die(v: int) -> String:
	var dice_emoji: Array[String] = ["", "①", "②", "③", "④", "⑤", "⑥"]
	return dice_emoji[v] if v >= 1 and v <= 6 else str(v)

func _rehide_casino_dice() -> void:
	if _casino_hidden <= 0: return
	# 每个存活者的杯中隐藏 _casino_hidden 颗骰子
	var cups: Array = [player_cup]
	if ai1_virus < AI_MAX_VIRUS: cups.append(ai_cup_1)
	if ai2_virus < AI_MAX_VIRUS: cups.append(ai_cup_2)
	if ai3_virus < AI_MAX_VIRUS: cups.append(ai_cup_3)
	for cup in cups:
		cup.hide_random_dice(_casino_hidden)

func queue_dice(target_id: String, count: int) -> void:
	if not _pending_dice.has(target_id): _pending_dice[target_id] = 0
	_pending_dice[target_id] += count

func _flush_pending_dice() -> void:
	if _pending_dice.is_empty(): return
	for t in _pending_dice:
		var n: int = _pending_dice[t]
		match t:
			"player":
				for _i in range(n): player_cup.add_die()
			"ai1":
				if ai1_virus < AI_MAX_VIRUS:
					for _i in range(n): ai_cup_1.add_die()
			"ai2":
				if ai2_virus < AI_MAX_VIRUS:
					for _i in range(n): ai_cup_2.add_die()
			"ai3":
				if ai3_virus < AI_MAX_VIRUS:
					for _i in range(n): ai_cup_3.add_die()
	_pending_dice.clear()

func use_chamberlain_item(ai_id: String) -> void:
	var items: Array = _chamberlain_items_by_ai.get(ai_id, [])
	if items.is_empty() or not _is_ai_alive(ai_id): return
	var item_id: String = ""
	var used_index: int = -1
	for i in range(items.size()):
		var candidate_id: String = items[i]
		if _apply_self_item_to_ai(ai_id, candidate_id):
			item_id = candidate_id
			used_index = i
			break
	if used_index < 0: return
	items.remove_at(used_index)
	_chamberlain_items_by_ai[ai_id] = items
	var info: ItemData = GameState.get_item_info(item_id)
	var item_name: String = info.item_name if info else item_id
	EventBus.card_skill_triggered.emit("chamberlain", "使用道具", "%s" % item_name)
	EventBus.hint_show.emit("侍从长使用: %s" % item_name, 3.0, Color(0.52, 0.72, 0.92))

# === 镜面技师: 复制玩家道具 ===
func get_ai_name_for_id(ai_id: String) -> String:
	match ai_id:
		"ai1": return ai_controller_1.get_name_str() if ai_controller_1 else "对手1"
		"ai2": return ai_controller_2.get_name_str() if ai_controller_2 else "对手2"
		"ai3": return ai_controller_3.get_name_str() if ai_controller_3 else "对手3"
	return ai_id

func mirror_item(item_id: String, context: Dictionary = {}) -> void:
	if item_id == "copy_die": item_id = "extra_die"
	if item_id not in SELF_ONLY_ITEM_IDS: return
	var copied: bool = false
	for mirror_id in _living_card_ais("mirror_tech"):
		if _apply_self_item_to_ai(mirror_id, item_id, context):
			copied = true
			EventBus.card_skill_triggered.emit("mirror_tech", "镜像道具", mirror_id + ":" + item_id)
	if not copied: return
	EventBus.hint_show.emit("镜面技师复制了你的自身道具!", 3.0, Color(0.75, 0.45, 0.85))
	if GameState.get("recent_log"):
		GameState.recent_log.append("镜面技师复制: " + item_id)

# === 黑吃黑: 胜利者瓜分骰子 ===
func _gang_feed(loser: String) -> void:
	var survivors: Array[String] = []
	if player_virus < PLAYER_MAX_VIRUS and loser != "player": survivors.append("player")
	if ai1_virus < AI_MAX_VIRUS and loser != "ai1": survivors.append("ai1")
	if ai2_virus < AI_MAX_VIRUS and loser != "ai2": survivors.append("ai2")
	if ai3_virus < AI_MAX_VIRUS and loser != "ai3": survivors.append("ai3")
	for s in survivors:
		match s:
			"player": player_cup.add_die(); player_cup.add_die()
			"ai1": ai_cup_1.add_die(); ai_cup_1.add_die()
			"ai2": ai_cup_2.add_die(); ai_cup_2.add_die()
			"ai3": ai_cup_3.add_die(); ai_cup_3.add_die()
	if survivors.size() > 1:
		EventBus.hint_show.emit("黑吃黑: 幸存者各+2骰!", 3.0, Color(0.98, 0.78, 0.29))

func get_ai_card(ai_idx: int) -> Resource:
	if ai_idx == 0 and ai_controller_1: return ai_controller_1.card
	if ai_idx == 1 and ai_controller_2: return ai_controller_2.card
	if ai_idx == 2 and ai_controller_3: return ai_controller_3.card
	return null
