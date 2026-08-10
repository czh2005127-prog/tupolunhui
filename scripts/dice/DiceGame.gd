class_name DiceGame
extends Node

signal state_changed(state: Dictionary)
signal message_posted(text: String, color: Color)
signal battle_finished(victory: bool, rounds_used: int)

const DiceCupRef := preload("res://scripts/dice/DiceCup.gd")
const ScoreEngineRef := preload("res://scripts/dice/ScoreEngine.gd")
const PlayerCardRef := preload("res://scripts/resources/PlayerCardData.gd")
const CardDataRef := preload("res://scripts/resources/CardData.gd")

const TARGETS := [
	[180, 260, 340, 500],
	[420, 600, 780, 1100],
	[850, 1200, 1550, 2400],
	[1700, 2500, 3300, 3200],
]

var cup: DiceCup
var stage: int = 0
var battle_index: int = 0
var is_boss: bool = false
var boss_phase: int = 1
var opponents: Array = []
var enemy_states: Array[Dictionary] = []
var round_number: int = 0
var max_rounds: int = 5
var target_score: int = 180
var total_score: int = 0
var hand: Array[Dictionary] = []
var draw_pile: Array[String] = []
var discard_pile: Array[String] = []
var exhausted_pile: Array[String] = []
var retained_indices: Array[int] = []
var round_bonuses: Dictionary = {}
var battle_flags: Dictionary = {}
var cards_used_this_round: Array[String] = []
var removed_dice: Array[Dictionary] = []
var battle_over: bool = false
var is_dice_god_battle: bool = false
var _rng := RandomNumberGenerator.new()
var _phase_two_snapshot:Dictionary={}

func configure(stage_index: int, cards: Array, boss: bool, normal_index: int = 0) -> void:
	stage = clampi(stage_index, 0, 3)
	battle_index = clampi(normal_index, 0, 2)
	is_boss = boss
	opponents = cards.duplicate()
	is_dice_god_battle = is_boss and not opponents.is_empty() and opponents.back() != null and opponents.back().card_id == "dice_god"
	var seed_value: int = GameState.current_battle_seed
	if seed_value <= 0:
		seed_value = randi_range(1, 2147483646)
		GameState.current_battle_seed = seed_value
	_rng.seed = seed_value
	var base_dice := 5
	if "twin_throw" in GameState.active_forbidden_rules: base_dice += 1
	if "dealer" in GameState.boss_fragments: base_dice += 1
	base_dice += int(GameState.next_battle_modifiers.get("bonus_dice", 0))
	base_dice -= int(GameState.next_battle_modifiers.get("base_dice_penalty", 0))
	cup = DiceCupRef.new(maxi(1, base_dice), seed_value)
	target_score = TARGETS[stage][3 if is_boss else battle_index]
	if is_dice_god_battle: target_score = 3200
	if is_boss and not opponents.is_empty() and opponents.back().card_id == "card_king": target_score = 10000; max_rounds = 6
	if "king_contract" in battle_flags: target_score = ceili(target_score * 1.25)
	_setup_deck()
	_setup_enemies()
	_start_round()

func _setup_deck() -> void:
	draw_pile.assign(GameState.player_deck)
	if draw_pile.is_empty(): draw_pile.assign(PlayerCardRef.get_starter_deck_ids())
	_shuffle(draw_pile)
	var guaranteed:=str(GameState.next_battle_modifiers.get("guaranteed_card",""))
	if not guaranteed.is_empty() and guaranteed in draw_pile:
		draw_pile.erase(guaranteed);draw_pile.append(guaranteed)
	discard_pile.clear(); exhausted_pile.clear(); hand.clear()

func _setup_enemies() -> void:
	enemy_states.clear()
	for card in opponents:
		if card == null: continue
		var skills: Array = card.skills.duplicate(true)
		if is_boss and card == opponents.back() and card.card_id != "dice_god":
			skills.push_front(_random_boss_skill())
		var state := {"card":card, "skills":skills, "skill_index":0, "timer":0, "current":{}, "active":false}
		enemy_states.append(state)
		_load_enemy_intent(enemy_states.size() - 1)

func _random_boss_skill() -> Dictionary:
	var pool := [
		{"name":"王座封印","kind":"continuous","countdown":4,"effect":"block_high_cards","desc":"高稀有度目标手牌不能使用。"},
		{"name":"铁幕","kind":"continuous","countdown":4,"effect":"protect_high","desc":"目标骰不能被卡牌修改。"},
		{"name":"归零指令","kind":"trigger","countdown":4,"effect":"high_to_one","desc":"目标骰变为①。"},
		{"name":"逆位裁定","kind":"trigger","countdown":3,"effect":"flip_high","desc":"翻转目标骰。"},
		{"name":"强制洗牌","kind":"trigger","countdown":4,"effect":"shuffle_high_hand","desc":"目标手牌送回牌库并抽等量。"},
		{"name":"废牌扣押","kind":"continuous","countdown":5,"effect":"seal_discard","desc":"封存弃牌堆目标牌。"},
		{"name":"复制禁令","kind":"continuous","countdown":4,"effect":"block_copy","desc":"禁止复制类牌。"},
		{"name":"同类管制","kind":"continuous","countdown":4,"effect":"block_category","desc":"封锁当前最多的卡牌类别。"},
	]
	return pool[_rng.randi_range(0, pool.size() - 1)].duplicate(true)

