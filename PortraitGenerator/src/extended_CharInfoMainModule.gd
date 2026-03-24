extends "res://gui_modules/CharacterInfo/CharInfoMainModule.gd"

var MOD_PATH = get_script().get_path().get_base_dir() + "/.."

var MAIN_THEME = load("res://assets/MainTheme.tres").duplicate()
var OPTIONS_THEME = load("res://assets/Themes_v2/UNIVERSAL/DropDown.tres")
var SAVE_ICON = load("res://assets/Textures_v2/CHAR_CREATION/Buttons/icon_save.png")
var DEFAULT_STEPS = 20
var DEFAULT_CFG = 7.5
var DEFAULT_DENOISE = 0.90
var DEFAULT_WIDTH = 768
var DEFAULT_HEIGHT = 1088
var INPUT_WIDTH = 550
var INPUT_HEIGHT = 50

var prompt_popup = null
var positive_input = null
var clothing_input = null
var negative_input = null
var _positive_placeholder = null
var _clothing_placeholder = null
var _negative_placeholder = null
var _prompt_scroll = null
var clothed_prompt_output = null
var clothed_negative_prompt_output = null
var nude_prompt_output = null
var nude_negative_prompt_output = null
var _clothed_prompt_placeholder = null
var _clothed_negative_prompt_placeholder = null
var _nude_prompt_placeholder = null
var _nude_negative_prompt_placeholder = null
var _output_user_modified = {"clothed": false, "clothed_negative": false, "nude": false, "nude_negative": false}
var _updating_prompts = false
# Expanding-input [text_edit, placeholder] pairs — single source of truth for reparenting logic
var _expanding_inputs = []

# ComfyUI integration
var comfyui_client = null
var comfyui_url_input = null
var comfyui_connect_button = null
var model_dropdown = null
var status_label = null
var preview_popup = null
var preview_close_btn = null
var preview_images_row = null
var _generated_textures = []
var _source_texture = null
var preview_title_label = null

# Generation settings inputs
var steps_input = null
var cfg_input = null
var denoise_input = null
var width_input = null
var height_input = null

# Generation buttons
var btn_generate_body = null
var btn_generate_nude = null
var btn_nude_from_body = null
var btn_generate_pregnant = null
var btn_pregnant_from_body = null
var btn_generate_nude_pregnant = null
var btn_nude_pregnant_from_nude = null
var btn_portrait_from_body = null
var btn_portrait_from_nude = null

# Tracks which button was pressed so the preview popup knows the save category
var _current_generation_type = -1
# Captures the person at generation dispatch time to prevent race conditions
var _generation_person = null

signal copy_pressed(prompt_type)

enum PromptOutput {
    CLOTHED = 0,
    CLOTHED_NEGATIVE = 1,
    NUDE = 2,
    NUDE_NEGATIVE = 3
}

enum GenerationType {
    BODY,
    NUDE,
    NUDE_FROM_BODY,
    PREGNANT,
    PREGNANT_FROM_BODY,
    NUDE_PREGNANT,
    NUDE_PREGNANT_FROM_NUDE,
    PORTRAIT_FROM_BODY,
    PORTRAIT_FROM_NUDE
}

func _init():
    # Add prompting button below Talk
    var prompting_button = build_prompting_button()
    add_child(prompting_button)
    prompting_button.connect('pressed', self , 'toggle_prompt_panel')

    # Construct prompting panel
    prompt_popup = build_prompt_panel()
    add_child(prompt_popup)

    # Construct preview popup
    preview_popup = build_preview_popup()
    add_child(preview_popup)

    call_deferred("_setup_comfyui_client")
    # Add close buttons after the popups are in the scene tree so
    # get_global_rect() returns the correct screen coordinates.
    call_deferred("_add_close_buttons")

func _add_close_buttons():
    _add_close_button_to_popup(prompt_popup)
    preview_close_btn = _add_close_button_to_popup(preview_popup)

# Loads the game's standard close button scene, adds it as a child of the
# popup, and anchors it to the top-right corner so it tracks popup size
# changes automatically — no global-position arithmetic needed.
func _add_close_button_to_popup(popup):
    var btn = load(ResourceScripts.scenedict.close).instance()
    popup.add_child(btn)
    btn.connect("pressed", popup, "hide")
    # Anchor right and top edges to the popup's top-right corner.
    btn.set_anchor(MARGIN_LEFT, 1.0)
    btn.set_anchor(MARGIN_TOP, 0.0)
    btn.set_anchor(MARGIN_RIGHT, 1.0)
    btn.set_anchor(MARGIN_BOTTOM, 0.0)
    # Negative left margin pulls the button leftward from the right edge.
    # 32 px is a safe estimate for the standard close button; it snaps flush
    # to the corner with no gap.
    btn.set_margin(MARGIN_LEFT, -32)
    btn.set_margin(MARGIN_RIGHT, 0)
    btn.set_margin(MARGIN_TOP, 0)
    btn.set_margin(MARGIN_BOTTOM, 32)
    return btn

func _setup_comfyui_client():
    comfyui_client = modding_core.modules.PortraitGenerator_comfyui
    if comfyui_client == null:
        return
    # Reparent into our scene tree so _process() and HTTPRequest children work
    var parent = comfyui_client.get_parent()
    if parent != null:
        parent.remove_child(comfyui_client)
    add_child(comfyui_client)
    # Connect signals
    comfyui_client.connect("connected", self , "_on_comfyui_connected")
    comfyui_client.connect("disconnected", self , "_on_comfyui_disconnected")
    comfyui_client.connect("connection_error", self , "_on_comfyui_connection_error")
    comfyui_client.connect("models_loaded", self , "_on_models_loaded")
    comfyui_client.connect("images_ready", self , "_on_images_ready")
    comfyui_client.connect("upload_complete", self , "_on_upload_complete")
    comfyui_client.connect("upload_error", self , "_on_upload_error")
    comfyui_client.connect("error", self , "_on_comfyui_error")

