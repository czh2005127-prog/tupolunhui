## AI decision engine for liar's dice — card-based opponent.
## No longer depends on AiPersonality. Behavior derived from card rarity.
class_name AiController
extends RefCounted

var card: Resource         # CardData instance
var ai_name: String = ""   # Display name from card
var cup: RefCounted        # DiceCup instance
var virus_count: int = 0
var _ai_id: String = ""    # "ai1", "ai2", "ai3"
var _game: Node = null
var _six_wild: bool = false  # 双面人: ①和⑥都是万能骰

func set_ai_id(id: String) -> void:
	_ai_id = id

func set_dice_game(game: Node) -> void:
	_game = game

func set_six_wild(val: bool) -> void:
	_six_wild = val

var suspicion_of_player: float = 0.0
var current_bid_count: int = 0
var current_bid_value: int = 1
var total_other_dice: int = 5
var player_full_values: Array = []
var min_opening: int = 3
var _just_bluffed: bool = false
var is_eliminated: bool = false
var _dealer_opening_count: int = 0  # Set by DiceGame if this AI is 庄家
var _peeked_player_value: int = 0  # 老杰克 偷窥 peeked value (0 = not used yet)
var _peek_uses: int = 0  # remaining peeks this game (Lv.2+ = 2 uses)
var _bk_saved: bool = false  # 电池小子 Lv.3 triggered

# Card-derived behavior params
var bluff_frequency: float = 0.35
var challenge_certainty: float = 0.4

func _init(card_data: Resource, dice_cup: RefCounted) -> void:
	card = card_data
	ai_name = card_data.card_name
	cup = dice_cup
	var r: int = card_data.rarity
	bluff_frequency = 0.3 + r * 0.05 + randf() * 0.1
	challenge_certainty = 0.3 + r * 0.05 + randf() * 0.1

func decide_action() -> String:
	if current_bid_count == 0:
		_try_use_item()
		return "bid"
	if _evaluate_challenge():
		return "challenge"
	return "bid"

func _try_use_item() -> void:
	if not _game or not _game.has_method("use_chamberlain_item"): return
	if _game.get_chamberlain_ai() == _ai_id and _game.get_chamberlain_items().size() > 0:
		_game.use_chamberlain_item()

func make_bid() -> Dictionary:
	var my_values: Array = cup.get_values()
	if current_bid_count == 0:
		return _make_opening_bid(my_values)
	var should_bluff: bool = randf() < bluff_frequency
	if should_bluff:
		return _make_bluff_bid(my_values)
	return _make_honest_bid(my_values)

func _make_opening_bid(my_values: Array) -> Dictionary:
	var best_val: int = 1; var best_cnt: int = 0
	for v: int in range(1, 7):
		var c: int = _count_value(v, my_values)
		if c > best_cnt: best_cnt = c; best_val = v
	if best_val == 1 and best_cnt >= 1:
		return {"count": max(min_opening, best_cnt + 1), "value": 1}
	# 庄家: opening count floor = total_dice / 2
	var min_c: int = maxi(min_opening, _dealer_opening_count)
	_dealer_opening_count = 0
	return {"count": maxi(min_c, best_cnt + 1), "value": best_val}

func _make_bluff_bid(my_values: Array) -> Dictionary:
	_just_bluffed = true
	var target_value: int = randi() % 6 + 1
	var bluff_count: int = current_bid_count + 1 + randi() % 3
	return {"count": max(current_bid_count + 1, bluff_count), "value": target_value}

func _make_honest_bid(my_values: Array) -> Dictionary:
	_just_bluffed = false
	var best_val: int = 1; var best_cnt: int = 0
	for v: int in range(1, 7):
		var c: int = _count_for_target(v, my_values)
		if c > best_cnt: best_cnt = c; best_val = v
	var pool_max: int = cup.dice.size() + total_other_dice + 2
	return {"count": clamp(current_bid_count + 1, 1, pool_max), "value": best_val}

func _evaluate_challenge() -> bool:
	if current_bid_count == 0: return false
	var my_count: int = _count_for_target(current_bid_value, cup.get_values())
	var extra: int = 0
	if player_full_values.size() > 0:
		extra = _count_for_target(current_bid_value, player_full_values)
	# 老杰克 偷窥: use the peeked value as additional info
	if card.card_id == "jack_crt" and _peeked_player_value > 0:
		extra = maxi(extra, _count_for_target(current_bid_value, [_peeked_player_value]))
	var possible_total: int = my_count + max(extra, int(total_other_dice * 0.4))
	if current_bid_count > possible_total: return true
	var threshold: float = challenge_certainty + suspicion_of_player * 0.3
	if my_count == 0 and current_bid_count > 3: return randf() < threshold * 1.5
	var gap: int = current_bid_count - my_count - (total_other_dice / 3)
	if gap > 0: return randf() < threshold * gap * 0.2
	return randf() < threshold * 0.03

func _count_for_target(target: int, values: Array) -> int:
	var c: int = 0
	for v: int in values:
		if v == target or v == 1: c += 1
		elif v == 6 and _six_wild: c += 1
	return c

func _count_value(target: int, values: Array) -> int:
	var c: int = 0
	for v: int in values:
		if v == target: c += 1
	return c

func infect() -> bool:
	# 已淘汰: 无操作
	if is_eliminated:
		return false
	# 电池小子：前N次被击败免死 (Lv.3=每次+1骰)
	var bk_lv: int = GameState.get_card_level("battery_kid")
	var free_infections: int = 1 + bk_lv
	if card.card_id == "battery_kid" and virus_count < free_infections:
		virus_count += 1
		if bk_lv >= 3:
			_bk_saved = true  # Signal DiceGame to add a die
		return false  # 免疫本次感染
	virus_count += 1
	if virus_count >= (1 if GameState.current_stage < 3 else 2):
		is_eliminated = true
	return true

## 老杰克 偷窥: peek player dice once per battle (Lv.1=2 dice, Lv.2=2 uses, Lv.3=3 dice+公开)
func peek_player_dice(count: int) -> Array[int]:
	if _peek_uses <= 0 or card.card_id != "jack_crt":
		return []
	if player_full_values.is_empty():
		player_full_values = []
	_peek_uses -= 1
	var result: Array[int] = []
	for _i in range(min(count, player_full_values.size())):
		var idx: int = randi() % player_full_values.size()
		var v: int = player_full_values[idx]
		player_full_values.remove_at(idx)
		result.append(v)
	if result.size() > 0:
		_peeked_player_value = result[0]
	return result

func is_alive() -> bool:
	return not is_eliminated

func get_name_str() -> String:
	return ai_name