func _load_enemy_intent(index: int) -> void:
	if index < 0 or index >= enemy_states.size(): return
	var state: Dictionary = enemy_states[index]
	var skills: Array = state.skills
	if skills.is_empty(): return
	var skill: Dictionary = skills[int(state.skill_index) % skills.size()].duplicate(true)
	var card_level:int=GameState.get_card_level(state.card.card_id)
	if card_level>=2:
		match str(skill.get("effect","")):
			"modify_limit","card_dice_limit":skill.value=1
			"lower_high","draw_penalty":skill.value=2
			"block_repeat_name":skill.value=2
	if state.card.card_id=="referee":skill.countdown=maxi(3,int(skill.get("countdown",5))-(card_level-1))
	var timer: int = int(skill.get("countdown", 3))
	if is_boss and stage == 3 and boss_phase == 2: timer = maxi(2, timer - 1)
	timer += int(GameState.next_battle_modifiers.get("enemy_timer_bonus", 0))
	if "closed_prophecy" in GameState.active_forbidden_rules: timer += 2
	state.current = skill
	state.timer = maxi(1, timer)
	state.active = str(skill.get("kind", "trigger")) == "continuous"
	enemy_states[index] = state
	if bool(state.active):_activate_continuous(index)
	_refresh_continuous_dice_state()

func _activate_continuous(index:int)->void:
	var state:Dictionary=enemy_states[index];var effect:=str(state.current.get("effect",""))
	if effect in ["remove_high_die","remove_low_die"]:
		removed_dice.append_array(cup.remove_indices(_select_dice("low" if effect=="remove_low_die" else "high",_target_count(state.card))))
	elif effect=="remove_high_card":_enemy_remove_hand(_target_count(state.card,hand.size()),"remove")
	elif effect=="remove_draw_cards":
		var count:=_target_count(state.card,draw_pile.size())
		for _i in range(mini(count,draw_pile.size())):exhausted_pile.append(draw_pile.pop_back())

func _refresh_continuous_dice_state()->void:
	if cup==null:return
	for die in cup.dice:die.hidden=bool(die.get("fragment_hidden",false))
	for state in enemy_states:
		if not bool(state.active):continue
		var effect:=str(state.current.get("effect",""))
		if effect in ["hide_dice","hide_lock_dice"]:
			for index in _select_dice("high",_target_count(state.card)):cup.dice[index].hidden=true

func _start_round() -> void:
	if battle_over: return
	round_number += 1
	if round_number > max_rounds:
		_lose_battle(); return
	_cleanup_round()
	_refill_hand()
	cup.roll_new_round()
	_apply_base_roll_fragments()
	_tick_enemies("新计分轮")
	if "rush_clock" in GameState.active_forbidden_rules: _tick_enemies("急行时钟")
	message_posted.emit("第%d轮：投骰完成。使用卡牌会推进敌方倒计时。" % round_number, Color(0.78,0.82,0.88))
	_emit_state()

func _cleanup_round() -> void:
	round_bonuses = {"chips":0, "mult":0, "final_mult":1, "face_chips":{6:2} if "forbidden_face" in GameState.active_forbidden_rules else {}}
	cards_used_this_round.clear()
	retained_indices.clear()
	for i in range(hand.size()-1,-1,-1):
		if bool(hand[i].get("temporary",false)):hand.remove_at(i)

func _refill_hand() -> void:
	var desired := 5 if "broken_cycle" in GameState.active_forbidden_rules else 6
	if "narrow_hand" in GameState.active_forbidden_rules: desired = 7
	desired += int(GameState.next_battle_modifiers.get("initial_hand_delta", 0)) if round_number == 1 else 0
	desired = mini(desired, get_hand_limit())
	_draw_cards(maxi(0,desired-hand.size()),true)
	if round_number==1 and bool(GameState.next_battle_modifiers.get("bottom_initial_card",false)) and not hand.is_empty():
		var moved:Dictionary=hand.pop_back();draw_pile.push_front(str(moved.id))
	if round_number==1 and bool(GameState.next_battle_modifiers.get("block_initial_card",false)) and not hand.is_empty():hand[0].blocked=true

func get_hand_limit() -> int:
	var limit := 8 if "narrow_hand" in GameState.active_forbidden_rules else 10
	limit=mini(limit,int(GameState.next_battle_modifiers.get("hand_limit",limit)))
	for state in enemy_states:
		if bool(state.active) and str(state.current.get("effect", "")) == "occupy_hand":
			limit -= _target_count(state.card, 10)
	return maxi(1, limit)

func _draw_cards(count: int, allow_reshuffle: bool = false) -> void:
	var remaining := count
	while remaining > 0 and hand.size() < get_hand_limit():
		if draw_pile.is_empty():
			if discard_pile.is_empty() or not allow_reshuffle: break
			draw_pile.assign(discard_pile); discard_pile.clear(); _shuffle(draw_pile)
		var id: String = draw_pile.pop_back()
		hand.append({"id":id, "temporary":false, "protected":false})
		remaining -= 1