func toggle_prompt_panel():
    if not prompt_popup.visible:
        _refresh_comfyui_status()
        _update_button_states()
        prompt_popup.popup()
        call_deferred("_sync_all_exp_inputs")

func _refresh_comfyui_status():
    if comfyui_client == null:
        return
    match comfyui_client.state:
        comfyui_client.State.CONNECTED, comfyui_client.State.GENERATING, comfyui_client.State.FETCHING_RESULT:
            status_label.set_text("Status: Connected")
            comfyui_connect_button.set_text("Disconnect")
            comfyui_url_input.set_editable(false)
        _:
            status_label.set_text("Status: Disconnected")
            comfyui_connect_button.set_text("Connect")
            comfyui_url_input.set_editable(true)

func generate_prompts(force = false):
    var style = positive_input.text
    var clothing = clothing_input.text
    var negative = negative_input.text
    var prompts = modding_core.modules.PortraitGenerator_prompting.build_prompts(active_person, style, clothing, negative)
    _updating_prompts = true
    if force or not _output_user_modified["clothed"]:
        clothed_prompt_output.set_text(prompts.clothed_positive)
        _output_user_modified["clothed"] = false
    if force or not _output_user_modified["clothed_negative"]:
        clothed_negative_prompt_output.set_text(prompts.clothed_negative)
        _output_user_modified["clothed_negative"] = false
    if force or not _output_user_modified["nude"]:
        nude_prompt_output.set_text(prompts.nude_positive)
        _output_user_modified["nude"] = false
    if force or not _output_user_modified["nude_negative"]:
        nude_negative_prompt_output.set_text(prompts.nude_negative)
        _output_user_modified["nude_negative"] = false
    _updating_prompts = false

func _on_from_equipment_pressed():
    if active_person == null:
        return
    clothing_input.set_text(modding_core.modules.PortraitGenerator_prompting.build_equipment_prompt(active_person))

func build_prompting_button():
    var button = TextureButton.new()
    button.set_theme(MAIN_THEME)
    button.set_tooltip("Generate AI prompts")
    button.set_normal_texture(input_handler.loadimage(MOD_PATH + "/resources/images/button_prompting.png"))
    button.set_pressed_texture(input_handler.loadimage(MOD_PATH + "/resources/images/button_prompting_pressed.png"))
    button.set_hover_texture(input_handler.loadimage(MOD_PATH + "/resources/images/button_prompting_hover.png"))
    button.set_margin(0, 1240) # Left
    button.set_margin(1, 976) # Top
    return button

func _make_panel_bg():
    var bg = StyleBoxFlat.new()
    bg.set_bg_color(Color(0.16, 0.1, 0.12, 1))
    bg.set_border_color(Color(0.85, 0.85, 0.6, 1))
    bg.set_border_width(0, 3)
    bg.set_border_width(1, 3)
    bg.set_border_width(2, 3)
    bg.set_border_width(3, 3)
    return bg

