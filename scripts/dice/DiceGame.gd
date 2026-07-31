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

var boss_skill: String = ""  # "swap" | "dark" | "collude" | "forbidden"
var forbidden_number: int = 0
var _holy_forbidden: Array[int] = []  # 圣洁禁忌点数 (阶段3)
var _holy_victim: String = ""  # 叫到禁忌的角色
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
var _dealer_ai: String = ""  # "ai1"/"ai2"/"ai3" if 庄家 is alive
var _noise_ai: String = ""   # "ai1"/"ai2"/"ai3" if 信号噪音 was drawn
var _noise_removed_items: Array[String] = []  # 信号噪音暂时移除的道具，对局结束归还
var _mirror_present: bool = false  # 镜像·广播 在场
var _twoface_present: bool = false  # 双面人: ①和⑥都是万能骰
var _cyclops_lock: int = 0  # 独眼龙LCD: 本局锁定点数, 0=未触发
var _cyclops_locks: Array[int] = []  # 独眼龙LCD: Lv.1+ 锁多个点数
var _chamberlain_triggered: bool = false  # 侍从长: 已发道具
var _chamberlain_items: Array[String] = []  # 侍从长的道具
var _cyclops_ai: String = ""  # 独眼龙所在 AI
var chamberlain_ai_id: String = ""  # 侍从长所在 AI (公开)
var _chaos_ai: String = ""  # 混沌所在 AI
var _chaos_real_bid: Dictionary = {}  # 混沌真实叫法 {count, value}
var _chaos_fake_bid: Dictionary = {}  # 混沌虚假显示 {count, value}
var _recycler_ai: String = ""  # 回收商
var _lucky_one_ai: String = ""  # 幸运儿
var _referee_ai: String = ""  # 裁判长
var _mirror_tech_ai: String = ""  # 镜面技师
var _casino_ai: String = ""  # 赌场主
var _casino_hidden: int = 1  # 赌场主暗骰数
var _casino_see_all: bool = false  # 赌场主Lv.3全看到
var _prophet_ai: String = ""  # 算法先知
var _dice_god_ai: String = ""  # 骰子之神
var _abyss_ai: String = ""  # 深渊
var _round_count: int = 0  # 裁判长用
var _battery_triggered: Dictionary = {}  # 电池小子已触发 {ai_id: bool}
var _card_levels: Dictionary = {}  # {card_id: int} upgrade levels from GameState
var _table_ghost_active: Dictionary = {}  # 幽灵附身 {ai_id: bool}
var _alliance_ai: String = ""  # 同盟OLED AI
var _alliance_target: String = ""  # 同盟选中者
var _ghost_target: String = ""  # 幽灵附身目标 (免疫1次伤害)

var player_virus: int = 0  # 0=2HP, 2=1HP, 4=dead
var ai1_virus: int = 0
var ai2_virus: int = 0
var ai3_virus: int = 0
const AI_MAX_VIRUS: int = 1
const PLAYER_MAX_VIRUS: int = 2
var _bonus_dice: int = 0
var _was_elimination: bool = false