func request_use_card(hand_index: int, target_die: int = -1, secondary_die: int = -1) -> Dictionary:
	if battle_over or hand_index < 0 or hand_index >= hand.size(): return {"ok":false, "error":"无效手牌"}
	var entry: Dictionary = hand[hand_index]
	if bool(entry.get("blocked",false)):return {"ok":false,"error":"这张牌被封锁至本轮计分"}
	var card: PlayerCardData = PlayerCardRef.get_by_id(str(entry.id))
	if card == null: return {"ok":false, "error":"卡牌数据缺失"}
	var block_reason := _card_block_reason(card)
	if not block_reason.is_empty(): return {"ok":false, "error":block_reason}
	if _needs_die_target(card.effect) and target_die < 0:
		return {"ok":false, "needs_target":true, "error":"请选择一颗骰子"}
	if target_die >= 0 and target_die < cup.dice.size() and bool(cup.dice[target_die].get("player_blocked",false)):
		return {"ok":false,"error":"双生投掷锁定了这颗骰子，本轮不能由玩家修改"}
	if "forbidden_face" in GameState.active_forbidden_rules and target_die>=0 and target_die<cup.dice.size() and card.effect=="adjust" and int(cup.dice[target_die].value)==5:
		return {"ok":false,"error":"禁忌骰面：不能直接把骰子调整成⑥"}
	var die_reason:=_die_target_block_reason(card,target_die)
	if not die_reason.is_empty():return {"ok":false,"error":die_reason}
	if not _apply_card(card, target_die, secondary_die):
		return {"ok":false, "error":"当前没有合法目标或条件未满足"}
	var used_position:=cards_used_this_round.size()+1
	if card.rarity==PlayerCardData.Rarity.LEGENDARY:battle_flags.used_legendary=true
	if "overload_circuit" in GameState.active_forbidden_rules and used_position==3 and card.rarity< PlayerCardData.Rarity.LEGENDARY and card.category!="金币" and card.effect not in ["copy","repeat_last"]:
		_apply_card(card,target_die,secondary_die)
	if target_die>=0 and _restriction_active("duplicate_single"):
		var extra:=_different_die(target_die)
		if extra>=0:_apply_card(card,extra,secondary_die)
	if target_die>=0 and _restriction_active("flip_after_change"):cup.flip_at(target_die)
	if target_die>=0 and _restriction_active("reroll_after_change"):cup.reroll_die(target_die)
	if target_die>=0 and "mirror_tech" in GameState.boss_fragments and not bool(battle_flags.get("mirror_fragment_used",false)) and card.effect not in ["clone","split","add_die","copy","repeat_last"]:
		var mirror_target:=_different_die(target_die)
		if mirror_target>=0:_apply_card(card,mirror_target,secondary_die);battle_flags.mirror_fragment_used=true
	cards_used_this_round.append(card.card_id)
	var unique_names:Dictionary={}
	for used_id in cards_used_this_round:unique_names[used_id]=true
	battle_flags.max_unique_names=maxi(int(battle_flags.get("max_unique_names",0)),unique_names.size())
	var removed: Dictionary = hand.pop_at(hand_index)
	if not bool(removed.get("temporary", false)):
		if _used_cards_go_bottom(): draw_pile.push_front(card.card_id)
		else: discard_pile.append(card.card_id)
	var skip_tick:bool="rush_clock" in GameState.active_forbidden_rules and cards_used_this_round.size()==1
	if not skip_tick:_tick_enemies("使用【%s】" % card.card_name)
	if "overload_circuit" in GameState.active_forbidden_rules and used_position==3:_tick_enemies("过载回路")
	message_posted.emit("使用【%s】：%s" % [card.card_name, card.description], card.get_rarity_color())
	_emit_state()
	return {"ok":true}

func _needs_die_target(effect: String) -> bool:
	return effect in ["reroll","flip","lock","adjust","clone","split","protect_die","fate_lock","mirror"]

func is_die_target_legal(hand_index: int, target_die: int) -> bool:
	if battle_over or hand_index < 0 or hand_index >= hand.size() or target_die < 0 or cup == null or target_die >= cup.dice.size():
		return false
	var entry: Dictionary = hand[hand_index]
	if bool(entry.get("blocked", false)):
		return false
	var card: PlayerCardData = PlayerCardRef.get_by_id(str(entry.get("id", "")))
	if card == null or not _needs_die_target(card.effect) or not _card_block_reason(card).is_empty():
		return false
	if bool(cup.dice[target_die].get("player_blocked", false)):
		return false
	if "forbidden_face" in GameState.active_forbidden_rules and card.effect == "adjust" and int(cup.dice[target_die].value) == 5:
		return false
	if not _die_target_block_reason(card, target_die).is_empty():
		return false
	if card.effect == "reroll" and bool(cup.dice[target_die].get("locked", false)):
		return false
	if card.effect == "split" and int(cup.dice[target_die].get("value", 0)) < 4:
		return false
	return true

func _card_block_reason(card: PlayerCardData) -> String:
	for state in enemy_states:
		if not bool(state.active): continue
		var effect := str(state.current.get("effect", ""))
		if effect == "block_persistent" and card.effect in ["fate_lock","battle_gold_engine","winner_take_all"]: return "敌方【装备检查】封锁持续型卡牌"
		if effect == "block_copy" and card.effect in ["copy","repeat_last","mirror"]: return "敌方禁止复制类卡牌"
		if effect == "block_high_cards" and card.rarity >= PlayerCardData.Rarity.RARE: return "高稀有度手牌被封印"
		if effect == "block_category" and card.category == _most_common_hand_category(): return "该卡牌类别被封锁"
		if effect=="block_repeat_name" and card.card_id in cards_used_this_round:return "军械记录封锁了同名卡牌"
		if effect=="limit_card_names" and cards_used_this_round.count(card.card_id)>=int(state.current.get("value",2)):return "重复违规：同名牌已达使用上限"
	return ""

func _die_target_block_reason(card:PlayerCardData,target:int)->String:
	if target<0 or target>=cup.dice.size():return ""
	for state in enemy_states:
		if not bool(state.active):continue
		var effect:=str(state.current.get("effect",""));var targets:=_select_dice("high",_target_count(state.card))
		if target not in targets:continue
		if effect in ["protect_high","protect_optimal","hide_lock_dice"]:return "这颗骰子受敌方保护，不能成为卡牌目标"
		if effect=="no_reroll" and card.effect in ["reroll","reroll_all"]:return "这颗骰子不能重投"
		if effect=="no_direct_change" and card.effect in ["adjust","make_pair","make_straight","mirror"]:return "这颗骰子不能直接改变点数"
		if effect=="no_lock" and card.effect in ["lock","fate_lock"]:return "这颗骰子不能被锁定"
		if effect=="modify_limit" and int(cup.dice[target].modified)>=int(state.current.get("value",2)):return "这颗骰子的修改次数已达上限"
		if effect=="lock_face" and int(cup.dice[target].value)==6:return "独眼龙锁定了⑥点骰"
	return ""