func build_prompt_panel():
    var POPUP_W = 1200
    var POPUP_H = 750
    var LEFT_COL_W = 450
    var RIGHT_COL_W = 500
    var SEP_W = 10

    var popup = Popup.new()
    popup.set_theme(MAIN_THEME)
    popup.set_anchors_and_margins_preset(Control.PRESET_CENTER_LEFT)
    popup.set_size(Vector2(POPUP_W, POPUP_H))
    popup.set_margin(MARGIN_LEFT, 20)
    popup.connect("popup_hide", self , "_on_prompt_popup_hide")

    # Panel anchored to fill the popup so the background always covers the content.
    var panel = Panel.new()
    panel.set_anchors_and_margins_preset(Control.PRESET_WIDE)
    panel.add_stylebox_override('panel', _make_panel_bg())
    popup.add_child(panel)

    # Customize input field colors on our cloned theme
    MAIN_THEME.set_color('clear_button_color', 'LineEdit', Color(0, 0, 0, 1))
    MAIN_THEME.set_color('cursor_color', 'LineEdit', Color(0, 0, 0, 0.9))
    MAIN_THEME.set_color('font_color_uneditable', 'LineEdit', Color(0, 0, 0, 0.8))

    # Container exactly fills the panel, then a fixed-pixel margin via MarginContainer
    var margin = MarginContainer.new()
    margin.set_anchors_and_margins_preset(Control.PRESET_WIDE)
    margin.add_constant_override("margin_left", 10)
    margin.add_constant_override("margin_right", 10)
    margin.add_constant_override("margin_top", 10)
    margin.add_constant_override("margin_bottom", 10)
    panel.add_child(margin)

    # Outer VBox is the sole child of the MarginContainer
    var outer = VBoxContainer.new()
    outer.set_h_size_flags(Control.SIZE_EXPAND_FILL)
    outer.set_v_size_flags(Control.SIZE_EXPAND_FILL)
    margin.add_child(outer)

    # ScrollContainer fills the VBox; columns HBox is its sole child.
    # Horizontal scroll is suppressed by giving columns SIZE_EXPAND_FILL so it
    # never exceeds the container width. Vertical scroll appears automatically
    # when label fonts make the content taller than the popup.
    var scroll = ScrollContainer.new()
    scroll.set_h_size_flags(Control.SIZE_EXPAND_FILL)
    scroll.set_v_size_flags(Control.SIZE_EXPAND_FILL)
    outer.add_child(scroll)
    _prompt_scroll = scroll

    # Two-column content row
    var columns = HBoxContainer.new()
    columns.set_h_size_flags(Control.SIZE_EXPAND_FILL)
    scroll.add_child(columns)

    # --- Left column: prompt inputs and outputs ---
    var left_col = VBoxContainer.new()
    left_col.set_custom_minimum_size(Vector2(LEFT_COL_W, 0))
    # No EXPAND flag → HBoxContainer gives this column exactly its minimum width.
    # Right column has SIZE_EXPAND_FILL and absorbs all remaining space.
    columns.add_child(left_col)

    var positive_label = Label.new()
    positive_label.set_text("Positive prompt")
    var pos_pair = _make_expanding_input(INPUT_WIDTH, INPUT_HEIGHT)
    _positive_placeholder = pos_pair[0]
    positive_input = pos_pair[1]
    left_col.add_child(positive_label)
    left_col.add_child(_positive_placeholder)

    var clothing_label = Label.new()
    clothing_label.set_text("Clothing description")
    var clothing_row = HBoxContainer.new()
    var clo_pair = _make_expanding_input(0, INPUT_HEIGHT)
    _clothing_placeholder = clo_pair[0]
    _clothing_placeholder.set_h_size_flags(Control.SIZE_EXPAND_FILL)
    clothing_input = clo_pair[1]
    clothing_row.add_child(_clothing_placeholder)
    var from_equipment_button = Button.new()
    from_equipment_button.set_text("From equipment")
    from_equipment_button.set_custom_minimum_size(Vector2(0, INPUT_HEIGHT))
    from_equipment_button.connect('pressed', self , '_on_from_equipment_pressed')
    clothing_row.add_child(from_equipment_button)
    left_col.add_child(clothing_label)
    left_col.add_child(clothing_row)

    var negative_label = Label.new()
    negative_label.set_text("Negative prompt")
    var neg_pair = _make_expanding_input(INPUT_WIDTH, INPUT_HEIGHT)
    _negative_placeholder = neg_pair[0]
    negative_input = neg_pair[1]
    left_col.add_child(negative_label)
    left_col.add_child(_negative_placeholder)

    var generate_prompts_button = Button.new()
    generate_prompts_button.set_text("Generate Prompts")
    generate_prompts_button.connect('pressed', self , 'generate_prompts', [true])
    left_col.add_child(generate_prompts_button)

    left_col.add_child(build_prompt_output(PromptOutput.CLOTHED, "Clothed Prompt"))
    left_col.add_child(build_prompt_output(PromptOutput.CLOTHED_NEGATIVE, "Clothed Negative Prompt"))
    left_col.add_child(build_prompt_output(PromptOutput.NUDE, "Nude Prompt"))
    left_col.add_child(build_prompt_output(PromptOutput.NUDE_NEGATIVE, "Nude Negative Prompt"))

    # Thin panel acting as a column divider; VSeparator uses a scrollbar-like theme style
    var vsep = Panel.new()
    vsep.set_custom_minimum_size(Vector2(SEP_W, 0))
    var sep_style = StyleBoxFlat.new()
    sep_style.set_bg_color(Color(0.5, 0.5, 0.4, 0.4))
    vsep.add_stylebox_override("panel", sep_style)
    columns.add_child(vsep)

    # --- Right column: ComfyUI controls ---
    var right_col = VBoxContainer.new()
    right_col.set_custom_minimum_size(Vector2(RIGHT_COL_W, 0))
    columns.add_child(right_col)

    var comfyui_label = Label.new()
    comfyui_label.set_text("ComfyUI Server")
    right_col.add_child(comfyui_label)

    var url_row = HBoxContainer.new()
    comfyui_url_input = LineEdit.new()
    comfyui_url_input.set_h_size_flags(Control.SIZE_EXPAND_FILL)
    comfyui_url_input.set_custom_minimum_size(Vector2(0, INPUT_HEIGHT))
    comfyui_url_input.set_text("http://127.0.0.1:8000")
    comfyui_url_input.cursor_set_blink_enabled(true)
    comfyui_url_input.set_placeholder("http://host:port")
    url_row.add_child(comfyui_url_input)
    comfyui_connect_button = Button.new()
    comfyui_connect_button.set_text("Connect")
    comfyui_connect_button.set_custom_minimum_size(Vector2(90, INPUT_HEIGHT))
    comfyui_connect_button.connect("pressed", self , "_on_connect_pressed")
    url_row.add_child(comfyui_connect_button)
    right_col.add_child(url_row)

    status_label = Label.new()
    status_label.set_text("Status: Disconnected")
    right_col.add_child(status_label)

    var model_label = Label.new()
    model_label.set_text("Model:")
    right_col.add_child(model_label)
    model_dropdown = OptionButton.new()
    model_dropdown.set_theme(OPTIONS_THEME)
    model_dropdown.set_h_size_flags(Control.SIZE_EXPAND_FILL)
    model_dropdown.set_custom_minimum_size(Vector2(0, INPUT_HEIGHT))
    model_dropdown.add_item("(connect first)")
    model_dropdown.set_disabled(true)
    right_col.add_child(model_dropdown)

    # --- Generation settings ---
    var settings_row1 = HBoxContainer.new()
    settings_row1.add_child(_make_labeled_field("Steps:", str(DEFAULT_STEPS), "steps_input"))
    settings_row1.add_child(_make_labeled_field("CFG:", str(DEFAULT_CFG), "cfg_input"))
    settings_row1.add_child(_make_labeled_field("Denoise:", str(DEFAULT_DENOISE), "denoise_input"))
    right_col.add_child(settings_row1)

    var settings_row2 = HBoxContainer.new()
    settings_row2.add_child(_make_labeled_field("Width:", str(DEFAULT_WIDTH), "width_input"))
    settings_row2.add_child(_make_labeled_field("Height:", str(DEFAULT_HEIGHT), "height_input"))
    right_col.add_child(settings_row2)

    # --- Generation button groups ---
    btn_generate_body = _make_gen_button("New body", "_on_gen_body")
    right_col.add_child(btn_generate_body)

    var nude_row = HBoxContainer.new()
    btn_generate_nude = _make_gen_button("New nude", "_on_gen_nude")
    btn_nude_from_body = _make_gen_button("Nude from body", "_on_gen_nude_from_body")
    nude_row.add_child(btn_generate_nude)
    nude_row.add_child(btn_nude_from_body)
    right_col.add_child(nude_row)

    var preg_row = HBoxContainer.new()
    btn_generate_pregnant = _make_gen_button("New pregnant", "_on_gen_pregnant")
    btn_pregnant_from_body = _make_gen_button("Pregnant from body", "_on_gen_pregnant_from_body")
    preg_row.add_child(btn_generate_pregnant)
    preg_row.add_child(btn_pregnant_from_body)
    right_col.add_child(preg_row)

    var nudepreg_row = HBoxContainer.new()
    btn_generate_nude_pregnant = _make_gen_button("New nude pregnant", "_on_gen_nude_pregnant")
    btn_nude_pregnant_from_nude = _make_gen_button("Nude preg. from nude", "_on_gen_nude_pregnant_from_nude")
    nudepreg_row.add_child(btn_generate_nude_pregnant)
    nudepreg_row.add_child(btn_nude_pregnant_from_nude)
    right_col.add_child(nudepreg_row)

    var portrait_row = HBoxContainer.new()
    btn_portrait_from_body = _make_gen_button("Portrait from body", "_on_gen_portrait_from_body")
    btn_portrait_from_nude = _make_gen_button("Portrait from nude", "_on_gen_portrait_from_nude")
    portrait_row.add_child(btn_portrait_from_body)
    portrait_row.add_child(btn_portrait_from_nude)
    right_col.add_child(portrait_row)

    _expanding_inputs = [
        [positive_input, _positive_placeholder],
        [clothing_input, _clothing_placeholder],
        [negative_input, _negative_placeholder],
        [clothed_prompt_output, _clothed_prompt_placeholder],
        [clothed_negative_prompt_output, _clothed_negative_prompt_placeholder],
        [nude_prompt_output, _nude_prompt_placeholder],
        [nude_negative_prompt_output, _nude_negative_prompt_placeholder],
    ]

    return popup

