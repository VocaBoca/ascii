extends Control

signal MoveToPointRequested(point_name: String)
signal ConsoleKeyPressed
signal ScreamerBabySpawn
signal ToggleConsoleVisibility(state: bool)

# ─────────────────────────────────────────────
#  Terminal.gd
# ─────────────────────────────────────────────

@export_range(8, 64) var FONT_SIZE: int = 16
@export var ERROR_COLOR: Color = Color(1.0, 0.25, 0.25, 1.0)
@export var BG_COLOR: Color = Color(0.05, 0.05, 0.05, 0.92)
@export var TEXT_COLOR: Color = Color(0.0, 1.0, 0.45, 1.0)
@export var DIM_COLOR: Color = Color(0.0, 0.6, 0.27, 1.0)
@export var CURSOR_COLOR: Color = Color(0.0, 1.0, 0.45, 1.0)
@export_range(0.0, 5.0, 0.1) var CURSOR_BLINK_HZ: float = 1.8

const PROMPT_STR: String = "@home # "
const MAX_HISTORY: int = 200
const MAX_COMMAND_HISTORY: int = 100

# This font is part of The Ultimate Oldschool PC Font Pack by VileR
# https://int10h.org/oldschool-pc-fonts/
const MONO_FONT_PATH: String = "res://fonts/Ac437_IBM_EGA_8x8.ttf"

# ── state ────────────────────────────────────────────────────────────────────
var _is_in_closing_state: bool = false
var _input_buffer: String = ""
var _cursor_visible: bool = true
var _cursor_timer: float = 0.0
var _history: Array[String] = []
var _history_idx: int = -1
var _output_lines: Array[String] = []

# ── node refs ────────────────────────────────────────────────────────────────
var bg: ColorRect
var _root_vbox: VBoxContainer
var _scroll: ScrollContainer
var _output_label: RichTextLabel
var _separator: ColorRect
var _input_row: HBoxContainer
var _prompt_label: Label
var _input_label: Label
var _cursor_label: Label

# ── resources ────────────────────────────────────────────────────────────────
var _mono_font: FontFile

# Username
var username: String = _get_username()


func _get_username() -> String:
	if OS.has_environment("USERNAME"):
		return OS.get_environment("USERNAME")
	return "Player"


# ════════════════════════════════════════════════════════════════════════════
#  LIFECYCLE
# ════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	_init_font()

	# If scene wasn't wired manually, auto-build.
	if not _try_cache_existing_nodes():
		build_scene()
	else:
		_apply_visual_settings()
		_refresh_output()
		_update_input_display()

	set_process(true)
	set_process_input(true)


func _process(delta: float) -> void:
	if not visible or _is_in_closing_state:
		return

	if not is_instance_valid(_cursor_label):
		return

	if CURSOR_BLINK_HZ <= 0.0:
		_cursor_label.visible = true
		return

	_cursor_timer += delta
	if _cursor_timer >= 1.0 / CURSOR_BLINK_HZ:
		_cursor_timer = 0.0
		_cursor_visible = not _cursor_visible
		_cursor_label.visible = _cursor_visible


# ════════════════════════════════════════════════════════════════════════════
#  BUILD / CACHE
# ════════════════════════════════════════════════════════════════════════════
func _try_cache_existing_nodes() -> bool:
	bg = get_node_or_null("Background") as ColorRect
	if not is_instance_valid(bg):
		return false

	_root_vbox = bg.get_node_or_null("RootVBox") as VBoxContainer
	_scroll = bg.get_node_or_null("RootVBox/ScrollContainer") as ScrollContainer
	_output_label = bg.get_node_or_null("RootVBox/ScrollContainer/OutputLabel") as RichTextLabel
	_separator = bg.get_node_or_null("RootVBox/Separator") as ColorRect
	_input_row = bg.get_node_or_null("RootVBox/InputRow") as HBoxContainer
	_prompt_label = bg.get_node_or_null("RootVBox/InputRow/Prompt") as Label
	_input_label = bg.get_node_or_null("RootVBox/InputRow/InputLabel") as Label
	_cursor_label = bg.get_node_or_null("RootVBox/InputRow/Cursor") as Label

	return (
		is_instance_valid(_root_vbox)
		and is_instance_valid(_scroll)
		and is_instance_valid(_output_label)
		and is_instance_valid(_separator)
		and is_instance_valid(_input_row)
		and is_instance_valid(_prompt_label)
		and is_instance_valid(_input_label)
		and is_instance_valid(_cursor_label)
	)


