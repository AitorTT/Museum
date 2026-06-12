@tool
extends Node3D

@export_category("Rack")
@export var rows: int = 4
@export var columns: int = 4
@export_dir var folder: String = ""
@export var separation: float = 2.0
@export var repeat_images: bool = true
@export var auto_fit: bool = false

@export_category("Remote Images")
@export var remote_manifest_url: String = ""
@export var load_on_start: bool = false
@export var fetch_and_generate: bool = false:
	set(v):
		if v:
			_fetch_and_generate()
			fetch_and_generate = false
@export var refresh_textures: bool = false:
	set(v):
		if v:
			_refresh_from_drive()
			refresh_textures = false

@export_category("Generation")
@export var generate_rack: bool = false:
	set(v):
		if v:
			_generate_rack()
			generate_rack = false
@export var clear_rack: bool = false:
	set(v):
		if v:
			_clear()
			clear_rack = false

static var _image_extensions := PackedStringArray(["png", "jpg", "jpeg", "webp", "bmp", "tga", "svg"])

var _fetched_textures: Array[Texture2D] = []
var _fetched_names: Array[String] = []
var _pending_downloads: int = 0
var _refresh_mode: bool = false
var _frame_cache: Dictionary = {}


static func _make_lightmapped(prim: PrimitiveMesh) -> ArrayMesh:
	var arrays := prim.get_mesh_arrays()
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	am.lightmap_unwrap(Transform3D.IDENTITY, 0.05)
	var mat := prim.material
	if mat:
		am.surface_set_material(0, mat)
	return am


func _ready() -> void:
	if not Engine.is_editor_hint() and load_on_start and not remote_manifest_url.is_empty():
		var has_existing := false
		for child in get_children():
			if child is Node3D and child.has_meta("rack_index"):
				has_existing = true
				break
		if has_existing:
			_refresh_mode = true
			_fetch_and_generate()
		else:
			var cached := _load_cached_textures()
			if cached.size() > 0:
				_build_rack(cached)
			_fetch_and_generate()


func _generate_rack() -> void:
	_clear()
	if folder.is_empty():
		push_warning("RackGenerator: folder is empty")
		return
	var textures := _load_textures(folder)
	if textures.is_empty():
		push_warning("RackGenerator: no textures found in " + folder)
		return
	_build_rack(textures)


