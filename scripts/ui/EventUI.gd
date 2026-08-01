## Event node — mini narrative with a choice, drawn from a typed event pool.
## Categories: intel (25%), resource (30%), risk (25%), narrative (20%).
## Some events are stage-locked. No repeats within the same run.
## Item rewards use rarity: common (70%) > rare (25%) > legendary (5%).
extends Control

const GameButton := preload("res://scripts/ui/components/GameButton.gd")
const GamePanel := preload("res://scripts/ui/components/GamePanel.gd")

enum Category { INTEL, RESOURCE, RISK, NARRATIVE }

var _flow: Node
var _stage: int = 0
var _pending_discard: bool = false

func set_parent_flow(f: Node) -> void:
	_flow = f
	_stage = GameState.current_stage
	if not EventBus.discard_prompt.is_connected(_on_discard_prompt):
		EventBus.discard_prompt.connect(_on_discard_prompt)
	_build()

func _build() -> void:
	GamePanel.create(self, Vector2.ZERO, Vector2(UITheme.SCREEN_W, UITheme.SCREEN_H), UITheme.BG_DEEP, Color(0,0,0,0))

	var ev: Dictionary = _pick_event()

	# Category badge
	var cat_names: Array = ["情报", "资源", "风险", "叙事"]
	var cat_cols: Array[Color] = [Color(0.22, 0.5, 0.87), Color(0.36, 0.79, 0.65), Color(0.94, 0.4, 0.4), Color(0.52, 0.72, 0.92)]
	var badge: Label = Label.new()
	badge.text = cat_names[ev["type"]]
	badge.position = Vector2(300, 30)
	badge.size = Vector2(680, 30)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", cat_cols[ev["type"]])
	add_child(badge)

	var t := UITheme.label(self, ev["title"], Vector2(160, 70), Vector2(960, 45), cat_cols[ev["type"]], 22)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var d := UITheme.label(self, ev["desc"], Vector2(140, 130), Vector2(1000, 120), UITheme.RARITY_COMMON, 15)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var result_label := UITheme.label(self, "", Vector2(300, 400), Vector2(680, 45), UITheme.GOLD, 16)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	GameButton.create(self, Vector2(200, 270), Vector2(400, 48), ev["choice_a"], cat_cols[ev["type"]], _on_choice_a.bind(ev, result_label))
	GameButton.create(self, Vector2(680, 270), Vector2(400, 48), ev["choice_b"], UITheme.RARITY_COMMON.darkened(0.15), _on_choice_b.bind(ev, result_label))

func _pick_event() -> Dictionary:
	var pool: Array[Dictionary] = _get_pool()
	var fresh: Array = []
	for e in pool:
		if not (e["id"] in GameState._seen_events):
			fresh.append(e)
	if fresh.is_empty(): fresh = pool

	var chosen: Dictionary = fresh[randi() % fresh.size()]
	_remember(chosen["id"])
	return chosen

func _get_pool() -> Array[Dictionary]:
	return [
		{"id": "scrap_heap", "type": Category.RESOURCE, "title": "废弃零件堆", "desc": "散落的零件中还残留着可用算力。", "choice_a": "翻找 (+15 金币)", "choice_b": "拆芯片 (1 件普通道具)"},
		{"id": "black_vendor", "type": Category.RESOURCE, "title": "黑市贩子", "desc": "披着斗篷的贩子压低声音兜售来路不明的芯片。", "choice_a": "买可疑道具 (5 金换 1 稀有)", "choice_b": "举报 (+20 金币)"},
		{"id": "fault_protocol", "type": Category.RISK, "title": "故障协议", "desc": "终端要求你确认一份来源不明的系统备份。", "choice_a": "确认备份 (清除半同化)", "choice_b": "拒绝协议 (下局 6 颗骰子)"},
		{"id": "runaway_die", "type": Category.RISK, "title": "失控骰子", "desc": "一颗失控的骰子在管道间来回跳动。", "choice_a": "抓住 (下局一颗固定⑥)", "choice_b": "让它跳 (+30 金币)"},
		{"id": "memory_fragment", "type": Category.NARRATIVE, "title": "记忆残片", "desc": "残片中保存着上一位挑战者最后留下的资源。", "choice_a": "继承道具 (1 件稀有)", "choice_b": "继承金币 (+40)"},
		{"id": "last_stand", "type": Category.RISK, "title": "破釜沉舟", "desc": "你可以提前破坏 Boss 的骰子，但代价会立刻侵入你的系统。", "choice_a": "孤注一掷 (Boss 对手−1骰，开场半同化)", "choice_b": "保存体力 (无效果)"},
	]