func _apply_card(card: PlayerCardData, target: int, secondary: int) -> bool:
	match card.effect:
		"reroll": return cup.reroll_die(target, _restriction_active("reroll_take_low"))
		"reroll_all": cup.roll_all()
		"flip": return cup.flip_at(target)
		"lock", "fate_lock": return cup.lock_die(target, card.amount)
		"adjust": return cup.adjust_at(target, 1 if int(cup.dice[target].value) < 6 else -1)
		"adjust_ratio":
			for index in _select_dice("low", maxi(1, cup.dice.size() / 3)): cup.adjust_at(index, 1)
		"clone": return cup.clone_at(target)
		"split": return cup.split_at(target)
		"add_die": cup.add_die()
		"add_die_discard":
			for _i in range(card.amount): cup.add_die()
			_discard_other_random(1)
		"make_pair":
			var other := secondary if secondary >= 0 else _different_die(target)
			if other < 0: return false
			cup.set_value(target, int(cup.dice[other].value))
		"make_straight": return _make_straight(target)
		"chips": round_bonuses.chips = int(round_bonuses.chips) + card.amount
		"mult": round_bonuses.mult = int(round_bonuses.mult) + card.amount
		"pair_bonus": round_bonuses.pair_bonus = int(round_bonuses.get("pair_bonus",0)) + card.amount
		"straight3_bonus": round_bonuses.straight3_bonus = int(round_bonuses.get("straight3_bonus",0)) + card.amount
		"variety_bonus": round_bonuses.variety_required = card.secondary; round_bonuses.variety_bonus = card.amount
		"type_bonus", "triple_bonus": round_bonuses[card.effect] = int(round_bonuses.get(card.effect,0)) + card.amount
		"third_mult":
			if cards_used_this_round.size() == 2: round_bonuses.mult = int(round_bonuses.mult) + card.amount
		"final_mult": round_bonuses.final_mult = int(round_bonuses.final_mult) * card.amount
		"face_group_chips":
			var faces := [4,5,6] if card.secondary == 1 else [2,4,6]
			for face in faces: round_bonuses.face_chips[face] = int(round_bonuses.face_chips.get(face,0)) + card.amount
		"face_chips":
			var face := _choose_best_face(); round_bonuses.face_chips[face] = int(round_bonuses.face_chips.get(face,0)) + card.amount
		"draw": _draw_cards(card.amount)
		"draw_to_max": _draw_cards(get_hand_limit() - hand.size())
		"discard_draw":
			var n := mini(card.amount, maxi(0, hand.size()-1)); _discard_other_random(n); _draw_cards(card.secondary if card.secondary > 0 else n)
		"search_draw": _draw_cards(1)
		"recover":
			if discard_pile.is_empty(): return false
			hand.append({"id":discard_pile.pop_back(),"temporary":false,"protected":false})
		"copy":
			var copy_id := _first_copyable_hand_id(card.card_id)
			if copy_id.is_empty(): return false
			hand.append({"id":copy_id,"temporary":true,"protected":false})
		"repeat_last":
			if cards_used_this_round.is_empty(): return false
			var previous := PlayerCardRef.get_by_id(cards_used_this_round.back())
			if previous == null or previous.effect in ["copy","repeat_last"]: return false
			return _apply_card(previous, target, secondary)
		"discard_chips":
			var n := maxi(0, hand.size()-1); _discard_other_random(n); round_bonuses.chips = int(round_bonuses.chips) + n * card.amount
		"protect_die": return cup.protect(target)
		"protect_card":
			if hand.is_empty(): return false
			hand[0].protected = true
		"counter": battle_flags.counter = int(battle_flags.get("counter",0)) + 1
		"gold": battle_flags.pending_gold = int(battle_flags.get("pending_gold",0)) + card.amount
		"face_gold": battle_flags.face_gold = {"face":_choose_best_face(),"amount":card.amount,"cap":card.secondary}
		"sole_gold": battle_flags.sole_gold = card.amount
		"coin_flip":
			if _rng.randf() < 0.5: round_bonuses.chips = int(round_bonuses.chips) + card.amount
			else: _discard_other_random(1)
		"pattern_gold": battle_flags.pattern_gold = {"reward":card.amount,"penalty":card.secondary}
		"exhaust_gold":
			var n := mini(card.secondary, maxi(0,hand.size()-1)); _exhaust_other(n); GameState.add_gold(n*card.amount)
		"investment":
			if not GameState.spend_gold(card.secondary): return false
			battle_flags.investment = card.amount
		"mirror":
			var other := secondary if secondary >= 0 else _different_die(target)
			if other < 0: return false
			cup.set_value(other, int(cup.dice[target].value))
		"forbidden_roulette":
			for i in range(cup.dice.size()):
				if not bool(cup.dice[i].locked): cup.set_value(i,1)
			round_bonuses.final_mult = int(round_bonuses.final_mult) * card.amount
		"battle_gold_engine": battle_flags.gold_engine = true
		"king_contract": GameState.add_gold(card.amount); target_score = ceili(target_score*(1.0+card.secondary/100.0))
		"winner_take_all": battle_flags.winner_take_all = true
		"alchemy": battle_flags.alchemy = {"face":_choose_best_face(),"amount":card.amount,"cap":card.secondary}
		_: return false
	return true