func _build_rack(textures: Array[Texture2D]) -> void:
	var num_images: int = textures.size()
	if num_images == 0:
		return

	var actual_rows: int = maxi(1, rows)
	var actual_cols: int = maxi(1, columns)
	if auto_fit:
		# Find the most square-like grid where rows*cols >= num_images
		var best_r := num_images
		var best_c := 1
		var best_diff := absf(float(num_images) - 1.0)
		var best_waste := num_images - 1
		for c in range(1, num_images + 1):
			var r := ceili(float(num_images) / float(c))
			var waste := r * c - num_images
			var diff := absf(float(r) - float(c))
			if diff < best_diff or (diff == best_diff and waste < best_waste):
				best_r = r
				best_c = c
				best_diff = diff
				best_waste = waste
		actual_rows = best_r
		actual_cols = best_c

	var slots: int = actual_rows * actual_cols
	if not repeat_images:
		slots = mini(slots, num_images)

	var shared_frame_mat := StandardMaterial3D.new()
	shared_frame_mat.albedo_color = Color(0.2, 0.2, 0.2)
	shared_frame_mat.emission_enabled = true
	shared_frame_mat.emission = Color.BLACK

	_frame_cache.clear()
	var idx := 0
	var start_x := -(actual_cols - 1) * separation * 0.5
	var start_y := (actual_rows - 1) * separation * 0.5

	for i in slots:
		var r: int = i / actual_cols
		var c: int = i % actual_cols
		if repeat_images:
			idx = i % num_images
		else:
			idx = i
		var tex: Texture2D = textures[idx]

		var aspect: float = 1.0
		if tex:
			var tw: int = tex.get_width()
			var th: int = tex.get_height()
			if th > 0:
				aspect = float(tw) / float(th)

		var fp: float = 0.05
		var fd: float = 0.08
		var s: float = 0.4

		var canvas_mat := StandardMaterial3D.new()
		if tex:
			canvas_mat.albedo_texture = tex
		canvas_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		canvas_mat.uv1_scale = Vector3(1, -1, 1)
		canvas_mat.uv1_offset = Vector3(0, 1, 0)

		var fw_val := aspect + fp * 2.0
		var fh_val := 1.0 + fp * 2.0

		var x: float = start_x + c * separation
		var y: float = start_y - r * separation

		var mount := Node3D.new()
		mount.name = "Painting_%d_%d" % [r, c]
		mount.position = Vector3(x, y, 0)
		mount.set_meta("rack_index", i)
		add_child(mount, true)
		_set_owner(mount)

		_add_rack_painting_mesh(mount, "Frame_Top",
			Vector3(0, fh_val * 0.5 - fp * 0.5, 0) * s,
			Vector3(fw_val * s, fp * s, fd * s), shared_frame_mat, _frame_cache)
		_add_rack_painting_mesh(mount, "Frame_Bottom",
			Vector3(0, -(fh_val * 0.5 - fp * 0.5), 0) * s,
			Vector3(fw_val * s, fp * s, fd * s), shared_frame_mat, _frame_cache)
		_add_rack_painting_mesh(mount, "Frame_Left",
			Vector3(-(fw_val * 0.5 - fp * 0.5), 0, 0) * s,
			Vector3(fp * s, fh_val * s, fd * s), shared_frame_mat, _frame_cache)
		_add_rack_painting_mesh(mount, "Frame_Right",
			Vector3(fw_val * 0.5 - fp * 0.5, 0, 0) * s,
			Vector3(fp * s, fh_val * s, fd * s), shared_frame_mat, _frame_cache)

		var canvas := MeshInstance3D.new()
		canvas.name = "Canvas"
		var plane := PlaneMesh.new()
		plane.size = Vector2(aspect * s, 1.0 * s)
		plane.material = canvas_mat
		canvas.mesh = _make_lightmapped(plane)
		canvas.rotation_degrees.x = -90
		canvas.scale.x = -1
		canvas.position = Vector3(0, 0, -0.0625 * s)
		mount.add_child(canvas, true)
		_set_owner(canvas)

		var area := Area3D.new()
		area.name = "ClickArea"
		area.collision_layer = 8
		area.set_meta("interact_type", "painting")
		area.set_meta("interact_index", -1)
		area.set_meta("painting_frame_mat", shared_frame_mat)
		area.set_meta("painting_tex", tex)
		var pname := ""
		if idx < _fetched_names.size():
			pname = _fetched_names[idx]
		if pname.is_empty() and tex:
			pname = tex.resource_path.get_file()
		area.set_meta("painting_name", pname)
		mount.add_child(area, true)
		_set_owner(area)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(fw_val * s, fh_val * s, fd * s + 0.05)
		cs.shape = shape
		area.add_child(cs, true)
		_set_owner(cs)

	if auto_fit:
		rows = actual_rows
		columns = actual_cols
		print("RackGenerator: auto_fit set grid to %dx%d" % [actual_rows, actual_cols])


func _apply_textures(textures: Array[Texture2D]) -> void:
	var count := 0
	for child in get_children():
		if not (child is Node3D) or not child.has_meta("rack_index"):
			continue
		var idx: int = child.get_meta("rack_index")
		if idx < textures.size() and textures[idx]:
			_update_painting_texture(child, textures[idx])
			count += 1
	print("RackGenerator: refreshed %d painting textures" % count)