func start_game(card1: Resource, card2: Resource, has_dark_die: bool = false, card3: Resource = null, _is_boss: bool = false) -> void:
	_bonus_dice = GameState.get_bonus_dice_count()
	is_boss_mode = _is_boss
	var total: int = 5 + _bonus_dice
	player_cup = preload("res://scripts/dice/DiceCup.gd").new(total)
	ai_cup_1 = preload("res://scripts/dice/DiceCup.gd").new(5)
	ai_cup_2 = preload("res://scripts/dice/DiceCup.gd").new(5)
	ai_cup_3 = preload("res://scripts/dice/DiceCup.gd").new(5)
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

	# 设置动态开局数值：存活人数 + 1
	var opening_min: int = get_min_opening()
	if ai_controller_1: ai_controller_1.min_opening = opening_min
	if ai_controller_2: ai_controller_2.min_opening = opening_min
	if ai_controller_3: ai_controller_3.min_opening = opening_min

	# Detect card skills
	_dealer_ai = ""; _noise_ai = ""; _twoface_present = false; _cyclops_ai = ""; _chaos_ai = ""
	_recycler_ai = ""; _lucky_one_ai = ""; _referee_ai = ""; _mirror_tech_ai = ""
	_casino_ai = ""; _prophet_ai = ""; _dice_god_ai = ""; _abyss_ai = ""
	_alliance_ai = ""; _alliance_target = ""
	_chaos_real_bid.clear(); _chaos_fake_bid.clear()
	player_shield = false; _ai_shields.clear(); _ghost_target = ""; _table_ghost_active.clear()
	_chamberlain_triggered = false
	for ai_info in [["ai1", card1], ["ai2", card2], ["ai3", card3]]:
		if ai_info[1] == null: continue
		if ai_info[1].card_id == "dealer": _dealer_ai = ai_info[0]
		if ai_info[1].card_id == "signal_noise": _noise_ai = ai_info[0]
		if ai_info[1].card_id == "two_face": _twoface_present = true; EventBus.hint_show.emit("双面人: ①和⑥都是万能骰", 4.0, Color(0.98, 0.85, 0.50))
		if ai_info[1].card_id == "cyclops_lcd": _cyclops_ai = ai_info[0]
		if ai_info[1].card_id == "chaos" or ai_info[1].card_id == "unknown_chaos": _chaos_ai = ai_info[0]; EventBus.hint_show.emit("混沌·乱码: 它的叫牌可能被篡改", 4.0, Color(0.85, 0.6, 0.2))
		if ai_info[1].card_id == "recycler": _recycler_ai = ai_info[0]; var rec_lv_hint: int = 2 if GameState.get_card_level("recycler") >= 1 else 1; EventBus.hint_show.emit("回收商·捡骰: 有人质疑失败时+%d骰" % rec_lv_hint, 4.0, Color(0.52, 0.72, 0.92))
		if ai_info[1].card_id == "lucky_one": _lucky_one_ai = ai_info[0]; var lucky_hint: int = 2 if GameState.get_card_level("lucky_one") >= 1 else 1; EventBus.hint_show.emit("幸运儿·骰神眷顾: 永远多%d个①" % lucky_hint, 4.0, Color(0.98, 0.78, 0.29))
		if ai_info[1].card_id == "referee": _referee_ai = ai_info[0]; var rrlv: int = GameState.get_card_level("referee"); EventBus.hint_show.emit("裁判长·加时: 第%d轮强制开" % (2 if rrlv >= 1 else 3), 4.0, Color(0.98, 0.78, 0.29))
		if ai_info[1].card_id == "mirror_tech": _mirror_tech_ai = ai_info[0]; EventBus.hint_show.emit("镜面技师·镜像: 复制玩家骰子", 4.0, Color(0.75, 0.45, 0.85))
		if ai_info[1].card_id == "casino_owner": _casino_ai = ai_info[0]; var cas_hint: int = 2 if GameState.get_card_level("casino_owner") >= 1 else 1; EventBus.hint_show.emit("赌场主·暗骰加码: 每人+%d暗骰" % cas_hint, 4.0, Color(0.52, 0.72, 0.92))
		if ai_info[1].card_id == "prophet": _prophet_ai = ai_info[0]; EventBus.hint_show.emit("算法先知·重算: 每轮重掷骰子", 4.0, Color(0.98, 0.78, 0.29))
		if ai_info[1].card_id == "dice_god": _dice_god_ai = ai_info[0]; EventBus.hint_show.emit("骰子之神·禁忌变更: 每轮换禁忌点数", 4.0, Color(0.98, 0.35, 0.35))
		if ai_info[1].card_id == "unknown_abyss": _abyss_ai = ai_info[0]; EventBus.hint_show.emit("深渊·吞噬: 受伤者被吞1骰", 4.0, Color(0.55, 0.35, 0.65))
		if ai_info[1].card_id == "alliance_oled": _alliance_ai = ai_info[0]
		if ai_info[1].card_id == "table_ghost": EventBus.card_skill_triggered.emit("table_ghost", "附身就绪", ai_info[0])
		if ai_info[1].card_id == "chamberlain" and not _chamberlain_triggered:
			_chamberlain_triggered = true
			chamberlain_ai_id = ai_info[0]
			_chamberlain_items.clear()
			var chamber_lv: int = GameState.get_card_level("chamberlain")
			var chamber_count: int = 3
			var chamber_rare: int = 0
			if chamber_lv >= 1: chamber_count = 5
			if chamber_lv >= 2: chamber_rare = 1
			if chamber_lv >= 3: chamber_count = 6; chamber_rare = 2
			# Generate rare-guaranteed items first
			var all_items: Array = ItemData.get_random_shop_items(chamber_count + chamber_rare * 3)
			var rares: Array = []
			var commons: Array = []
			for it in all_items:
				if it.rarity >= ItemData.Rarity.RARE:
					rares.append(it)
				else:
					commons.append(it)
			# Ensure at least chamber_rare rare items
			while _chamberlain_items.size() < chamber_count:
				if chamber_rare > 0 and rares.size() > 0:
					_chamberlain_items.append(rares.pop_front().item_id)
					chamber_rare -= 1
				elif commons.size() > 0:
					_chamberlain_items.append(commons.pop_front().item_id)
				elif rares.size() > 0:
					_chamberlain_items.append(rares.pop_front().item_id)
				else:
					break
			EventBus.hint_show.emit("侍从长·军械库: 获得%d个道具!" % _chamberlain_items.size(), 4.0, Color(0.52, 0.72, 0.92))

	# Read card upgrade levels for all drawn cards
	_card_levels.clear()
	for ai_info in [["ai1", card1], ["ai2", card2], ["ai3", card3]]:
		if ai_info[1] == null: continue
		var cid: String = ai_info[1].card_id
		_card_levels[cid] = GameState.get_card_level(cid)

	# === 幸运儿: 骰子替换1颗为① ===
	if _lucky_one_ai != "":
		match _lucky_one_ai:
			"ai1": if ai_cup_1.dice.size() > 0: ai_cup_1.dice[0].value = 1
			"ai2": if ai_cup_2.dice.size() > 0: ai_cup_2.dice[0].value = 1
			"ai3": if ai_cup_3.dice.size() > 0: ai_cup_3.dice[0].value = 1
	# === 镜面技师: 复制玩家骰子 ===
	if _mirror_tech_ai != "":
		var pvals: Array = player_cup.get_all_values()
		match _mirror_tech_ai:
			"ai1": for _j in range(5 - ai_cup_1.dice.size()): ai_cup_1.add_die()
			"ai2": for _j in range(5 - ai_cup_2.dice.size()): ai_cup_2.add_die()
			"ai3": for _j in range(5 - ai_cup_3.dice.size()): ai_cup_3.add_die()
		match _mirror_tech_ai:
			"ai1": for k in range(min(pvals.size(), ai_cup_1.dice.size())): ai_cup_1.dice[k].value = pvals[k]
			"ai2": for k in range(min(pvals.size(), ai_cup_2.dice.size())): ai_cup_2.dice[k].value = pvals[k]
			"ai3": for k in range(min(pvals.size(), ai_cup_3.dice.size())): ai_cup_3.dice[k].value = pvals[k]
		EventBus.card_skill_triggered.emit("mirror_tech", "镜像", "player")
	# === 赌场主: 每人+暗骰 (Lv.1=2颗, Lv.2=自己能看, Lv.3=3颗+全看到) ===
	if _casino_ai != "":
		var casino_lv: int = GameState.get_card_level("casino_owner")
		_casino_hidden = 1 + casino_lv
		if _casino_hidden > 3: _casino_hidden = 3
		if casino_lv >= 2:
			_casino_hidden = 3 if casino_lv >= 3 else 2
		for _i in range(_casino_hidden):
			player_cup.add_hidden_die()
			if ai1_virus < AI_MAX_VIRUS: ai_cup_1.add_hidden_die()
			if ai2_virus < AI_MAX_VIRUS: ai_cup_2.add_hidden_die()
			if ai3_virus < AI_MAX_VIRUS: ai_cup_3.add_hidden_die()
		# Lv.2: 赌场主能看到自己的暗骰，Lv.3: 看到所有人的暗骰
		if casino_lv >= 2:
			var target_cup: RefCounted = null
			match _casino_ai:
				"ai1": target_cup = ai_cup_1
				"ai2": target_cup = ai_cup_2
				"ai3": target_cup = ai_cup_3
			if target_cup:
				if casino_lv >= 3:
					# 全看到 — 将所有暗骰标记为可见（在揭示前手动处理）
					_casino_see_all = true
					var ctrl = null
					match _casino_ai:
						"ai1": ctrl = ai_controller_1
						"ai2": ctrl = ai_controller_2
						"ai3": ctrl = ai_controller_3
					if ctrl:
						# 读取所有玩家的可见骰子值给赌场主
						var all_vals: Array = []
						for v in player_cup.get_values(): if v != -1: all_vals.append(v)
						for v in ai_cup_1.get_values(): if v != -1: all_vals.append(v)
						for v in ai_cup_2.get_values(): if v != -1: all_vals.append(v)
						for v in ai_cup_3.get_values(): if v != -1: all_vals.append(v)
						ctrl.player_full_values = all_vals
						EventBus.hint_show.emit("赌场主看穿了所有人的骰子!", 4.0, Color(0.52, 0.72, 0.92))
				else:
					# Lv.2: 只能看自己的暗骰
					for die in target_cup.dice:
						if die.is_hidden:
							die.is_hidden = false
					EventBus.hint_show.emit("赌场主看穿了自己的暗骰", 4.0, Color(0.52, 0.72, 0.92))
		EventBus.card_skill_triggered.emit("casino_owner", "暗骰", "全场")
	# === 同盟OLED: 随机选一个对手分享骰子 ===
	if _alliance_ai != "":
		var candidates: Array[String] = []
		if player_virus < PLAYER_MAX_VIRUS: candidates.append("player")
		if ai1_virus < AI_MAX_VIRUS and "ai1" != _alliance_ai: candidates.append("ai1")
		if ai2_virus < AI_MAX_VIRUS and "ai2" != _alliance_ai: candidates.append("ai2")
		if ai3_virus < AI_MAX_VIRUS and "ai3" != _alliance_ai: candidates.append("ai3")
		if candidates.size() > 0:
			_alliance_target = candidates[randi() % candidates.size()]
			var pvals: Array = player_cup.get_all_values()
			match _alliance_target:
				"ai1": ai_controller_1.player_full_values = pvals.duplicate()
				"ai2": if ai_controller_2: ai_controller_2.player_full_values = pvals.duplicate()
				"ai3": if ai_controller_3: ai_controller_3.player_full_values = pvals.duplicate()
			EventBus.hint_show.emit("同盟OLED全知: " + _alliance_target + " 知道了你的骰子!", 4.0, Color(0.75, 0.45, 0.85))
			EventBus.card_skill_triggered.emit("alliance_oled", "全知", _alliance_target)

	# === 庄家: 开局8颗骰子 ===
	if _dealer_ai != "":
		match _dealer_ai:
			"ai1": for _k in range(3): ai_cup_1.add_die()
			"ai2": for _k in range(3): ai_cup_2.add_die()
			"ai3": for _k in range(3): ai_cup_3.add_die()
		EventBus.hint_show.emit("庄家·开盘: 拥有8颗骰子!", 4.0, Color(0.52, 0.72, 0.92))

	# 信号噪音: disable consumable items (本局生效, 结束归还)
	if _noise_ai != "" and GameState.consumable_items.size() > 0:
		var noise_lv: int = GameState.get_card_level("signal_noise")
		var disabled_count: int = 1 + noise_lv
		_noise_removed_items.clear()
		for _i in range(disabled_count):
			if GameState.consumable_items.size() > 0:
				var removed: String = GameState.consumable_items.pop_back()
				_noise_removed_items.append(removed)
				EventBus.item_used.emit(removed)
		EventBus.card_skill_triggered.emit("signal_noise", "干扰", "player")
		EventBus.hint_show.emit("信号噪音干扰：你的 %d 个道具被禁用" % _noise_removed_items.size(), 4.0, Color(0.85, 0.6, 0.2))

	# 镜像·广播: 揭示全场最多的点数 (ON_GAME_START)
	_mirror_present = false
	if card1.card_id == "unknown_mirror" or (card2 and card2.card_id == "unknown_mirror") or (card3 and card3.card_id == "unknown_mirror"):
		_mirror_present = true
		EventBus.card_skill_triggered.emit("unknown_mirror", "广播", "全场")

	# Dark dice are set per-round in _start_round via boss_skill
	ai1_virus = 0; ai2_virus = 0; player_virus = 0  # 每局恢复全生命
	game_active = true; round_number = 0
	boss_mode_changed.emit(is_boss_mode)
	_start_round()

