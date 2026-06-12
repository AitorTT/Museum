@tool
class_name PaintingViewer
extends Node

var generator: Node3D
var viewer: Control
var _bg: ColorRect
var _img: TextureRect
var _transitioning: bool = false
var _thief_name: String = ""
var _stolen_label: Label
var _stolen_bg: ColorRect
var _viewed_area: Area3D
var _steal_btn: Button
var _edit_btn: Button
var _info_btn: Button
var _info_label: Label
var _info_label_visible: bool = false
var _emoji_grid_canvas: CanvasLayer
var _emoji_selection: String = ""
var _emoji_display: Label
var _saved_mouse_mode: int
var _character_body_script

const EMOJI_LIST: Array[String] = [
	"🐶", "🐱", "🐰", "🐼", "🐯", "🗿",
	"🦁", "🐸", "🐵", "🐧", "🐦", "🔮",
	"❤️", "💛", "💚", "💙", "💜", "🔥",
	"⭐", "🌟", "🤡", "🌻", "🌸", "🤖"
]


func setup(gen: Node3D) -> void:
	generator = gen
	name = "PaintingViewer"


func is_visible() -> bool:
	return viewer and viewer.visible


func is_transitioning() -> bool:
	return _transitioning


func show_viewer(tex: Texture2D, area: Area3D = null) -> void:
	_viewed_area = area
	if area:
		var mount := _find_painting_mount(area)
		generator._painting_mount = mount if mount else null
	_img.texture = tex
	_img.rotation = 0.0
	_img.scale = Vector2.ONE
	_img.visible = true
	_steal_btn.visible = true
	_edit_btn.visible = true
	_info_btn.visible = true
	_info_label.visible = false
	_info_label_visible = false
	_stolen_bg.visible = false
	_stolen_label.visible = false
	viewer.visible = true
	viewer.mouse_filter = Control.MOUSE_FILTER_STOP
	if not _character_body_script:
		_character_body_script = load("res://SCENES/PLAYER/character_body_3d.gd")
	_character_body_script.ignore_clicks = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if generator._interaction_panel:
		generator._interaction_panel.set_crosshair_visible(false)
	_transitioning = true
	await get_tree().process_frame
	_transitioning = false


func hide_viewer() -> void:
	_img.texture = null
	viewer.visible = false
	_steal_btn.visible = false
	_edit_btn.visible = false
	_info_btn.visible = false
	_info_label.visible = false
	_info_label_visible = false
	_stolen_bg.visible = false
	_stolen_label.visible = false
	viewer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _character_body_script:
		_character_body_script.ignore_clicks = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if generator._interaction_panel:
		generator._interaction_panel.set_crosshair_visible(true)
	if generator._transform_panel and generator._transform_panel.is_visible():
		generator._transform_panel.hide_panel()
	_transitioning = true
	await get_tree().process_frame
	_transitioning = false


func handle_input(event: InputEvent) -> bool:
	if not viewer or not viewer.visible or _transitioning:
		return false
	if _emoji_grid_canvas:
		return false
	var tap: bool = event is InputEventMouseButton and event.pressed
	var touch: bool = generator.IS_ANDROID_WEB and event is InputEventScreenTouch and event.pressed
	if tap or touch:
		var pos: Vector2
		if event is InputEventMouseButton:
			pos = event.global_position
		else:
			pos = (event as InputEventScreenTouch).position
		if _steal_btn and _steal_btn.get_global_rect().has_point(pos):
			return false
		if _edit_btn and _edit_btn.visible and _edit_btn.get_global_rect().has_point(pos):
			return false
		if _info_btn and _info_btn.visible and _info_btn.get_global_rect().has_point(pos):
			return false
		if generator._transform_panel and generator._transform_panel.is_visible():
			return false
		hide_viewer()
		get_viewport().set_input_as_handled()
		return true
	if generator.IS_ANDROID_WEB:
		return false
	if event is InputEventMouseButton and event.pressed:
		hide_viewer()
		get_viewport().set_input_as_handled()
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_KP_ADD or (event.keycode == KEY_EQUAL and event.shift_pressed) or event.unicode == ord('+'):
			_on_steal_clicked()
			get_viewport().set_input_as_handled()
			return true
		if event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:
			generator._on_edit_clicked()
			get_viewport().set_input_as_handled()
			return true
		if event.keycode == KEY_ASTERISK or event.keycode == KEY_KP_MULTIPLY:
			_on_info_clicked()
			get_viewport().set_input_as_handled()
			return true
	return false


