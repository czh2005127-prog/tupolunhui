## Manages a set of dice — rolling, counting, and result reporting.
class_name DiceCup
extends RefCounted

var dice: Array = []
var dice_count: int = 5
var wild_disabled: bool = false  # 阶段3+: ①不再是万能

func _init(count: int = 5) -> void:
	dice_count = count
	_create_dice()

func _create_dice() -> void:
	dice.clear()
	for i: int in range(dice_count):
		dice.append(preload("res://scripts/dice/DiceDie.gd").new())

## Check if values form a straight (consecutive 1-5 or 2-6, ignoring order)
func _is_straight() -> bool:
	var vals: Array = []
	for die in dice:
		if not die.is_hidden:
			vals.append(die.value)
	if vals.size() < 2: return false
	vals.sort()
	for i in range(vals.size() - 1):
		if vals[i + 1] - vals[i] != 1:
			return false
	# Reject if it's a straight — must not be consecutive
	return true

func roll_all() -> void:
	for die in dice:
		if not die.locked:
			die.roll()
	# Re-roll if results are a straight (e.g., 1-2-3-4-5)
	# Cap at 20 attempts to avoid infinite loop
	var attempts: int = 0
	while _is_straight() and attempts < 20:
		for die in dice:
			if not die.locked:
				die.roll()
		attempts += 1

## Make all dice visible (cancel any hidden/dark dice)
func set_all_visible() -> void:
	for die in dice:
		die.is_hidden = false
		die.is_dark = false

## Reroll only dice at specific indices
func roll_indices(indices: Array[int]) -> void:
	for idx in indices:
		if idx >= 0 and idx < dice.size():
			dice[idx].roll()
	# Reroll whole cup if rerolled subset somehow formed a straight
	var attempts: int = 0
	while _is_straight() and attempts < 20:
		for idx in indices:
			if idx >= 0 and idx < dice.size():
				dice[idx].roll()
		attempts += 1

## Flip a die at index (1↔6, 2↔5, 3↔4)
func flip_at(idx: int) -> void:
	if idx >= 0 and idx < dice.size():
		dice[idx].value = 7 - dice[idx].value

## Add an extra die with given value (for 锈铁战士 意志依存 skill)
func add_die_with_value(v: int) -> void:
	var new_die := preload("res://scripts/dice/DiceDie.gd").new()
	new_die.value = v
	dice.append(new_die)
	dice_count += 1

func set_hidden_die(index: int, hidden: bool) -> void:
	if index >= 0 and index < dice.size():
		dice[index].is_hidden = hidden

func get_values() -> Array:
	var result: Array = []
	for die in dice:
		if not die.is_hidden:
			result.append(die.value)
		else:
			result.append(-1)
	return result

## Get all values including hidden — for boss who can see dark dice
func get_all_values() -> Array:
	var result: Array = []
	for die in dice:
		result.append(die.value)
	return result

func count_matches(target: int) -> int:
	var count: int = 0
	for die in dice:
		if die.matches(target):
			count += 1
	return count

func count_matches_revealing(target: int, six_wild: bool = false) -> int:
	var count: int = 0
	for die in dice:
		if die.value == target: count += 1
		elif die.value == 1 and not wild_disabled: count += 1
		elif die.value == 6 and six_wild: count += 1
	return count

func reveal_all() -> Array:
	var revealed: Array = []
	for die in dice:
		if die.is_hidden:
			revealed.append(die.value)
		die.is_hidden = false
	return revealed

func has_value(val: int) -> bool:
	for die in dice:
		if not die.is_hidden and die.value == val:
			return true
	return false

func get_hidden_count() -> int:
	var count: int = 0
	for die in dice:
		if die.is_hidden:
			count += 1
	return count

func reroll_die(index: int) -> void:
	if index >= 0 and index < dice.size():
		dice[index].roll()

## Add one die (split_die item effect)
func add_hidden_die() -> void:
	var new_die = preload("res://scripts/dice/DiceDie.gd").new()
	new_die.roll()
	new_die.is_hidden = true
	dice.append(new_die)
	dice_count += 1

func add_die() -> void:
	var new_die = preload("res://scripts/dice/DiceDie.gd").new()
	new_die.roll()
	dice.append(new_die)
	dice_count += 1

## Clone die at index — add one extra die with same value (must have pair)
func clone_at(idx: int) -> void:
	if idx < 0 or idx >= dice.size(): return
	var val: int = dice[idx].value
	var d = preload("res://scripts/dice/DiceDie.gd").new()
	d.value = val
	dice.append(d)
	dice_count += 1

## Get indices of dice that have at least one other die with same value
func get_pair_indices() -> Array[int]:
	var value_counts: Dictionary = {}
	for i in range(dice.size()):
		if dice[i].is_hidden: continue  # 隐藏骰不参与
		var v: int = dice[i].value
		if not value_counts.has(v):
			value_counts[v] = []
		value_counts[v].append(i)
	var result: Array[int] = []
	for v in value_counts:
		var indices: Array = value_counts[v]
		if indices.size() >= 2:
			for idx in indices:
				result.append(idx as int)
	return result

## Check if cup has any pair (2+ dice with same value)
func has_pairs() -> bool:
	return get_pair_indices().size() > 0

## Split die at index into 2 smaller dice summing to its value (only >=4)
func split_at(idx: int) -> void:
	if idx < 0 or idx >= dice.size(): return
	var val: int = dice[idx].value
	if val < 4: return
	dice.remove_at(idx)
	dice_count -= 1
	# Pairs that sum to val
	var pairs: Dictionary = {4: [[1, 3], [2, 2]], 5: [[1, 4], [2, 3]], 6: [[1, 5], [2, 4], [3, 3]]}
	var options: Array = pairs.get(val, [[1, 1]])
	var pick: Array = options[randi() % options.size()]
	for v in pick:
		var d = preload("res://scripts/dice/DiceDie.gd").new()
		d.value = v
		dice.append(d)
		dice_count += 1

## Lock die at index so roll_all skips it (freeze_die/fate_die item)
func lock_die(idx: int) -> void:
	if idx >= 0 and idx < dice.size():
		dice[idx].locked = true