func _start_round() -> void:
	if not game_active: return
	round_number += 1
	_round_count += 1
	# 老杰克 偷窥: 跨局重置
	for ctrl: RefCounted in [ai_controller_1, ai_controller_2, ai_controller_3]:
		if ctrl:
			ctrl.player_full_values.clear()
			ctrl._peek_uses = 0
	player_cup.roll_all()
	if ai1_virus < AI_MAX_VIRUS: ai_cup_1.roll_all()
	if ai2_virus < AI_MAX_VIRUS: ai_cup_2.roll_all()
	if ai3_virus < AI_MAX_VIRUS: ai_cup_3.roll_all()
	current_bid_count = 0; current_bid_value = 1; last_bidder = ""
	# Stage 1: dark dice — 1 for normal, 2 for boss
	if GameState.current_stage == 1:
		var hc: int = 2 if is_boss_mode else 1
		player_cup.set_all_visible()
		for _i in range(hc): player_cup.set_hidden_die(randi() % player_cup.dice.size(), true)
		ai_cup_1.set_all_visible()
		for _i in range(hc): ai_cup_1.set_hidden_die(randi() % ai_cup_1.dice.size(), true)
		ai_cup_2.set_all_visible()
		for _i in range(hc): ai_cup_2.set_hidden_die(randi() % ai_cup_2.dice.size(), true)
		if ai3_virus < AI_MAX_VIRUS:
			ai_cup_3.set_all_visible()
			for _i in range(hc): ai_cup_3.set_hidden_die(randi() % ai_cup_3.dice.size(), true)
		boss_skill_effect.emit("dark", "每人 %d 颗暗骰" % hc)
	# Hardcore mode: +1 extra dark die per round for everyone
	if GameState.hardcore_mode:
		player_cup.set_hidden_die(randi() % player_cup.dice.size(), true)
		ai_cup_1.set_hidden_die(randi() % ai_cup_1.dice.size(), true)
		ai_cup_2.set_hidden_die(randi() % ai_cup_2.dice.size(), true)
		if ai3_virus < AI_MAX_VIRUS:
			ai_cup_3.set_hidden_die(randi() % ai_cup_3.dice.size(), true)
	# === 幸运儿: 每局投骰①概率更高 (Lv.1=2个①) ===
	if _lucky_one_ai != "":
		var lucky_lv: int = GameState.get_card_level("lucky_one")
		var lucky_count: int = 1 + lucky_lv
		var cup: RefCounted = null
		match _lucky_one_ai:
			"ai1": if ai1_virus < AI_MAX_VIRUS: cup = ai_cup_1
			"ai2": if ai2_virus < AI_MAX_VIRUS: cup = ai_cup_2
			"ai3": if ai3_virus < AI_MAX_VIRUS: cup = ai_cup_3
		if cup:
			var made: int = 0
			for die in cup.dice:
				if made >= lucky_count: break
				if not die.is_hidden and die.value != 1 and randf() < 0.35:
					die.value = 1; made += 1
	# === 算法先知: 每轮可重掷 (Lv.1=重掷后+1骰, Lv.2=可重掷2次) ===
	if _prophet_ai != "":
		var prop_lv: int = GameState.get_card_level("prophet")
		var reroll_count: int = 2 if prop_lv >= 2 else 1
		var cup: RefCounted = null
		match _prophet_ai:
			"ai1": if ai1_virus < AI_MAX_VIRUS: cup = ai_cup_1
			"ai2": if ai2_virus < AI_MAX_VIRUS: cup = ai_cup_2
			"ai3": if ai3_virus < AI_MAX_VIRUS: cup = ai_cup_3
		if cup:
			var candidates: Array = []
			for i in range(cup.dice.size()):
				if not cup.dice[i].is_hidden:
					candidates.append(i)
			candidates.shuffle()
			var rerolled: int = 0
			for idx in candidates:
				if rerolled >= reroll_count: break
				cup.dice[idx].value = randi() % 6 + 1
				rerolled += 1
			if rerolled > 0:
				EventBus.card_skill_triggered.emit("prophet", "重算", "%d颗" % rerolled)
			# Lv.1: gain +1 die after reroll
			if prop_lv >= 1:
				cup.add_die()
	# === 圣洁禁忌 (阶段3): 每局生成禁忌点数 ===
	if GameState.current_stage == 3:
		_holy_victim = ""
		_holy_forbidden.clear()
		var count: int = 3 if _dice_god_ai != "" else 1
		while _holy_forbidden.size() < count:
			var f: int = randi() % 6 + 1
			if f not in _holy_forbidden: _holy_forbidden.append(f)
		var msg: String = "圣洁禁忌: 有%d个未知禁忌点数, 叫到减2骰" % count
		if _dice_god_ai != "": msg += "+1病毒!"
		EventBus.hint_show.emit(msg, 4.0, Color(0.98, 0.35, 0.35))
	# 淘汰检测：失效的技能
	if _noise_ai == "ai1" and ai1_virus >= AI_MAX_VIRUS: _noise_ai = ""
	if _noise_ai == "ai2" and ai2_virus >= AI_MAX_VIRUS: _noise_ai = ""
	if _noise_ai == "ai3" and ai3_virus >= AI_MAX_VIRUS: _noise_ai = ""
	var tf_ai1: bool = ai1_virus < AI_MAX_VIRUS and card_has("ai1", "two_face")
	var tf_ai2: bool = ai2_virus < AI_MAX_VIRUS and card_has("ai2", "two_face")
	var tf_ai3: bool = ai3_virus < AI_MAX_VIRUS and card_has("ai3", "two_face")
	_twoface_present = tf_ai1 or tf_ai2 or tf_ai3
	ai_controller_1.set_six_wild(_twoface_present)
	if ai_controller_2: ai_controller_2.set_six_wild(_twoface_present)
	if ai_controller_3: ai_controller_3.set_six_wild(_twoface_present)
	# 独眼龙LCD: 每局锁定点数不可叫 (Lv.1=锁2个)
	_cyclops_lock = 0
	_cyclops_locks.clear()
	if _cyclops_ai != "":
		var cl_lv: int = GameState.get_card_level("cyclops_lcd")
		var alive: bool = false
		match _cyclops_ai:
			"ai1": alive = ai1_virus < AI_MAX_VIRUS
			"ai2": alive = ai2_virus < AI_MAX_VIRUS
			"ai3": alive = ai3_virus < AI_MAX_VIRUS
		if alive:
			var lock_count: int = 1 + cl_lv
			for _i in range(lock_count):
				var new_lock: int = randi() % 6 + 1
				var tries: int = 0
				while new_lock in _cyclops_locks and tries < 20:
					new_lock = randi() % 6 + 1; tries += 1
				if new_lock not in _cyclops_locks:
					_cyclops_locks.append(new_lock)
		if _cyclops_locks.size() > 0:
			_cyclops_lock = _cyclops_locks[0]
			EventBus.hint_show.emit("独眼龙·锁定: 本局不能叫 %s" % str(_cyclops_locks), 4.0, Color(0.52, 0.72, 0.92))
	if boss_skill == "forbidden":
		var prev: int = forbidden_number
		while forbidden_number == prev or forbidden_number == 0:
			forbidden_number = randi() % 6 + 1
		boss_skill_effect.emit("forbidden", "封禁点数: %d" % forbidden_number)
	elif forbidden_number > 0:
		forbidden_number = 0
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
			var wc: int = counts[i] + counts[1] if i > 1 else counts[i]  # ① as wild
			if wc > best_cnt: best_cnt = wc; best_val = i
		EventBus.hint_show.emit("镜像·广播: 全场最多点数 %d" % best_val, 5.0, Color(0.65, 0.5, 0.85))
	var pm: int = get_min_opening()
	if ai_controller_1: ai_controller_1.min_opening = pm
	if ai_controller_2: ai_controller_2.min_opening = pm
	if ai_controller_3: ai_controller_3.min_opening = pm
	# === 回收商 Lv.3: 每局结束+1骰 ===
	if _recycler_ai != "" and GameState.get_card_level("recycler") >= 3:
		match _recycler_ai:
			"ai1": if ai1_virus < AI_MAX_VIRUS: ai_cup_1.add_die()
			"ai2": if ai2_virus < AI_MAX_VIRUS: ai_cup_2.add_die()
			"ai3": if ai3_virus < AI_MAX_VIRUS: ai_cup_3.add_die()
	round_started.emit()
	var alive: Array[String] = ["player"]
	if ai1_virus < AI_MAX_VIRUS: alive.append("ai1")
	if ai2_virus < AI_MAX_VIRUS: alive.append("ai2")
	if ai3_virus < AI_MAX_VIRUS: alive.append("ai3")
	# 庄家: always start the round, opening count floor = total_dice / 2
	var starter: String = alive[randi() % alive.size()]
	if _dealer_ai != "":
		var dealer_alive := false
		match _dealer_ai:
			"ai1": dealer_alive = ai1_virus < AI_MAX_VIRUS
			"ai2": dealer_alive = ai2_virus < AI_MAX_VIRUS
			"ai3": dealer_alive = ai3_virus < AI_MAX_VIRUS
		if dealer_alive and _dealer_ai in alive:
			starter = _dealer_ai
	current_player = starter

	turn_changed.emit(current_player)
	if starter != "player":
		await get_tree().create_timer(_think_delay(starter, false, true)).timeout
		if game_active: _ai_turn(starter)