func confirm_score() -> Dictionary:
	if battle_over: return {}
	var result: Dictionary = ScoreEngineRef.score(cup.get_all_values(), _score_bonuses())
	total_score += int(result.score)
	battle_flags.twos_scored=int(battle_flags.get("twos_scored",0))+cup.get_all_values().count(2)
	battle_flags.max_pattern_types=maxi(int(battle_flags.get("max_pattern_types",0)),_pattern_type_count(result.patterns))
	_resolve_round_gold(result)
	message_posted.emit("本轮 %d × %d%s = %d，累计 %d / %d" % [result.base, result.multiplier, " × %d" % result.final_factor if int(result.final_factor)>1 else "", result.score, total_score, target_score], Color(0.98,0.78,0.29))
	if total_score >= target_score:
		if is_dice_god_battle and boss_phase == 1:
			_start_god_phase_two()
		else:
			_win_battle()
	else:
		_end_hand_and_continue()
	_emit_state()
	return result

func _end_hand_and_continue() -> void:
	var kept:Array[Dictionary]=[]
	for i in range(hand.size()):
		var entry:Dictionary=hand[i]
		if i in retained_indices:kept.append(entry)
		elif not bool(entry.get("temporary",false)):discard_pile.append(str(entry.id))
	hand.assign(kept)
	_start_round()

func toggle_retain(index: int) -> void:
	if index in retained_indices:retained_indices.erase(index)
	else:
		var limit:=2 if "broken_cycle" in GameState.active_forbidden_rules else 1
		if retained_indices.size()>=limit:retained_indices.pop_front()
		retained_indices.append(index)
	_emit_state()

func _tick_enemies(reason: String) -> void:
	var order: Array[int] = []
	for i in range(enemy_states.size()): order.append(i)
	order.sort_custom(func(a:int,b:int):
		var ac: CardData = enemy_states[a].card; var bc: CardData = enemy_states[b].card
		if ac.card_id == "dealer": return true
		if bc.card_id == "dealer": return false
		return a < b)
	for index in order:
		var state: Dictionary = enemy_states[index]
		state.timer = int(state.timer) - 1
		enemy_states[index] = state
		if int(state.timer) <= 0:
			if str(state.current.get("kind","trigger")) == "trigger":
				if int(battle_flags.get("counter",0)) > 0:
					battle_flags.counter = int(battle_flags.counter)-1
					message_posted.emit("反制协议取消了【%s】" % state.current.get("name","技能"), Color(0.45,0.85,0.75))
				else: _execute_enemy_effect(index, state.current)
			else:
				message_posted.emit("【%s】的持续效果结束" % state.current.get("name","技能"), Color(0.62,0.65,0.7))
				_expire_continuous(state.current)
			state.active = false
			state.skill_index = int(state.skill_index)+1
			enemy_states[index] = state
			_load_enemy_intent(index)
	_refresh_continuous_dice_state()
	if reason != "新计分轮": message_posted.emit("敌方行动推进：%s" % reason, Color(0.68,0.5,0.5))

func _expire_continuous(skill:Dictionary)->void:
	var effect:=str(skill.get("effect",""))
	if effect in ["remove_high_die","remove_low_die"] and not removed_dice.is_empty():
		for die in removed_dice:cup.dice.append(die)
		removed_dice.clear();cup.dice_count=cup.dice.size()

func _execute_enemy_effect(index: int, skill: Dictionary) -> void:
	var effect := str(skill.get("effect","")); var count := _target_count(enemy_states[index].card)
	var indices: Array[int] = _select_dice("high", count)
	match effect:
		"flip_high": for i in indices: if not cup.consume_protection(i): cup.flip_at(i)
		"lower_high": for i in indices: if not cup.consume_protection(i): cup.adjust_at(i, -int(skill.get("value",1)))
		"reroll_high", "hidden_reroll": for i in indices: if not cup.consume_protection(i): cup.reroll_die(i, boss_phase == 2 and stage == 3)
		"lock_high": for i in indices: if not cup.consume_protection(i): cup.lock_die(i,1)
		"high_to_one": for i in indices: if not cup.consume_protection(i): cup.set_value(i,1)
		"copy_low_to_high":
			var low := _select_dice("low",1)
			if not low.is_empty(): for i in indices: cup.set_value(i,int(cup.dice[low[0]].value))
		"flip_all": for i in range(cup.dice.size()): cup.flip_at(i)
		"swap_high_low": _swap_extremes(count)
		"randomize_dice": for i in indices: cup.set_value(i,_rng.randi_range(1,6))
		"remove_low_die", "remove_high_die": removed_dice.append_array(cup.remove_indices(_select_dice("low" if effect=="remove_low_die" else "high",count)))
		"discard_high_card": _enemy_remove_hand(_target_count(enemy_states[index].card,hand.size()), "discard")
		"bottom_high_card", "shuffle_high_hand": _enemy_remove_hand(_target_count(enemy_states[index].card,hand.size()), "bottom")
		"seal_hand": for entry in hand: entry.blocked = true
	message_posted.emit("%s发动【%s】" % [enemy_states[index].card.card_name, skill.get("name","技能")], enemy_states[index].card.get_rarity_color())

