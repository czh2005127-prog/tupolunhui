## Luxury gold-framed button for the main menu — V2 (fixed overlap, thicker gold, bigger icons).
class_name LuxButton
extends Control

# === Configuration ===
enum ThemeColor { GOLD, TEAL, RED, GRAY, DISABLED }
enum State { IDLE, HOVER, PRESSED }

var label_text: String = ""
var icon_left_text: String = ""
var icon_right_text: String = ""
var button_width: float = 360.0
var button_height: float = 54.0
var theme_color: ThemeColor = ThemeColor.GOLD
var enabled: bool = true

var _state: State = State.IDLE

# === Color palette (matches MainMenu V5 spec) ===
const GOLD_HI := Color(0.91, 0.773, 0.416)   # #E8C56A
const GOLD_MID := Color(0.659, 0.486, 0.18)  # #A87C2E
const GOLD_LOW := Color(0.431, 0.306, 0.094) # #6E4E18

const TEAL := Color(0.357, 0.788, 0.651)     # #5BC9A6
const TEAL_DARK := Color(0.18, 0.541, 0.471) # #2E8A78

const RED := Color(0.89, 0.29, 0.29)        # #E34A4A
const RED_DARK := Color(0.604, 0.157, 0.157) # #9A2828

const GRAY := Color(0.722, 0.722, 0.69)     # #B8B8B0
const GRAY_DARK := Color(0.478, 0.478, 0.447) # #7A7A72

const DISABLED_TEXT := Color(0.353, 0.353, 0.322) # #5A5A52
const LEATHER_BG := Color(0.102, 0.067, 0.039)

const PANEL_BG_DEFAULT := Color(0.082, 0.055, 0.039)  # darker default
const PANEL_BG_RED := Color(0.082, 0.039, 0.039)
const PANEL_BG_TEAL := Color(0.039, 0.082, 0.063)
const PANEL_BG_GRAY := Color(0.063, 0.063, 0.047)
const PANEL_BG_DISABLED := Color(0.039, 0.039, 0.031)

var on_pressed: Callable = Callable()

signal pressed

func _ready() -> void:
	custom_minimum_size = Vector2(button_width, button_height)
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	if enabled:
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)
		gui_input.connect(_on_gui_input)
	queue_redraw()

func _on_mouse_entered() -> void:
	if not enabled: return
	_state = State.HOVER
	queue_redraw()

func _on_mouse_exited() -> void:
	_state = State.IDLE
	queue_redraw()

func _on_gui_input(event: InputEvent) -> void:
	if not enabled: return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_state = State.PRESSED
				queue_redraw()
			else:
				if _state == State.PRESSED:
					_state = State.HOVER
					queue_redraw()
					_emit_pressed()
	elif event is InputEventKey and event.is_action_pressed("ui_accept"):
		_emit_pressed()

func _emit_pressed() -> void:
	if on_pressed.is_valid():
		on_pressed.call()
	pressed.emit()

func setup(text: String, icon_l: String, icon_r: String, w: float, h: float, c: ThemeColor, is_enabled: bool) -> void:
	label_text = text
	icon_left_text = icon_l
	icon_right_text = icon_r
	button_width = w
	button_height = h
	theme_color = c
	enabled = is_enabled
	if is_node_ready():
		custom_minimum_size = Vector2(w, h)
		mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
		queue_redraw()

# === Outer gold frame outline (gothic sharp corner shape) ===
# Designed at 360x54 reference, scaled to actual size
func _get_frame_outline() -> PackedVector2Array:
	var sx := button_width / 360.0
	var sy := button_height / 54.0
	var raw := [
		[6, 3], [24, 3], [28, 7], [332, 7], [336, 3], [354, 3],
		[354, 14], [350, 18], [350, 36], [354, 40], [354, 51],
		[336, 51], [332, 47], [28, 47], [24, 51], [6, 51],
		[6, 40], [10, 36], [10, 18], [6, 14]
	]
	var pts := PackedVector2Array()
	for p in raw:
		pts.append(Vector2(p[0] * sx, p[1] * sy))
	return pts