## Bid validation
func _is_valid_bid(count: int, value: int) -> bool:
	if value < 1 or value > 6 or count < 1: return false
	if count <= current_bid_count: return false
	if boss_skill == "forbidden" and value == forbidden_number: return false
	if _cyclops_lock > 0 and value in _cyclops_locks: return false
	if current_bid_count == 0: return count >= get_min_opening()
	return true

## Player actions
func player_bid(count: int, value: int) -> bool:
	if not game_active or current_player != "player": return false
	if not _is_valid_bid(count, value): return false
	current_bid_count = count; current_bid_value = value; last_bidder = "player"
	if GameState.current_stage == 3 and _holy_forbidden.has(value):
		_holy_victim = "player"
		EventBus.hint_show.emit("圣洁禁忌: 叫了未知禁忌点数, 本局结束减2骰!", 4.0, Color(0.98, 0.35, 0.35))
	bid_updated.emit(count, value, "你")
	_next_player()
	return true

func player_challenge() -> bool:
	if not game_active or current_player != "player": return false
	if current_bid_count == 0: return false
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
	# 老杰克 偷窥: 偷玩家的可见骰子（Lv.1=2颗, Lv.2=2次, Lv.3=3颗+公开）
	if ctrl.card.card_id == "jack_crt" and ctrl._peek_uses == 0 and ctrl.player_full_values.is_empty():
		var jack_lv: int = GameState.get_card_level("jack_crt")
		ctrl._peek_uses = 2 if jack_lv >= 2 else 1
		var visible_vals: Array = []
		for v in player_cup.get_values():
			if v != -1:
				visible_vals.append(v)
		ctrl.player_full_values = visible_vals
	var jack_lv: int = GameState.get_card_level("jack_crt")
	var peek_count: int = 1 + jack_lv
	if peek_count > 3: peek_count = 3
	if ctrl.card.card_id == "jack_crt" and ctrl._peek_uses > 0:
		var peeked: Array = ctrl.peek_player_dice(peek_count)
		if peeked.size() > 0:
			var msg: String = "老杰克偷窥了你的 %d 颗骰子" % peeked.size()
			if jack_lv >= 3:
				msg += ": " + str(peeked)
			EventBus.card_skill_triggered.emit("jack_crt", "偷窥(%d颗)" % peeked.size(), "player")
			EventBus.hint_show.emit(msg, 3.0, Color(0.36, 0.5, 0.84))
	ctrl.current_bid_count = current_bid_count
	ctrl.current_bid_value = current_bid_value
	ctrl.total_other_dice = 0
	if ai_id != "ai1" and ai1_virus < AI_MAX_VIRUS: ctrl.total_other_dice += ai_cup_1.dice.size()
	if ai_id != "ai2" and ai2_virus < AI_MAX_VIRUS: ctrl.total_other_dice += ai_cup_2.dice.size()
	if ai_id != "ai3" and ai3_virus < AI_MAX_VIRUS: ctrl.total_other_dice += ai_cup_3.dice.size()
	if ai_id != "player": ctrl.total_other_dice += player_cup.dice.size()
	if GameState.current_stage == 2:
		_collude_enrage_check()
	# === 裁判长: 第N轮强制开 (Lv.0=3轮, Lv.1=2轮, Lv.3=第1轮结束) + Lv.2=公布危险点 ===
	var ref_lv: int = GameState.get_card_level("referee")
	var ref_round: int = 3
	if ref_lv >= 3: ref_round = 2  # 第1轮结束 = 第二轮开场强制
	elif ref_lv >= 1: ref_round = 2
	if _referee_ai != "" and _round_count >= ref_round and current_bid_count > 0:
		var ref_alive: bool = false
		match _referee_ai:
			"ai1": ref_alive = ai1_virus < AI_MAX_VIRUS
			"ai2": ref_alive = ai2_virus < AI_MAX_VIRUS
			"ai3": ref_alive = ai3_virus < AI_MAX_VIRUS
		if ref_alive:
			if ref_lv >= 2:
				# 公布危险点数
				var danger: int = randi() % 6 + 1
				EventBus.hint_show.emit("裁判长公布危险点数: %d!" % danger, 4.0, Color(0.98, 0.35, 0.35))
			EventBus.card_skill_triggered.emit("referee", "强制执行", "第%d轮" % ref_round)
			_resolve_challenge(ai_id, last_bidder); return
	var action: String = ctrl.decide_action()
	if action == "challenge":
		_resolve_challenge(ai_id, last_bidder); return
	elif action == "bid":
		var bid: Dictionary = ctrl.make_bid()
		current_bid_count = bid["count"]; current_bid_value = bid["value"]; last_bidder = ai_id
		var nm := get_ai_name()
		if GameState.current_stage == 3 and _holy_forbidden.has(bid["value"]): _holy_victim = ai_id
		if ai_id == _chaos_ai:  # (chaos or unknown_chaos)
			_chaos_real_bid = {"count": current_bid_count, "value": current_bid_value}
			var fake_count: int = clampi(current_bid_count + randi() % 3 - 1, 1, 15)
			var fake_value: int = clampi(randi() % 6 + 1, 1, 6)
			_chaos_fake_bid = {"count": fake_count, "value": fake_value}
			bid_updated.emit(fake_count, fake_value, nm + " [?]")
		else:
			bid_updated.emit(current_bid_count, current_bid_value, nm)
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
	if ai1_virus < AI_MAX_VIRUS: total_match += ai_cup_1.count_matches_revealing(target_value, six_wild)
	if ai2_virus < AI_MAX_VIRUS: total_match += ai_cup_2.count_matches_revealing(target_value, six_wild)
	if ai3_virus < AI_MAX_VIRUS: total_match += ai_cup_3.count_matches_revealing(target_value, six_wild)
	# 幸运儿 Lv.3: 他的①不能当万能
	if _lucky_one_ai != "" and target_value != 1 and GameState.get_card_level("lucky_one") >= 3:
		var lucky_cup: RefCounted = null
		match _lucky_one_ai:
			"ai1": lucky_cup = ai_cup_1
			"ai2": lucky_cup = ai_cup_2
			"ai3": lucky_cup = ai_cup_3
		if lucky_cup:
			for die in lucky_cup.dice:
				if die.value == 1:
					total_match -= 1  # 他的①不算万能
	var bid_true: bool = total_match >= current_bid_count
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
		else:
			player_virus += 1
			EventBus.half_assimilated.emit()
			GameState.total_assimilations += 1
	elif loser == "ai1":
		if _ai_shields.get("ai1", false):
			_ai_shields["ai1"] = false; EventBus.card_skill_triggered.emit("table_ghost", "免疫", "ai1")
		elif ai_controller_1.infect():
			ai1_virus += 1 + (1 if (GameState.current_stage >= 2 or GameState.hardcore_mode) else 0)
			_apply_rust_warrior_skill("ai1", winner)
		elif ai_controller_1._bk_saved:
			ai_controller_1._bk_saved = false; ai_cup_1.add_die()
			EventBus.hint_show.emit("电池小子备用电源: +1骰!", 3.0, Color(0.52, 0.72, 0.92))
	elif loser == "ai2":
		if _ai_shields.get("ai2", false):
			_ai_shields["ai2"] = false; EventBus.card_skill_triggered.emit("table_ghost", "免疫", "ai2")
		elif ai_controller_2 and ai_controller_2.infect():
			ai2_virus += 1 + (1 if (GameState.current_stage >= 2 or GameState.hardcore_mode) else 0)
			_apply_rust_warrior_skill("ai2", winner)
		elif ai_controller_2 and ai_controller_2._bk_saved:
			ai_controller_2._bk_saved = false; ai_cup_2.add_die()
			EventBus.hint_show.emit("电池小子备用电源: +1骰!", 3.0, Color(0.52, 0.72, 0.92))
	elif loser == "ai3":
		if _ai_shields.get("ai3", false):
			_ai_shields["ai3"] = false; EventBus.card_skill_triggered.emit("table_ghost", "免疫", "ai3")
		elif ai_controller_3 and ai_controller_3.infect():
			ai3_virus += 1 + (1 if (GameState.current_stage >= 2 or GameState.hardcore_mode) else 0)
			_apply_rust_warrior_skill("ai3", winner)
		elif ai_controller_3 and ai_controller_3._bk_saved:
			ai_controller_3._bk_saved = false; ai_cup_3.add_die()
			EventBus.hint_show.emit("电池小子备用电源: +1骰!", 3.0, Color(0.52, 0.72, 0.92))
	var player_dead: bool = player_virus >= PLAYER_MAX_VIRUS
	var ai1_dead: bool = ai1_virus >= AI_MAX_VIRUS
	var ai2_dead: bool = ai2_virus >= AI_MAX_VIRUS
	var ai3_dead: bool = ai3_virus >= AI_MAX_VIRUS
	# === 回收商: 有人质疑失败时回收商+骰 (Lv.1=+2骰, Lv.2=吸对手1骰) ===
	if _recycler_ai != "" and not bid_true:
		var rec_lv: int = GameState.get_card_level("recycler")
		var dice_bonus: int = 2 if rec_lv >= 1 else 1
		match _recycler_ai:
			"ai1": if ai1_virus < AI_MAX_VIRUS: for _j in range(dice_bonus): ai_cup_1.add_die()
			"ai2": if ai2_virus < AI_MAX_VIRUS: for _j in range(dice_bonus): ai_cup_2.add_die()
			"ai3": if ai3_virus < AI_MAX_VIRUS: for _j in range(dice_bonus): ai_cup_3.add_die()
		# Lv.2+: steal 1 die from loser
		if rec_lv >= 2:
			var lose_cup: RefCounted = null
			match loser:
				"player": lose_cup = player_cup
				"ai1": lose_cup = ai_cup_1
				"ai2": lose_cup = ai_cup_2
				"ai3": lose_cup = ai_cup_3
			if lose_cup and lose_cup.dice.size() > 1:
				lose_cup.dice.pop_back(); lose_cup.dice_count -= 1
				EventBus.hint_show.emit("回收商吸走了输家的1颗骰子!", 3.0, Color(0.52, 0.72, 0.92))
		EventBus.card_skill_triggered.emit("recycler", "捡骰", _recycler_ai)
	# === 深渊: 受伤者被吞噬1骰 ===
	if _abyss_ai != "" and loser != _abyss_ai:
		var victim_cup: RefCounted = null
		var vname: String = ""
		match loser:
			"player": if player_cup.dice.size() > 1: victim_cup = player_cup; vname = "你"
			"ai1": if ai_cup_1.dice.size() > 1: victim_cup = ai_cup_1; vname = get_ai_name_for_id("ai1")
			"ai2": if ai_cup_2.dice.size() > 1: victim_cup = ai_cup_2; vname = get_ai_name_for_id("ai2")
			"ai3": if ai_cup_3.dice.size() > 1: victim_cup = ai_cup_3; vname = get_ai_name_for_id("ai3")
		if victim_cup:
			victim_cup.dice.pop_back(); victim_cup.dice_count -= 1
			match _abyss_ai:
				"ai1": ai_cup_1.add_die()
				"ai2": ai_cup_2.add_die()
				"ai3": ai_cup_3.add_die()
			EventBus.card_skill_triggered.emit("abyss", "吞噬", loser)
			EventBus.hint_show.emit("深渊吞噬了 " + vname + " 的1颗骰子!", 3.0, Color(0.55, 0.35, 0.65))
	# === 圣洁禁忌惩罚: 叫了禁忌的点数减2骰 (+1病毒 if dice_god) ===
	if _holy_victim != "":
		match _holy_victim:
			"player": for _i in range(2): if player_cup.dice.size() > 1: player_cup.dice.pop_back(); player_cup.dice_count -= 1
			"ai1": for _i in range(2): if ai_cup_1.dice.size() > 1: ai_cup_1.dice.pop_back(); ai_cup_1.dice_count -= 1
			"ai2": for _i in range(2): if ai_cup_2.dice.size() > 1: ai_cup_2.dice.pop_back(); ai_cup_2.dice_count -= 1
			"ai3": for _i in range(2): if ai_cup_3.dice.size() > 1: ai_cup_3.dice.pop_back(); ai_cup_3.dice_count -= 1
		var msg: String = "圣洁禁忌: " + _holy_victim + " 叫到禁忌点数, 受-2骰惩罚!"
		if _dice_god_ai != "":
			msg += " +1病毒!"
			match _holy_victim:
				"player": if player_virus < PLAYER_MAX_VIRUS: player_virus += 1; EventBus.half_assimilated.emit()
				"ai1": if ai1_virus < AI_MAX_VIRUS: ai1_virus += 1
				"ai2": if ai2_virus < AI_MAX_VIRUS: ai2_virus += 1
				"ai3": if ai3_virus < AI_MAX_VIRUS: ai3_virus += 1
		EventBus.hint_show.emit(msg, 4.0, Color(0.98, 0.35, 0.35))
		EventBus.card_skill_triggered.emit("holy", "惩罚", _holy_victim)
		_holy_victim = ""
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
	# === 黑吃黑 (阶段2): 揭示后幸存者各+2骰 ===
	if GameState.current_stage == 2:
		_gang_feed(loser)
	# === 赌桌幽灵: 淘汰时附身 (Lv.1=附身2人) ===
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
			if g_target == "player" and not player_shield:
				player_shield = true; gifted += 1
			elif g_target != "player" and not _ai_shields.get(g_target, false):
				_ai_shields[g_target] = true; gifted += 1
		if gifted > 0:
			EventBus.card_skill_triggered.emit("table_ghost", "附身免疫(%d人)" % gifted, "")
			EventBus.hint_show.emit("赌桌幽灵附身 %d 人, 可挡一次伤害!" % gifted, 3.0, Color(0.75, 0.45, 0.85))
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
	return alive_count + 1

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

