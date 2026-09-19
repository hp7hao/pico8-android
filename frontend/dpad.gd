extends TextureRect

func send_ev(key: String, down: bool):
	PicoVideoStreamer.instance.vkb_setstate(key, down)

var center_offset = Vector2.ZERO
const SHIFT = Vector2(13.5, 13.5)
const ORIGIN = Vector2(0, 0)

@onready var lit_texture = preload("res://assets/dpad_lit.png")
@onready var default_texture = preload("res://assets/dpad.png")

var original_position: Vector2
var original_scale: Vector2
var editor_scale: Vector2
var drag_offset_start: Vector2

var active_touches = {}
var initial_pinch_dist = 0.0
var initial_scale_modifier = 1.0

const CustomControlTextures = preload("res://custom_control_textures.gd")
const DPAD_DEADZONE_RATIO = 0.12

# Custom texture themes retain their directional highlight treatment. The
# default control is drawn as a minimal circular four-button D-pad.
var has_press_effect: bool = true
var use_minimal_visual: bool = false


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_filter = Control.MOUSE_FILTER_STOP
	center_offset = size / 2
	
	# Reset all
	update_visuals(Vector2i.ONE)
	
	# --- Drag & Drop Init ---
	original_position = position
	original_scale = scale
	editor_scale = scale
	if PicoVideoStreamer.instance:
		PicoVideoStreamer.instance.layout_reset.connect(_on_layout_reset)
		PicoVideoStreamer.instance.bezel_layout_updated.connect(_on_bezel_layout_updated)
	
	# Attempt to load saved position and scale
	var is_landscape = _is_in_landscape_ui()
	var saved_pos = PicoVideoStreamer.get_control_pos(name, is_landscape)
	if saved_pos != null:
		position = saved_pos
	else:
		# Theme Layout Fallback (Startup Race Check)
		if PicoVideoStreamer.instance:
			var rect = PicoVideoStreamer.instance.get_current_bezel_rect()
			if rect.has_area():
				_on_bezel_layout_updated(rect, Vector2.ONE)
	
	var saved_scale = PicoVideoStreamer.get_control_scale(name, is_landscape)
	scale = original_scale * saved_scale
	
	# --- Custom Texture Loading ---
	if not _load_and_apply_custom_textures(is_landscape):
		_enable_minimal_visual()

func _enable_minimal_visual():
	use_minimal_visual = true
	has_press_effect = false
	for direction in [%Up, %Down, %Left, %Right]:
		direction.visible = false
	queue_redraw()

func _draw() -> void:
	if not use_minimal_visual:
		return
	var radius = min(size.x, size.y) * 0.48
	var button_radius = radius * 0.27
	var button_offset = radius * 0.57
	var border_width = max(1.25, radius * 0.055)
	var idle_fill = Color(0.27, 0.25, 0.34, 0.98)
	var active_fill = Color(0.68, 0.64, 0.96, 1.0)
	var outline = Color(0.55, 0.49, 0.82, 1.0)
	var active_outline = Color(0.90, 0.87, 1.0, 1.0)
	var directions = [
		[Vector2(0, -button_offset), current_dir.y == 0],
		[Vector2(0, button_offset), current_dir.y == 2],
		[Vector2(-button_offset, 0), current_dir.x == 0],
		[Vector2(button_offset, 0), current_dir.x == 2],
	]
	draw_circle(center_offset, radius, Color(0.12, 0.11, 0.16, 0.92))
	draw_arc(center_offset, radius, 0.0, TAU, 64, outline, border_width, true)
	for item in directions:
		var button_center: Vector2 = center_offset + item[0]
		var active: bool = item[1]
		draw_circle(button_center, button_radius, active_fill if active else idle_fill)
		draw_arc(button_center, button_radius, 0.0, TAU, 40, active_outline if active else outline, border_width, true)
	draw_circle(center_offset, button_radius * 0.58, Color(0.16, 0.14, 0.21, 1.0))