func _target_count(card: CardData, eligible_count:int=-1) -> int:
	var level: int = GameState.get_card_level(card.card_id)
	var denominator := 3
	match card.rarity:
		CardData.Rarity.COMMON, CardData.Rarity.RARE: denominator = 3 if level <= 1 else 2
		CardData.Rarity.EPIC, CardData.Rarity.LEGENDARY: denominator = [4,3,2][clampi(level-1,0,2)]
		CardData.Rarity.GENESIS: denominator = [5,4,3,2][clampi(level-1,0,3)]
		CardData.Rarity.UNKNOWN: denominator = [5,4,3,2][stage]
	var eligible:=cup.dice.size() if eligible_count<0 else eligible_count
	return eligible / denominator

func _restriction_active(effect: String) -> bool:
	for state in enemy_states:
		if bool(state.active) and str(state.current.get("effect","")) == effect: return true
	return false

func _used_cards_go_bottom() -> bool: return _restriction_active("used_to_bottom") or _restriction_active("rust_used_cards")

func _start_god_phase_two() -> void:
	boss_phase = 2; total_score = 0; target_score = 4800; round_number = 0
	for i in range(enemy_states.size()):
		if enemy_states[i].card.card_id == "dice_god": enemy_states[i].skill_index = _rng.randi_range(0,3)
	_setup_enemies(); cup.roll_all(); message_posted.emit("骰子之神撕开第二条命：禁忌全面升级。", Color(1,0.3,0.35)); _start_round();_capture_phase_two_snapshot()

func _win_battle() -> void:
	_resolve_contract(true)
	battle_over = true; GameState.battle_rounds_used = round_number
	battle_finished.emit(true, round_number)
	_emit_state()

func _lose_battle() -> void:
	if is_dice_god_battle and boss_phase==2 and GameState.royal_fragment_available and not _phase_two_snapshot.is_empty():
		GameState.royal_fragment_available=false;_restore_phase_two_snapshot();message_posted.emit("流亡王印碎裂：骰子之神第二阶段被重置。",Color(0.95,0.72,0.3));return
	if "table_ghost" in GameState.boss_fragments:
		GameState.consume_boss_fragment("table_ghost")
		GameState.restore_battle_entry_preserving_costs();message_posted.emit("幽灵碎片抵挡同化，战斗重新开始。", Color(0.72,0.45,0.9)); restart_battle(); return
	GameState.assimilate()
	if GameState.assimilation_count < GameState.MAX_ASSIMILATION:
		GameState.restore_battle_entry_preserving_costs();message_posted.emit("半同化：回到进入战斗前的状态。", Color(0.9,0.3,0.4)); restart_battle()
	else:
		battle_over = true; battle_finished.emit(false, round_number); _emit_state()

func _capture_phase_two_snapshot()->void:
	_phase_two_snapshot={"dice":cup.dice.duplicate(true),"draw":draw_pile.duplicate(),"discard":discard_pile.duplicate(),"exhausted":exhausted_pile.duplicate(),"hand":hand.duplicate(true),"enemies":enemy_states.duplicate(true),"flags":battle_flags.duplicate(true),"round":round_number,"gold":GameState.gold}

func _restore_phase_two_snapshot()->void:
	var data:=_phase_two_snapshot.duplicate(true);cup=DiceCupRef.new(maxi(1,(data.dice as Array).size()),GameState.current_battle_seed);cup.dice.assign(data.dice);cup.dice_count=cup.dice.size();draw_pile.assign(data.draw);discard_pile.assign(data.discard);exhausted_pile.assign(data.exhausted);hand.assign(data.hand);enemy_states.assign(data.enemies);battle_flags=(data.flags as Dictionary).duplicate(true);round_number=int(data.round);GameState.gold=int(data.gold);total_score=0;battle_over=false;_emit_state()

func restart_battle() -> void:
	var cards := opponents.duplicate(); configure(stage, cards, is_boss, battle_index)

func get_view_state() -> Dictionary:
	var preview := ScoreEngineRef.score(cup.get_all_values(), _score_bonuses()) if cup != null else {}
	var enemy_views: Array[Dictionary] = []
	for state in enemy_states:
		var skills: Array = state.skills
		var next: Dictionary = {} if "closed_prophecy" in GameState.active_forbidden_rules else (skills[(int(state.skill_index)+1)%skills.size()] if not skills.is_empty() else {})
		var next_two:Dictionary={}
		if "alliance_oled" in GameState.boss_fragments and not skills.is_empty():next_two=skills[(int(state.skill_index)+2)%skills.size()]
		var denominator := _target_denominator(state.card)
		var eligible_count := _intent_eligible_count(str(state.current.get("effect", "")))
		enemy_views.append({"card_id":state.card.card_id,"name":state.card.card_name,"rarity":state.card.get_rarity_name(),"color":state.card.get_rarity_color(),"current":state.current,"timer":state.timer,"next":next,"next_two":next_two,"ratio_count":_target_count(state.card,eligible_count),"ratio":"1/%d"%denominator,"skills":skills.duplicate(true),"skill_index":state.skill_index,"active":bool(state.active)})
	return {"round":round_number,"max_rounds":max_rounds,"total":total_score,"target":target_score,"phase":boss_phase,"dice":cup.dice.duplicate(true) if cup else [],"hand":hand.duplicate(true),"draw_count":draw_pile.size(),"discard_count":discard_pile.size(),"exhaust_count":exhausted_pile.size(),"retained":retained_indices.duplicate(),"preview":preview,"enemies":enemy_views,"effects":_build_effect_views(),"over":battle_over,"hand_limit":get_hand_limit(),"gold":GameState.gold}

