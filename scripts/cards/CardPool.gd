## Card pool — dual-deck drawing system.
## Mixes rarity pools with a random unknown card for each draw.
## Unlocked cards are filtered; unknown/genesis are injected by their dedicated decks.
class_name CardPool
extends RefCounted

const CardDataRef := preload("res://scripts/resources/CardData.gd")

const MIN_CANDIDATES: int = 3
const MAX_CANDIDATES: int = 5

static func _filter_unlocked(pool: Array) -> Array:
	var result: Array = []
	for card in pool:
		if card and card.card_id in GameState.unlocked_cards:
			result.append(card)
	return result

## Pick exactly [param count] cards; the same card may appear at most twice.
static func _pick_from(pool: Array, count: int) -> Array:
	var result: Array = []
	var source: Array = _filter_unlocked(pool)
	if source.is_empty():
		return result
	var occurrences: Dictionary = {}
	while result.size() < count:
		var candidates: Array = []
		for card in source:
			if int(occurrences.get(card.card_id, 0)) < 2:
				candidates.append(card)
		if candidates.is_empty(): break
		var picked = candidates[randi() % candidates.size()]
		result.append(picked)
		occurrences[picked.card_id] = int(occurrences.get(picked.card_id, 0)) + 1
	return result

## Get mixed pool for manual card selection.
## Exactly five candidates: three unlocked regular cards and two distinct unknowns.
static func get_mixed_pool(stage: int, is_boss: bool = false) -> Array:
	var full_rarity_pool: Array
	match stage:
		0: full_rarity_pool = CardDataRef.get_common_pool()
		1: full_rarity_pool = CardDataRef.get_rare_pool()
		2: full_rarity_pool = CardDataRef.get_epic_pool()
		3: full_rarity_pool = CardDataRef.get_legendary_pool()
		_: full_rarity_pool = CardDataRef.get_common_pool()
	var picked: Array = _pick_from(full_rarity_pool, 3)
	var unknown: Array = CardDataRef.get_unknown_pool()
	unknown.shuffle()
	for i in range(mini(2, unknown.size())):
		picked.append(unknown[i])
	picked.shuffle()
	return picked

## Get boss-only extra pool. Returns 3-5 unlocked candidates, except the single genesis card.
## Boss pool follows the design document exactly:
## stage 1 = epic, stage 2 = legendary, stage 3 = legendary, stage 4 = genesis.
static func get_boss_pool(stage: int) -> Array:
	if stage == 3:
		return CardDataRef.get_genesis_pool()
	var full_next_rarity: Array = []
	match stage:
		0: full_next_rarity = CardDataRef.get_epic_pool()
		1, 2: full_next_rarity = CardDataRef.get_legendary_pool()
	var unlocked: Array = _filter_unlocked(full_next_rarity)
	if unlocked.is_empty(): return []
	var candidate_count: int = clampi(unlocked.size(), MIN_CANDIDATES, MAX_CANDIDATES)
	return _pick_from(full_next_rarity, candidate_count)

## Draw N cards from a mixed pool (rarity_pool + 1 random unknown) + optional pure rarity pool.
static func draw_cards(stage: int, is_boss: bool) -> Array[CardData]:
	var result: Array[CardData] = []
	var rarity_pool_a: Array = get_mixed_pool(stage, is_boss)
	var pure_pool_b: Array = get_boss_pool(stage) if is_boss else []

	# Draw 2 from mixed pool
	_draw_from_pool(rarity_pool_a, 2, result)

	# If boss, draw from pure pool B
	if is_boss and not pure_pool_b.is_empty():
		_draw_from_pool(pure_pool_b, 1, result)

	return result

## Draw count cards from pool into result, allowing max 2 of same card
static func _draw_from_pool(pool: Array, count: int, result: Array[CardData]) -> void:
	for _i in range(count):
		if pool.is_empty(): return
		var card: CardData = pool[randi() % pool.size()]
		var same_count: int = 0
		for c in result:
			if c.card_id == card.card_id:
				same_count += 1
		var tries: int = 0
		while same_count >= 2 and tries < 10:
			card = pool[randi() % pool.size()]
			same_count = 0
			for c in result:
				if c.card_id == card.card_id:
					same_count = 1
			tries += 1
		result.append(card)

## Check if any drawn card is unknown
static func has_unknown_cards(cards: Array[CardData]) -> bool:
	for c in cards:
		if c.rarity == CardData.Rarity.UNKNOWN:
			return true
	return false

## Get the unknown card from drawn cards (returns null if none)
static func get_unknown_card(cards: Array[CardData]) -> CardData:
	for c in cards:
		if c.rarity == CardData.Rarity.UNKNOWN:
			return c
	return null

## Get gold reward for a regular battle
static func get_battle_gold(stage: int) -> int:
	return GameState.get_stage_gold(stage)

## Generate a random item (80% common, 20% rare) for elite reward.
static func get_elite_item() -> String:
	var pool: Array = ItemData.get_unlocked_pool()
	if pool.is_empty(): pool = ItemData.get_consumable_pool()
	var common: Array = []
	var rare: Array = []
	for i in pool:
		var it := i as ItemData
		if it.rarity == ItemData.Rarity.COMMON: common.append(it)
		elif it.rarity == ItemData.Rarity.RARE: rare.append(it)
	var selected_pool: Array = rare if randf() < 0.2 else common
	if selected_pool.is_empty(): selected_pool = pool
	var item: Resource = selected_pool[randi() % selected_pool.size()]
	return item.item_id

static func get_rare_item() -> String:
	var pool: Array = ItemData.get_unlocked_pool()
	if pool.is_empty(): pool = ItemData.get_consumable_pool()
	var rare: Array = []
	for item in pool:
		if item.rarity == ItemData.Rarity.RARE: rare.append(item)
	if rare.is_empty(): return get_elite_item()
	return rare[randi() % rare.size()].item_id

## Get a legendary item for boss reward
static func get_legendary_item() -> String:
	var pool: Array = ItemData.get_unlocked_pool()
	if pool.is_empty(): pool = ItemData.get_consumable_pool()
	var legendaries: Array = []
	for i in pool:
		var it := i as ItemData
		if it.rarity == ItemData.Rarity.LEGENDARY:
			legendaries.append(it)
	if legendaries.is_empty():
		return get_elite_item()
	var item: Resource = legendaries[randi() % legendaries.size()]
	return item.item_id
