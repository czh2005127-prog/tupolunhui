class_name DiceCup
extends RefCounted

var dice: Array[Dictionary] = []
var dice_count: int = 5
var rng := RandomNumberGenerator.new()

func _init(count: int = 5, seed_value: int = 0) -> void:
	dice_count = maxi(1, count)
	if seed_value > 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	for _i in range(dice_count):
		dice.append(_new_die())

func _new_die(value: int = 0) -> Dictionary:
	return {"value": rng.randi_range(1, 6) if value <= 0 else clampi(value, 1, 6), "locked":false, "lock_rounds":0, "hidden":false, "protected":false, "modified":0,"wild":false,"player_blocked":false}

func roll_new_round() -> void:
	for die in dice:
		if int(die.get("lock_rounds", 0)) > 0:
			die.lock_rounds = int(die.lock_rounds) - 1
			die.locked = int(die.lock_rounds) > 0
		else:
			die.value = rng.randi_range(1, 6)
			die.locked = false
		die.hidden = false
		die.wild = false
		die.modified = 0

func roll_all() -> void:
	for die in dice:
		if not bool(die.locked):
			die.value = rng.randi_range(1, 6)

func get_values() -> Array[int]:
	var result: Array[int] = []
	for die in dice:
		result.append(0 if bool(die.hidden) else int(die.value))
	return result

func get_all_values() -> Array[int]:
	var result: Array[int] = []
	for die in dice:
		result.append(int(die.value))
	return result

func reroll_die(index: int, take_lower: bool = false) -> bool:
	if not _valid(index) or bool(dice[index].locked): return false
	var value := rng.randi_range(1, 6)
	if take_lower: value = mini(value, rng.randi_range(1, 6))
	dice[index].value = value
	dice[index].modified = int(dice[index].modified) + 1
	return true

func roll_indices(indices: Array[int]) -> void:
	for index in indices: reroll_die(index)

func flip_at(index: int) -> bool:
	if not _valid(index): return false
	dice[index].value = 7 - int(dice[index].value)
	dice[index].modified = int(dice[index].modified) + 1
	return true

func adjust_at(index: int, delta: int) -> bool:
	if not _valid(index): return false
	var old := int(dice[index].value)
	dice[index].value = clampi(old + delta, 1, 6)
	dice[index].modified = int(dice[index].modified) + 1
	return int(dice[index].value) != old

func set_value(index: int, value: int) -> bool:
	if not _valid(index): return false
	dice[index].value = clampi(value, 1, 6)
	dice[index].modified = int(dice[index].modified) + 1
	return true

func lock_die(index: int, rounds: int = 1) -> bool:
	if not _valid(index): return false
	dice[index].locked = true
	dice[index].lock_rounds = maxi(1, rounds)
	return true

func add_die(value: int = 0) -> int:
	dice.append(_new_die(value))
	dice_count = dice.size()
	return dice.size() - 1

func clone_at(index: int) -> bool:
	if not _valid(index): return false
	add_die(int(dice[index].value))
	return true

func split_at(index: int) -> bool:
	if not _valid(index) or int(dice[index].value) < 4: return false
	var total := int(dice[index].value)
	var first := rng.randi_range(1, total - 1)
	if first > 6 or total - first > 6: return false
	dice[index].value = first
	add_die(total - first)
	return true

func remove_indices(indices: Array[int]) -> Array[Dictionary]:
	var sorted := indices.duplicate(); sorted.sort(); sorted.reverse()
	var removed: Array[Dictionary] = []
	for index in sorted:
		if _valid(index): removed.push_front(dice.pop_at(index))
	dice_count = dice.size()
	return removed

func protect(index: int) -> bool:
	if not _valid(index): return false
	dice[index].protected = true
	return true

func consume_protection(index: int) -> bool:
	if not _valid(index) or not bool(dice[index].protected): return false
	dice[index].protected = false
	return true

func _valid(index: int) -> bool:
	return index >= 0 and index < dice.size()

# Legacy helpers kept for old save/test compatibility.
func reveal_all() -> Array: return get_all_values()
func set_all_visible() -> void:
	for die in dice: die.hidden = false
func has_value(value: int) -> bool: return value in get_all_values()
func get_hidden_count() -> int:
	var n := 0
	for die in dice:
		if bool(die.hidden): n += 1
	return n
func hide_random_dice(count: int) -> void:
	var indices: Array[int] = []
	for i in range(dice.size()): indices.append(i)
	indices.shuffle()
	for i in range(mini(count, indices.size())): dice[indices[i]].hidden = true
func add_die_with_value(value: int) -> void: add_die(value)
func enforce_roll_constraints(_mutable_indices: Array[int] = []) -> void: pass