func reload_textures():
	var is_landscape = _is_in_landscape_ui()
	
	# Reset defaults first
	lit_texture = preload("res://assets/dpad_lit.png")
	self.texture = default_texture
	has_press_effect = true
	use_minimal_visual = false
	
	# Try Load Custom
	if not _load_and_apply_custom_textures(is_landscape):
		var saved_scale = PicoVideoStreamer.get_control_scale(name, is_landscape)
		scale = original_scale * saved_scale
		_enable_minimal_visual()
		z_index = 0 # Default z-index? Or whatever it was.

func reload_layout():
	# Dpad is practically always repositionable unless in specific containers, assumes yes for now or checks parent
	var is_landscape = _is_in_landscape_ui()
	var user_pos = PicoVideoStreamer.get_control_pos(name, is_landscape)
	
	# 1. User Override
	if user_pos != null:
		position = user_pos
		var saved_scale = PicoVideoStreamer.get_control_scale(name, is_landscape)
		scale = original_scale * saved_scale
		return
		
	# 2. Theme or Default
	var layout = ThemeManager.get_theme_layout(is_landscape)
	if layout.is_empty():
		# Restore Default
		position = original_position
		scale = original_scale
	else:
		# Apply Theme
		if PicoVideoStreamer.instance:
			var rect = PicoVideoStreamer.instance.get_current_bezel_rect()
			LayoutHelper.apply_layout(self, rect)

func _load_and_apply_custom_textures(is_landscape: bool) -> bool:
	var custom_textures = CustomControlTextures.get_custom_textures("dpad", is_landscape)
	if custom_textures[0] != null:
		self.texture = custom_textures[0]
		self.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		
		if custom_textures[1] != null:
			lit_texture = custom_textures[1]
			has_press_effect = true
		else:
			has_press_effect = false
			
		# Apply sprites (if press effect enabled, or just to be safe if enabled later)
		_setup_dpad_sprites(lit_texture)
			
		# Aspect Ratio Logic
		var tex_size = custom_textures[0].get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			var tex_aspect = tex_size.x / tex_size.y
			var dpad_size = self.size if self.size.y > 0 else (texture.get_size() if texture else Vector2(100, 100))
			var dpad_aspect = dpad_size.x / dpad_size.y if dpad_size.y > 0 else 1.0
			
			if abs(tex_aspect - dpad_aspect) > 0.05:
				var area = dpad_size.x * dpad_size.y
				var new_width = sqrt(area * tex_aspect)
				var new_height = new_width / tex_aspect
				
				# Use editor_scale as base
				scale.x = (new_width / dpad_size.x) * editor_scale.x
				scale.y = (new_height / dpad_size.y) * editor_scale.y
				
		z_index = 150
		return true
	
	return false

func _setup_dpad_sprites(tex: Texture2D):
	var w = tex.get_width()
	var h = tex.get_height()
	var s_w = w / 3.0
	var s_h = h / 3.0
	
	# Destination sizing
	var dest_w = size.x / 3.0
	var dest_h = size.y / 3.0
	
	# Helper to setup a slice
	_setup_slice(%Up, tex, Rect2(s_w, 0, s_w, s_h), Vector2(dest_w, 0), Vector2(dest_w, dest_h))
	_setup_slice(%Down, tex, Rect2(s_w, s_h * 2, s_w, s_h), Vector2(dest_w, dest_h * 2), Vector2(dest_w, dest_h))
	_setup_slice(%Left, tex, Rect2(0, s_h, s_w, s_h), Vector2(0, dest_h), Vector2(dest_w, dest_h))
	_setup_slice(%Right, tex, Rect2(s_w * 2, s_h, s_w, s_h), Vector2(dest_w * 2, dest_h), Vector2(dest_w, dest_h))

func _setup_slice(node: TextureRect, atlas: Texture2D, region: Rect2, pos: Vector2, slice_size: Vector2):
	if not node: return
	
	var at = node.texture as AtlasTexture
	if not at:
		at = AtlasTexture.new()
		node.texture = at
	
	at.atlas = atlas
	at.region = region
	at.filter_clip = true
	
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.position = pos
	node.size = slice_size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _is_in_landscape_ui() -> bool:
	return LayoutHelper.is_in_landscape_ui(self)

func _save_layout():
	LayoutHelper.save_layout(self, original_scale.x)

