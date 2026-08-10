class_name CombatDieWidget
extends Control

signal pressed(index: int)

const FACE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/dice/die_1.png"),
	preload("res://assets/dice/die_2.png"),
	preload("res://assets/dice/die_3.png"),
	preload("res://assets/dice/die_4.png"),
	preload("res://assets/dice/die_5.png"),
	preload("res://assets/dice/die_6.png"),
]
const HIDDEN_TEXTURE: Texture2D = preload("res://assets/dice/die_hidden.png")

var die_index := -1
var value := 1
var is_hidden := false
var locked := false
var protected := false
var blocked := false
var selected := false
var hovered := false
var lock_rounds := 0
var modified := 0
var render_face := true

func setup(index: int, data: Dictionary, is_selected: bool = false, show_face: bool = true) -> void:
	die_index = index
	value = clampi(int(data.get("value", 1)), 1, 6)
	is_hidden = bool(data.get("hidden", false))
	locked = bool(data.get("locked", false))
	protected = bool(data.get("protected", false))
	blocked = bool(data.get("player_blocked", false))
	lock_rounds = int(data.get("lock_rounds", 0))
	modified = int(data.get("modified", 0))
	selected = is_selected
	render_face = show_face
	custom_minimum_size = Vector2(64, 64)
	size = Vector2(64, 64)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = _tooltip()
	queue_redraw()

func _ready() -> void:
	mouse_entered.connect(func(): hovered = true; queue_redraw())
	mouse_exited.connect(func(): hovered = false; queue_redraw())

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(die_index)
		accept_event()

func _draw() -> void:
	var face_rect := Rect2(4, 4, 56, 56)
	if locked:
		_draw_glow(face_rect.grow(3), Color("e9b34f"), 3)
	if protected:
		_draw_glow(face_rect.grow(5), Color("48d5cf"), 2)
	if blocked:
		_draw_glow(face_rect.grow(7), Color("e45555"), 2)
	if selected or hovered:
		_draw_glow(face_rect.grow(2), Color("f4d68a"), 2)
	if modified > 0:
		_draw_glow(face_rect.grow(1), Color("b58cff"), 1)
	if render_face:
		var texture := HIDDEN_TEXTURE if is_hidden else FACE_TEXTURES[value - 1]
		var target := Rect2(11, 11, 42, 42) if is_hidden else face_rect
		draw_texture_rect(texture, target, false)
	if lock_rounds > 0:
		draw_rect(Rect2(10, 54, 44, 7), Color("6a4c2b"), true)
		draw_string(ThemeDB.fallback_font, Vector2(27, 61), str(lock_rounds), HORIZONTAL_ALIGNMENT_CENTER, 12, 10, Color("f3d27b"))

func _draw_glow(rect: Rect2, color: Color, width: float) -> void:
	draw_rect(rect, Color(color, 0.16), true)
	draw_rect(rect, Color(color, 0.92), false, width)

func _tooltip() -> String:
	var parts: Array[String] = ["暗骰：点数不可见" if is_hidden else "点数：%d" % value]
	if locked: parts.append("已锁定：基础投掷时保留，剩余 %d 轮" % lock_rounds)
	if protected: parts.append("保护：可抵挡下一次敌方影响")
	if blocked: parts.append("封锁：当前不能被玩家卡牌修改")
	if modified > 0: parts.append("本轮已被修改 %d 次" % modified)
	return "\n".join(parts)
