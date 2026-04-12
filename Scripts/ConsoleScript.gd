extends Control

# ─────────────────────────────────────────────
#  Terminal.gd
#  Attach to a Control node inside your CanvasLayer.
#  The node tree expected:
#
#   CanvasLayer
#   └── Terminal          (this script, Control)
#       ├── Background    (ColorRect)
#       ├── ScrollContainer
#       │   └── OutputLabel  (RichTextLabel)
#       └── InputRow      (HBoxContainer)
#           ├── Prompt    (Label)  – shows "$ "
#           ├── InputLabel (Label) – current typed text
#           └── Cursor    (Label) – "█" blinks
#
#  Or call  Terminal.build_scene()  from your scene's _ready()
#  to have it auto-create the whole subtree.
# ─────────────────────────────────────────────

const FONT_SIZE       : int   = 16
const BG_COLOR        : Color = Color(0.05, 0.05, 0.05, 0.92)
const TEXT_COLOR      : Color = Color(0.0,  1.0,  0.45, 1.0)   # green phosphor
const DIM_COLOR       : Color = Color(0.0,  0.6,  0.27, 1.0)
const CURSOR_COLOR    : Color = Color(0.0,  1.0,  0.45, 1.0)
const PROMPT_STR      : String = "$ "
const CURSOR_BLINK_HZ : float = 1.8   # blinks per second
const MAX_HISTORY     : int   = 200   # lines kept in output

# ── node refs (populated in build_scene or _ready) ──────────────────────────
var _output_label   : RichTextLabel
var _input_label    : Label
var _cursor_label   : Label
var _scroll         : ScrollContainer

# ── state ────────────────────────────────────────────────────────────────────
var _input_buffer   : String = ""
var _cursor_visible : bool   = true
var _cursor_timer   : float  = 0.0
var _history        : Array[String] = []   # command history
var _history_idx    : int    = -1
var _output_lines   : Array[String] = []

# ── built-in font (monospace fallback) ───────────────────────────────────────
# If you have a .ttf in res://fonts/ set this path; otherwise leave ""
# and Godot will use its default monospace font.
const MONO_FONT_PATH : String = ""   # e.g. "res://fonts/JetBrainsMono-Regular.ttf"