# === Inner panel outline (slightly inset gothic) ===
func _get_inner_outline() -> PackedVector2Array:
	var sx := button_width / 360.0
	var sy := button_height / 54.0
	var raw := [
		[10, 7], [26, 7], [28, 10], [332, 10], [334, 7], [350, 7],
		[350, 16], [348, 19], [348, 35], [350, 38], [350, 47],
		[334, 47], [332, 44], [28, 44], [26, 47], [10, 47],
		[10, 38], [12, 35], [12, 19], [10, 16]
	]
	var pts := PackedVector2Array()
	for p in raw:
		pts.append(Vector2(p[0] * sx, p[1] * sy))
	return pts

func _get_accent_color() -> Color:
	match theme_color:
		ThemeColor.TEAL: return TEAL
		ThemeColor.RED: return RED
		ThemeColor.GRAY: return GRAY
		ThemeColor.DISABLED: return DISABLED_TEXT
		_: return GOLD_HI

func _get_inner_panel_color() -> Color:
	if not enabled: return PANEL_BG_DISABLED
	match theme_color:
		ThemeColor.GOLD: return PANEL_BG_DEFAULT
		ThemeColor.TEAL: return PANEL_BG_TEAL
		ThemeColor.RED: return PANEL_BG_RED
		ThemeColor.GRAY: return PANEL_BG_GRAY
		_: return PANEL_BG_DEFAULT

func _draw() -> void:
	var accent_color: Color = _get_accent_color()
	var panel_bg: Color = _get_inner_panel_color()

	# Determine gold frame color
	var gold_color := GOLD_HI if enabled else Color(0.541, 0.455, 0.282)

	# Hover/pressed state adjustments
	match _state:
		State.HOVER:
			gold_color = gold_color.lightened(0.12)
			accent_color = accent_color.lightened(0.12)
			panel_bg = panel_bg.lightened(0.15)
		State.PRESSED:
			gold_color = gold_color.darkened(0.35)
			accent_color = accent_color.darkened(0.35)
			panel_bg = panel_bg.darkened(0.30)

	# === LAYER 1: Outer gold gothic frame (filled polygon) ===
	draw_polygon(_get_frame_outline(), PackedColorArray([gold_color]))

	# === LAYER 2: Dark inner stripe (between outer frame and inner panel) ===
	# This creates the leather "depth" between gold border and panel
	var outer_frame := _get_frame_outline()
	var inner_panel := _get_inner_outline()
	# Draw leather bg BEHIND inner panel, but ABOVE outer frame
	draw_polygon(outer_frame, PackedColorArray([Color(0.082, 0.067, 0.039)]))
	# Redraw outer frame on top to restore gold
	draw_polygon(outer_frame, PackedColorArray([gold_color]))

	# === LAYER 3: Inner gothic panel (dark fill) ===
	draw_polygon(inner_panel, PackedColorArray([panel_bg]))

	# === LAYER 4: Inner border line (decorative) ===
	var sx := button_width / 360.0
	var sy := button_height / 54.0
	var ib_pts := PackedVector2Array([
		Vector2(16 * sx, 13 * sy),
		Vector2((360 - 16) * sx, 13 * sy),
		Vector2((360 - 16) * sx, (54 - 13) * sy),
		Vector2(16 * sx, (54 - 13) * sy)
	])
	draw_polyline(ib_pts, gold_color.darkened(0.4), 1.5, true)

	# === LAYER 5: Gold corner accents ===
	_draw_corner_accents(gold_color, sx, sy)

	# === LAYER 6: Text + Icons ===
	_draw_all_text(gold_color, accent_color)