func _build_effect_views() -> Array[Dictionary]:
	var views: Array[Dictionary] = []
	for state in enemy_states:
		if not bool(state.get("active", false)):
			continue
		var skill: Dictionary = state.get("current", {})
		views.append({
			"category": _effect_icon_category(str(skill.get("effect", ""))),
			"name": str(skill.get("name", "持续影响")),
			"description": str(skill.get("desc", "")),
			"remaining": int(state.get("timer", 0)),
			"source": str(state.card.card_name),
		})
	if int(round_bonuses.get("chips", 0)) != 0 or int(round_bonuses.get("mult", 0)) != 0 or int(round_bonuses.get("final_mult", 1)) != 1:
		views.append({"category":8,"name":"本轮强化","description":"卡牌给予的基础点数或倍率强化。","remaining":1,"source":"玩家卡牌"})
	if battle_flags.has("fate_locks") or battle_flags.has("gold_engine") or battle_flags.has("winner_take_all"):
		views.append({"category":8,"name":"本场持续效果","description":"本场对局内持续生效的卡牌能力。","remaining":-1,"source":"玩家卡牌"})
	if not GameState.boss_fragments.is_empty():
		views.append({"category":10,"name":"Boss碎片","description":"当前携带的碎片正在提供局内能力。","remaining":-1,"source":"碎片"})
	return views

func _effect_icon_category(effect: String) -> int:
	if "rust" in effect or "remove" in effect:
		return 1
	if "lock" in effect or "seal" in effect or "block" in effect:
		return 2
	if "forbidden" in effect:
		return 3
	if "hide" in effect or "cover" in effect:
		return 4
	if "cost" in effect:
		return 7
	if "contract" in effect:
		return 9
	if "protect" in effect:
		return 10
	return 6

func _target_denominator(card: CardData) -> int:
	var level: int = GameState.get_card_level(card.card_id)
	match card.rarity:
		CardData.Rarity.COMMON, CardData.Rarity.RARE: return 3 if level <= 1 else 2
		CardData.Rarity.EPIC, CardData.Rarity.LEGENDARY: return [4,3,2][clampi(level-1,0,2)]
		CardData.Rarity.GENESIS: return [5,4,3,2][clampi(level-1,0,3)]
		CardData.Rarity.UNKNOWN: return [5,4,3,2][stage]
	return 3

func _intent_eligible_count(effect: String) -> int:
	if effect == "occupy_hand":
		return 10
	if effect in ["block_category","discard_high_card","block_repeat_name","block_persistent","limit_card_names","seal_hand","haunt_hand","bottom_high_card","shuffle_high_hand","cover_hand","remove_high_card","pair_hand","rotate_card_effects","used_to_bottom","rust_used_cards"]:
		return hand.size()
	if effect in ["seal_discard","seal_voluntary_discard"]:
		return discard_pile.size()
	if effect == "remove_draw_cards":
		return draw_pile.size()
	return cup.dice.size() if cup != null else 0

func _emit_state() -> void: state_changed.emit(get_view_state())
func _shuffle(array: Array) -> void:
	for i in range(array.size()-1,0,-1):
		var j:=_rng.randi_range(0,i); var t=array[i]; array[i]=array[j]; array[j]=t
func _select_dice(mode: String, count: int) -> Array[int]:
	var indices: Array[int]=[]; for i in range(cup.dice.size()): indices.append(i)
	indices.sort_custom(func(a:int,b:int): return int(cup.dice[a].value)>int(cup.dice[b].value) if mode=="high" else int(cup.dice[a].value)<int(cup.dice[b].value))
	return indices.slice(0,mini(count,indices.size()))
func _different_die(index:int)->int:
	for i in range(cup.dice.size()): if i!=index:return i
	return -1
func _make_straight(index:int)->bool:
	if index<0 or index>=cup.dice.size():return false
	var values:=cup.get_all_values(); for start in range(1,5):
		var needed:=[start,start+1,start+2]; var misses:=[]
		for v in needed: if v not in values: misses.append(v)
		if misses.size()==1:return cup.set_value(index,misses[0])
	return false
func _choose_best_face()->int:
	var counts:={}; for v in cup.get_all_values():counts[v]=int(counts.get(v,0))+1
	var best:=1; for v in counts: if int(counts[v])>int(counts.get(best,0)):best=int(v)
	return best
func _discard_other_random(count:int)->void:
	var discarded:=0
	for _i in range(mini(count,hand.size())): var e:Dictionary=hand.pop_back(); if not bool(e.get("temporary",false)):discard_pile.append(str(e.id));discarded+=1
	battle_flags.voluntary_discards=int(battle_flags.get("voluntary_discards",0))+discarded
	if discarded>0 and "recycler" in GameState.boss_fragments and not bool(battle_flags.get("recycler_fragment_used",false)):
		battle_flags.recycler_fragment_used=true;_draw_cards(1)
func _exhaust_other(count:int)->void:
	for _i in range(mini(count,hand.size())): var e:Dictionary=hand.pop_back(); exhausted_pile.append(str(e.id))
func _first_copyable_hand_id(exclude:String)->String:
	for e in hand:
		var c:=PlayerCardRef.get_by_id(str(e.id)); if c and c.card_id!=exclude and c.effect not in ["copy","repeat_last"]:return c.card_id
	return ""
func _most_common_hand_category()->String:
	var counts:={}; for e in hand: var c:=PlayerCardRef.get_by_id(str(e.id)); if c:counts[c.category]=int(counts.get(c.category,0))+1
	var best:=""; for k in counts: if best.is_empty() or int(counts[k])>int(counts.get(best,0)):best=str(k)
	return best
func _enemy_remove_hand(count:int,destination:String)->void:
	for _i in range(mini(count,hand.size())):
		var e:Dictionary=hand.pop_back()
		if bool(e.get("protected",false)): hand.push_front(e)
		elif destination=="bottom": draw_pile.push_front(str(e.id))
		else: discard_pile.append(str(e.id))