func build_preview_popup():
    var popup = Popup.new()
    popup.set_theme(MAIN_THEME)
    popup.set_size(Vector2(400, 480))
    popup.set_anchors_and_margins_preset(Control.PRESET_CENTER_LEFT)
    popup.set_margin(MARGIN_LEFT, 20)

    # Panel anchored to fill the popup so the background always covers the content.
    var panel = Panel.new()
    panel.set_anchors_and_margins_preset(Control.PRESET_WIDE)
    panel.add_stylebox_override("panel", _make_panel_bg())
    popup.add_child(panel)

    var margin = MarginContainer.new()
    margin.set_anchors_and_margins_preset(Control.PRESET_WIDE)
    margin.add_constant_override("margin_left", 10)
    margin.add_constant_override("margin_right", 10)
    margin.add_constant_override("margin_top", 10)
    margin.add_constant_override("margin_bottom", 10)
    panel.add_child(margin)

    var outer = VBoxContainer.new()
    outer.set_h_size_flags(Control.SIZE_EXPAND_FILL)
    outer.set_v_size_flags(Control.SIZE_EXPAND_FILL)
    margin.add_child(outer)

    preview_title_label = Label.new()
    preview_title_label.set_text("Generated Image")
    preview_title_label.set_align(Label.ALIGN_CENTER)
    outer.add_child(preview_title_label)

    # Image row — populated dynamically when images arrive
    preview_images_row = HBoxContainer.new()
    preview_images_row.set_h_size_flags(Control.SIZE_EXPAND_FILL)
    preview_images_row.set_alignment(BoxContainer.ALIGN_CENTER)
    outer.add_child(preview_images_row)

    var try_again_button = Button.new()
    try_again_button.set_text("Try Again")
    try_again_button.connect("pressed", self , "_on_try_again_pressed")
    outer.add_child(try_again_button)

    return popup

func build_prompt_output(output_type, description):
    var total_layout = VBoxContainer.new()

    var label = Label.new()
    label.set_text(description)

    var output_layout = HBoxContainer.new()
    var out_pair = _make_expanding_input(INPUT_WIDTH, INPUT_HEIGHT)
    var ph = out_pair[0]
    var output = out_pair[1]
    ph.set_h_size_flags(Control.SIZE_EXPAND_FILL)

    var copy_button = TextureButton.new()
    copy_button.set_normal_texture(SAVE_ICON)

    match output_type:
        PromptOutput.CLOTHED:
            clothed_prompt_output = output
            _clothed_prompt_placeholder = ph
            copy_button.connect('pressed', self , 'copy_prompt_type_pressed', [PromptOutput.CLOTHED])
        PromptOutput.CLOTHED_NEGATIVE:
            clothed_negative_prompt_output = output
            _clothed_negative_prompt_placeholder = ph
            copy_button.connect('pressed', self , 'copy_prompt_type_pressed', [PromptOutput.CLOTHED_NEGATIVE])
        PromptOutput.NUDE:
            nude_prompt_output = output
            _nude_prompt_placeholder = ph
            copy_button.connect('pressed', self , 'copy_prompt_type_pressed', [PromptOutput.NUDE])
        PromptOutput.NUDE_NEGATIVE:
            nude_negative_prompt_output = output
            _nude_negative_prompt_placeholder = ph
            copy_button.connect('pressed', self , 'copy_prompt_type_pressed', [PromptOutput.NUDE_NEGATIVE])

    output.connect("text_changed", self , "_on_output_text_changed", [output_type])

    output_layout.add_child(ph)
    output_layout.add_child(copy_button)

    total_layout.add_child(label)
    total_layout.add_child(output_layout)

    return total_layout

# --- UI Helper Methods ---

