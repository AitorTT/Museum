extends Node3D

var _records: Array[Dictionary] = []
var _sheets_url: String = ""
var _waiting_for_fetch: bool = false
var _poll_cooldown: int = 0
var _label_pool: Array[Label] = []

@onready var _viewport: SubViewport = $ThiefViewport
@onready var _container: VBoxContainer = $ThiefViewport/Container
@onready var _billboard: MeshInstance3D = $Billboard
@onready var _quad: QuadMesh = $Billboard.mesh
@onready var _bg: ColorRect = $ThiefViewport/Bg
var _emoji_font: Font


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_emoji_font = load("res://SCENES/FONTS/NotoColorEmoji-Regular.ttf") as Font
	if _emoji_font:
		var base := ThemeDB.fallback_font as FontFile
		if base:
			var fbs: Array[Font] = base.get_fallbacks()
			if _emoji_font not in fbs:
				fbs.push_back(_emoji_font)
				base.set_fallbacks(fbs)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _viewport.get_texture()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_billboard.material_override = mat
	_rebuild()


func _process(_delta: float) -> void:
	if not _waiting_for_fetch:
		return
	if not (OS.has_feature("web") or OS.has_feature("web_android")):
		return
	_poll_cooldown -= 1
	if _poll_cooldown > 0:
		return
	_poll_cooldown = 5
	var raw = JavaScriptBridge.eval("window.godot_sheets_ready?window.godot_sheets_data:''")
	if raw == null or typeof(raw) != TYPE_STRING or String(raw).is_empty():
		return
	_waiting_for_fetch = false
	JavaScriptBridge.eval("window.godot_sheets_ready=false;window.godot_sheets_data=''")
	_on_web_sheets_fetched(String(raw))


func _on_web_sheets_fetched(json_str: String) -> void:
	var json := JSON.new()
	var parse_err := json.parse(json_str)
	if parse_err != OK:
		return
	var data = json.data
	if data is Array:
		_records.clear()
		for entry in data:
			if entry is Dictionary:
				var painting: String = str(entry.get("painting", ""))
				var thief_name: String = str(entry.get("name", ""))
				var entry_time: String = str(entry.get("time", ""))
				if not painting.is_empty() and not thief_name.is_empty():
					_records.push_back({"painting": painting, "name": thief_name, "time": entry_time})
		call_deferred("_rebuild")


func set_sheets_url(url: String) -> void:
	_sheets_url = url
	if not _sheets_url.is_empty() and is_node_ready():
		_fetch_from_sheets()


func add_entry(painting: String, thief_name: String, time: String = "") -> void:
	_records.push_back({"painting": painting, "name": thief_name, "time": time})
	_rebuild()


func _fetch_from_sheets() -> void:
	if OS.has_feature("web") or OS.has_feature("web_android"):
		_waiting_for_fetch = true
		_poll_cooldown = 0
		JavaScriptBridge.eval("fetch('" + _sheets_url + "').then(function(r){return r.json();}).then(function(d){window.godot_sheets_data=JSON.stringify(d);window.godot_sheets_ready=true;}).catch(function(e){console.error(e);});")
		return
	var http := HTTPRequest.new()
	http.name = "SheetsFetch"
	add_child(http)
	http.request_completed.connect(_on_sheets_fetched.bind(http))
	var err := 	http.request(_sheets_url, PackedStringArray(["User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"]), HTTPClient.METHOD_GET)
	if err != OK:
		http.queue_free()


func _on_sheets_fetched(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var json_str := body.get_string_from_utf8()
	var json := JSON.new()
	var parse_err := json.parse(json_str)
	if parse_err != OK:
		return
	var data = json.data
	if data is Array:
		_records.clear()
		for entry in data:
			if entry is Dictionary:
				var painting: String = str(entry.get("painting", ""))
				var thief_name: String = str(entry.get("name", ""))
				var entry_time: String = str(entry.get("time", ""))
				if not painting.is_empty() and not thief_name.is_empty():
					_records.push_back({"painting": painting, "name": thief_name, "time": entry_time})
		call_deferred("_rebuild")


func _rebuild() -> void:
	var max_entries := mini(_records.size(), 5)
	var display := _records.slice(_records.size() - max_entries)
	var h := 120 + 80 * max_entries
	_container.size = Vector2(1400, h)
	_container.position = Vector2.ZERO
	_viewport.size = Vector2i(1400, h)
	if _bg:
		_bg.size = Vector2(1400, h)

	# Reuse or create title
	var title: Label
	if _container.get_child_count() > 0 and _container.get_child(0) is Label:
		title = _container.get_child(0)
	else:
		title = Label.new()
		title.add_theme_font_size_override("font_size", 40)
		title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
		title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		title.add_theme_constant_override("outline_size", 6)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.custom_minimum_size = Vector2(0, 90)
		title.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_container.add_child(title)
	title.text = "THIEF REGISTRY"

	# Reuse or create entry labels
	for i in max_entries:
		var label: Label
		if i < _container.get_child_count() - 1:
			label = _container.get_child(i + 1)
		else:
			label = Label.new()
			label.add_theme_font_size_override("font_size", 32)
			label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
			label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
			label.add_theme_constant_override("outline_size", 4)
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.custom_minimum_size = Vector2(0, 75)
			label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			_container.add_child(label)
		var rec: Dictionary = display[i]
		label.text = "%s  —  stolen by  %s" % [rec.painting, rec.name]

	# Remove excess labels
	while _container.get_child_count() > max_entries + 1:
		var c = _container.get_child(_container.get_child_count() - 1)
		_container.remove_child(c)
		c.queue_free()

	var mat := _billboard.material_override as StandardMaterial3D
	if mat:
		mat.albedo_texture = _viewport.get_texture()

	var aspect: float = float(_viewport.size.x) / max(float(_viewport.size.y), 1.0)
	_quad.size = Vector2(3.5, min(3.5 / aspect, 2.5))