func set_player_die_value(idx: int, val: int) -> void:
	if player_virus >= PLAYER_MAX_VIRUS: return
	if idx >= 0 and idx < player_cup.dice.size():
		player_cup.dice[idx].value = clamp(val, 1, 6)

func skip_player_turn() -> void:
	if not game_active: return
	# Player skips their bid; advance to next AI directly
	if current_player == "player":
		_next_player()

func sabotage_enemy_dice() -> void:
	# Pick a random alive AI and set 2 of their dice to 1
	var alive_ais: Array = []
	if ai1_virus < AI_MAX_VIRUS: alive_ais.append("ai1")
	if ai2_virus < AI_MAX_VIRUS: alive_ais.append("ai2")
	if alive_ais.is_empty(): return
	var pick: String = alive_ais[randi() % alive_ais.size()]
	var cup = ai_cup_1 if pick == "ai1" else ai_cup_2
	if cup.dice.size() < 2: return
	var i1: int = randi() % cup.dice.size()
	var i2: int = (i1 + 1 + randi() % max(1, cup.dice.size() - 1)) % cup.dice.size()
	cup.dice[i1].value = 1
	cup.dice[i2].value = 1

func peek_ai_die(ai_id: String, idx: int) -> int:
	var cup = null
	if ai_id == "ai1": cup = ai_cup_1
	elif ai_id == "ai2": cup = ai_cup_2
	elif ai_id == "ai3": cup = ai_cup_3
	if cup == null: return -1
	if idx >= 0 and idx < cup.dice.size():
		var d = cup.dice[idx]
		if d.is_hidden: return -1
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