func _swap_extremes(count:int)->void:
	var highs:=_select_dice("high",count);var lows:=_select_dice("low",count)
	for i in range(mini(highs.size(),lows.size())):var t=int(cup.dice[highs[i]].value);cup.set_value(highs[i],int(cup.dice[lows[i]].value));cup.set_value(lows[i],t)
func _apply_base_roll_fragments()->void:
	for die in cup.dice:die.player_blocked=false;die.fragment_hidden=false
	if "twin_throw" in GameState.active_forbidden_rules and not cup.dice.is_empty():cup.dice[_rng.randi_range(0,cup.dice.size()-1)].player_blocked=true
	if "lucky_one" in GameState.boss_fragments:
		var ids:Array[int]=[];for i in range(cup.dice.size()):ids.append(i);ids.shuffle()
		for i in range(mini(2,ids.size())):
			if _rng.randf()<1.0/3.0:cup.set_value(ids[i],1);cup.dice[ids[i]].wild=true
	if "casino_owner" in GameState.boss_fragments:
		var candidates:Array[int]=[]
		for i in range(cup.dice.size()):if not bool(cup.dice[i].locked):candidates.append(i)
		if not candidates.is_empty():
			var index:=candidates[_rng.randi_range(0,candidates.size()-1)];var second:=_rng.randi_range(1,6);cup.dice[index].value=maxi(int(cup.dice[index].value),second);cup.dice[index].hidden=true;cup.dice[index].fragment_hidden=true
func _resolve_round_gold(result:Dictionary)->void:
	var gain:=int(battle_flags.get("pending_gold",0));battle_flags.pending_gold=0
	if int(battle_flags.get("sole_gold",0))>0 and cards_used_this_round.size()==1:gain+=int(battle_flags.sole_gold)
	if battle_flags.has("face_gold"):var d:Dictionary=battle_flags.face_gold;gain+=mini(int(d.cap),cup.get_all_values().count(int(d.face))*int(d.amount))
	if bool(battle_flags.get("gold_engine",false)) and not result.patterns.is_empty():gain+=3
	if int(battle_flags.get("investment",0))>0 and int(result.score)>=ceili(target_score*0.3):gain+=int(battle_flags.investment);battle_flags.erase("investment")
	if gain>0:GameState.add_gold(gain)

func _score_bonuses()->Dictionary:
	var result:=round_bonuses.duplicate(true);var wilds:Array[int]=[]
	if cup!=null:
		for i in range(cup.dice.size()):if bool(cup.dice[i].get("wild",false)):wilds.append(i)
	result.wild_indices=wilds
	return result

func _pattern_type_count(patterns:Array)->int:
	var types:Dictionary={}
	for pattern in patterns:types[str(pattern.type)]=true
	return types.size()

func _resolve_contract(victory:bool)->void:
	if GameState.current_contract.is_empty():return
	var id:=str(GameState.current_contract.get("id",""));var success:=victory
	match id:
		"five_twos":success=success and int(battle_flags.get("twos_scored",0))>=5
		"two_patterns":success=success and int(battle_flags.get("max_pattern_types",0))>=2
		"four_discards":success=success and int(battle_flags.get("voluntary_discards",0))>=4
		"no_legendary":success=success and not bool(battle_flags.get("used_legendary",false))
		"three_rounds":success=success and round_number<=3
		"four_names":success=success and int(battle_flags.get("max_unique_names",0))>=4
	if success:
		match id:
			"five_twos":GameState.add_gold(14)
			"two_patterns":_grant_random_card(PlayerCardData.Rarity.RARE)
			"four_discards":GameState.after_battle_modifiers.free_shop_refresh=true
			"no_legendary":GameState.add_gold(20)
			"three_rounds":for _i in range(6):_grant_random_card(PlayerCardData.Rarity.COMMON)
			"four_names":GameState.after_battle_modifiers.bonus_dice=1
	else:
		GameState.prisoner_breaches+=1
		match id:
			"five_twos":GameState.after_battle_modifiers.initial_hand_delta=-1
			"two_patterns":GameState.after_battle_modifiers.bottom_initial_card=true
			"four_discards":GameState.after_battle_modifiers.shop_price_bonus=15
			"no_legendary":GameState.after_battle_modifiers.block_initial_card=true
			"three_rounds":GameState.after_battle_modifiers.enemy_timer_bonus=-1
			"four_names":GameState.after_battle_modifiers.base_dice_penalty=1
	GameState.current_contract.clear()

func _grant_random_card(rarity:int)->void:
	var pool:=PlayerCardData.get_pool(rarity)
	if not pool.is_empty():GameState.add_player_card(pool[_rng.randi_range(0,pool.size()-1)].card_id)

func use_fragment(fragment_id:String,target_enemy:int=-1)->Dictionary:
	if fragment_id not in GameState.boss_fragments:return {"ok":false,"error":"未持有该碎片"}
	match fragment_id:
		"referee":
			if bool(battle_flags.get("referee_fragment_used",false)):return {"ok":false,"error":"裁判碎片本场已使用"}
			if target_enemy<0 or target_enemy>=enemy_states.size():return {"ok":false,"error":"请选择敌人"}
			enemy_states[target_enemy].timer=int(enemy_states[target_enemy].timer)+2;battle_flags.referee_fragment_used=true
		"prophet":
			if bool(battle_flags.get("prophet_fragment_used",false)):return {"ok":false,"error":"先知碎片本场已使用"}
			cup.roll_all();battle_flags.prophet_fragment_used=true
		_:return {"ok":false,"error":"该碎片自动生效"}
	_emit_state();return {"ok":true}
