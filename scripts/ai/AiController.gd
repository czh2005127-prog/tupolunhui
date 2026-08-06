class_name AiController
extends RefCounted

## Score-mode opponents use deterministic, telegraphed intentions rather than
## hidden liar's-dice decisions. This helper centralizes target selection.
static func target_count(eligible_count:int,denominator:int)->int:
	if eligible_count<=0 or denominator<=0:return 0
	return eligible_count/denominator

static func ordered_dice(values:Array,highest_first:bool=true)->Array[int]:
	var indices:Array[int]=[]
	for i in range(values.size()):indices.append(i)
	indices.sort_custom(func(a:int,b:int):return int(values[a])>int(values[b]) if highest_first else int(values[a])<int(values[b]))
	return indices

static func ordered_cards(cards:Array,highest_rarity_first:bool=true)->Array[int]:
	var indices:Array[int]=[]
	for i in range(cards.size()):indices.append(i)
	indices.sort_custom(func(a:int,b:int):
		var ar:=int(cards[a].get("rarity",0));var br:=int(cards[b].get("rarity",0))
		return ar>br if highest_rarity_first else ar<br)
	return indices
