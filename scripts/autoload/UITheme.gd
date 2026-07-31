## Central UI Theme — colors, fonts, spacing, and reusable widget factories.
## Replaces scattered hardcoded colors and _make_btn/_make_label patterns.
extends Node

# ── Color Palette ──────────────────────────────────────────

## Backgrounds
const BG_DEEP: Color         = Color(0.025, 0.025, 0.03)       # 最暗底色
const BG_PANEL: Color        = Color(0.04, 0.04, 0.06)         # 面板暗色
const BG_CARD: Color         = Color(0.08, 0.08, 0.10)         # 卡片底色
const BG_LEFT: Color         = Color(0.067, 0.067, 0.083)      # 左侧面板
const BG_SLOT: Color         = Color(0.10, 0.10, 0.11)         # 道具槽位

## Borders
const BORDER_SUBTLE: Color   = Color(0.16, 0.16, 0.16)         # 普通边框
const BORDER_DIM: Color      = Color(0.12, 0.12, 0.13)         # 更淡的边
const BORDER_STRONG: Color   = Color(0.25, 0.25, 0.25)         # 强边框

## Accent colors
const GOLD: Color            = Color(0.98, 0.78, 0.29)         # 金色主色调
const GREEN: Color           = Color(0.36, 0.79, 0.65)         # 骰子局/成功
const BLUE: Color            = Color(0.22, 0.50, 0.87)         # 确认/小点数
const RED: Color             = Color(0.89, 0.29, 0.29)         # 质疑/大点数/危险
const PINK: Color            = Color(0.83, 0.33, 0.49)         # 商店
const CYAN: Color            = Color(0.52, 0.72, 0.92)         # 稀有道具
const ORANGE: Color          = Color(0.94, 0.59, 0.16)         # 即用道具标题
const PURPLE: Color          = Color(0.33, 0.29, 0.72)         # 点数1

## Semantic
const SUCCESS: Color         = GREEN
const DANGER: Color          = RED
const WARNING: Color         = ORANGE
const INFO: Color            = CYAN

## Text
const TEXT_PRIMARY: Color    = Color(0.90, 0.90, 0.88)         # 主文字
const TEXT_SECONDARY: Color  = Color(0.60, 0.60, 0.58)         # 次要文字
const TEXT_MUTED: Color      = Color(0.35, 0.35, 0.35)         # 禁用/灰色
const TEXT_DIM: Color        = Color(0.25, 0.25, 0.25)         # 更淡
const TEXT_INVERSE: Color    = Color(0.10, 0.10, 0.10)         # 深色底上浅字

## Rarity
const RARITY_COMMON: Color   = Color(0.70, 0.70, 0.66)
const RARITY_RARE: Color     = CYAN
const RARITY_LEGENDARY: Color = GOLD

## Selection / highlight
const HIGHLIGHT: Color       = Color(0.36, 0.79, 0.65)         # 选中绿色
const HOVER_BRIGHT: Color    = Color(0.15, 0.15, 0.18)         # hover 高亮

## Virus
const VIRUS_DEAD: Color      = Color(0.85, 0.18, 0.18)
const VIRUS_CLEAN: Color     = Color(0.06, 0.06, 0.06)

# ── Typography ─────────────────────────────────────────────

const FONT_TITLE: int        = 42     # 大标题
const FONT_HEADING: int      = 20     # 区段标题
const FONT_SUBHEADING: int   = 15     # 子标题
const FONT_BODY: int         = 13     # 正文
const FONT_SMALL: int        = 11     # 小字
const FONT_CAPTION: int      = 9      # 说明文字
const FONT_DICE: int         = 48     # 骰子点数

# ── Spacing ─────────────────────────────────────────────────

const SPACING_XS: int        = 4
const SPACING_SM: int        = 8
const SPACING_MD: int        = 12
const SPACING_LG: int        = 16
const SPACING_XL: int        = 24
const RADIUS_SM: int         = 6      # 小圆角
const RADIUS_MD: int         = 8      # 中圆角
const RADIUS_LG: int         = 12     # 大圆角

# ── Layout ──────────────────────────────────────────────────

const SCREEN_W: int          = 1280
const SCREEN_H: int          = 720
const LEFT_PANEL_W: int      = 280
const CONTENT_X: int         = LEFT_PANEL_W + SPACING_SM    # = 288
const CONTENT_W: int         = SCREEN_W - CONTENT_X - SPACING_SM  # ≈ 980

# ── Factory Methods ─────────────────────────────────────────

## Create a styled ColorRect (panel background).
static func panel(parent: Control, pos: Vector2, size: Vector2, bg: Color = BG_PANEL) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.color = bg
	parent.add_child(r)
	return r

## Add a border to an existing ColorRect (4 edge strips).
static func add_border(rect: ColorRect, w: int, h: int, col: Color = BORDER_SUBTLE, thickness: int = 1) -> void:
	for i in range(4):
		var edge := ColorRect.new()
		var is_horizontal: bool = i < 2
		var pos_idx: int = i % 2
		edge.color = col
		if is_horizontal:
			edge.position = Vector2(0, pos_idx * (h - thickness))
			edge.size = Vector2(w, thickness)
		else:
			edge.position = Vector2(pos_idx * (w - thickness), 0)
			edge.size = Vector2(thickness, h)
		rect.add_child(edge)

## Create a styled Label.
static func label(parent: Control, text: String, pos: Vector2, size: Vector2, col: Color = TEXT_PRIMARY, font_size: int = FONT_BODY) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l

## Create a rich text label (with BBCode support).
static func rich_label(parent: Control, pos: Vector2, size: Vector2, col: Color = TEXT_PRIMARY, font_size: int = FONT_SMALL) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.position = pos
	l.size = size
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.add_theme_font_size_override("normal_font_size", font_size)
	l.add_theme_color_override("default_color", col)
	parent.add_child(l)
	return l

## Create a section header (title on left, count on right).
static func section_header(parent: Control, y: int, title: String, count_text: String, title_color: Color) -> void:
	var tl := label(parent, title, Vector2(SPACING_MD, y), Vector2(140, 16), title_color, FONT_CAPTION)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var cl := label(parent, count_text, Vector2(LEFT_PANEL_W - 40, y), Vector2(32, 16), TEXT_MUTED, FONT_CAPTION)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

## Create a horizontal separator line.
static func separator(parent: Control, y: int) -> void:
	var line := ColorRect.new()
	line.position = Vector2(SPACING_SM, y)
	line.size = Vector2(LEFT_PANEL_W - 16, 1)
	line.color = Color(0.25, 0.25, 0.25, 0.5)
	parent.add_child(line)

## Create a button (ColorRect + Label, no native Button).
## Returns the ColorRect container.
static func button(parent: Control, pos: Vector2, size: Vector2, text: String, bg: Color, callback: Callable) -> ColorRect:
	var btn := ColorRect.new()
	btn.position = pos
	btn.size = size
	btn.color = bg
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	add_border(btn, int(size.x), int(size.y), bg.darkened(0.3), 1)

	var lbl := Label.new()
	lbl.text = text
	lbl.position = Vector2.ZERO
	lbl.size = size
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", FONT_BODY)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	btn.add_child(lbl)

	# Hover effect
	btn.mouse_entered.connect(func(): btn.color = bg.lightened(0.15))
	btn.mouse_exited.connect(func(): btn.color = bg)

	btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			callback.call()
	)
	parent.add_child(btn)
	return btn

## Get rarity color by item rarity name.
static func rarity_color(rarity_name: String) -> Color:
	match rarity_name:
		"传说": return GOLD
		"稀有": return CYAN
		_:      return RARITY_COMMON