## Retained only as narrative source material; it is not part of the v1.0 event pool.
func _get_legacy_pool() -> Array[Dictionary]:
	return [
		# === INTEL — 情报类：揭示王国秘密 ===

		{"id": "intel_chip", "type": Category.INTEL, "stages": [0],
		 "title": "革命者的残片", "desc": "锈铁堆里埋着一块烧焦的记忆芯片。\n插上后，一段模糊的全息投影闪了三秒:\n'…国王不是神。他的骰子，和我的一样，只是塑料方块。'",
		 "choice_a": "收下芯片 (获得重摇石)", "choice_b": "翻找更多残片 (随机普通道具)"},

		{"id": "intel_ledger", "type": Category.INTEL,
		 "title": "国王的账本", "desc": "一本半烧毁的皇家审计日志。\n「今日淘汰 47 名不合格公民。算力预算超额 300%。\n备注: 国王下令增铸骰子，规格与民用骰一致。」",
		 "choice_a": "记下情报 (获得克隆骰)", "choice_b": "撕掉当废品卖 (+20 点)"},

		{"id": "intel_whisper", "type": Category.INTEL, "stages": [1],
		 "title": "地下广播", "desc": "赌场的暗角，一台非法无线电在低语:\n「…独眼龙不是天生的。她是皇家筛选中被淘汰的侍卫长。\n国王挖掉了她的一只眼摄像头——因为她看到了不该看的东西。」",
		 "choice_a": "记下这个秘密 (+50 点)", "choice_b": "关掉，太危险了 (随机普通道具)"},

		# === RESOURCE — 资源类：拾取王国遗产 ===

		{"id": "res_vendor", "type": Category.RESOURCE, "stages": [0, 1],
		 "title": "被遗弃者的小摊", "desc": "一个没了腿的清洁机器人守着台生锈的交换终端。\n「国王不需要我打扫了。他说他需要一个标杆——\n看，一个连算力都没有的废物就是最好的反面教材。」",
		 "choice_a": "暴力破拆 (70% 获得随机道具)", "choice_b": "砸开硬取 (+25 点，触发警报有感染风险)"},

		{"id": "res_chips", "type": Category.RESOURCE,
		 "title": "皇家筛选场", "desc": "你路过一间废弃工厂，流水线还在运作。\n传送带上排列着标有「不合格」的芯片。\n每个芯片上都刻着一行小字: '我不够格。我接受淘汰。'",
		 "choice_a": "拾取残次品 (+15 点)", "choice_b": "全吞——管它病毒 (+30 点，35%感染)"},

		{"id": "res_toolbox", "type": Category.RESOURCE,
		 "title": "抵抗军的死信箱", "desc": "一根管道背后嵌着一只防爆工具箱。\n密码锁显示: '输入你的淘汰编号。'\n盒盖上焊着一行字: '我们没有编号。我们只是被划掉了名字。'",
		 "choice_a": "撬开取货 (获得随机道具)", "choice_b": "拆芯片卖钱 (+20 点)"},

		# === RISK — 风险类：挑战王国的秩序 ===

		{"id": "risk_terminal", "type": Category.RISK, "stages": [1],
		 "title": "禁区的终端", "desc": "一扇标着「皇家禁地」的门虚掩着。\n里面的终端正在运行一段自毁序列，屏幕闪烁:\n「叛徒数据库即将泄露。请输入终止码。输错三次 = 全面消毒。」",
		 "choice_a": "输入终止码 (50% 清感染 / 50% +1感染)", "choice_b": "离开禁区 (安全)"},

		{"id": "risk_arena", "type": Category.RISK,
		 "title": "骰子审判", "desc": "一个披着法官袍的机器骰子立在废墟中央。\n「你不是来推翻国王的，你是来取代他的——\n每个挑战者都这么说。证明给我看。」",
		 "choice_a": "接受审判 (55%赢=+15点+道具 / 输=感染)", "choice_b": "低头走过 (安全)"},

		{"id": "risk_recycle", "type": Category.RISK,
		 "title": "算力深渊", "desc": "深渊底部是一台巨型碾骰机，成千上万的骰子被粉碎。\n告示:「不合格的骰子与不合格的公民一同回收。\n算力不养闲人。骰子之神注视着你。」",
		 "choice_a": "赌一把投骰 (+5~35 点随机)", "choice_b": "捡边角料 (+5 点保底)"},

		# === NARRATIVE — 叙事类：揭示历史真相 ===

		{"id": "narr_robot", "type": Category.NARRATIVE, "stages": [3],
		 "title": "上一任国王", "desc": "终极赌场的光辉之下，墙角蜷着一个屏幕破碎的老旧机器人。\n它的屏幕上弹出一串颤抖的文字:\n「我赢了骰子之神。他微笑了一下，然后把我变成了这副模样。\n赢了骰子，输了王国。」",
		 "choice_a": "问: 那为什么不阻止他？ (了解历史)", "choice_b": "帮不了你 (获得道具)"},

		{"id": "narr_graffiti", "type": Category.NARRATIVE, "stages": [0, 1, 2],
		 "title": "墙壁在说话", "desc": "墙上涂着一行又一行被反复划掉的字:\n'0: CRASHED' '1: CRASHED' '2: CRASHED'\n……一直划到 '14: CRASHED'。\n最下面，有人颤着手写: '15号。轮到你了。别怕。'",
		 "choice_a": "写下祝福 (下局对手 bluff 降低)", "choice_b": "沉默离去 (无事发生)"},

		{"id": "narr_mirror", "type": Category.NARRATIVE,
		 "title": "我是谁", "desc": "赌场的一面反光墙映出你的脸——\n你突然愣住。屏幕上的像素脸，隐约透出上一任勇士的残影。\n那些死去的挑战者，残存记忆碎片烙在了每一任继承者的屏幕里。",
		 "choice_a": "接受这段记忆 (获得传说道具)", "choice_b": "强迫冷静 (+10 点)"},
	]