func check_web_emoji() -> void:
	if not (OS.has_feature("web") or OS.has_feature("web_android")):
		return
	var raw = JavaScriptBridge.eval("window.godot_emoji_confirm||''")
	if raw == null or typeof(raw) != TYPE_STRING or String(raw).is_empty():
		return
	JavaScriptBridge.eval("window.godot_emoji_confirm=''")
	_hide_emoji_grid()
	var name := String(raw)
	if not name.is_empty():
		_send_theft(name)


func scan_paintings() -> void:
	generator._paintings.clear()
	_scan_recursive(generator)


func get_painting_tex(area: Area3D, fallback_index: int) -> Texture2D:
	var mount := _find_painting_mount(area)
	if mount:
		for sub in mount.get_children():
			if sub is MeshInstance3D and sub.name == "Canvas":
				var mi := sub as MeshInstance3D
				var cm := mi.material_override as StandardMaterial3D
				if not cm and mi.mesh:
					cm = mi.mesh.surface_get_material(0) as StandardMaterial3D
				if cm and cm.albedo_texture:
					return cm.albedo_texture
	if area.has_meta("painting_tex"):
		return area.get_meta("painting_tex") as Texture2D
	if fallback_index >= 0 and fallback_index < generator._paintings.size():
		return generator._paintings[fallback_index].get("texture") as Texture2D
	return null


func get_painting_frame_mat(area: Area3D, fallback_index: int) -> StandardMaterial3D:
	var mount := _find_painting_mount(area)
	if mount:
		for sub in mount.get_children():
			if sub is MeshInstance3D and (sub.name == "Frame" or sub.name.begins_with("Frame_")):
				var mi := sub as MeshInstance3D
				if mi.mesh:
					return mi.mesh.surface_get_material(0) as StandardMaterial3D
	if area.has_meta("painting_frame_mat"):
		return area.get_meta("painting_frame_mat") as StandardMaterial3D
	if fallback_index >= 0 and fallback_index < generator._paintings.size():
		return generator._paintings[fallback_index].get("frame_mat") as StandardMaterial3D
	return null


func highlight_painting(area: Area3D, hovered: bool, fallback_index: int = -1) -> void:
	var mat := get_painting_frame_mat(area, fallback_index)
	if not mat:
		return
	if hovered:
		mat.emission = Color(1.0, 0.9, 0.6)
		mat.emission_energy = 1.5
	else:
		mat.emission = Color.BLACK
		mat.emission_energy = 0.0