func _make_labeled_field(label_text, default_value, field_var_name):
    var container = VBoxContainer.new()
    container.set_h_size_flags(Control.SIZE_EXPAND_FILL)
    var label = Label.new()
    label.set_text(label_text)
    container.add_child(label)
    var input = LineEdit.new()
    input.set_text(default_value)
    input.set_custom_minimum_size(Vector2(0, 35))
    input.cursor_set_blink_enabled(true)
    container.add_child(input)
    set(field_var_name, input)
    return container

func _make_gen_button(text, callback):
    var button = Button.new()
    button.set_text(text)
    button.set_h_size_flags(Control.SIZE_EXPAND_FILL)
    button.set_custom_minimum_size(Vector2(0, 36))
    button.set_disabled(true)
    button.connect("pressed", self , callback)
    return button

func _load_texture_from_path(path):
    var img = Image.new()
    if img.load(path) != OK:
        return null
    var tex = ImageTexture.new()
    tex.create_from_image(img)
    return tex

# --- Expanding input helpers ---

# Returns [placeholder_Control, TextEdit].
# The placeholder holds space in the VBox layout at a fixed height. When focused,
# the TextEdit is reparented to the popup (last child = renders on top) and sized
# to fit its content. When blurred it is returned to the placeholder.
func _make_expanding_input(min_width, min_height):
    var te_style = StyleBoxFlat.new()
    te_style.set_bg_color(Color(0.95, 0.92, 0.85, 1))
    te_style.set_border_color(Color(0.4, 0.35, 0.3, 1))
    te_style.set_border_width_all(1)

    var placeholder = Control.new()
    placeholder.set_custom_minimum_size(Vector2(min_width, min_height))
    placeholder.set_mouse_filter(Control.MOUSE_FILTER_IGNORE)

    var te = TextEdit.new()
    te.set_theme(MAIN_THEME)
    te.add_stylebox_override("normal", te_style)
    te.add_stylebox_override("focus", te_style)
    te.add_stylebox_override("read_only", te_style)
    te.add_color_override("font_color", Color(0.1, 0.05, 0.08, 1))
    te.add_color_override("selection_color", Color(0.5, 0.4, 0.2, 0.7))
    te.cursor_set_blink_enabled(true)
    te.set_wrap_enabled(false)
    te.set_anchors_and_margins_preset(Control.PRESET_WIDE)
    te.connect("focus_entered", self , "_on_exp_focus_entered", [te])
    te.connect("focus_exited", self , "_on_exp_focus_exited", [te])
    te.connect("text_changed", self , "_on_exp_text_changed", [te])
    placeholder.add_child(te)
    return [placeholder, te]

func _get_placeholder_for(te):
    for pair in _expanding_inputs:
        if pair[0] == te:
            return pair[1]
    return null

# Only needs to act when the TextEdit is living in the popup (focused/expanded
# state) and the scroll container has moved its placeholder underneath it.
func _sync_exp_input(te, ph):
    if not is_instance_valid(te) or not is_instance_valid(ph):
        return
    if te.get_parent() == prompt_popup:
        te.rect_global_position = ph.get_global_rect().position

func _sync_all_exp_inputs():
    for pair in _expanding_inputs:
        _sync_exp_input(pair[0], pair[1])

func _on_exp_focus_entered(te):
    var ph = _get_placeholder_for(te)
    if ph == null:
        return
    # Capture position before reparenting changes the tree.
    var ph_rect = ph.get_global_rect()
    # Move to popup so it is the last child and renders above everything.
    if te.get_parent() != prompt_popup:
        te.get_parent().remove_child(te)
        prompt_popup.add_child(te)
        te.grab_focus()
    # Switch from fill-parent anchors to manual positioning before sizing.
    te.set_anchors_and_margins_preset(Control.PRESET_TOP_LEFT)
    te.rect_global_position = ph_rect.position
    te.rect_size = ph_rect.size
    # Defer wrap+expand so the reparent layout pass completes first.
    call_deferred("_apply_expanded_state", te)

func _apply_expanded_state(te):
    if not te.has_focus():
        return
    var ph = _get_placeholder_for(te)
    if ph == null:
        return
    te.set_wrap_enabled(true)
    var ph_rect = ph.get_global_rect()
    te.rect_global_position = ph_rect.position
    te.rect_size = Vector2(ph_rect.size.x, _calc_exp_height(te, ph_rect.size.x))

func _on_exp_focus_exited(te):
    te.set_wrap_enabled(false)
    var ph = _get_placeholder_for(te)
    if ph == null:
        return
    if te.get_parent() != ph:
        te.get_parent().remove_child(te)
        ph.add_child(te)
    te.set_anchors_and_margins_preset(Control.PRESET_WIDE)

func _on_prompt_popup_hide():
    # If the popup closes while a field is still reparented to it (e.g. the
    # close button was clicked while a field had focus), return them to their
    # placeholders so the next popup() shows a clean state.
    for pair in _expanding_inputs:
        var te = pair[0]
        var ph = pair[1]
        if not is_instance_valid(te) or not is_instance_valid(ph):
            continue
        te.set_wrap_enabled(false)
        if te.get_parent() != ph:
            te.get_parent().remove_child(te)
            ph.add_child(te)
        te.set_anchors_and_margins_preset(Control.PRESET_WIDE)

func _on_exp_text_changed(te):
    # TextEdit inserts a real newline on Enter; strip it to behave like LineEdit.
    if "\n" in te.text:
        te.text = te.text.replace("\n", "")
        te.cursor_set_line(0)
        te.cursor_set_column(te.text.length())
        return # assignment above re-fires text_changed; expand happens on that pass
    if te.has_focus():
        call_deferred("_apply_expanded_state", te)