func _on_choice_a(ev: Dictionary, result_label: Label) -> void:
	var r: String = _apply_result(ev, "a")
	result_label.text = r
	GameState.event_notification = r
	GameState.events_completed += 1
	while _pending_discard:
		await get_tree().process_frame
	await get_tree().create_timer(2.2).timeout
	if not is_instance_valid(result_label): return
	if GameState.assimilation_count >= GameState.MAX_ASSIMILATION:
		if _flow and _flow.has_method("handle_event_death"):
			_flow.handle_event_death()
		return
	_emit_done()

func _on_choice_b(ev: Dictionary, result_label: Label) -> void:
	var r: String = _apply_result(ev, "b")
	result_label.text = r
	GameState.event_notification = r
	GameState.events_completed += 1
	while _pending_discard:
		await get_tree().process_frame
	await get_tree().create_timer(2.2).timeout
	if not is_instance_valid(result_label): return
	if GameState.assimilation_count >= GameState.MAX_ASSIMILATION:
		if _flow and _flow.has_method("handle_event_death"):
			_flow.handle_event_death()
		return
	_emit_done()

func _apply_result(ev: Dictionary, choice: String) -> String:
	var eid: String = ev["id"]
	var stage_bonus: int = 2 if (_stage >= 2 and ev["type"] == Category.RESOURCE) else 1

	match eid:
		"scrap_heap":
			if choice == "a":
				GameState.add_gold(15)
				return "翻找完成，获得 15 金币。"
			var item_id: String = _give_item("common")
			return "拆出一枚可用芯片：%s。" % _item_name(item_id)
		"black_vendor":
			if choice == "a":
				if not GameState.spend_gold(5):
					return "金币不足，交易取消。"
				var item_id: String = _pick_rare()
				return "支付 5 金币，获得：%s。" % _item_name(item_id)
			GameState.add_gold(20)
			return "举报成功，获得 20 金币。"
		"fault_protocol":
			if choice == "a":
				GameState.clear_assimilation()
				return "备份恢复完成，半同化状态已清除。"
			GameState.set_bonus_dice(1)
			return "协议已拒绝，下一局以 6 颗骰子开场。"
		"runaway_die":
			if choice == "a":
				GameState.next_battle_fixed_six = true
				return "你抓住了骰子，下一局有一颗固定为⑥。"
			GameState.add_gold(30)
			return "你让它继续跳动，获得 30 金币。"
		"memory_fragment":
			if choice == "a":
				var item_id: String = _pick_rare()
				return "继承了上一位挑战者的道具：%s。" % _item_name(item_id)
			GameState.add_gold(40)
			return "继承了残片中的 40 金币。"
		"last_stand":
			if choice == "a":
				GameState.next_boss_dice_penalty = 1
				GameState.next_boss_start_assimilated = true
				return "破坏程序已经植入：Boss 对手开场各少 1 骰，你将以半同化状态迎战。"
			return "你保存了体力，没有额外效果。"
		# INTEL
		"intel_chip":
			if choice == "a":
				GameState.add_consumable_item("reroll_stone")
				return "芯片里的加密序列是一段重摇程序。\n「记住，骰子只是塑料方块。」"
			var item: String = _give_item("common")
			return "你翻出了更多残片。这一片里藏着一把旧骰子——\n不知是谁的遗物。"
		"intel_ledger":
			if choice == "a":
				GameState.add_consumable_item("clone_die")
				return "账本的折角页粘着一片克隆芯片。\n国王的骰子，和你的，能有多大的不同？"
			GameState.add_gold(20)
			return "你把账本当废品卖了 20 点。\n买家瞟了一眼内容，脸色大变。"
		"intel_whisper":
			if choice == "a":
				GameState.add_gold(50)
				return "独眼龙曾是国王的亲卫。\n你记住了这个名字——也许战场上用得上。"
			var item: String = _give_item("common")
			return "你悄悄关掉了无线电。\n从机器底部的暗格摸到一件它藏的东西。"

		# RESOURCE
		"res_vendor":
			if choice == "a":
				if randf() < 0.7:
					var item: String = _give_item("any")
					return "终端爆出一阵电火花，掉出几件存货。\n老人笑了一声: '拿去，别像我一样。'"
				return "空荡荡的货架。老清洁工叹了口气。\n'也好，至少你没伤着自己。'"
			GameState.add_gold(25 * stage_bonus)
			if randf() < 0.3:
				GameState.assimilate()
				return "警铃大作。卫兵的程序序列侵入了你的系统。\n获得 %d 点，但被感染。" % (25 * stage_bonus)
			return "你砸开了后面的保险柜。\n%d 点。老人没有——或者说，来不及阻止。" % (25 * stage_bonus)
		"res_chips":
			if choice == "a":
				GameState.add_gold(15 * stage_bonus)
				return "你拾起几片完好的。\n上面刻着的字让你沉默了很久: '我接受。'"
			GameState.add_gold(30 * stage_bonus)
			if randf() < 0.35:
				GameState.assimilate()
				return "你吞下了太多。残次品的病毒在你体内炸开。\n获得 %d 点，但被感染。" % (30 * stage_bonus)
			return "居然没事。%d 点净收。\n也许你真的是那个例外。" % (30 * stage_bonus)
		"res_toolbox":
			if choice == "a":
				var item: String = _give_item("any")
				return "工具箱里躺着一件老式武装。\n盒盖上多了一行新刻的字: '15号，轮到你了。'"
			GameState.add_gold(20 * stage_bonus)
			return "你把芯片拆出来卖了 %d 点。\n抵抗军不会怪你的——活下来比什么都重要。" % (20 * stage_bonus)

		# RISK
		"risk_terminal":
			if choice == "a":
				if randf() < 0.5:
					GameState.clear_assimilation()
					return "终端嗡鸣着清空了你的感染。\n最后一行字浮现: 「叛徒名单已加密。祝你好运。」"
				GameState.assimilate()
				return "滴滴两声。消毒程序启动了——\n「检测到未授权的访问。正在清除威胁。」"
			return "你退出了禁区。\n有些秘密，不需要现在揭开。"
		"risk_arena":
			if choice == "a":
				if randf() < 0.55:
					GameState.add_gold(15)
					var item: String = _give_item("any")
					return "你赢了。法官的骰子碎了一地。\n「看来你是认真的。」"
				GameState.assimilate()
				return "法官默然。骰子落定的瞬间感染扩散——\n「下一个。」"
			return "你低下了头。\n法官没有拦你。它见过太多低头的挑战者了。"
		"risk_recycle":
			if choice == "a":
				var pts: int = 5 + randi() % 31
				GameState.add_gold(pts)
				return "粉碎机轰鸣。\n%d 点算力从废骰中析出——这些曾是别人的命。" % pts
			GameState.add_gold(5)
			return "你捡了边角料，5 点。\n够买一张入场券了。"

		# NARRATIVE
		"narr_robot":
			if choice == "a":
				return "「他输给我的那天，只是微笑了一下。\n你知道吗——骰子之神，曾经也只是一个挑战者。」\n老国王的屏幕暗了下去。"
			var item: String = _give_item("any")
			return "你无法说服自己帮他。\n只是从他的遗骸里捡起一件还能用的东西。"
		"narr_graffiti":
			if choice == "a": return "你写下: '15号来过了。我会打开这条路。\n16号，轮到你了。'"
			return "你转身离开。墙上的 15 个划痕在瓦斯光下沉默。"
		"narr_mirror":
			if choice == "a":
				var item: String = _give_item("legendary")
				return "记忆之流贯穿了你。\n你看到了 14 张不同的脸——然后它们消失了，只留下一个骰子。"
			GameState.add_gold(10)
			return "你深吸一口气，强迫系统冷静。\n那些脸暂时退去，留下 10 点算力。"
	return ev.get("result_%s" % choice, "…")