func setup_viewer() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI_Layer"
	add_child(ui)

	viewer = Control.new()
	viewer.name = "FullscreenViewer"
	viewer.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewer.visible = false
	ui.add_child(viewer)

	_bg = ColorRect.new()
	_bg.name = "ColorRect"
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0, 0, 0, 0.725)
	viewer.add_child(_bg)

	_img = TextureRect.new()
	_img.name = "ImageDisplay"
	_img.set_anchors_preset(Control.PRESET_FULL_RECT)
	_img.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	viewer.add_child(_img)

	_steal_btn = Button.new()
	_steal_btn.name = "StealBtn"
	_steal_btn.text = "STEAL"
	_steal_btn.visible = false
	_steal_btn.anchor_left = 1.0
	_steal_btn.anchor_right = 1.0
	_steal_btn.anchor_top = 1.0
	_steal_btn.anchor_bottom = 1.0
	_steal_btn.offset_left = -320.0
	_steal_btn.offset_right = -20.0
	_steal_btn.offset_top = -160.0
	_steal_btn.offset_bottom = -10.0
	_steal_btn.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	_steal_btn.add_theme_font_size_override("font_size", 48)
	_steal_btn.add_theme_stylebox_override("normal", _make_toggle_style(Color(0.0, 0.0, 0.0, 0.85), Color(1.0, 0.8, 0.0, 0.8)))
	_steal_btn.add_theme_stylebox_override("hover", _make_toggle_style(Color(0.1, 0.1, 0.1, 0.9), Color(1.0, 0.85, 0.1, 1.0)))
	_steal_btn.add_theme_stylebox_override("pressed", _make_toggle_style(Color(0.0, 0.0, 0.0, 0.95), Color(0.8, 0.6, 0.0, 1.0)))
	_steal_btn.pressed.connect(_on_steal_clicked)
	viewer.add_child(_steal_btn)

	_edit_btn = Button.new()
	_edit_btn.name = "EditBtn"
	_edit_btn.text = "EDIT"
	_edit_btn.visible = false
	_edit_btn.anchor_left = 0.0
	_edit_btn.anchor_right = 0.0
	_edit_btn.anchor_top = 1.0
	_edit_btn.anchor_bottom = 1.0
	_edit_btn.offset_left = 20.0
	_edit_btn.offset_right = 320.0
	_edit_btn.offset_top = -160.0
	_edit_btn.offset_bottom = -10.0
	_edit_btn.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	_edit_btn.add_theme_font_size_override("font_size", 48)
	_edit_btn.add_theme_stylebox_override("normal", _make_toggle_style(Color(0.0, 0.0, 0.0, 0.85), Color(0.3, 0.7, 1.0, 0.8)))
	_edit_btn.add_theme_stylebox_override("hover", _make_toggle_style(Color(0.1, 0.1, 0.1, 0.9), Color(0.4, 0.8, 1.0, 1.0)))
	_edit_btn.add_theme_stylebox_override("pressed", _make_toggle_style(Color(0.0, 0.0, 0.0, 0.95), Color(0.2, 0.5, 0.8, 1.0)))
	_edit_btn.pressed.connect(generator._on_edit_clicked)
	viewer.add_child(_edit_btn)

	_info_btn = Button.new()
	_info_btn.name = "InfoBtn"
	_info_btn.text = "INFO"
	_info_btn.visible = false
	_info_btn.anchor_left = 0.0
	_info_btn.anchor_right = 0.0
	_info_btn.anchor_top = 0.5
	_info_btn.anchor_bottom = 0.5
	_info_btn.offset_left = 20.0
	_info_btn.offset_right = 140.0
	_info_btn.offset_top = -60.0
	_info_btn.offset_bottom = 0.0
	_info_btn.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	_info_btn.add_theme_font_size_override("font_size", 32)
	_info_btn.add_theme_stylebox_override("normal", _make_toggle_style(Color(0.0, 0.0, 0.0, 0.85), Color(0.6, 0.8, 0.6, 0.6)))
	_info_btn.add_theme_stylebox_override("hover", _make_toggle_style(Color(0.1, 0.1, 0.1, 0.9), Color(0.7, 0.9, 0.7, 0.8)))
	_info_btn.add_theme_stylebox_override("pressed", _make_toggle_style(Color(0.0, 0.0, 0.0, 0.95), Color(0.5, 0.7, 0.5, 1.0)))
	_info_btn.pressed.connect(_on_info_clicked)
	viewer.add_child(_info_btn)

	_info_label = Label.new()
	_info_label.name = "InfoLabel"
	_info_label.visible = false
	_info_label.anchor_left = 0.0
	_info_label.anchor_right = 0.4
	_info_label.anchor_top = 0.5
	_info_label.anchor_bottom = 0.5
	_info_label.offset_left = 20.0
	_info_label.offset_top = 10.0
	_info_label.offset_bottom = 60.0
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_info_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.8))
	_info_label.add_theme_font_size_override("font_size", 22)
	var ils := LabelSettings.new()
	ils.font_size = 22
	ils.font_color = Color(0.8, 0.9, 0.8)
	ils.outline_size = 2
	ils.outline_color = Color(0, 0, 0, 0.8)
	_info_label.label_settings = ils
	viewer.add_child(_info_label)

	_stolen_bg = ColorRect.new()
	_stolen_bg.name = "StolenBG"
	_stolen_bg.color = Color(0, 0, 0, 1)
	_stolen_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stolen_bg.visible = false
	viewer.add_child(_stolen_bg)

	_stolen_label = Label.new()
	_stolen_label.name = "StolenLabel"
	_stolen_label.text = "STOLEN"
	_stolen_label.visible = false
	_stolen_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stolen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stolen_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new()
	ls.font_size = 128
	ls.font_color = Color(1, 0, 0, 0.9)
	ls.outline_size = 4
	ls.outline_color = Color(0, 0, 0)
	_stolen_label.label_settings = ls
	_stolen_label.rotation = PI * 0.12
	viewer.add_child(_stolen_label)


func _make_toggle_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = 4
	sb.border_width_right = 4
	sb.border_width_top = 4
	sb.border_width_bottom = 4
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb


func _on_info_clicked() -> void:
	_info_label_visible = not _info_label_visible
	if _info_label_visible:
		var lines := PackedStringArray()
		if _viewed_area and _viewed_area.has_meta("painting_name"):
			lines.append("File: " + _viewed_area.get_meta("painting_name") as String)
		var tex := _img.texture
		if tex:
			lines.append("Size: " + str(tex.get_width()) + "x" + str(tex.get_height()))
			if not lines[0].begins_with("File:"):
				lines.append("File: " + tex.resource_path.get_file())
		_info_label.text = "\n".join(lines)
		_info_label.visible = true
	else:
		_info_label.visible = false


func _on_steal_clicked() -> void:
	if _stolen_bg.visible:
		return
	_show_emoji_grid()


func _show_emoji_grid() -> void:
	_hide_emoji_grid()
	_emoji_selection = ""

	if OS.has_feature("web") or OS.has_feature("web_android"):
		_show_emoji_grid_web()
		return

	_build_emoji_ui()


func _build_emoji_ui() -> void:
	_saved_mouse_mode = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if not _character_body_script:
		_character_body_script = load("res://SCENES/PLAYER/character_body_3d.gd")
	_character_body_script.ignore_clicks = true
	_emoji_grid_canvas = CanvasLayer.new()
	_emoji_grid_canvas.name = "EmojiGrid"
	_emoji_grid_canvas.layer = 134
	add_child(_emoji_grid_canvas)

	var emoji_font := load("res://SCENES/FONTS/NotoColorEmoji-Regular.ttf") as Font

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_emoji_grid_canvas.add_child(bg)

	var panel := Panel.new()
	panel.anchor_left = 0.05
	panel.anchor_right = 0.95
	panel.anchor_top = 0.3
	panel.anchor_bottom = 0.92
	var pnl_style := StyleBoxFlat.new()
	pnl_style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	pnl_style.border_color = Color(0.3, 0.5, 0.8, 0.6)
	pnl_style.border_width_left = 2
	pnl_style.border_width_right = 2
	pnl_style.border_width_top = 2
	pnl_style.border_width_bottom = 2
	pnl_style.corner_radius_top_left = 12
	pnl_style.corner_radius_top_right = 12
	pnl_style.corner_radius_bottom_left = 12
	pnl_style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", pnl_style)
	_emoji_grid_canvas.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	var top_hb := HBoxContainer.new()
	top_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(top_hb)

	var sel_lbl := Label.new()
	sel_lbl.text = "Thief:"
	sel_lbl.add_theme_font_size_override("font_size", 18)
	sel_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	top_hb.add_child(sel_lbl)

	_emoji_display = Label.new()
	_emoji_display.text = ""
	_emoji_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_emoji_display.add_theme_font_size_override("font_size", 28)
	_emoji_display.add_theme_color_override("font_color", Color(1, 1, 1))
	if emoji_font:
		_emoji_display.add_theme_font_override("font", emoji_font)
	top_hb.add_child(_emoji_display)

	var back_btn := Button.new()
	back_btn.text = "←"
	back_btn.custom_minimum_size = Vector2(60, 0)
	back_btn.add_theme_font_size_override("font_size", 24)
	back_btn.pressed.connect(_on_emoji_backspace)
	top_hb.add_child(back_btn)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(grid)

	for emoji in EMOJI_LIST:
		var btn := Button.new()
		btn.text = emoji
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 36)
		if emoji_font:
			btn.add_theme_font_override("font", emoji_font)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.15, 0.15, 0.2, 0.9)
		sb.border_color = Color(0.3, 0.5, 0.8, 0.4)
		sb.border_width_left = 1
		sb.border_width_right = 1
		sb.border_width_top = 1
		sb.border_width_bottom = 1
		sb.corner_radius_top_left = 8
		sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_left = 8
		sb.corner_radius_bottom_right = 8
		btn.add_theme_stylebox_override("normal", sb)
		btn.pressed.connect(_on_emoji_tapped.bind(emoji))
		grid.add_child(btn)

	var bottom_hb := HBoxContainer.new()
	bottom_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_hb.add_theme_constant_override("separation", 16)
	vbox.add_child(bottom_hb)

	var confirm_btn := Button.new()
	confirm_btn.text = "CONFIRM"
	confirm_btn.custom_minimum_size = Vector2(160, 50)
	confirm_btn.add_theme_font_size_override("font_size", 22)
	var c_sb := StyleBoxFlat.new()
	c_sb.bg_color = Color(0.0, 0.3, 0.0, 0.85)
	c_sb.border_color = Color(0.2, 0.8, 0.2, 0.8)
	c_sb.border_width_left = 2
	c_sb.border_width_right = 2
	c_sb.border_width_top = 2
	c_sb.border_width_bottom = 2
	c_sb.corner_radius_top_left = 8
	c_sb.corner_radius_top_right = 8
	c_sb.corner_radius_bottom_left = 8
	c_sb.corner_radius_bottom_right = 8
	confirm_btn.add_theme_stylebox_override("normal", c_sb)
	confirm_btn.pressed.connect(_on_emoji_confirm)
	bottom_hb.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "CANCEL"
	cancel_btn.custom_minimum_size = Vector2(160, 50)
	cancel_btn.add_theme_font_size_override("font_size", 22)
	var x_sb := StyleBoxFlat.new()
	x_sb.bg_color = Color(0.2, 0.0, 0.0, 0.85)
	x_sb.border_color = Color(0.8, 0.2, 0.2, 0.8)
	x_sb.border_width_left = 2
	x_sb.border_width_right = 2
	x_sb.border_width_top = 2
	x_sb.border_width_bottom = 2
	x_sb.corner_radius_top_left = 8
	x_sb.corner_radius_top_right = 8
	x_sb.corner_radius_bottom_left = 8
	x_sb.corner_radius_bottom_right = 8
	cancel_btn.add_theme_stylebox_override("normal", x_sb)
	cancel_btn.pressed.connect(_hide_emoji_grid)
	bottom_hb.add_child(cancel_btn)


