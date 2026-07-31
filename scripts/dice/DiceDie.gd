## A single six-sided die. Defaults to 1-6, can mutate to different ranges.
class_name DiceDie
extends RefCounted

var value: int = 1
var sides: int = 6
var is_hidden: bool = false  # 暗骰 — player can't see this die's value
var is_dark: bool = false    # Shorthand alias, kept for compatibility
var locked: bool = false     # Skip roll if locked (freeze_die/fate_die)

func roll() -> void:
	if locked: return
	value = randi() % sides + 1

func get_display_value() -> String:
	if is_hidden:
		return "?"
	return str(value)

func matches(target: int) -> bool:
	if is_hidden:
		return false
	if value == target:
		return true
	if value == 1:
		return true  # 1 is always wild
	return false
