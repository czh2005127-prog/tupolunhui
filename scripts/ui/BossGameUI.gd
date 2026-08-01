## Boss 4-player dice game scene — thin wrapper around DiceGameScene with 3 cards.
extends Control

var _flow: Node
var _stage: Resource
var _dice_inst: Control

func setup_with_flow(stage: Resource, flow: Node, param3: Variant = null) -> void:
	_flow = flow
	_stage = stage

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.04, 0.02, 0.02)
	bg.anchors_preset = PRESET_FULL_RECT
	add_child(bg)

	var dice_scene: PackedScene = load("res://scenes/gameflow/DiceGameScene.tscn") as PackedScene
	if not dice_scene: return
	_dice_inst = dice_scene.instantiate() as Control
	if not _dice_inst: return
	_dice_inst.position = Vector2(0, 0)
	_dice_inst.size = Vector2(1280, 720)
	add_child(_dice_inst)

	await get_tree().process_frame
	await get_tree().process_frame

	if _dice_inst and _dice_inst.has_method("setup_with_flow"):
		# Pass card data as Array (3 cards for boss), DiceGameHUD detects count >= 3 → is_boss
		var cards: Array = param3 if param3 is Array else []
		_dice_inst.setup_with_flow(stage, flow, cards)