func build_scene() -> void:
	# Root background
	bg = ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main layout
	_root_vbox = VBoxContainer.new()
	_root_vbox.name = "RootVBox"
	_root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_vbox.add_theme_constant_override("separation", 0)
	bg.add_child(_root_vbox)

	# Scroll + output
	_scroll = ScrollContainer.new()
	_scroll.name = "ScrollContainer"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_vbox.add_child(_scroll)

	_output_label = RichTextLabel.new()
	_output_label.name = "OutputLabel"
	_output_label.bbcode_enabled = true
	_output_label.fit_content = true
	_output_label.scroll_active = false
	_output_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_output_label)

	# Separator
	_separator = ColorRect.new()
	_separator.name = "Separator"
	_separator.custom_minimum_size = Vector2(0, 1)
	_root_vbox.add_child(_separator)

	# Input row
	_input_row = HBoxContainer.new()
	_input_row.name = "InputRow"
	_input_row.add_theme_constant_override("separation", 0)
	_root_vbox.add_child(_input_row)

	_prompt_label = Label.new()
	_prompt_label.name = "Prompt"
	_input_row.add_child(_prompt_label)

	_input_label = Label.new()
	_input_label.name = "InputLabel"
	_input_row.add_child(_input_label)

	_cursor_label = Label.new()
	_cursor_label.name = "Cursor"
	_cursor_label.text = "█"
	_input_row.add_child(_cursor_label)

	_apply_visual_settings()
	_print_welcome()


# ════════════════════════════════════════════════════════════════════════════
#  FONT / STYLE
# ════════════════════════════════════════════════════════════════════════════
func _init_font() -> void:
	if MONO_FONT_PATH.is_empty():
		return

	var loaded := load(MONO_FONT_PATH)
	if loaded is FontFile:
		_mono_font = loaded as FontFile
	else:
		push_warning("Could not load font: " + MONO_FONT_PATH)


func _apply_control_font(ctrl: Control) -> void:
	if not is_instance_valid(ctrl):
		return

	ctrl.add_theme_font_size_override("font_size", FONT_SIZE)

	if _mono_font != null:
		ctrl.add_theme_font_override("font", _mono_font)


func _apply_visual_settings() -> void:
	if is_instance_valid(bg):
		bg.color = BG_COLOR

	if is_instance_valid(_separator):
		_separator.color = DIM_COLOR

	if is_instance_valid(_input_row):
		_input_row.custom_minimum_size = Vector2(0, FONT_SIZE + 10)

	if is_instance_valid(_prompt_label):
		_prompt_label.text = username + PROMPT_STR
		_prompt_label.add_theme_color_override("font_color", DIM_COLOR)
		_prompt_label.add_theme_font_size_override("font_size", FONT_SIZE)
		if _mono_font != null:
			_prompt_label.add_theme_font_override("font", _mono_font)

	if is_instance_valid(_input_label):
		_input_label.add_theme_color_override("font_color", TEXT_COLOR)
		_input_label.add_theme_font_size_override("font_size", FONT_SIZE)
		if _mono_font != null:
			_input_label.add_theme_font_override("font", _mono_font)

	if is_instance_valid(_cursor_label):
		_cursor_label.add_theme_color_override("font_color", CURSOR_COLOR)
		_cursor_label.add_theme_font_size_override("font_size", FONT_SIZE)
		if _mono_font != null:
			_cursor_label.add_theme_font_override("font", _mono_font)

	if is_instance_valid(_output_label):
		_output_label.add_theme_color_override("default_color", TEXT_COLOR)
		_output_label.add_theme_font_size_override("normal_font_size", FONT_SIZE)
		_output_label.add_theme_font_size_override("mono_font_size", FONT_SIZE)

		if _mono_font != null:
			_output_label.add_theme_font_override("normal_font", _mono_font)
			_output_label.add_theme_font_override("mono_font", _mono_font)