# ════════════════════════════════════════════════════════════════════════════
#  SCENE BUILDER  –  call this from your scene _ready if you don't want
#                    to wire up nodes by hand in the editor.
# ════════════════════════════════════════════════════════════════════════════
func build_scene() -> void:
	# ── Background ──────────────────────────────────────────────────────────
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = BG_COLOR
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# ── VBoxContainer wraps output + input ──────────────────────────────────
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 0)
	add_child(vbox)

	# ── ScrollContainer + OutputLabel ───────────────────────────────────────
	_scroll = ScrollContainer.new()
	_scroll.name = "ScrollContainer"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_scroll)

	_output_label = RichTextLabel.new()
	_output_label.name = "OutputLabel"
	_output_label.bbcode_enabled = true
	_output_label.fit_content = true
	_output_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_output_label.scroll_active = false   # we handle scroll ourselves
	_output_label.add_theme_color_override("default_color", TEXT_COLOR)
	_output_label.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_output_label.add_theme_font_size_override("mono_font_size", FONT_SIZE)
	if MONO_FONT_PATH != "":
		var fnt : FontFile = load(MONO_FONT_PATH)
		_output_label.add_theme_font_override("normal_font", fnt)
		_output_label.add_theme_font_override("mono_font", fnt)
	_scroll.add_child(_output_label)

	# ── Separator ────────────────────────────────────────────────────────────
	var sep := ColorRect.new()
	sep.color = DIM_COLOR
	sep.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(sep)

	# ── Input row ────────────────────────────────────────────────────────────
	var row := HBoxContainer.new()
	row.name = "InputRow"
	row.custom_minimum_size = Vector2(0, FONT_SIZE + 10)
	row.add_theme_constant_override("separation", 0)
	vbox.add_child(row)

	var prompt := Label.new()
	prompt.name = "Prompt"
	prompt.text = PROMPT_STR
	prompt.add_theme_color_override("font_color", DIM_COLOR)
	prompt.add_theme_font_size_override("font_size", FONT_SIZE)
	if MONO_FONT_PATH != "":
		prompt.add_theme_font_override("font", load(MONO_FONT_PATH))
	row.add_child(prompt)

	_input_label = Label.new()
	_input_label.name = "InputLabel"
	_input_label.text = ""
	_input_label.add_theme_color_override("font_color", TEXT_COLOR)
	_input_label.add_theme_font_size_override("font_size", FONT_SIZE)
	if MONO_FONT_PATH != "":
		_input_label.add_theme_font_override("font", load(MONO_FONT_PATH))
	row.add_child(_input_label)

	_cursor_label = Label.new()
	_cursor_label.name = "Cursor"
	_cursor_label.text = "█"
	_cursor_label.add_theme_color_override("font_color", CURSOR_COLOR)
	_cursor_label.add_theme_font_size_override("font_size", FONT_SIZE)
	if MONO_FONT_PATH != "":
		_cursor_label.add_theme_font_override("font", load(MONO_FONT_PATH))
	row.add_child(_cursor_label)

	# Print a welcome banner
	_print_raw("[color=#00ff72]╔══════════════════════════════════╗[/color]")
	_print_raw("[color=#00ff72]║   TERMINAL v1.0  –  type [b]help[/b]    ║[/color]")
	_print_raw("[color=#00ff72]╚══════════════════════════════════╝[/color]")
	_print_raw("")


# ════════════════════════════════════════════════════════════════════════════
#  LIFECYCLE
# ════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	# If nodes aren't wired from editor, build them automatically
	if not _output_label:
		build_scene()
	set_process_input(true)


func _process(delta: float) -> void:
	# ── cursor blink ────────────────────────────────────────────────────────
	_cursor_timer += delta
	if _cursor_timer >= 1.0 / CURSOR_BLINK_HZ:
		_cursor_timer = 0.0
		_cursor_visible = !_cursor_visible
		_cursor_label.visible = _cursor_visible


# ════════════════════════════════════════════════════════════════════════════
#  INPUT
# ════════════════════════════════════════════════════════════════════════════
func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed:
		var key : int = event.keycode

		match key:
			KEY_ENTER, KEY_KP_ENTER:
				_submit()

			KEY_BACKSPACE:
				if _input_buffer.length() > 0:
					_input_buffer = _input_buffer.left(_input_buffer.length() - 1)
					_update_input_display()

			KEY_UP:
				_history_navigate(-1)

			KEY_DOWN:
				_history_navigate(1)

			KEY_C:
				if event.ctrl_pressed:
					# Ctrl+C  –  cancel current input
					_print_line(PROMPT_STR + _input_buffer + "^C")
					_input_buffer = ""
					_history_idx = -1
					_update_input_display()
				else:
					_type_char(event)

			KEY_L:
				if event.ctrl_pressed:
					# Ctrl+L  –  clear screen
					_output_lines.clear()
					_output_label.clear()
				else:
					_type_char(event)

			_:
				_type_char(event)

		get_viewport().set_input_as_handled()


func _type_char(event: InputEventKey) -> void:
	var ch := char(event.unicode)
	# Only printable ASCII (32–126)
	if event.unicode >= 32 and event.unicode <= 126:
		_input_buffer += ch
		_update_input_display()


func _update_input_display() -> void:
	_input_label.text = _input_buffer
	# Reset blink so cursor stays visible while typing
	_cursor_timer = 0.0
	_cursor_visible = true
	_cursor_label.visible = true