func _on_output_text_changed(output_type):
    if _updating_prompts:
        return
    match output_type:
        PromptOutput.CLOTHED:
            _output_user_modified["clothed"] = true
        PromptOutput.CLOTHED_NEGATIVE:
            _output_user_modified["clothed_negative"] = true
        PromptOutput.NUDE:
            _output_user_modified["nude"] = true
        PromptOutput.NUDE_NEGATIVE:
            _output_user_modified["nude_negative"] = true

# Estimates the pixel height needed to display all text in `te` when wrapped
# to `width` pixels wide.
func _calc_exp_height(te, width):
    var font = te.get_font("font", "")
    var txt = te.text
    if font == null or txt.empty():
        return INPUT_HEIGHT
    var usable_w = max(1.0, width - 20.0)
    var text_w = font.get_string_size(txt).x
    var line_h = font.get_height() + 6
    var visual_lines = max(1, int(ceil(text_w / usable_w)))
    return int(visual_lines * line_h) + 16

# --- Button State Management ---

func _has_body_image():
    if active_person == null:
        return false
    var path = active_person.get_stat('body_image')
    if path == null or path == "":
        return false
    var file = File.new()
    return file.file_exists(path)

func _get_nude_path_from_body(body_path):
    var dir = body_path.get_base_dir()
    var filename = body_path.get_file()
    var nude_dir = dir.replace("/bodies", "/exposed")
    return nude_dir + "/" + filename

func _has_nude_image():
    if not _has_body_image():
        return false
    var body_path = active_person.get_stat('body_image')
    var nude_path = _get_nude_path_from_body(body_path)
    var file = File.new()
    return file.file_exists(nude_path)

func _get_all_gen_buttons():
    return [btn_generate_body, btn_generate_nude, btn_nude_from_body,
            btn_generate_pregnant, btn_pregnant_from_body,
            btn_generate_nude_pregnant, btn_nude_pregnant_from_nude,
            btn_portrait_from_body, btn_portrait_from_nude]

func _disable_all_gen_buttons():
    for btn in _get_all_gen_buttons():
        if btn != null:
            btn.set_disabled(true)

func _update_button_states():
    var connected = comfyui_client != null and (comfyui_client.state == comfyui_client.State.CONNECTED)
    var has_model = model_dropdown.get_selected() >= 0 and not model_dropdown.is_disabled()
    var can_generate = connected and has_model
    var has_body = _has_body_image()
    var has_nude = _has_nude_image()

    # txt2img buttons: only need connection + model
    btn_generate_body.set_disabled(not can_generate)
    btn_generate_nude.set_disabled(not can_generate)
    btn_generate_pregnant.set_disabled(not can_generate)
    btn_generate_nude_pregnant.set_disabled(not can_generate)

    # img2img "from body" buttons: need connection + model + body image
    btn_nude_from_body.set_disabled(not (can_generate and has_body))
    btn_pregnant_from_body.set_disabled(not (can_generate and has_body))

    # img2img "from nude" button: need connection + model + nude image
    btn_nude_pregnant_from_nude.set_disabled(not (can_generate and has_nude))

    # Portrait buttons: need connection + model + respective source image
    btn_portrait_from_body.set_disabled(not (can_generate and has_body))
    btn_portrait_from_nude.set_disabled(not (can_generate and has_nude))
    
func _update_page():
	gui_controller.slavepanel.BodyModule.update()
	gui_controller.slavepanel.SummaryModule.show_summary()

# --- Generation Settings Helpers ---

func _get_gen_steps():
    return int(steps_input.text) if steps_input.text.is_valid_integer() else DEFAULT_STEPS

func _get_gen_cfg():
    return float(cfg_input.text) if cfg_input.text.is_valid_float() else DEFAULT_CFG

func _get_gen_denoise():
    return float(denoise_input.text) if denoise_input.text.is_valid_float() else DEFAULT_DENOISE

func _get_gen_width():
    return int(width_input.text) if width_input.text.is_valid_integer() else DEFAULT_WIDTH

func _get_gen_height():
    return int(height_input.text) if height_input.text.is_valid_integer() else DEFAULT_HEIGHT

func _get_selected_model():
    var idx = model_dropdown.get_selected()
    if idx < 0:
        return ""
    return model_dropdown.get_item_text(idx)

func _get_save_category():
    match _current_generation_type:
        GenerationType.BODY:
            return comfyui_client.SaveCategory.CLOTHED_BODY
        GenerationType.NUDE, GenerationType.NUDE_FROM_BODY:
            return comfyui_client.SaveCategory.NUDE_BODY
        GenerationType.PREGNANT, GenerationType.PREGNANT_FROM_BODY:
            return comfyui_client.SaveCategory.PREGNANT_CLOTHED
        GenerationType.NUDE_PREGNANT, GenerationType.NUDE_PREGNANT_FROM_NUDE:
            return comfyui_client.SaveCategory.PREGNANT_NUDE
        GenerationType.PORTRAIT_FROM_BODY, GenerationType.PORTRAIT_FROM_NUDE:
            return comfyui_client.SaveCategory.PORTRAIT
    return comfyui_client.SaveCategory.CLOTHED_BODY

# --- ComfyUI Signal Handlers ---

func _on_connect_pressed():
    if comfyui_client == null:
        return
    if comfyui_client.state == comfyui_client.State.DISCONNECTED:
        var url = comfyui_url_input.text.strip_edges()
        if url == "":
            status_label.set_text("Status: Enter a URL first")
            return
        status_label.set_text("Status: Connecting...")
        comfyui_connect_button.set_disabled(true)
        comfyui_client.connect_to_comfyui(url)
    else:
        comfyui_client.disconnect_from_comfyui()

func _on_comfyui_connected():
    status_label.set_text("Status: Connected")
    comfyui_connect_button.set_text("Disconnect")
    comfyui_connect_button.set_disabled(false)
    comfyui_url_input.set_editable(false)
    comfyui_client.fetch_models()