func _set_font_size(new_size: int) -> void:
	var clamped_size := clampi(new_size, 8, 64)
	if clamped_size == FONT_SIZE:
		return

	FONT_SIZE = clamped_size
	_apply_visual_settings()
	_refresh_output()
	_update_input_display()
	_scroll_to_bottom()


# ════════════════════════════════════════════════════════════════════════════
#  INPUT
# ════════════════════════════════════════════════════════════════════════════
func _input(event: InputEvent) -> void:
	if not visible or _is_in_closing_state:
		return

	if event is InputEventKey and event.pressed:
		var key_event := event as InputEventKey
		var key: int = key_event.keycode

		match key:
			KEY_ENTER, KEY_KP_ENTER:
				_submit()

			KEY_BACKSPACE:
				if not _input_buffer.is_empty():
					_input_buffer = _input_buffer.left(_input_buffer.length() - 1)
					_update_input_display()

			KEY_DOWN:
				_history_navigate(-1)

			KEY_UP:
				_history_navigate(1)

			KEY_C:
				if key_event.ctrl_pressed:
					_print_line(username + PROMPT_STR + _input_buffer + "^C")
					_input_buffer = ""
					_history_idx = -1
					_update_input_display()
				else:
					_type_char(key_event)

			KEY_L:
				if key_event.ctrl_pressed:
					_clear_output()
				else:
					_type_char(key_event)

			KEY_EQUAL, KEY_KP_ADD:
				if key_event.ctrl_pressed:
					_set_font_size(FONT_SIZE + 1)
				else:
					_type_char(key_event)

			KEY_MINUS, KEY_KP_SUBTRACT:
				if key_event.ctrl_pressed:
					_set_font_size(FONT_SIZE - 1)
				else:
					_type_char(key_event)

			_:
				_type_char(key_event)

		ConsoleKeyPressed.emit()
		get_viewport().set_input_as_handled()


func _type_char(event: InputEventKey) -> void:
	if event.unicode >= 32 and event.unicode <= 126:
		_input_buffer += char(event.unicode)
		_update_input_display()


func _update_input_display() -> void:
	if is_instance_valid(_input_label):
		_input_label.text = _input_buffer

	_cursor_timer = 0.0
	_cursor_visible = true

	if is_instance_valid(_cursor_label):
		_cursor_label.visible = true


# ════════════════════════════════════════════════════════════════════════════
#  SUBMIT / EXECUTE
# ════════════════════════════════════════════════════════════════════════════
func _submit() -> void:
	var raw := _input_buffer.strip_edges()

	_print_raw(
		"[color=#4dffaa]" + username + PROMPT_STR + "[/color]" +
		"[color=#ffffff]" + raw.xml_escape() + "[/color]"
	)

	if not raw.is_empty():
		if _history.is_empty() or _history[0] != raw:
			_history.push_front(raw)
			if _history.size() > MAX_COMMAND_HISTORY:
				_history.pop_back()

		_execute(raw)

	_input_buffer = ""
	_history_idx = -1
	_update_input_display()
	_scroll_to_bottom()


func _cmd_cd(args: Array) -> void:
	if args.is_empty():
		_print_error("Usage: cd <object_name>")
		return

	var point_name := String(args[0]).strip_edges()
	MoveToPointRequested.emit(point_name)


func _execute(cmd: String) -> void:
	var parts: Array = cmd.split(" ", false)
	if parts.is_empty():
		return

	var name_: String = String(parts[0]).to_lower()
	var args: Array = parts.slice(1)

	match name_:
		"help":
			_cmd_help(args)

		"clear", "cls":
			_clear_output()

		"echo":
			_print_line((" ".join(args)) if args.size() > 0 else "")

		"history":
			for i in _history.size():
				_print_line("  %3d  %s" % [i + 1, _history[i]])

		"ver", "version":
			_print_line("Terminal v1.0  –  Godot 4")

		"exit", "quit":
			_is_in_closing_state = true
			ToggleConsoleVisibility.emit(false)
			await get_tree().create_timer(1.0).timeout
			_is_in_closing_state = false
			visible = false

		"baby":
			ToggleConsoleVisibility.emit(false)
			await get_tree().create_timer(1.0).timeout
			visible = false
			ScreamerBabySpawn.emit()
			await get_tree().create_timer(3.0).timeout
			visible = true
			ToggleConsoleVisibility.emit(true)

		"cd":
			_cmd_cd(args)

		_:
			_print_error("Unknown command: '%s'  (type [color=#ffffff]help[/color] for a list)" % name_)


