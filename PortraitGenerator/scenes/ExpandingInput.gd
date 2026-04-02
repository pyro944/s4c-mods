extends Control

# ExpandingInput: A TextEdit wrapped in a placeholder Control that expands on focus.
#
# When focused, the TextEdit reparents to `popup_root` so it renders above all other
# controls (a Godot 3.5 z-ordering workaround). When unfocused, it returns to this
# placeholder. Newlines are stripped so it behaves like a single-line input with
# word-wrap on focus.
#
# Setup (by the parent script):
#   input.popup_root = some_popup_node
#   input.connect("text_changed", self, "_on_input_text_changed")

signal text_changed()

# Must be set by the parent before the input can expand. The node the TextEdit
# reparents to when focused (usually the owning Popup).
var popup_root = null

# The minimum height used when the input has no content.
var default_height = 50

var _text_edit = null
var _style_inactive = null
var _style_active = null

var text setget set_text, get_text

func set_text(value):
	if _text_edit:
		_text_edit.set_text(value)

func get_text():
	if _text_edit:
		return _text_edit.text
	return ""

func setup(mod_path, min_size = Vector2(550, 50)):
    _text_edit = $TextEdit
    rect_min_size = min_size
    default_height = int(min_size.y)
    _load_styles(mod_path)
    _text_edit.connect("focus_entered", self , "_on_focus_entered")
    _text_edit.connect("focus_exited", self , "_on_focus_exited")
    _text_edit.connect("text_changed", self , "_on_text_changed")

func _load_styles(mod_path):
	var style_dir = mod_path + "/resources/styles"
	_style_inactive = load(style_dir + "/text_edit_inactive.tres")
	_style_active = load(style_dir + "/text_edit_active.tres")
	if _style_inactive:
		_text_edit.add_stylebox_override("normal", _style_inactive)
		_text_edit.add_stylebox_override("read_only", _style_inactive)
	if _style_active:
		_text_edit.add_stylebox_override("focus", _style_active)
	_text_edit.add_color_override("font_color", Color(0.1, 0.05, 0.08, 1))
	_text_edit.add_color_override("selection_color", Color(0.5, 0.4, 0.2, 0.7))
	_text_edit.add_color_override("cursor_color", Color(0, 0, 0))

# --- Focus lifecycle ---

func _on_focus_entered():
    if popup_root == null:
        return
    var ph_rect = get_global_rect()
    if _text_edit.get_parent() != popup_root:
        _text_edit.get_parent().remove_child(_text_edit)
        popup_root.add_child(_text_edit)
        _text_edit.grab_focus()
    _text_edit.set_anchors_and_margins_preset(Control.PRESET_TOP_LEFT)
    _text_edit.rect_global_position = ph_rect.position
    _text_edit.rect_size = ph_rect.size
    call_deferred("_apply_expanded_state")

func _apply_expanded_state():
	if not _text_edit.has_focus():
		return
	_text_edit.set_wrap_enabled(true)
	var ph_rect = get_global_rect()
	_text_edit.rect_global_position = ph_rect.position
	_text_edit.rect_size = Vector2(ph_rect.size.x, _calc_height(ph_rect.size.x))
	# Clamp bottom edge to viewport
	var screen_rect = get_viewport().get_visible_rect()
	var te_rect = _text_edit.get_global_rect()
	if te_rect.position.y + te_rect.size.y > screen_rect.position.y + screen_rect.size.y:
		_text_edit.rect_global_position = Vector2(
			te_rect.position.x,
			max(screen_rect.position.y, screen_rect.position.y + screen_rect.size.y - te_rect.size.y - 10)
		)

func _on_focus_exited():
	_text_edit.set_wrap_enabled(false)
	if _text_edit.get_parent() != self:
		_text_edit.get_parent().remove_child(_text_edit)
		add_child(_text_edit)
	_text_edit.set_anchors_and_margins_preset(Control.PRESET_WIDE)

func _on_text_changed():
	# Strip newlines so it behaves like a single-line input.
	if "\n" in _text_edit.text:
		_text_edit.text = _text_edit.text.replace("\n", "")
		_text_edit.cursor_set_line(0)
		_text_edit.cursor_set_column(_text_edit.text.length())
		return # The assignment above re-fires text_changed; expand happens on that pass
	if _text_edit.has_focus():
		call_deferred("_apply_expanded_state")
	emit_signal("text_changed")

# --- Public helpers ---

# Return the TextEdit to this placeholder. Call this when the popup hides while
# the input may still be focused/reparented.
func return_to_placeholder():
	_text_edit.set_wrap_enabled(false)
	if _text_edit.get_parent() != self:
		_text_edit.get_parent().remove_child(_text_edit)
		add_child(_text_edit)
	_text_edit.set_anchors_and_margins_preset(Control.PRESET_WIDE)

# Sync position when the scroll container moves while this input is expanded.
func sync_position():
	if _text_edit.get_parent() == popup_root:
		_text_edit.rect_global_position = get_global_rect().position

func _calc_height(width):
	var font = _text_edit.get_font("font", "")
	var txt = _text_edit.text
	if font == null or txt.empty():
		return default_height
	var usable_w = max(1.0, width - 20.0)
	var text_w = font.get_string_size(txt).x
	var line_h = font.get_height() + 6
	var visual_lines = max(1, int(ceil(text_w / usable_w)))
	return int(visual_lines * line_h) + 16
