extends CanvasLayer
class_name ProjectBrowser

const ROOT_PATH := "/sdcard/Documents/pico8/data/carts"

@onready var margin: MarginContainer = $Panel/Margin
@onready var title: Label = $Panel/Margin/VBox/Header/Title
@onready var path_label: Label = $Panel/Margin/VBox/Header/Path
@onready var entries: VBoxContainer = %Entries
@onready var status: Label = %Status
@onready var refresh_button: Button = %Refresh
@onready var close_button: Button = %Close

var expanded_paths: Dictionary = {ROOT_PATH: true}
var visible_entries: Array[Dictionary] = []
var entry_buttons: Dictionary = {}
var run_cmd: Node
var launching_project := false
var focus_path := ""

func _ready() -> void:
	run_cmd = get_node_or_null("/root/Main/runcmd")
	refresh_button.pressed.connect(_refresh)
	close_button.pressed.connect(_close)
	get_tree().root.size_changed.connect(_update_layout)
	_update_layout()

	if PicoVideoStreamer.instance:
		PicoVideoStreamer.instance.set_input_blocked(true)
	if run_cmd and run_cmd.has_method("suspend_pico_process"):
		run_cmd.suspend_pico_process()

	_refresh()
	set_process_unhandled_input(true)

func _exit_tree() -> void:
	if PicoVideoStreamer.instance:
		PicoVideoStreamer.instance.set_input_blocked(false)
	if not launching_project and run_cmd and run_cmd.has_method("resume_pico_process"):
		run_cmd.resume_pico_process()

func _update_layout() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	var font_size = clampi(int(min(viewport_size.x, viewport_size.y) * 0.027), 16, 48)
	var vertical_margin = int(viewport_size.y * 0.06)
	var horizontal_margin = int(viewport_size.x * 0.05)
	for side in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, vertical_margin)
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, horizontal_margin)
	title.add_theme_font_size_override("font_size", int(font_size * 1.1))
	path_label.add_theme_font_size_override("font_size", int(font_size * 0.65))
	status.add_theme_font_size_override("font_size", int(font_size * 0.75))
	refresh_button.add_theme_font_size_override("font_size", font_size)
	close_button.add_theme_font_size_override("font_size", font_size)
	for button in entry_buttons.values():
		_style_entry_button(button, font_size)

func _refresh() -> void:
	focus_path = _focused_entry_path()
	visible_entries.clear()
	entry_buttons.clear()
	for child in entries.get_children():
		child.queue_free()

	if not _append_directory(ROOT_PATH, 0):
		status.text = "Unable to read /Documents/pico8/data/carts"
		close_button.grab_focus.call_deferred()
		return

	status.text = "No editable .p8 projects found" if visible_entries.is_empty() else "%d entries  •  read only" % visible_entries.size()
	path_label.text = "/Documents/pico8/data/carts"
	for item in visible_entries:
		var button = _create_entry_button(item)
		entries.add_child(button)
		entry_buttons[item.path] = button
	_update_focus_chain()
	call_deferred("_restore_focus")

func _append_directory(directory_path: String, depth: int) -> bool:
	var directory = DirAccess.open(directory_path)
	if not directory:
		return false

	var folders: Array[String] = []
	var files: Array[String] = []
	directory.list_dir_begin()
	while true:
		var name = directory.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue
		if directory.current_is_dir():
			folders.append(name)
		elif name.to_lower().ends_with(".p8"):
			files.append(name)
	directory.list_dir_end()
	folders.sort_custom(func(a, b): return a.naturalnocasecmp_to(b) < 0)
	files.sort_custom(func(a, b): return a.naturalnocasecmp_to(b) < 0)

	for name in folders:
		var child_path = directory_path.path_join(name)
		visible_entries.append({"path": child_path, "name": name, "is_dir": true, "depth": depth})
		if expanded_paths.get(child_path, false):
			_append_directory(child_path, depth + 1)
	for name in files:
		visible_entries.append({"path": directory_path.path_join(name), "name": name, "is_dir": false, "depth": depth})
	return true

func _create_entry_button(item: Dictionary) -> Button:
	var button = Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var indent = "    ".repeat(int(item.depth))
	if item.is_dir:
		button.text = indent + ("▼  " if expanded_paths.get(item.path, false) else "▶  ") + item.name + "/"
	else:
		button.text = indent + "    ◇  " + item.name
	button.set_meta("entry", item)
	button.pressed.connect(_activate_entry.bind(item))
	button.gui_input.connect(_entry_gui_input.bind(button, item))
	button.focus_entered.connect(func(): focus_path = item.path)
	_style_entry_button(button, clampi(int(min(get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y) * 0.027), 16, 48))
	return button

