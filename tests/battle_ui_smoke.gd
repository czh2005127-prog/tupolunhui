extends Node

const CardDataRef:=preload("res://scripts/resources/CardData.gd")

func _ready()->void:
	GameState.setup_new_run();GameState.next_battle_modifiers.starting_shop_done=true
	var scene:=load("res://scenes/gameflow/DiceGameScene.tscn") as PackedScene
	var battle:=scene.instantiate();add_child(battle)
	battle.setup_with_flow(null,null,[CardDataRef.get_common_pool()[0],CardDataRef.get_common_pool()[1]])
	await get_tree().process_frame
	await get_tree().process_frame
	assert(battle.get_node_or_null("DiceGame")!=null)
	assert(battle._latest_state.hand.size()==6)
	assert(battle._latest_state.dice.size()==5)
	assert(battle._latest_state.enemies.size()==2)
	assert(battle._confirm_button!=null and not battle._confirm_button.disabled)
	print("BATTLE_UI_SMOKE_OK")
	get_tree().quit(0)