# ════════════════════════════════════════════════════════════════════════════
#  SUBMIT / EXECUTE
# ════════════════════════════════════════════════════════════════════════════
func _submit() -> void:
	var raw := _input_buffer.strip_edges()

	# Echo the command
	_print_raw("[color=#4dffaa]" + PROMPT_STR + "[/color]" +
			   "[color=#ffffff]" + raw.xml_escape() + "[/color]")

	if raw != "":
		# Save to history (avoid duplicates at top)
		if _history.is_empty() or _history[0] != raw:
			_history.push_front(raw)
			if _history.size() > 100:
				_history.pop_back()

		_execute(raw)

	_input_buffer = ""
	_history_idx  = -1
	_update_input_display()
	_scroll_to_bottom()


func _execute(cmd: String) -> void:
	var parts  : Array = cmd.split(" ", false)
	var name_  : String = parts[0].to_lower()
	var args   : Array  = parts.slice(1)

	match name_:
		# ── built-in commands ────────────────────────────────────────────
		"help":
			_cmd_help(args)
		"clear", "cls":
			_output_lines.clear()
			_output_label.clear()
		"echo":
			_print_line((" ".join(args)) if args.size() > 0 else "")
		"history":
			for i in _history.size():
				_print_line("  %3d  %s" % [i + 1, _history[i]])
		"ver", "version":
			_print_line("Terminal v1.0  –  Godot 4")
		"exit", "quit":
			visible = false
		_:
			_print_error("Unknown command: '%s'  (type [b]help[/b] for a list)" % name_)


# ════════════════════════════════════════════════════════════════════════════
#  BUILT-IN COMMAND IMPLEMENTATIONS
# ════════════════════════════════════════════════════════════════════════════
func _cmd_help(_args: Array) -> void:
	_print_raw("")
	_print_raw("[b][color=#00ff72]Hello World[/color][/b]")
	_print_raw("")
	_print_raw("[color=#4dffaa]Available commands:[/color]")
	_print_raw("  [b]help[/b]          –  show this message")
	_print_raw("  [b]echo[/b] <text>   –  print text")
	_print_raw("  [b]clear[/b]         –  clear the screen")
	_print_raw("  [b]history[/b]       –  show command history")
	_print_raw("  [b]ver[/b]           –  show version")
	_print_raw("  [b]exit[/b]          –  hide terminal")
	_print_raw("")


# ════════════════════════════════════════════════════════════════════════════
#  OUTPUT HELPERS
# ════════════════════════════════════════════════════════════════════════════

## Append a plain text line (auto-escaped, no BBCode)
func _print_line(text: String) -> void:
	_print_raw(text.xml_escape())


## Append a BBCode line directly
func _print_raw(bbcode: String) -> void:
	_output_lines.append(bbcode)
	if _output_lines.size() > MAX_HISTORY:
		_output_lines.pop_front()
		# Rebuild from scratch to keep within limit
		_output_label.clear()
		for line in _output_lines:
			_output_label.append_text(line + "\n")
	else:
		_output_label.append_text(bbcode + "\n")


## Print a red error line
func _print_error(msg: String) -> void:
	_print_raw("[color=#ff4444]" + msg + "[/color]")


## Expose for other scripts: Terminal.print_output("text")
func print_output(text: String) -> void:
	_print_line(text)
	_scroll_to_bottom()


func _scroll_to_bottom() -> void:
	# Two frames lets RichTextLabel finish layout before we read max_value
	await get_tree().process_frame
	await get_tree().process_frame
	if _scroll:
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


# ════════════════════════════════════════════════════════════════════════════
#  HISTORY NAVIGATION  (↑ / ↓)
# ════════════════════════════════════════════════════════════════════════════
func _history_navigate(direction: int) -> void:
	if _history.is_empty():
		return
	_history_idx = clamp(_history_idx + direction, -1, _history.size() - 1)
	if _history_idx == -1:
		_input_buffer = ""
	else:
		_input_buffer = _history[_history_idx]
	_update_input_display()
