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
var own_hidden_visible: bool = false

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
var _peeked_player_value: int = 0  # 老杰克 偷窥 peeked value (0 = not used yet)
var _peek_uses: int = 0  # remaining peeks this game (Lv.2+ = 2 uses)
var _peek_initialized: bool = false
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
	if _game.get_chamberlain_items(_ai_id).size() > 0:
		_game.use_chamberlain_item(_ai_id)

func make_bid() -> Dictionary:
	var my_values: Array = cup.get_all_values() if own_hidden_visible else cup.get_values()
	if current_bid_count == 0:
		return _make_opening_bid(my_values)
	return _make_evidence_bid(my_values)

func _make_opening_bid(my_values: Array) -> Dictionary:
	var best_val: int = 2
	var best_probability: float = -1.0
	for v: int in range(1, 7):
		if not _bid_is_legal(min_opening, v): continue
		var probability: float = estimate_bid_truth_probability(min_opening, v, my_values)
		if probability > best_probability:
			best_probability = probability; best_val = v
	_just_bluffed = best_probability < 0.45
	return {"count": min_opening, "value": best_val}

func _make_evidence_bid(my_values: Array) -> Dictionary:
	var candidates: Array[Dictionary] = []
	# Prefer the smallest legal raise. A larger jump is considered only when the
	# visible evidence makes that quantity safer than an ordinary one-step raise.
	for value in range(current_bid_value + 1, 7):
		if _bid_is_legal(current_bid_count, value):
			candidates.append({"count": current_bid_count, "value": value})
	for value in range(1, 7):
		if _bid_is_legal(current_bid_count + 1, value):
			candidates.append({"count": current_bid_count + 1, "value": value})
	for value in range(1, 7):
		var support: float = _expected_total_for(value, my_values)
		var supported_count: int = mini(current_bid_count + 3, floori(support))
		if supported_count > current_bid_count + 1 and _bid_is_legal(supported_count, value):
			if estimate_bid_truth_probability(supported_count, value, my_values) >= 0.72:
				candidates.append({"count": supported_count, "value": value})
	if candidates.is_empty():
		return {"count": current_bid_count + 1, "value": 2}
	var best: Dictionary = candidates[0]
	var best_score: float = -100.0
	for candidate in candidates:
		var probability: float = estimate_bid_truth_probability(candidate.count, candidate.value, my_values)
		var jump_penalty: float = maxf(0.0, float(candidate.count - current_bid_count - 1)) * 0.12
		var score: float = probability - jump_penalty + randf_range(-0.025, 0.025)
		if score > best_score:
			best_score = score; best = candidate
	_just_bluffed = estimate_bid_truth_probability(best.count, best.value, my_values) < 0.42
	return best

func _evaluate_challenge() -> bool:
	if current_bid_count == 0: return false
	var own_values: Array = cup.get_all_values() if own_hidden_visible else cup.get_values()
	var truth_probability: float = estimate_bid_truth_probability(current_bid_count, current_bid_value, own_values)
	var rarity: int = int(card.rarity) if card else 0
	var challenge_line: float = clampf(0.28 + rarity * 0.045 + suspicion_of_player * 0.12, 0.25, 0.62)
	# Small noise prevents identical cards from becoming perfectly readable while
	# preserving evidence as the dominant factor.
	return truth_probability < challenge_line + randf_range(-0.035, 0.035)

func estimate_bid_truth_probability(bid_count: int, bid_value: int, own_values: Array) -> float:
	var known_values: Array = player_full_values.duplicate()
	if known_values.is_empty() and card and card.card_id == "jack_crt" and _peeked_player_value > 0:
		known_values.append(_peeked_player_value)
	var certain_matches: int = _count_for_target(bid_value, own_values) + _count_for_target(bid_value, known_values)
	var unknown_count: int = maxi(0, total_other_dice - known_values.size())
	var needed: int = bid_count - certain_matches
	if needed <= 0: return 1.0
	if needed > unknown_count: return 0.0
	var face_probability: float = _unknown_match_probability(bid_value)
	var result: float = 0.0
	for hits in range(needed, unknown_count + 1):
		result += _binomial_term(unknown_count, hits, face_probability)
	return clampf(result, 0.0, 1.0)

func _expected_total_for(value: int, own_values: Array) -> float:
	var known_values: Array = player_full_values
	var unknown_count: int = maxi(0, total_other_dice - known_values.size())
	return float(_count_for_target(value, own_values) + _count_for_target(value, known_values)) + unknown_count * _unknown_match_probability(value)

func _unknown_match_probability(target: int) -> float:
	if target == 1:
		return 2.0 / 6.0 if _six_wild else 1.0 / 6.0
	return 3.0 / 6.0 if _six_wild else 2.0 / 6.0

func _binomial_term(n: int, k: int, probability: float) -> float:
	var combinations: float = 1.0
	for i in range(1, k + 1):
		combinations *= float(n - k + i) / float(i)
	return combinations * pow(probability, k) * pow(1.0 - probability, n - k)

func _bid_is_legal(count: int, value: int) -> bool:
	if _game and _game.has_method("_is_valid_bid"):
		return bool(_game._is_valid_bid(count, value))
	if current_bid_count == 0: return count >= min_opening
	return count > current_bid_count or (count == current_bid_count and value > current_bid_value)

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
	var free_infections: int = mini(3, 1 + bk_lv)
	if card.card_id == "battery_kid" and virus_count < free_infections:
		virus_count += 1
		if bk_lv >= 3:
			_bk_saved = true  # Signal DiceGame to add a die
		return false  # 免疫本次感染
	virus_count += 1
	is_eliminated = true
	return true

## 老杰克 偷窥: peek player dice once per battle (Lv.1=2 dice, Lv.2=2 uses, Lv.3=3 dice+公开)
func peek_player_dice(count: int, available_values: Array) -> Array[int]:
	if _peek_uses <= 0 or card.card_id != "jack_crt":
		return []
	_peek_uses -= 1
	var result: Array[int] = []
	var candidates: Array = available_values.duplicate()
	for _i in range(min(count, candidates.size())):
		var idx: int = randi() % candidates.size()
		var v: int = candidates[idx]
		candidates.remove_at(idx)
		result.append(v)
	if result.size() > 0:
		_peeked_player_value = result[0]
	return result

func is_alive() -> bool:
	return not is_eliminated

func get_name_str() -> String:
	return ai_name