## Give a random item with specified rarity filter.
## "common" = only common, "any" = common 70% / rare 25% / legendary 5%, "legendary" = legendary weighted.
func _give_item(filter: String) -> String:
	var roll: float = randf()
	if filter == "common":
		return _pick_common()
	elif filter == "legendary":
		# 小概率传说道具: 5% legendary, otherwise rare
		return _pick_legendary() if roll < 0.05 else _pick_rare()
	else:  # "any": 60% common / 30% rare / 10% legendary
		if roll < 0.60:
			return _pick_common()
		elif roll < 0.90:
			return _pick_rare()
		return _pick_legendary()

func _pick_common() -> String:
	var pool: Array = _filter_by_rarity(0)
	if pool.is_empty(): return "reroll_stone"
	var pick: String = pool[randi() % pool.size()]
	GameState.add_consumable_item(pick)
	return pick

func _pick_rare() -> String:
	var pool: Array = _filter_by_rarity(1)
	if pool.is_empty(): return "freeze_die"
	var pick: String = pool[randi() % pool.size()]
	GameState.add_consumable_item(pick)
	return pick

func _pick_legendary() -> String:
	var pool: Array = _filter_by_rarity(2)
	if pool.is_empty(): return "fate_die"
	var pick: String = pool[randi() % pool.size()]
	GameState.add_consumable_item(pick)
	return pick