func _style_entry_button(button: Button, font_size: int) -> void:
	button.add_theme_font_size_override("font_size", font_size)
	button.custom_minimum_size.y = font_size * 1.8
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.08, 0.08, 0.78)
	normal.content_margin_left = font_size * 0.5
	normal.content_margin_right = font_size * 0.5
	var focus = normal.duplicate()
	focus.bg_color = Color(0.22, 0.22, 0.26, 0.96)
	focus.border_width_left = 2
	focus.border_width_top = 2
	focus.border_width_right = 2
	focus.border_width_bottom = 2
	focus.border_color = Color.WHITE
	var pressed = focus.duplicate()
	pressed.bg_color = Color(0.45, 0.34, 0.62, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", focus)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("pressed", pressed)

func _activate_entry(item: Dictionary) -> void:
	focus_path = item.path
	if item.is_dir:
		expanded_paths[item.path] = not expanded_paths.get(item.path, false)
		_refresh()
		return
	_confirm_open_project(item.path)

func _entry_gui_input(event: InputEvent, button: Button, item: Dictionary) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_RIGHT and item.is_dir and not expanded_paths.get(item.path, false):
		expanded_paths[item.path] = true
		focus_path = item.path
		_refresh()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_LEFT:
		if item.is_dir and expanded_paths.get(item.path, false):
			expanded_paths[item.path] = false
			focus_path = item.path
		else:
			var parent_path = item.path.get_base_dir()
			if parent_path != ROOT_PATH and parent_path.begins_with(ROOT_PATH + "/"):
				expanded_paths[parent_path] = false
			focus_path = parent_path
		_refresh()
		get_viewport().set_input_as_handled()

func _confirm_open_project(project_path: String) -> void:
	var dialog: Control
	var cancel = func():
		if is_instance_valid(dialog):
			dialog.queue_free()
		call_deferred("_restore_focus")
	var confirm = func():
		if is_instance_valid(dialog):
			dialog.queue_free()
		_open_project(project_path)
	dialog = UIUtils.create_confirm_dialog(
		self,
		"Open Project",
		"Open %s?\nThe current PICO-8 session will close. Save your work first." % project_path.get_file(),
		"OPEN",
		"CANCEL",
		false,
		confirm,
		cancel
	)

func _open_project(project_path: String) -> void:
	var normalized = project_path.simplify_path()
	if not normalized.begins_with(ROOT_PATH + "/") or not normalized.to_lower().ends_with(".p8") or not FileAccess.file_exists(normalized):
		UIUtils.create_message_dialog(self, "Project unavailable", "The selected .p8 project is missing or outside My Projects.")
		return
	if not run_cmd or not run_cmd.has_method("open_project_in_editor"):
		UIUtils.create_message_dialog(self, "Unable to open", "The PICO-8 launcher is unavailable.")
		return

	if run_cmd.has_method("resume_pico_process"):
		run_cmd.resume_pico_process()
	if run_cmd.open_project_in_editor(normalized):
		launching_project = true
		queue_free()
	else:
		UIUtils.create_message_dialog(self, "Busy", "PICO-8 is already switching sessions. Try again shortly.")

func _update_focus_chain() -> void:
	var buttons = entry_buttons.values()
	for i in range(buttons.size()):
		var button: Button = buttons[i]
		button.focus_neighbor_top = (buttons[i - 1] if i > 0 else refresh_button).get_path()
		button.focus_neighbor_bottom = (buttons[i + 1] if i + 1 < buttons.size() else refresh_button).get_path()
	if not buttons.is_empty():
		refresh_button.focus_neighbor_top = buttons[-1].get_path()
		close_button.focus_neighbor_top = buttons[-1].get_path()
		refresh_button.focus_neighbor_bottom = buttons[0].get_path()
		close_button.focus_neighbor_bottom = buttons[0].get_path()
	refresh_button.focus_neighbor_right = close_button.get_path()
	close_button.focus_neighbor_left = refresh_button.get_path()

func _focused_entry_path() -> String:
	var focused = get_viewport().gui_get_focus_owner()
	if focused and focused.has_meta("entry"):
		return focused.get_meta("entry").path
	return focus_path

func _restore_focus() -> void:
	if not focus_path.is_empty() and entry_buttons.has(focus_path):
		entry_buttons[focus_path].grab_focus()
	elif not entry_buttons.is_empty():
		entry_buttons.values()[0].grab_focus()
	else:
		refresh_button.grab_focus()

func _close() -> void:
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_BACKSPACE:
			_close()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F5:
			_refresh()
			get_viewport().set_input_as_handled()
