extends Node

func _ready()->void:
	GameState.setup_new_run()
	var scene:=load("res://scenes/gameflow/RunManager.tscn") as PackedScene
	var flow:=scene.instantiate();add_child(flow)
	await get_tree().process_frame
	await get_tree().process_frame
	var shop:=flow.get_node_or_null("ShopUI")
	assert(shop!=null,"新游戏必须先进入行前商店")
	assert(GameState.gold>=45,"行前资金必须至少45")
	shop._leave()
	await get_tree().process_frame
	await get_tree().process_frame
	assert(flow.nodes_this_stage.size()==7,"每层必须生成7个节点")
	assert(flow.nodes_this_stage.count(flow.NodeType.DICE)==3)
	assert(flow.nodes_this_stage.count(flow.NodeType.EVENT)==2)
	assert(flow.nodes_this_stage.back()==flow.NodeType.BOSS)
	var first_type:int=flow.nodes_this_stage[0]
	if first_type==flow.NodeType.DICE:
		assert(flow.get_node_or_null("CardDrawUI")!=null,"首个战斗节点必须进入抽卡")
	elif first_type==flow.NodeType.EVENT:
		assert(flow.get_node_or_null("EventUI")!=null,"首个事件节点必须打开事件")
	print("RUN_FLOW_SMOKE_OK")
	get_tree().quit(0)