func _on_comfyui_disconnected():
    status_label.set_text("Status: Disconnected")
    comfyui_connect_button.set_text("Connect")
    comfyui_connect_button.set_disabled(false)
    comfyui_url_input.set_editable(true)
    model_dropdown.clear()
    model_dropdown.add_item("(connect first)")
    model_dropdown.set_disabled(true)
    _disable_all_gen_buttons()

func _on_comfyui_connection_error(message):
    status_label.set_text("Error: " + str(message))
    comfyui_connect_button.set_text("Connect")
    comfyui_connect_button.set_disabled(false)
    comfyui_url_input.set_editable(true)

func _on_models_loaded(model_list):
    model_dropdown.clear()
    if model_list.size() == 0:
        model_dropdown.add_item("(no models found)")
        model_dropdown.set_disabled(true)
        return
    for model_name in model_list:
        model_dropdown.add_item(model_name)
    model_dropdown.set_disabled(false)
    _update_button_states()

func _on_images_ready(textures):
    _generated_textures = textures
    status_label.set_text("Status: %d image(s) ready" % textures.size())
    _update_button_states()
    _rebuild_preview_images(textures)
    preview_popup.popup()

func _rebuild_preview_images(textures):
    var MAX_POPUP_W = 1100
    var GAP = 8
    var MARGIN = 20
    # CTRL_H covers: title label + save button + try-again button
    # + VBox separations + outer margins (~10px top + 10px bottom).
    var CTRL_H = 160

    var gen_count = min(textures.size(), 5)
    var has_source = _source_texture != null
    var total_count = gen_count + (1 if has_source else 0)

    # Update title to reflect workflow type
    if has_source:
        preview_title_label.set_text("Original → Generated")
    else:
        preview_title_label.set_text("Generated Image")

    # Scale each image to be as tall as possible (max 600px) while keeping
    # the total popup width under MAX_POPUP_W.
    var max_image_w = int((MAX_POPUP_W - MARGIN - (total_count - 1) * GAP) / total_count)
    var IMAGE_W = min(max_image_w, int(600.0 * 768.0 / 1088.0)) # 600px tall -> 423px wide
    var IMAGE_H = int(IMAGE_W * 1088.0 / 768.0)

    var popup_w = total_count * IMAGE_W + (total_count - 1) * GAP + MARGIN
    var popup_h = IMAGE_H + CTRL_H

    preview_popup.set_size(Vector2(popup_w, popup_h))

    # Free old image columns immediately so there is no flash when the popup opens
    var old_children = preview_images_row.get_children()
    for child in old_children:
        preview_images_row.remove_child(child)
        child.free()

    # Source image column (img2img only)
    if has_source:
        var col = VBoxContainer.new()

        var tex_rect = TextureRect.new()
        tex_rect.set_custom_minimum_size(Vector2(IMAGE_W, IMAGE_H))
        tex_rect.set_stretch_mode(TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
        tex_rect.set_expand(true)
        tex_rect.set_texture(_source_texture)
        col.add_child(tex_rect)

        var orig_label = Label.new()
        orig_label.set_text("Original")
        orig_label.set_align(Label.ALIGN_CENTER)
        orig_label.set_custom_minimum_size(Vector2(IMAGE_W, 0))
        col.add_child(orig_label)

        preview_images_row.add_child(col)

    # Generated image columns
    for i in range(gen_count):
        var col = VBoxContainer.new()

        var tex_rect = TextureRect.new()
        tex_rect.set_custom_minimum_size(Vector2(IMAGE_W, IMAGE_H))
        tex_rect.set_stretch_mode(TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
        tex_rect.set_expand(true)
        tex_rect.set_texture(textures[i])
        col.add_child(tex_rect)

        var save_btn = Button.new()
        save_btn.set_text("Save")
        save_btn.set_custom_minimum_size(Vector2(IMAGE_W, 0))
        save_btn.connect("pressed", self , "_on_save_image_pressed", [i])
        col.add_child(save_btn)

        preview_images_row.add_child(col)

func _on_comfyui_error(message):
    status_label.set_text("Error: " + str(message))
    _update_button_states()
    comfyui_connect_button.set_disabled(false)

# --- Generation Dispatch: txt2img ---

# Config for each txt2img generation type: [positive_output, negative_output, suffix, status_text]
var _txt2img_config = {}

func _init_txt2img_config():
    _txt2img_config = {
        GenerationType.BODY: [clothed_prompt_output, clothed_negative_prompt_output, "", "body"],
        GenerationType.NUDE: [nude_prompt_output, nude_negative_prompt_output, "", "nude"],
        GenerationType.PREGNANT: [clothed_prompt_output, clothed_negative_prompt_output, ", pregnant", "pregnant"],
        GenerationType.NUDE_PREGNANT: [nude_prompt_output, nude_negative_prompt_output, ", pregnant", "nude pregnant"],
    }

func _do_txt2img(gen_type):
    if comfyui_client == null or active_person == null:
        return
    if not _txt2img_config:
        _init_txt2img_config()
    var config = _txt2img_config[gen_type]
    _current_generation_type = gen_type
    _generation_person = active_person
    _source_texture = null
    generate_prompts()
    var model = _get_selected_model()
    if model == "":
        return
    var pos = config[0].text + config[2]
    var neg = config[1].text
    status_label.set_text("Status: Generating %s..." % config[3])
    _disable_all_gen_buttons()
    comfyui_client.generate_image(model, pos, neg, -1, _get_gen_width(), _get_gen_height(), _get_gen_steps(), _get_gen_cfg())

func _on_gen_body():
    _do_txt2img(GenerationType.BODY)

func _on_gen_nude():
    _do_txt2img(GenerationType.NUDE)

func _on_gen_pregnant():
    _do_txt2img(GenerationType.PREGNANT)

func _on_gen_nude_pregnant():
    _do_txt2img(GenerationType.NUDE_PREGNANT)

# --- Generation Dispatch: img2img / portrait (upload then generate) ---

func _do_upload_gen(gen_type, use_nude_path, show_source_in_preview, status_text):
    if comfyui_client == null or active_person == null:
        return
    _current_generation_type = gen_type
    _generation_person = active_person
    generate_prompts()
    var body_path = active_person.get_stat('body_image')
    var source_path = _get_nude_path_from_body(body_path) if use_nude_path else body_path
    _source_texture = _load_texture_from_path(source_path) if show_source_in_preview else null
    status_label.set_text("Status: Uploading %s..." % status_text)
    _disable_all_gen_buttons()
    comfyui_client.upload_image(source_path)

func _on_gen_nude_from_body():
    _do_upload_gen(GenerationType.NUDE_FROM_BODY, false, true, "body image")

func _on_gen_pregnant_from_body():
    _do_upload_gen(GenerationType.PREGNANT_FROM_BODY, false, true, "body image")

func _on_gen_nude_pregnant_from_nude():
    _do_upload_gen(GenerationType.NUDE_PREGNANT_FROM_NUDE, true, true, "nude image")

func _on_gen_portrait_from_body():
    _do_upload_gen(GenerationType.PORTRAIT_FROM_BODY, false, false, "body image")

func _on_gen_portrait_from_nude():
    _do_upload_gen(GenerationType.PORTRAIT_FROM_NUDE, true, false, "nude image")

# --- Upload Complete -> img2img ---

func _on_upload_complete(uploaded_filename):
    var model = _get_selected_model()
    if model == "":
        _update_button_states()
        return
    var pos = ""
    var neg = ""
    match _current_generation_type:
        GenerationType.NUDE_FROM_BODY:
            pos = nude_prompt_output.text
            neg = nude_negative_prompt_output.text
        GenerationType.PREGNANT_FROM_BODY:
            pos = clothed_prompt_output.text + ", pregnant"
            neg = clothed_negative_prompt_output.text
        GenerationType.NUDE_PREGNANT_FROM_NUDE:
            pos = nude_prompt_output.text + ", pregnant"
            neg = nude_negative_prompt_output.text
        GenerationType.PORTRAIT_FROM_BODY:
            pos = clothed_prompt_output.text
            neg = clothed_negative_prompt_output.text
        GenerationType.PORTRAIT_FROM_NUDE:
            pos = nude_prompt_output.text
            neg = nude_negative_prompt_output.text
    if _current_generation_type == GenerationType.PORTRAIT_FROM_BODY or \
            _current_generation_type == GenerationType.PORTRAIT_FROM_NUDE:
        status_label.set_text("Status: Generating portrait (face crop)...")
        comfyui_client.generate_face_crop(model, pos, neg, uploaded_filename, -1, _get_gen_steps(), _get_gen_cfg())
    else:
        status_label.set_text("Status: Generating (img2img)...")
        comfyui_client.generate_img2img(model, pos, neg, uploaded_filename, _get_gen_denoise(), -1, _get_gen_steps(), _get_gen_cfg())

func _on_upload_error(message):
    status_label.set_text("Upload error: " + str(message))
    _update_button_states()

# --- Save Handler ---

func _on_save_image_pressed(image_index):
    var person = _generation_person if _generation_person != null else active_person
    if image_index >= _generated_textures.size() or person == null or comfyui_client == null:
        return
    var texture = _generated_textures[image_index]
    var category = _get_save_category()
    var saved_path = comfyui_client.save_image(texture, person.id, person.get_full_name(), category)
    if saved_path == "":
        return
    _apply_saved_image_stat(saved_path, category, person)
    status_label.set_text("Saved %s image!" % comfyui_client.SaveCategory.keys()[category])
    _update_button_states()

func _apply_saved_image_stat(saved_path, category, person):
    match category:
        comfyui_client.SaveCategory.PORTRAIT:
            person.set_stat('icon_image', saved_path)
            person.set_stat('dynamic_portrait', false)
            person.set_stat('player_selected_icon', true)
            person.set_stat('portrait_update', false)
        comfyui_client.SaveCategory.CLOTHED_BODY:
            person.set_stat('body_image', saved_path)
            person.set_stat('player_selected_body', true)
    _update_page()

# --- Try Again ---

var _gen_handlers = {}

func _init_gen_handlers():
    _gen_handlers = {
        GenerationType.BODY: "_on_gen_body",
        GenerationType.NUDE: "_on_gen_nude",
        GenerationType.NUDE_FROM_BODY: "_on_gen_nude_from_body",
        GenerationType.PREGNANT: "_on_gen_pregnant",
        GenerationType.PREGNANT_FROM_BODY: "_on_gen_pregnant_from_body",
        GenerationType.NUDE_PREGNANT: "_on_gen_nude_pregnant",
        GenerationType.NUDE_PREGNANT_FROM_NUDE: "_on_gen_nude_pregnant_from_nude",
        GenerationType.PORTRAIT_FROM_BODY: "_on_gen_portrait_from_body",
        GenerationType.PORTRAIT_FROM_NUDE: "_on_gen_portrait_from_nude",
    }

func _on_try_again_pressed():
    preview_popup.hide()
    if not _gen_handlers:
        _init_gen_handlers()
    if _current_generation_type in _gen_handlers:
        call(_gen_handlers[_current_generation_type])

# --- Clipboard Copy ---

func copy_prompt_type_pressed(prompt_type):
    match prompt_type:
        PromptOutput.CLOTHED:
            OS.clipboard = clothed_prompt_output.text
        PromptOutput.CLOTHED_NEGATIVE:
            OS.clipboard = clothed_negative_prompt_output.text
        PromptOutput.NUDE:
            OS.clipboard = nude_prompt_output.text
        PromptOutput.NUDE_NEGATIVE:
            OS.clipboard = nude_negative_prompt_output.text