func _draw_corner_accents(gold_color: Color, sx: float, sy: float) -> void:
	var corner_len := 10.0
	var cor := Color(0.91, 0.773, 0.416) if not _state == State.PRESSED else gold_color
	if _state == State.PRESSED:
		cor = gold_color

	# Top-left
	draw_line(Vector2(16 * sx, 13 * sy), Vector2((16 + corner_len) * sx, 13 * sy), cor, 2.5)
	draw_line(Vector2(16 * sx, 13 * sy), Vector2(16 * sx, (13 + corner_len) * sy), cor, 2.5)
	# Top-right
	draw_line(Vector2((360 - 16) * sx, 13 * sy), Vector2((360 - 16 - corner_len) * sx, 13 * sy), cor, 2.5)
	draw_line(Vector2((360 - 16) * sx, 13 * sy), Vector2((360 - 16) * sx, (13 + corner_len) * sy), cor, 2.5)
	# Bottom-left
	draw_line(Vector2(16 * sx, (54 - 13) * sy), Vector2((16 + corner_len) * sx, (54 - 13) * sy), cor, 2.5)
	draw_line(Vector2(16 * sx, (54 - 13) * sy), Vector2(16 * sx, (54 - 13 - corner_len) * sy), cor, 2.5)
	# Bottom-right
	draw_line(Vector2((360 - 16) * sx, (54 - 13) * sy), Vector2((360 - 16 - corner_len) * sx, (54 - 13) * sy), cor, 2.5)
	draw_line(Vector2((360 - 16) * sx, (54 - 13) * sy), Vector2((360 - 16) * sx, (54 - 13 - corner_len) * sy), cor, 2.5)

func _draw_all_text(gold_color: Color, accent_color: Color) -> void:
	var cn_font := _get_font()

	# === Define safe text area (between left and right icons) ===
	var icon_size := 24
	var icon_offset_x := 28.0  # distance from button edge to icon center
	var text_size := 22

	# Left icon: position at left edge
	if icon_left_text != "":
		var icon_color := accent_color if enabled else DISABLED_TEXT
		# Draw as a 42px box centered at icon_offset_x
		var box := Rect2(Vector2(8, (button_height - 36) / 2.0), Vector2(36, 36))
		draw_rect(box, _get_icon_bg_color(), true)
		draw_rect(box, icon_color, false, 1.5)
		_draw_centered_in_box(cn_font, icon_left_text, box, icon_size, icon_color)

	# Right icon: position at right edge
	if icon_right_text != "":
		var icon_color := accent_color if enabled else DISABLED_TEXT
		var box := Rect2(Vector2(button_width - 44, (button_height - 36) / 2.0), Vector2(36, 36))
		# Only draw bg for buttons that have ornamental icons (dice, sun)
		# Don't draw bg for simple chevron/play arrows
		if icon_right_text in ["🎲", "🔒", "🔓", "☀"]:
			draw_rect(box, _get_icon_bg_color(), true)
			draw_rect(box, icon_color, false, 1.5)
		_draw_centered_in_box(cn_font, icon_right_text, box, icon_size, icon_color)

	# Center label - safe area between icons
	var label_color := accent_color if enabled else DISABLED_TEXT
	var label_safe_x_left := 56.0   # past left icon area
	var label_safe_x_right := button_width - 56.0  # before right icon area
	var safe_w := label_safe_x_right - label_safe_x_left
	var text_w := cn_font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, text_size).x
	var text_x := label_safe_x_left + (safe_w - text_w) / 2.0
	var text_y := (button_height - text_size) / 2.0 + text_size - 4
	draw_string(cn_font, Vector2(text_x, text_y), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, label_color)

func _get_icon_bg_color() -> Color:
	if not enabled: return PANEL_BG_DISABLED
	match theme_color:
		ThemeColor.GOLD: return Color(0.102, 0.067, 0.039)
		ThemeColor.TEAL: return Color(0.039, 0.082, 0.063)
		ThemeColor.RED: return Color(0.102, 0.039, 0.039)
		ThemeColor.GRAY: return Color(0.063, 0.063, 0.047)
		_: return Color(0.102, 0.067, 0.039)

func _draw_centered_in_box(font: Font, text: String, box: Rect2, font_size: int, col: Color) -> void:
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var x := box.position.x + (box.size.x - ts.x) / 2.0
	var y := box.position.y + (box.size.y - ts.y) / 2.0 + ts.y - 4
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)

func _get_font() -> Font:
	var font := ThemeDB.fallback_font
	var font_paths := [
		"res://assets/fonts/SourceHanSansCN-Regular.otf",
		"res://assets/fonts/NotoSansCJK-Regular.otf",
		"res://assets/fonts/msyh.ttc",
		"res://assets/fonts/simhei.ttf",
		"res://fonts/SourceHanSansCN-Regular.otf",
	]
	for p in font_paths:
		if ResourceLoader.exists(p):
			return load(p)
	return font