# ════════════════════════════════════════════════════════════════════════════
#  COMMANDS
# ════════════════════════════════════════════════════════════════════════════
func _cmd_help(_args: Array) -> void:
	_print_raw("")
	_print_raw("[color=#00ff72]Hello World[/color]")
	_print_raw("")
	_print_raw("[color=#4dffaa]Available commands:[/color]")
	_print_raw("  [color=#ffffff]help[/color]          –  show this message")
	_print_raw("  [color=#ffffff]echo[/color] <text>   –  print text")
	_print_raw("  [color=#ffffff]clear[/color]         –  clear the screen")
	_print_raw("  [color=#ffffff]history[/color]       –  show command history")
	_print_raw("  [color=#ffffff]ver[/color]           –  show version")
	_print_raw("  [color=#ffffff]exit[/color]          –  hide terminal")
	_print_raw("  [color=#ffffff]baby[/color]          –  show baby")
	_print_raw("  [color=#ffffff]cd[/color] <name>     –  move player to object")
	_print_raw("  [color=#ffffff]Ctrl+=[/color]        –  make font bigger")
	_print_raw("  [color=#ffffff]Ctrl+-[/color]        –  make font smaller")
	_print_raw("")


# ════════════════════════════════════════════════════════════════════════════
#  OUTPUT
# ════════════════════════════════════════════════════════════════════════════
func _print_welcome() -> void:
	_print_raw("[color=#00ff72]Terminal v0.1 alpha[/color]")
	_print_raw("[color=#00ff72]Last login: [/color]" + username + " at TTY1")
	_print_raw("")


func _clear_output() -> void:
	_output_lines.clear()
	if is_instance_valid(_output_label):
		_output_label.clear()

	_print_welcome()
	_scroll_to_bottom()


func _refresh_output() -> void:
	if not is_instance_valid(_output_label):
		return

	_output_label.clear()
	for line in _output_lines:
		_output_label.append_text(line + "\n")


func _print_line(text: String) -> void:
	_print_raw(text.xml_escape())


func _print_raw(bbcode: String) -> void:
	_output_lines.append(bbcode)

	if _output_lines.size() > MAX_HISTORY:
		_output_lines.pop_front()

	if is_instance_valid(_output_label):
		if _output_lines.size() == MAX_HISTORY:
			_refresh_output()
		else:
			_output_label.append_text(bbcode + "\n")


func _print_error(msg: String) -> void:
	_print_raw("[color=%s]%s[/color]" % [ERROR_COLOR.to_html(false), msg.xml_escape()])


func print_error(text: String) -> void:
	_print_error(text)
	_scroll_to_bottom()


func print_output(text: String) -> void:
	_print_line(text)
	_scroll_to_bottom()


func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	if is_instance_valid(_scroll):
		var bar := _scroll.get_v_scroll_bar()
		if bar != null:
			_scroll.scroll_vertical = int(bar.max_value)


# ════════════════════════════════════════════════════════════════════════════
#  HISTORY
# ════════════════════════════════════════════════════════════════════════════
func _history_navigate(direction: int) -> void:
	if _history.is_empty():
		return

	_history_idx = clampi(_history_idx + direction, -1, _history.size() - 1)

	if _history_idx == -1:
		_input_buffer = ""
	else:
		_input_buffer = _history[_history_idx]

	_update_input_display()


func _on_toggle_console_visibility(state: bool) -> void:
	_is_in_closing_state = true
	await get_tree().create_timer(1.0).timeout
	_is_in_closing_state = false
	visible = state