func _filter_by_rarity(rarity: int) -> Array[String]:
	var result: Array[String] = []
	for item in ItemData.get_unlocked_pool():
		match rarity:
			0: if item.rarity == ItemData.Rarity.COMMON: result.append(item.item_id)
			1: if item.rarity == ItemData.Rarity.RARE: result.append(item.item_id)
			2: if item.rarity == ItemData.Rarity.LEGENDARY: result.append(item.item_id)
	return result

func _item_name(item_id: String) -> String:
	var info: ItemData = GameState.get_item_info(item_id)
	return info.item_name if info else item_id

func _weighted_pick(weights: Array) -> int:
	var total: int = 0
	for w in weights: total += w
	var roll: int = randi() % total
	var acc: int = 0
	for i in range(weights.size()):
		acc += weights[i]
		if roll < acc: return i
	return weights.size() - 1

func _remember(eid: String) -> void:
	GameState._seen_events.append(eid)

func _emit_done() -> void:
	if _flow and _flow.has_method("emit_node_done"):
		_flow.emit_node_done()

func _on_discard_prompt(new_item_id: String) -> void:
	_pending_discard = true
	var popup := Panel.new()
	popup.position = Vector2(290, 440); popup.size = Vector2(700, 220)
	add_child(popup)
	var title := Label.new()
	title.text = "道具已满：选择一件替换，或放弃新道具"
	title.position = Vector2(20, 12); title.size = Vector2(660, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.add_child(title)
	for i in range(GameState.consumable_items.size()):
		var idx: int = i
		var button := Button.new()
		var info = GameState.get_item_info(GameState.consumable_items[i])
		button.text = "替换 %s" % (info.item_name if info else GameState.consumable_items[i])
		button.position = Vector2(35 + i * 215, 60); button.size = Vector2(200, 44)
		button.pressed.connect(func():
			GameState.force_swap_consumable(new_item_id, idx)
			_pending_discard = false
			popup.queue_free()
			EventBus.discard_resolved.emit())
		popup.add_child(button)
	var cancel := Button.new()
	cancel.text = "放弃新道具"
	cancel.position = Vector2(250, 130); cancel.size = Vector2(200, 44)
	cancel.pressed.connect(func():
		_pending_discard = false
		popup.queue_free()
		EventBus.discard_resolved.emit())
	popup.add_child(cancel)
