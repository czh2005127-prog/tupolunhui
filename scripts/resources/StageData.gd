class_name StageData
extends Resource

@export var stage_name:String=""
@export var node_count:int=7
@export var bg_color:Color=Color(0.03,0.025,0.02)
@export var normal_targets:Array[int]=[]
@export var boss_target:int=0

func describe_mutation()->String:
	return "本层包含三场计分战、两次事件、一家商店与最终Boss。"