func _update_painting_texture(mount: Node3D, tex: Texture2D) -> void:
	var tw := tex.get_width()
	var th := tex.get_height()
	var aspect := float(tw) / float(th) if th > 0 else 1.0

	var fp := 0.05
	var fd := 0.08
	var s := 0.4
	var fw_val := aspect + fp * 2.0
	var fh_val := 1.0 + fp * 2.0

	# Rebuild canvas with new texture and correct aspect
	var old_canvas := mount.get_node_or_null("Canvas") as MeshInstance3D
	if old_canvas:
		mount.remove_child(old_canvas)
		old_canvas.queue_free()

	var canvas_mat := StandardMaterial3D.new()
	canvas_mat.albedo_texture = tex
	canvas_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	canvas_mat.uv1_scale = Vector3(1, -1, 1)
	canvas_mat.uv1_offset = Vector3(0, 1, 0)

	var plane := PlaneMesh.new()
	plane.size = Vector2(aspect * s, 1.0 * s)
	plane.material = canvas_mat

	var canvas := MeshInstance3D.new()
	canvas.name = "Canvas"
	canvas.mesh = _make_lightmapped(plane)
	canvas.rotation_degrees.x = -90
	canvas.scale.x = -1
	canvas.position = Vector3(0, 0, -0.0625 * s)
	mount.add_child(canvas, true)

	# Get the shared frame material from any frame child
	var frame_mat: Material = null
	for seg_name in ["Frame_Top", "Frame_Bottom", "Frame_Left", "Frame_Right"]:
		var seg := mount.get_node_or_null(seg_name) as MeshInstance3D
		if seg:
			frame_mat = seg.mesh.surface_get_material(0) if seg.mesh.get_surface_count() > 0 else null
			# Remove old frame parts
			mount.remove_child(seg)
			seg.queue_free()

	if not frame_mat:
		frame_mat = StandardMaterial3D.new()
		frame_mat.albedo_color = Color(0.2, 0.2, 0.2)
		frame_mat.emission_enabled = true
		frame_mat.emission = Color.BLACK

	# Rebuild frames at new size
	_add_rack_painting_mesh(mount, "Frame_Top",
		Vector3(0, fh_val * 0.5 - fp * 0.5, 0) * s,
		Vector3(fw_val * s, fp * s, fd * s), frame_mat, _frame_cache)
	_add_rack_painting_mesh(mount, "Frame_Bottom",
		Vector3(0, -(fh_val * 0.5 - fp * 0.5), 0) * s,
		Vector3(fw_val * s, fp * s, fd * s), frame_mat, _frame_cache)
	_add_rack_painting_mesh(mount, "Frame_Left",
		Vector3(-(fw_val * 0.5 - fp * 0.5), 0, 0) * s,
		Vector3(fp * s, fh_val * s, fd * s), frame_mat, _frame_cache)
	_add_rack_painting_mesh(mount, "Frame_Right",
		Vector3(fw_val * 0.5 - fp * 0.5, 0, 0) * s,
		Vector3(fp * s, fh_val * s, fd * s), frame_mat, _frame_cache)

	# Update collision shape and painting name
	var area := mount.get_node_or_null("ClickArea") as Area3D
	if area:
		area.set_meta("painting_tex", tex)
		var idx: int = mount.get_meta("rack_index") if mount.has_meta("rack_index") else -1
		var pname := ""
		if idx >= 0 and idx < _fetched_names.size():
			pname = _fetched_names[idx]
		if pname.is_empty():
			pname = tex.resource_path.get_file()
		area.set_meta("painting_name", pname)
		var cs := area.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if cs and cs.shape is BoxShape3D:
			cs.shape.size = Vector3(fw_val * s, fh_val * s, fd * s + 0.05)


static func _mesh_key(size: Vector3) -> String:
	return "%.6f_%.6f_%.6f" % [size.x, size.y, size.z]


func _add_rack_painting_mesh(parent: Node, seg_name: String, pos: Vector3, size: Vector3, mat: Material, cache: Dictionary) -> void:
	var mi := MeshInstance3D.new()
	mi.name = seg_name
	var key := _mesh_key(size)
	var mesh := cache.get(key) as ArrayMesh
	if not mesh:
		var box := BoxMesh.new()
		box.size = size
		if mat:
			box.material = mat
		mesh = _make_lightmapped(box)
		cache[key] = mesh
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi, true)
	_set_owner(mi)


func _load_textures(path: String) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	var dir := DirAccess.open(path)
	if not dir:
		push_warning("RackGenerator: cannot open folder " + path)
		return result

	dir.list_dir_begin()
	var fname := dir.get_next()
	while not fname.is_empty():
		if dir.current_is_dir():
			fname = dir.get_next()
			continue
		var ext := fname.get_extension().to_lower()
		if ext in _image_extensions:
			var full := path.trim_suffix("/") + "/" + fname
			var tex := ResourceLoader.load(full, "", ResourceLoader.CACHE_MODE_REUSE) as Texture2D
			if tex:
				result.append(tex)
		fname = dir.get_next()
	dir.list_dir_end()
	return result


func _refresh_from_drive() -> void:
	if remote_manifest_url.is_empty():
		push_warning("RackGenerator: remote_manifest_url is empty")
		return
	_refresh_mode = true
	_fetch_and_generate()


func _fetch_and_generate() -> void:
	if remote_manifest_url.is_empty():
		push_warning("RackGenerator: remote_manifest_url is empty")
		return
	print("RackGenerator: fetching manifest from ", remote_manifest_url)
	var http := HTTPRequest.new()
	http.name = "ManifestFetch"
	add_child(http)
	http.request_completed.connect(_on_manifest_fetched.bind(http))
	http.request(remote_manifest_url, PackedStringArray(), HTTPClient.METHOD_GET)


