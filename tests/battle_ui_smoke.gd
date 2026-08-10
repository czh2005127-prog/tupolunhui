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
	assert(battle.get_node_or_null("BattleBoard")!=null)
	assert(battle._enemy_row.get_child_count()==2)
	assert((battle._enemy_row.get_child(0) as Control).position.distance_to(Vector2(682,89.6))<0.01)
	assert((battle._enemy_row.get_child(1) as Control).position.distance_to(Vector2(937,89.6))<0.01)
	var opponent_face:=battle._enemy_row.get_child(0).get_child(0) as Control
	var has_large_skill_text:=false
	for text_node in opponent_face.find_children("*","Label",true,false):
		assert((text_node as Label).text!=str(battle._latest_state.enemies[0].name))
		if (text_node as Label).get_theme_font_size("font_size")>=10:
			has_large_skill_text=true
	assert(has_large_skill_text)
	assert(battle._enemy_speech_panel!=null and not battle._enemy_speech_panel.visible)
	battle._show_enemy_speech(0)
	assert(battle._enemy_speech_panel.visible)
	assert(battle._enemy_speech_panel.position.distance_to(Vector2(779,44.6))<0.01)
	assert(str(battle._enemy_speech_label.text).contains("倒计时："))
	var tick_enemies:Array=battle._latest_state.enemies.duplicate(true)
	for enemy in tick_enemies:
		enemy.timer=maxi(0,int(enemy.timer)-1)
	battle._update_enemy_countdown_bubbles(tick_enemies,false)
	assert(battle._enemy_speech_panels[0].visible and battle._enemy_speech_panels[1].visible)
	assert(str(battle._enemy_speech_labels[0].text)==str(int(tick_enemies[0].timer)))
	assert(str(battle._enemy_speech_labels[1].text)==str(int(tick_enemies[1].timer)))
	assert(battle._enemy_speech_labels[0].get_theme_font_size("font_size")==30)
	var three_enemies:Array=battle._latest_state.enemies.duplicate(true)
	three_enemies.append(three_enemies[0].duplicate(true))
	battle._rebuild_enemies(three_enemies)
	assert((battle._enemy_row.get_child(0) as Control).position.distance_to(Vector2(570,89.6))<0.01)
	assert((battle._enemy_row.get_child(1) as Control).position.distance_to(Vector2(802,89.6))<0.01)
	assert((battle._enemy_row.get_child(2) as Control).position.distance_to(Vector2(1035,89.6))<0.01)
	assert(battle._physical_dice_board!=null)
	assert(battle._physical_dice_board._bodies.size()==5)
	assert(battle._dice_hitboxes.get_child_count()==5)
	assert(battle._physical_dice_board.clip_contents)
	await get_tree().create_timer(4.0).timeout
	assert(not battle._physical_dice_board._rolling)
	assert(battle._physical_dice_board._detected_top_values.size()==5)
	var expected_sorted_values:Array[int]=[]
	for die in battle._latest_state.dice:
		expected_sorted_values.append(int(die.value))
	expected_sorted_values.sort()
	for die_index in range(expected_sorted_values.size()):
		var physical_die:RigidBody3D=battle._physical_dice_board._bodies[die_index]
		assert(int(physical_die.get_meta("landing_top", 0))==expected_sorted_values[die_index])
		assert(battle._physical_dice_board._detect_top_value(physical_die)==expected_sorted_values[die_index])
		assert(str(physical_die.get_meta("settle_phase", ""))=="settled")
		var sorting_rotation:Quaternion=physical_die.get_meta("sorting_rotation", Quaternion.IDENTITY)
		assert(absf(physical_die.quaternion.dot(sorting_rotation))>0.9999)
	assert(battle._hand_area.get_child_count()==6)
	var first_player_card:=PlayerCardData.get_by_id(str(battle._latest_state.hand[0].id))
	var first_player_face:=battle._hand_area.get_child(0).get_child(0) as Control
	for text_node in first_player_face.find_children("*","Label",true,false):
		assert((text_node as Label).text!=first_player_card.description)
	battle._show_player_card_details(0)
	var found_card_description:=false
	for detail_node in battle.find_children("*","RichTextLabel",true,false):
		if str((detail_node as RichTextLabel).text).contains(first_player_card.description):
			found_card_description=true
	assert(found_card_description)
	var held_index:=4
	var hand_size_before_hold:int=battle._latest_state.hand.size()
	battle._card_hold_generation+=1
	var hold_token:int=battle._card_hold_generation
	battle._card_hold_tokens[held_index]=hold_token
	battle._complete_card_hold(held_index,hold_token)
	assert(held_index in battle._game.retained_indices)
	battle._on_card_clicked(held_index)
	assert(battle._latest_state.hand.size()==hand_size_before_hold)
	battle._clear_all_long_presses()
	assert(battle._score_label.position==Vector2(118,4) and battle._score_label.size==Vector2(216,52))
	assert(battle._formula_label.position==Vector2(70,12) and battle._formula_label.size==Vector2(270,54))
	assert(battle._breakdown_label.position==Vector2.ZERO and battle._breakdown_label.size==Vector2(147,56))
	assert(battle._draw_pile_label.position.is_equal_approx(Vector2(593,622.6)) and battle._draw_pile_label.size==Vector2(60,24))
	assert(battle._discard_pile_label.position.is_equal_approx(Vector2(23,622.6)) and battle._discard_pile_label.size==Vector2(60,24))
	assert(battle._toast_panel.visible)
	assert(battle._toast_panel.position.is_equal_approx(Vector2(25,336.6)))
	assert(battle._toast_panel.size==Vector2(454,52))
	assert(battle._effects_row!=null)
	assert(battle._effects_row.position.distance_to(Vector2(520,281.6))<0.01)
	var found_score_hitbox:=false
	for node in battle.find_children("ScoreRulesHitbox","Button",true,false):
		found_score_hitbox=true
	assert(found_score_hitbox)
	assert(battle._round_banner!=null and battle._round_banner.position.distance_to(Vector2(440,300))<0.01)
	assert(battle._dice_row.position.distance_to(Vector2(680,352.6))<0.01 and battle._dice_row.size.distance_to(Vector2(558,322))<0.01)
	assert(battle._confirm_button.position.distance_to(Vector2(217,626.6))<0.01 and battle._confirm_button.size.distance_to(Vector2(241,68))<0.01)
	var settings_button:=battle.get_node_or_null("BattleBoard/BattleSettingsButton") as Button
	assert(settings_button!=null)
	settings_button.pressed.emit()
	assert(get_tree().paused and is_instance_valid(battle._settings_layer))
	battle._close_pause_settings()
	assert(not get_tree().paused)
	assert(battle._health_label!=null and battle._gold_label!=null)
	for node in battle.find_children("*","Button",true,false):
		assert((node as Button).text!="教程回顾")
	assert(str(battle._multiplier_label.text).contains("×"))
	assert(str(battle._latest_state.enemies[0].ratio).begins_with("1/"))
	assert(battle._latest_state.has("effects"))
	var target_card_index:=-1
	for index in range(battle._latest_state.hand.size()):
		if str(battle._latest_state.hand[index].id) in ["reroll_stone","flip_die","freeze_die"]:
			target_card_index=index
			break
	assert(target_card_index>=0)
	var hand_before_target:int=battle._latest_state.hand.size()
	battle._on_card_clicked(target_card_index)
	assert(battle._pending_hand_index==target_card_index and is_instance_valid(battle._target_cursor))
	battle._cancel_die_targeting()
	assert(battle._pending_hand_index==-1 and battle._latest_state.hand.size()==hand_before_target)
	var reroll_index:=-1
	for index in range(battle._latest_state.hand.size()):
		if str(battle._latest_state.hand[index].id)=="reroll_stone":
			reroll_index=index
			break
	assert(reroll_index>=0)
	var reroll_target:=-1
	for die_index in range(battle._latest_state.dice.size()):
		if battle._game.is_die_target_legal(reroll_index,die_index):
			reroll_target=die_index
			break
	assert(reroll_target>=0)
	var values_before_reroll:Array[int]=battle._game.cup.get_all_values()
	var modified_before_reroll:int=int(battle._game.cup.dice[reroll_target].modified)
	var reroll_result:Dictionary=battle._game.request_use_card(reroll_index,reroll_target)
	assert(bool(reroll_result.get("ok",false)))
	for die_index in range(values_before_reroll.size()):
		if die_index!=reroll_target:
			assert(int(battle._game.cup.dice[die_index].value)==values_before_reroll[die_index])
	assert(int(battle._game.cup.dice[reroll_target].modified)==modified_before_reroll+1)
	await get_tree().process_frame
	var rolling_body_count:=0
	var rolling_source_index:=-1
	for physical_die in battle._physical_dice_board._bodies:
		if not physical_die.freeze:
			rolling_body_count+=1
			rolling_source_index=int(physical_die.get_meta("source_index",-1))
	assert(rolling_body_count==1 and rolling_source_index==reroll_target)
	var normal_basis:Basis=battle._physical_dice_board._top_basis(4,false)
	var locked_basis:Basis=battle._physical_dice_board._top_basis(4,true)
	var face_normal:Vector3=battle._physical_dice_board._local_face_normal(4)
	assert((normal_basis*face_normal).normalized().dot(Vector3.UP)>0.9999)
	var locked_alignment:float=(locked_basis*face_normal).normalized().dot(Vector3.UP)
	assert(locked_alignment>0.95 and locked_alignment<0.999)
	battle._on_battle_finished(true,1)
	var result_panels:=battle.find_children("BattleResultPanel","TextureRect",true,false)
	var result_buttons:=battle.find_children("BattleResultConfirmButton","TextureButton",true,false)
	assert(result_panels.size()==1 and (result_panels[0] as Control).position==Vector2(330,145))
	assert(result_buttons.size()==1 and (result_buttons[0] as Control).position==Vector2(520,500))
	print("BATTLE_UI_SMOKE_OK")
	get_tree().quit(0)