func _on_emoji_tapped(emoji: String) -> void:
	if _emoji_selection.length() >= 7:
		return
	_emoji_selection += emoji
	_emoji_display.text = _emoji_selection


func _on_emoji_backspace() -> void:
	if _emoji_selection.is_empty():
		return
	_emoji_selection = _emoji_selection.left(-1)
	_emoji_display.text = _emoji_selection


func _on_emoji_confirm() -> void:
	if _emoji_selection.is_empty():
		return
	_hide_emoji_grid()
	_send_theft(_emoji_selection)


func _show_emoji_grid_web() -> void:
	var json := JSON.stringify(EMOJI_LIST)
	JavaScriptBridge.eval("(function(){if(document.getElementById('emoji_overlay'))return;var a=" + json + ",ov=document.createElement('div'),p,h,l,d,g,b,i,e,bt,ok,no;ov.id='emoji_overlay';ov.style.cssText='position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.6);z-index:99999;display:flex;align-items:center;justify-content:center;';p=document.createElement('div');p.style.cssText='background:#0e0e14;border:2px solid #358;border-radius:12px;padding:12px;width:320px;';h=document.createElement('div');h.style.cssText='display:flex;align-items:center;margin-bottom:8px;';l=document.createElement('span');l.textContent='Thief:';l.style.cssText='color:#888;font-size:14px;';h.appendChild(l);d=document.createElement('span');d.id='ed';d.style.cssText='color:#fff;font-size:24px;margin-left:6px;';h.appendChild(d);p.appendChild(h);g=document.createElement('div');g.style.cssText='display:grid;grid-template-columns:repeat(5,1fr);gap:4px;margin-bottom:8px;';for(i=0;i<a.length;i++){(function(e){b=document.createElement('button');b.textContent=e;b.style.cssText='background:#1a1a24;border:1px solid #358;border-radius:8px;font-size:28px;padding:4px;cursor:pointer;';b.onclick=function(){var x=document.getElementById('ed');if(x&&x.textContent.length<7)x.textContent+=e;};g.appendChild(b);})(a[i]);}p.appendChild(g);bt=document.createElement('div');bt.style.cssText='display:flex;gap:12px;justify-content:center;';ok=document.createElement('button');ok.textContent='OK';ok.style.cssText='background:#030;border:2px solid #2a2;color:#fff;border-radius:8px;padding:6px 16px;font-size:16px;cursor:pointer;';ok.onclick=function(){var x=document.getElementById('ed');if(x&&x.textContent.length){window.godot_emoji_confirm=x.textContent;ov.remove();}};bt.appendChild(ok);no=document.createElement('button');no.textContent='X';no.style.cssText='background:#300;border:2px solid #a22;color:#fff;border-radius:8px;padding:6px 16px;font-size:16px;cursor:pointer;';no.onclick=function(){ov.remove();};bt.appendChild(no);p.appendChild(bt);ov.appendChild(p);document.body.appendChild(ov);})();")


