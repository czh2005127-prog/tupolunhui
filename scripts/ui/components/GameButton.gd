## Reusable button — ColorRect + Label with hover, border, click callback.
## Use GameButton.create(...) to instantiate and configure in one call.
extends ColorRect

signal clicked

var _bg: Color
var _label: Label

## Factory: create and return a fully configured button.
static func create(parent: Control, pos: Vector2, size: Vector2, text: String, bg: Color, cb: Callable) -> ColorRect:
	var btn := ColorRect.new()
	btn.set_script(load("res://scripts/ui/components/GameButton.gd"))
	btn.position = pos
	btn.size = size
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn._bg = bg
	btn.color = bg
	UITheme.add_border(btn, int(size.x), int(size.y), bg.darkened(0.3))

	var lbl := Label.new()
	lbl.text = text
	lbl.position = Vector2.ZERO
	lbl.size = size
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	btn.add_child(lbl)

	btn.mouse_entered.connect(func(): btn.color = bg.lightened(0.15))
	btn.mouse_exited.connect(func(): btn.color = bg)
	btn.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			btn.clicked.emit()
			cb.call()
	)

	parent.add_child(btn)
	return btn