func _on_layout_reset(target_is_landscape: bool):
	if is_visible_in_tree() and target_is_landscape == _is_in_landscape_ui():
		position = original_position
		scale = original_scale

func _on_bezel_layout_updated(bezel_rect: Rect2, _unused_scale: Vector2):
	LayoutHelper.apply_layout(self, bezel_rect)


func constrain(val: float, shift: float, _origin: float):
	# Symmetric deadzone logic
	var threshold = shift * 0.4
	
	if val < -threshold:
		return 0
	elif val > threshold:
		return 2
	else:
		return 1

var current_dir = Vector2i.ONE

func dir2keys(dir: Vector2i):
	var keys = []
	if dir.x == 0: keys.append("Left")
	if dir.x == 2: keys.append("Right")
	if dir.y == 0: keys.append("Up")
	if dir.y == 2: keys.append("Down")
	return keys

func update_dir(new_dir: Vector2i):
	if new_dir == current_dir:
		return
	var old_keys = dir2keys(current_dir)
	var new_keys = dir2keys(new_dir)
	for k in old_keys:
		if k not in new_keys:
			send_ev(k, false)
	for k in new_keys:
		if k not in old_keys:
			send_ev(k, true)
	current_dir = new_dir
	update_visuals(new_dir)

func update_visuals(dir: Vector2i):
	if use_minimal_visual:
		queue_redraw()
		return
	# Only update visuals if press effect is enabled
	if has_press_effect:
		# Center is (1,1)
		%Left.visible = (dir.x == 0)
		%Right.visible = (dir.x == 2)
		%Up.visible = (dir.y == 0)
		%Down.visible = (dir.y == 2)

func _gui_input(event: InputEvent) -> void:
	if PicoVideoStreamer.display_drag_enabled:
		var event_index = event.index if "index" in event else 0
		if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
			if event.pressed:
				drag_offset_start = event.position
				active_touches[event_index] = event.position
				
				# Centralized Selection: Update the last touched element
				if PicoVideoStreamer.instance:
					PicoVideoStreamer.instance.selected_control = self
					PicoVideoStreamer.instance.control_selected.emit(self)
				
				accept_event()
			else:
				active_touches.erase(event_index)
				_save_layout()
				accept_event()
		elif event is InputEventScreenDrag or (event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT)):
			if active_touches.has(event_index):
				active_touches[event_index] = event.position
				
			if active_touches.size() == 1:
				# Single touch: Drag logic
				position += event.position - drag_offset_start
				accept_event()
			elif active_touches.size() == 2:
				# Multi-touch: CONSUME but don't handle locally
				accept_event()
		return # Block normal input

	if event is InputEventScreenDrag or event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT)):
		if (event is InputEventScreenTouch and not event.pressed) or (event is InputEventMouseButton and not event.pressed):
			update_dir(Vector2i.ONE)
		else:
			var vec: Vector2 = event.position - center_offset
			var threshold = min(size.x, size.y) * DPAD_DEADZONE_RATIO
			
			# 1. Deadzone Check
			if vec.length() < threshold:
				update_dir(Vector2i.ONE)
				return

			# 2. Determine Raw Direction based on signs
			var dir = Vector2i.ONE
			if vec.x < -threshold: dir.x = 0
			elif vec.x > threshold: dir.x = 2
			
			if vec.y < -threshold: dir.y = 0
			elif vec.y > threshold: dir.y = 2
			
			# 3. Diagonal Suppression (Ratio Logic)
			# If one axis is much stronger than the other, snap to cardinal
			if dir.x != 1 and dir.y != 1:
				var abs_x = abs(vec.x)
				var abs_y = abs(vec.y)
				var ratio = min(abs_x, abs_y) / max(abs_x, abs_y)
				
				# Threshold 0.6 = approx 31 degrees (Even wider cardinal zone)
				# Increasing this makes diagonals HARDER to hit (must be more precise)
				if ratio < 0.6:
					# Suppress the weaker axis
					if abs_x > abs_y:
						dir.y = 1 # Snap to Horizontal
					else:
						dir.x = 1 # Snap to Vertical

			update_dir(dir)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_MOUSE_EXIT:
		update_dir(Vector2i.ONE)