func _hide_emoji_grid() -> void:
	if _emoji_grid_canvas:
		_emoji_grid_canvas.queue_free()
		_emoji_grid_canvas = null
	if OS.has_feature("web") or OS.has_feature("web_android"):
		JavaScriptBridge.eval("var e=document.getElementById('emoji_overlay');if(e)e.remove();")
	if _character_body_script:
		_character_body_script.ignore_clicks = false
	Input.set_mouse_mode(_saved_mouse_mode)


func _send_theft(thief_name: String) -> void:
	var filename := ""
	if _viewed_area and _viewed_area.has_meta("painting_name"):
		filename = _viewed_area.get_meta("painting_name") as String
	if filename.is_empty():
		var tex := _img.texture
		if tex:
			filename = tex.resource_path.get_file()
	var time_str := Time.get_datetime_string_from_system()
	if generator._thieflist:
		generator._thieflist.add_entry(filename, thief_name, time_str)
	_close_viewer_after_theft()
	var url := str(generator.google_sheets_url)
	if url.is_empty():
		return
	var body := JSON.stringify({"painting": filename, "name": thief_name, "time": time_str})
	var headers := PackedStringArray(["Content-Type: text/plain;charset=utf-8"])
	var http := HTTPRequest.new()
	http.name = "TheftHTTP"
	add_child(http)
	http.request_completed.connect(_on_theft_completed.bind(http))
	var err := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()


func _close_viewer_after_theft() -> void:
	_img.texture = null
	_img.visible = false
	viewer.visible = false
	viewer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_steal_btn.visible = false
	_edit_btn.visible = false
	_info_btn.visible = false
	_info_label.visible = false
	_info_label_visible = false
	_stolen_bg.visible = false
	_stolen_label.visible = false
	if _character_body_script:
		_character_body_script.ignore_clicks = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if generator._interaction_panel:
		generator._interaction_panel.set_crosshair_visible(true)
	if generator._transform_panel and generator._transform_panel.is_visible():
		generator._transform_panel.hide_panel()
	_blacken_canvas_3d()
	_add_stolen_label_3d()


func _on_theft_completed(_result: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()


func _blacken_canvas_3d() -> void:
	if not _viewed_area:
		return
	var mount := _find_painting_mount(_viewed_area)
	if not mount:
		return
	for sub in mount.get_children():
		if sub is MeshInstance3D and sub.name == "Canvas":
			var cm := StandardMaterial3D.new()
			cm.albedo_color = Color(0.05, 0.0, 0.0)
			cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			sub.material_override = cm


func _add_stolen_label_3d() -> void:
	if not _viewed_area:
		return
	var mount := _find_painting_mount(_viewed_area)
	if not mount:
		return
	for child in mount.get_children():
		if child is Label3D and child.name == "StolenLabel3D":
			child.queue_free()
		for sub in child.get_children():
			if sub is Label3D and sub.name == "StolenLabel3D":
				sub.queue_free()
	var lbl := Label3D.new()
	lbl.name = "StolenLabel3D"
	lbl.text = "STOLEN"
	lbl.font_size = 28
	lbl.outline_size = 2
	lbl.outline_modulate = Color(0, 0, 0, 0.9)
	lbl.modulate = Color(1, 0, 0, 0.95)
	lbl.rotation_degrees.y = 180
	lbl.position = Vector3(0, 0, -0.05)
	mount.add_child(lbl)


func _scan_recursive(node: Node) -> void:
	for child in node.get_children():
		if child.name.begins_with("Painting_"):
			_scan_one(child as Node3D)
		_scan_recursive(child)


func _scan_one(mount: Node3D) -> void:
	var frame_mat: StandardMaterial3D = null
	var tex: Texture2D = null
	for sub in mount.get_children():
		if sub is MeshInstance3D and (sub.name == "Frame" or sub.name.begins_with("Frame_")):
			var mi := sub as MeshInstance3D
			if mi.mesh:
				frame_mat = mi.mesh.surface_get_material(0) as StandardMaterial3D
		elif sub is MeshInstance3D and sub.name == "Canvas":
			var mi := sub as MeshInstance3D
			var cm := mi.material_override as StandardMaterial3D
			if not cm and mi.mesh:
				cm = mi.mesh.surface_get_material(0) as StandardMaterial3D
			if cm:
				tex = cm.albedo_texture
	generator._paintings.append({"mount": mount, "frame_mat": frame_mat, "texture": tex})


func _find_painting_mount(area: Area3D) -> Node3D:
	var node := area.get_parent() as Node3D
	while node and node != generator:
		if node.name.begins_with("Painting_"):
			return node
		node = node.get_parent()
	return null
