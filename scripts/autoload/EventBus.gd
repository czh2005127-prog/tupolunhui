@warning_ignore("unused_signal")
extends Node

signal score_preview_changed(preview:Dictionary)
signal card_played(card_id:String)
signal enemy_intent_advanced(enemy_id:String,skill_name:String,timer:int)
signal battle_finished(victory:bool,rounds_used:int,total_score:int)
signal half_assimilated
signal fully_assimilated
signal node_entered(node_type:String,node_data:Dictionary)
signal node_completed(node_type:String)
signal stage_changed(stage_id:int,stage_name:String)
signal run_started
signal run_ended(victory:bool)
signal gold_changed(new_amount:int)
signal shop_entered
signal shop_exited
signal hint_show(message:String,duration:float,color:Color)
signal tutorial_hint_show(message:String,duration:float)
