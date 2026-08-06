extends Control

func _ready()->void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameState.has_cleared_game=true;GameState.save_progress();_build()

func _build()->void:
	var true_ending:=bool(get_meta("true_ending",false))
	var bg:=ColorRect.new();bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);bg.color=Color(0.015,0.014,0.025);add_child(bg)
	var title:=_label("轮回终结" if true_ending else "暂时脱离",46,Color(0.96,0.75,0.28));title.position=Vector2(190,70);title.size=Vector2(900,70);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;add_child(title)
	var story_text:="卡牌国王倒下时，木盒里的天空第一次裂开。\n那些被抹去名字的人逐一想起自己的世界。\n骰子之神没有追赶你——它只是低声说了一句‘谢谢’。\n\n木盒合上了。这一次，里面再也没有哭声。" if true_ending else "骰子之神承认了你的胜利，却说这还不够。\n\n‘用锈点强化你的对手，再回来真正击败我。’\n它的声音忽然变得陌生而恐惧：\n\n‘……求你，救救我。’\n\n下一秒，你的视线终于离开了木盒。"
	var story:=_label(story_text,22,Color(0.82,0.81,0.78));story.position=Vector2(270,175);story.size=Vector2(740,280);story.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;story.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(story)
	var stats:=GameState.calculate_score();var info:=_label("评级 %s　旅程分 %d　锈点 %d　科技点 %d"%[stats.tier,stats.score,GameState.rust_points,GameState.tech_points],19,Color(0.55,0.82,0.78));info.position=Vector2(240,500);info.size=Vector2(800,36);info.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;add_child(info)
	var button:=Button.new();button.text="返回主菜单";button.position=Vector2(490,590);button.size=Vector2(300,58);button.pressed.connect(func():GameState._clear_save();get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn"));add_child(button)

func _label(text:String,size_value:int,color:Color)->Label:var l:=Label.new();l.text=text;l.add_theme_font_size_override("font_size",size_value);l.add_theme_color_override("font_color",color);return l