func get_chamberlain_items() -> Array[String]:
	return _chamberlain_items.duplicate()

func get_chamberlain_ai() -> String:
	return chamberlain_ai_id

func get_chaos_reveal_text() -> String:
	if _chaos_ai == "" or _chaos_real_bid.is_empty() or _chaos_fake_bid.is_empty():
		return ""
	var ai_name: String = ""
	match _chaos_ai:
		"ai1": ai_name = ai_controller_1.get_name_str() if ai_controller_1 else "对手1"
		"ai2": ai_name = ai_controller_2.get_name_str() if ai_controller_2 else "对手2"
		"ai3": ai_name = ai_controller_3.get_name_str() if ai_controller_3 else "对手3"
	return "混沌 %s: 显示 %d个%s, 实际 %d个%s" % [
		ai_name,
		_chaos_fake_bid.get("count", 0), _num_to_die(_chaos_fake_bid.get("value", 1)),
		_chaos_real_bid.get("count", 0), _num_to_die(_chaos_real_bid.get("value", 1))
	]

func _num_to_die(v: int) -> String:
	var dice_emoji: Array[String] = ["", "①", "②", "③", "④", "⑤", "⑥"]
	return dice_emoji[v] if v >= 1 and v <= 6 else str(v)

func _rehide_casino_dice() -> void:
	if _casino_ai == "" or _casino_hidden <= 0: return
	# 每个存活者的杯中隐藏 _casino_hidden 颗骰子
	var cups: Array = [player_cup]
	if ai1_virus < AI_MAX_VIRUS: cups.append(ai_cup_1)
	if ai2_virus < AI_MAX_VIRUS: cups.append(ai_cup_2)
	if ai3_virus < AI_MAX_VIRUS: cups.append(ai_cup_3)
	for cup in cups:
		for _i in range(_casino_hidden):
			if cup.dice.size() > 0:
				var idx: int = randi() % cup.dice.size()
				cup.dice[idx].is_hidden = true

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

