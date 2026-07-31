## Settings page — programmatic UI.
extends Control

func _ready() -> void:
    _build()

func _build() -> void:
    var bg: ColorRect = ColorRect.new()
    bg.color = Color(0.025, 0.025, 0.03)
    bg.anchors_preset = PRESET_FULL_RECT
    add_child(bg)

    var title: Label = Label.new()
    title.text = "设 置"
    title.position = Vector2(520, 40)
    title.size = Vector2(240, 50)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 24)
    title.add_theme_color_override("font_color", Color(0.98, 0.78, 0.29))
    add_child(title)

    # Audio section
    var items: Array[Dictionary] = [
        {"label": "主音量", "value": 0.72},
        {"label": "音效", "value": 0.83},
        {"label": "音乐", "value": 0.60},
    ]

    var y: int = 120
    for item: Dictionary in items:
        var lbl: Label = Label.new()
        lbl.text = item["label"]
        lbl.position = Vector2(350, y)
        lbl.size = Vector2(200, 30)
        lbl.add_theme_font_size_override("font_size", 15)
        lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.66))
        add_child(lbl)

        var slider_bg: ColorRect = ColorRect.new()
        slider_bg.position = Vector2(580, y + 12)
        slider_bg.size = Vector2(200, 6)
        slider_bg.color = Color(0.1, 0.1, 0.1)
        add_child(slider_bg)

        var slider_fill: ColorRect = ColorRect.new()
        var val: float = item["value"]
        slider_fill.position = Vector2(580, y + 12)
        slider_fill.size = Vector2(200 * val, 6)
        slider_fill.color = Color(0.22, 0.54, 0.87)
        add_child(slider_fill)

        var pct: Label = Label.new()
        pct.text = "%d%%" % int(val * 100)
        pct.position = Vector2(790, y)
        pct.size = Vector2(60, 30)
        pct.add_theme_font_size_override("font_size", 13)
        pct.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
        add_child(pct)

        y += 45

    # Tutorial toggle
    y += 10
    var tut: Label = Label.new()
    tut.text = "教程提示"
    tut.position = Vector2(350, y)
    tut.size = Vector2(200, 30)
    tut.add_theme_font_size_override("font_size", 15)
    tut.add_theme_color_override("font_color", Color(0.7, 0.7, 0.66))
    add_child(tut)

    var on_btn: ColorRect = ColorRect.new()
    on_btn.position = Vector2(580, y)
    on_btn.size = Vector2(80, 30)
    on_btn.color = Color(0.04, 0.2, 0.08)
    _add_btn_border(on_btn, 80, 30, Color(0.36, 0.79, 0.65, 0.8))
    add_child(on_btn)
    var on_lbl: Label = Label.new()
    on_lbl.text = "开"
    on_lbl.position = Vector2(0, 0)
    on_lbl.size = Vector2(80, 30)
    on_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    on_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    on_lbl.add_theme_font_size_override("font_size", 14)
    on_lbl.add_theme_color_override("font_color", Color(0.36, 0.79, 0.65))
    on_btn.add_child(on_lbl)

    y += 50

    # Back button
    var back: ColorRect = ColorRect.new()
    back.position = Vector2(520, y)
    back.size = Vector2(200, 44)
    back.color = Color(0.07, 0.07, 0.07)
    _add_btn_border(back, 200, 44, Color(0.98, 0.78, 0.29, 0.9))
    add_child(back)
    var back_lbl: Label = Label.new()
    back_lbl.text = "返 回"
    back_lbl.position = Vector2(0, 0)
    back_lbl.size = Vector2(200, 44)
    back_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    back_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    back_lbl.add_theme_font_size_override("font_size", 18)
    back_lbl.add_theme_color_override("font_color", Color(0.98, 0.78, 0.29))
    back.add_child(back_lbl)

    back.mouse_entered.connect(func():
        back.color = Color(0.12, 0.12, 0.12)
        back_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
    )
    back.mouse_exited.connect(func():
        back.color = Color(0.07, 0.07, 0.07)
        back_lbl.add_theme_color_override("font_color", Color(0.98, 0.78, 0.29))
    )
    back.mouse_filter = Control.MOUSE_FILTER_STOP
    back.gui_input.connect(func(e: InputEvent):
        if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
            get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
    )

func _add_btn_border(parent: Control, w: int, h: int, col: Color) -> void:
    for b: Array in [[0,0,w,2], [0,h-2,w,2], [0,0,2,h], [w-2,0,2,h]]:
        var r: ColorRect = ColorRect.new()
        r.position = Vector2(b[0], b[1])
        r.size = Vector2(b[2] - b[0], b[3] - b[1])
        r.color = col
        r.mouse_filter = Control.MOUSE_FILTER_IGNORE
        parent.add_child(r)
