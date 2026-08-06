class_name CardPool
extends RefCounted

const CardDataRef := preload("res://scripts/resources/CardData.gd")
const MIN_CANDIDATES := 3
const MAX_CANDIDATES := 5
const NORMAL_GOLD: Array[int] = [5, 8, 12, 17]
const BOSS_GOLD: Array[int] = [12, 18, 26, 36]

static func candidate_count(stage:int=0) -> int:
	var unlocked: int = get_layer_pool(stage).size()
	return clampi(unlocked,MIN_CANDIDATES,MAX_CANDIDATES)

static func get_layer_pool(stage: int) -> Array[CardData]:
	var tier: int = clampi(stage, 0, 3)
	var source: Array[CardData] = CardDataRef.get_pool_by_rarity(tier as CardData.Rarity)
	var filtered: Array[CardData] = []
	for card in source:
		if GameState.unlocked_cards.is_empty() or card.card_id in GameState.unlocked_cards:
			filtered.append(card)
	return source if filtered.size() < 2 else filtered

static func get_mixed_pool(stage: int, _is_boss: bool = false) -> Array:
	var result: Array = get_layer_pool(stage)
	result.append_array(CardDataRef.get_unknown_pool())
	return result

static func draw_candidates(stage: int, count: int = -1) -> Array[CardData]:
	var wanted: int = candidate_count(stage) if count < 0 else clampi(count, 3, 5)
	var result: Array[CardData] = []
	var unknowns: Array[CardData] = CardDataRef.get_unknown_pool()
	result.append(unknowns[randi() % unknowns.size()])
	var pool: Array[CardData] = get_layer_pool(stage)
	while result.size() < wanted and not pool.is_empty():
		var picked: CardData = _weighted_pick(pool, result)
		result.append(picked)
	result.shuffle()
	return result

static func _weighted_pick(pool: Array[CardData], existing: Array[CardData]) -> CardData:
	var weighted: Array[CardData] = []
	for card in pool:
		var duplicate_count := 0
		for old in existing:
			if old.card_id == card.card_id:
				duplicate_count += 1
		if duplicate_count >= 2:
			continue
		var tickets := 1 if duplicate_count == 1 else 4
		for _i in range(tickets):
			weighted.append(card)
	if weighted.is_empty():
		return pool[randi() % pool.size()]
	return weighted[randi() % weighted.size()]

static func get_boss_pool(stage: int) -> Array[CardData]:
	if stage == 0:
		return CardDataRef.get_epic_pool()
	if stage < 3:
		return CardDataRef.get_legendary_pool()
	return CardDataRef.get_genesis_pool()

static func draw_cards(stage: int, is_boss: bool) -> Array[CardData]:
	if not is_boss:
		return draw_candidates(stage)
	var guards: Array[CardData] = draw_candidates(stage)
	var main_pool: Array[CardData] = get_boss_pool(stage)
	guards.append(main_pool[randi() % main_pool.size()])
	return guards

static func has_unknown_cards(cards: Array) -> bool:
	for card in cards:
		if card != null and card.rarity == CardData.Rarity.UNKNOWN:
			return true
	return false

static func get_unknown_card(cards: Array) -> CardData:
	for card in cards:
		if card != null and card.rarity == CardData.Rarity.UNKNOWN:
			return card
	return null

static func get_battle_gold(stage: int, is_boss: bool = false) -> int:
	var index := clampi(stage, 0, 3)
	return BOSS_GOLD[index] if is_boss else NORMAL_GOLD[index]

# Compatibility shims for scenes from the old build.
static func get_elite_item() -> String: return ""
static func get_rare_item() -> String: return ""
static func get_legendary_item() -> String: return ""