func use_chamberlain_item() -> void:
	if _chamberlain_items.is_empty() or chamberlain_ai_id == "": return
	var item_id: String = _chamberlain_items.pop_front()
	var info: ItemData = GameState.get_item_info(item_id)
	var item_name: String = info.item_name if info else item_id
	EventBus.card_skill_triggered.emit("chamberlain", "使用道具", "%s" % item_name)
	EventBus.hint_show.emit("侍从长使用: %s" % item_name, 3.0, Color(0.52, 0.72, 0.92))
	match item_id:
		"purge_chip":
			match chamberlain_ai_id:
				"ai1": ai1_virus = 0
				"ai2": ai2_virus = 0
				"ai3": ai3_virus = 0
		"full_reroll":
			match chamberlain_ai_id:
				"ai1": ai_cup_1.roll_all()
				"ai2": ai_cup_2.roll_all()
				"ai3": ai_cup_3.roll_all()
		"extra_die":
			match chamberlain_ai_id:
				"ai1": ai_cup_1.add_die()
				"ai2": ai_cup_2.add_die()
				"ai3": ai_cup_3.add_die()
		_: pass

# === 镜面技师: 复制玩家道具 ===
func get_ai_name_for_id(ai_id: String) -> String:
	match ai_id:
		"ai1": return ai_controller_1.get_name_str() if ai_controller_1 else "对手1"
		"ai2": return ai_controller_2.get_name_str() if ai_controller_2 else "对手2"
		"ai3": return ai_controller_3.get_name_str() if ai_controller_3 else "对手3"
	return ai_id