func _on_manifest_fetched(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		push_error("RackGenerator: manifest fetch failed (code %d)" % code)
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		push_error("RackGenerator: invalid manifest JSON")
		return

	var data = json.data
	if not (data is Array):
		push_error("RackGenerator: manifest must be a JSON array of URLs or {url, name} objects")
		return

	var urls: Array[String] = []
	var names: Array[String] = []
	for entry in data:
		if entry is Dictionary:
			var u := str(entry.get("url", entry.get("directUrl", "")))
			var n := str(entry.get("name", ""))
			if not u.is_empty():
				urls.append(u)
				names.append(n)
		elif entry is String:
			var s := entry as String
			if not s.is_empty():
				urls.append(s)
				names.append("")

	if urls.is_empty():
		push_warning("RackGenerator: no image URLs in manifest")
		return

	_fetched_textures.resize(urls.size())
	_fetched_names = names
	_pending_downloads = urls.size()
	for i in urls.size():
		_download_image(i, urls[i])


func _download_image(index: int, url: String) -> void:
	var http := HTTPRequest.new()
	http.name = "ImgDL_%d" % index
	add_child(http)
	http.request_completed.connect(_on_image_downloaded.bind(http, index))
	http.request(url, PackedStringArray(), HTTPClient.METHOD_GET)


func _on_image_downloaded(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, index: int) -> void:
	http.queue_free()
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var tex := _parse_image_response(body)
		if tex:
			if Engine.is_editor_hint():
				tex = _save_tex_to_file(tex, index)
			else:
				_save_to_cache(tex, index)
			_fetched_textures[index] = tex

	_pending_downloads -= 1
	if _pending_downloads <= 0:
		var valid: Array[Texture2D] = []
		for t in _fetched_textures:
			if t:
				valid.append(t)
		if valid.is_empty():
			push_error("RackGenerator: no images could be downloaded")
			_refresh_mode = false
			return
		if _refresh_mode:
			_apply_textures(valid)
			_refresh_mode = false
		else:
			for child in get_children():
				if child is Node3D:
					child.free()
			_build_rack(valid)


static func _save_tex_to_file(tex: Texture2D, index: int) -> Texture2D:
	var dir_path := "res://rack_downloads/"
	var dir := DirAccess.open("res://")
	if not dir.dir_exists(dir_path):
		dir.make_dir_recursive(dir_path)
	var path := dir_path + "img_%d.png" % index
	var img := tex.get_image()
	if img:
		img.save_png(path)
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE) as Texture2D


static func _parse_image_response(body: PackedByteArray) -> Texture2D:
	var raw := body
	var img := Image.new()

	# Check if it's base64 JSON (Apps Script proxy format)
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) == OK:
		var d = json.data
		if d is Dictionary:
			var b64 := d.get("data") as String
			if b64:
				var decoded := Marshalls.base64_to_raw(b64)
				if decoded:
					raw = decoded

	# Try loading from raw bytes (PNG, JPEG, or WebP)
	img = Image.new()
	if img.load_png_from_buffer(raw) == OK:
		return ImageTexture.create_from_image(img)
	img = Image.new()
	if img.load_jpg_from_buffer(raw) == OK:
		return ImageTexture.create_from_image(img)
	img = Image.new()
	if img.load_webp_from_buffer(raw) == OK:
		return ImageTexture.create_from_image(img)

	return null


func _clear() -> void:
	for child in get_children():
		child.queue_free()
	_fetched_textures.clear()
	_fetched_names.clear()
	_pending_downloads = 0
	_refresh_mode = false
	_frame_cache.clear()


static func _cache_dir() -> String:
	return "user://rack_cache/"


static func _save_to_cache(tex: Texture2D, index: int) -> void:
	var dir := DirAccess.open("user://")
	if not dir.dir_exists("rack_cache"):
		dir.make_dir("rack_cache")
	var img := tex.get_image()
	if img:
		img.save_png(_cache_dir() + "%d.png" % index)


static func _load_cached_textures() -> Array[Texture2D]:
	var dir := DirAccess.open(_cache_dir())
	if not dir:
		return []
	var result: Array[Texture2D] = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while not fname.is_empty():
		if not dir.current_is_dir() and fname.ends_with(".png"):
			var img := Image.new()
			if img.load(_cache_dir() + fname) == OK:
				result.append(ImageTexture.create_from_image(img))
		fname = dir.get_next()
	dir.list_dir_end()
	return result


func _set_owner(node: Node) -> void:
	if not Engine.is_editor_hint():
		return
	var tree := get_tree()
	if not tree:
		return
	var root := tree.edited_scene_root
	if root:
		node.owner = root
