## Card pool — dual-deck drawing system.
## Mixes rarity pools with a random unknown card for each draw.
## Unlocked cards are filtered; unknown/genesis always pass.
## Boss stages show exactly 2+1 cards; normal stages show 2+1 (with 1 unknown).
class_name CardPool
extends RefCounted

const CardDataRef := preload("res://scripts/resources/CardData.gd")

## Display counts per card draw screen
const SHOW_MIXED: int = 2    # rarity-pool cards shown (e.g., 2 common)
const SHOW_BOSS: int = 3     # boss-pool cards shown — pick 1

static func _filter_unlocked(pool: Array) -> Array:
	var result: Array = []
	for c in pool:
		var card: CardData = c
		if card.rarity >= CardData.Rarity.GENESIS:
			result.append(c)  # unknown / genesis: always available
		elif card.card_id in GameState.unlocked_cards:
			result.append(c)
	return result

## Pick exactly [param count] random cards from [param pool] (no duplicates).
## Pads with common cards if pool is too small.
static func _pick_from(pool: Array, count: int) -> Array:
	var result: Array = []
	var source: Array = _filter_unlocked(pool)
	if source.is_empty():
		# Fallback: use any common cards
		source = _filter_unlocked(CardDataRef.get_common_pool())
	if source.is_empty():
		return result
	var shuffled: Array = source.duplicate()
	shuffled.shuffle()
	for i in range(min(count, shuffled.size())):
		result.append(shuffled[i])
	return result

## Get mixed pool for manual card selection.
## Normal stage: [SHOW_MIXED] rarity cards + 1 unknown.
## Boss stage:   [SHOW_MIXED] rarity cards only (no unknown — boss adds its own pool).
static func get_mixed_pool(stage: int, is_boss: bool = false) -> Array:
	var rarity_pool: Array
	match stage:
		0: rarity_pool = _filter_unlocked(CardDataRef.get_common_pool())
		1: rarity_pool = _filter_unlocked(CardDataRef.get_rare_pool())
		2: rarity_pool = _filter_unlocked(CardDataRef.get_epic_pool())
		3: rarity_pool = _filter_unlocked(CardDataRef.get_legendary_pool())
		_: rarity_pool = _filter_unlocked(CardDataRef.get_common_pool())
	var picked: Array = _pick_from(rarity_pool, SHOW_MIXED)
	if not is_boss:
		var unknown := CardDataRef.get_unknown_pool()
		if unknown.size() > 0:
			picked.append(unknown[randi() % unknown.size()])
	return picked

## Get boss-only extra pool. Returns up to [SHOW_BOSS] cards.
## Stage N boss = mixed(N) + mixed(N+1 rarity). NO common fallback.
## If next-rarity pool is empty, fallback to current rarity (mixed N) — never show empty.
static func get_boss_pool(stage: int) -> Array:
	if stage == 3:
		return CardDataRef.get_genesis_pool()
	var next_rarity: Array = []
	match stage:
		0: next_rarity = _filter_unlocked(CardDataRef.get_rare_pool())
		1: next_rarity = _filter_unlocked(CardDataRef.get_epic_pool())
		2: next_rarity = _filter_unlocked(CardDataRef.get_legendary_pool())
	if next_rarity.size() >= SHOW_BOSS:
		var shuffled: Array = next_rarity.duplicate()
		shuffled.shuffle()
		var result: Array = []
		for i in range(min(SHOW_BOSS, shuffled.size())):
			result.append(shuffled[i])
		return result
	# Fallback: use current tier (mixed N)
	if next_rarity.size() > 0:
		var fb: Array = next_rarity.duplicate()
		fb.shuffle()
		var result2: Array = []
		for i in range(min(SHOW_BOSS, fb.size())):
			result2.append(fb[i])
		return result2
	# Last fallback: current stage rarity
	var current_tier: Array = []
	match stage:
		0: current_tier = _filter_unlocked(CardDataRef.get_common_pool())
		1: current_tier = _filter_unlocked(CardDataRef.get_rare_pool())
		2: current_tier = _filter_unlocked(CardDataRef.get_epic_pool())
	if current_tier.is_empty():
		return []
	var csh: Array = current_tier.duplicate()
	csh.shuffle()
	var result3: Array = []
	for i in range(min(SHOW_BOSS, csh.size())):
		result3.append(csh[i])
	return result3

## Draw N cards from a mixed pool (rarity_pool + 1 random unknown) + optional pure rarity pool.
static func draw_cards(stage: int, is_boss: bool) -> Array[CardData]:
	var result: Array[CardData] = []
	var rarity_pool_a: Array[CardData] = get_mixed_pool(stage, is_boss)
	var pure_pool_b: Array[CardData] = get_boss_pool(stage) if is_boss else []

	# Draw 2 from mixed pool
	_draw_from_pool(rarity_pool_a, 2, result)

	# If boss, draw from pure pool B
	if is_boss and not pure_pool_b.is_empty():
		_draw_from_pool(pure_pool_b, 1, result)

	return result

## Draw count cards from pool into result, allowing max 2 of same card
static func _draw_from_pool(pool: Array[CardData], count: int, result: Array[CardData]) -> void:
	for _i in range(count):
		if pool.is_empty(): return
		var card := pool[randi() % pool.size()]
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

## Generate a random item (80% common, 20% epic) for elite reward
static func get_elite_item() -> String:
	var pool: Array = ItemData.get_consumable_pool()
	var item: Resource
	if randf() < 0.2:
		var epics: Array = []
		for i in pool:
			var it := i as ItemData
			if it.rarity >= ItemData.Rarity.RARE:
				epics.append(it)
		if epics.is_empty():
			epics = pool
		item = epics[randi() % epics.size()]
	else:
		item = pool[randi() % pool.size()]
	return item.item_id

## Get a legendary item for boss reward
static func get_legendary_item() -> String:
	var pool: Array = ItemData.get_consumable_pool()
	var legendaries: Array = []
	for i in pool:
		var it := i as ItemData
		if it.rarity == ItemData.Rarity.LEGENDARY:
			legendaries.append(it)
	if legendaries.is_empty():
		return get_elite_item()
	var item: Resource = legendaries[randi() % legendaries.size()]
	return item.item_id