func mirror_item(item_id: String) -> void:
	if _mirror_tech_ai == "": return
	var alive: bool = false
	match _mirror_tech_ai:
		"ai1": if ai1_virus < AI_MAX_VIRUS: alive = true
		"ai2": if ai2_virus < AI_MAX_VIRUS: alive = true
		"ai3": if ai3_virus < AI_MAX_VIRUS: alive = true
	if not alive: return
	match item_id:
		"full_reroll":
			match _mirror_tech_ai:
				"ai1": ai_cup_1.roll_all()
				"ai2": ai_cup_2.roll_all()
				"ai3": ai_cup_3.roll_all()
		"extra_die", "copy_die":
			match _mirror_tech_ai:
				"ai1": queue_dice("ai1", 2)
				"ai2": queue_dice("ai2", 2)
				"ai3": queue_dice("ai3", 2)
		"purge_chip":
			match _mirror_tech_ai:
				"ai1": ai1_virus = 0; _ai_shields["ai1"] = true
				"ai2": ai2_virus = 0; _ai_shields["ai2"] = true
				"ai3": ai3_virus = 0; _ai_shields["ai3"] = true
		_:
			return  # 涉及他人/需选目标的道具不复制
	EventBus.card_skill_triggered.emit("mirror_tech", "镜像道具", item_id)
	EventBus.hint_show.emit("镜面技师复制了你的道具!", 3.0, Color(0.75, 0.45, 0.85))
	# 写入提示历史
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
