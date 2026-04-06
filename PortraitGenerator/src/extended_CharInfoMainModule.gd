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
var _prompt_scroll = null
var clothed_prompt_output = null
var clothed_negative_prompt_output = null
var nude_prompt_output = null
var nude_negative_prompt_output = null
var _output_user_modified = {"clothed": false, "clothed_negative": false, "nude": false, "nude_negative": false}
var _updating_prompts = false
# All ExpandingInput instances — used for return_to_placeholder on popup hide
var _expanding_inputs = []

# Face prompts, not user-configurable
var face_positive_prompt = ""
var face_negative_prompt = ""

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
var _preview_save_type_selectors = {}
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

# Settings popup
var settings_popup = null
var lora_config = null
var util = null
var _available_loras = []
var _workflow_dropdowns = {}
var _lora_search = null
var _lora_popup = null
var _lora_weight_input = null
var _lora_entries_container = null
var _lora_subkey_dropdown = null
var _lora_subkey_container = null
var _current_lora_tab = "global"
var _lora_tab_buttons = {}

signal copy_pressed(prompt_type)

enum PromptOutput {
    CLOTHED = 0,
    CLOTHED_NEGATIVE = 1,
    NUDE = 2,
    NUDE_NEGATIVE = 3
}

var GenerationType

# Scene and script resources — loaded once in _init()
var _ExpandingInputScene = null
var _ExpandingInputScript = null
var _PromptOutputScene = null
var _FilterableDropdownScene = null
var _FilterableDropdownScript = null
var _PANEL_BG = null
var _SEPARATOR_BG = null

func _ready():
    GenerationType = modding_core.modules.PortraitGenerator_util.GenerationType

func _init():
    # Load shared resources
    _PANEL_BG = load(MOD_PATH + "/resources/styles/panel_bg.tres")
    _SEPARATOR_BG = load(MOD_PATH + "/resources/styles/column_separator.tres")
    _ExpandingInputScene = load(MOD_PATH + "/scenes/ExpandingInput.tscn")
    _ExpandingInputScript = load(MOD_PATH + "/scenes/ExpandingInput.gd")
    _PromptOutputScene = load(MOD_PATH + "/scenes/PromptOutput.tscn")
    _FilterableDropdownScene = load(MOD_PATH + "/scenes/FilterableDropdown.tscn")
    _FilterableDropdownScript = load(MOD_PATH + "/scenes/FilterableDropdown.gd")

    # Customize input field colors on our cloned theme
    MAIN_THEME.set_color('clear_button_color', 'LineEdit', Color(0, 0, 0, 1))
    MAIN_THEME.set_color('cursor_color', 'LineEdit', Color(0, 0, 0, 0.9))
    MAIN_THEME.set_color('font_color_uneditable', 'LineEdit', Color(0, 0, 0, 0.8))

    # Add prompting button below Talk
    var prompting_button = _build_prompting_button()
    add_child(prompting_button)
    prompting_button.connect('pressed', self , 'toggle_prompt_panel')

    # Construct popups from scenes
    prompt_popup = _setup_prompt_panel()
    add_child(prompt_popup)

    preview_popup = _setup_preview_popup()
    add_child(preview_popup)

    settings_popup = _setup_settings_popup()
    add_child(settings_popup)

    call_deferred("_setup_comfyui_client")
    call_deferred("_add_close_buttons")

# --- Scene Setup Methods ---

func _instance_expanding_input(popup_root, min_size = Vector2(550, 50)):
    var input = _ExpandingInputScene.instance()
    input.set_script(_ExpandingInputScript)
    input.setup(MOD_PATH, min_size)
    input.popup_root = popup_root
    _expanding_inputs.append(input)
    return input

func _instance_prompt_output(popup_root, output_type, description):
    var output_node = _PromptOutputScene.instance()
    output_node.get_node("DescriptionLabel").set_text(description)

    var input = _instance_expanding_input(popup_root, Vector2(INPUT_WIDTH, INPUT_HEIGHT))
    input.set_h_size_flags(Control.SIZE_EXPAND_FILL)
    var placeholder = output_node.get_node("OutputRow/InputPlaceholder")
    _replace_placeholder(placeholder, input)

    var copy_button = output_node.get_node("OutputRow/CopyButton")

    match output_type:
        PromptOutput.CLOTHED:
            clothed_prompt_output = input
            copy_button.connect('pressed', self , '_copy_prompt_type_pressed', [PromptOutput.CLOTHED])
        PromptOutput.CLOTHED_NEGATIVE:
            clothed_negative_prompt_output = input
            copy_button.connect('pressed', self , '_copy_prompt_type_pressed', [PromptOutput.CLOTHED_NEGATIVE])
        PromptOutput.NUDE:
            nude_prompt_output = input
            copy_button.connect('pressed', self , '_copy_prompt_type_pressed', [PromptOutput.NUDE])
        PromptOutput.NUDE_NEGATIVE:
            nude_negative_prompt_output = input
            copy_button.connect('pressed', self , '_copy_prompt_type_pressed', [PromptOutput.NUDE_NEGATIVE])

    input.connect("text_changed", self , "_on_output_text_changed", [output_type])
    return output_node

func _replace_placeholder(placeholder, replacement):
    var parent = placeholder.get_parent()
    var idx = placeholder.get_index()
    parent.remove_child(placeholder)
    placeholder.queue_free()
    parent.add_child(replacement)
    parent.move_child(replacement, idx)

func _setup_prompt_panel():
    var popup = load(MOD_PATH + "/scenes/PromptPanel.tscn").instance()
    popup.connect("popup_hide", self , "_on_prompt_popup_hide")

    # Apply mod styles
    popup.get_node("Panel").add_stylebox_override("panel", _PANEL_BG)
    popup.get_node("Panel/Margin/Outer/Scroll/Columns/ColumnSeparator").add_stylebox_override("panel", _SEPARATOR_BG)

    _prompt_scroll = popup.get_node("Panel/Margin/Outer/Scroll")
    var left_col = popup.get_node("Panel/Margin/Outer/Scroll/Columns/LeftColumn")
    var right_col = popup.get_node("Panel/Margin/Outer/Scroll/Columns/RightColumn")

    # --- Left column: Insert ExpandingInputs at placeholders ---
    positive_input = _instance_expanding_input(popup, Vector2(INPUT_WIDTH, INPUT_HEIGHT))
    _replace_placeholder(left_col.get_node("PositiveInputPlaceholder"), positive_input)

    clothing_input = _instance_expanding_input(popup, Vector2(0, INPUT_HEIGHT))
    clothing_input.set_h_size_flags(Control.SIZE_EXPAND_FILL)
    _replace_placeholder(left_col.get_node("ClothingRow/ClothingInputPlaceholder"), clothing_input)

    negative_input = _instance_expanding_input(popup, Vector2(INPUT_WIDTH, INPUT_HEIGHT))
    _replace_placeholder(left_col.get_node("NegativeInputPlaceholder"), negative_input)

    # Wire left-column signals
    left_col.get_node("ClothingRow/FromEquipmentBtn").connect('pressed', self , '_on_from_equipment_pressed')
    left_col.get_node("GeneratePromptsBtn").connect('pressed', self , '_generate_prompts', [true])

    # Insert PromptOutput sub-scenes at placeholders
    _replace_placeholder(left_col.get_node("ClothedOutputPlaceholder"),
        _instance_prompt_output(popup, PromptOutput.CLOTHED, "Clothed Prompt"))
    _replace_placeholder(left_col.get_node("ClothedNegOutputPlaceholder"),
        _instance_prompt_output(popup, PromptOutput.CLOTHED_NEGATIVE, "Clothed Negative Prompt"))
    _replace_placeholder(left_col.get_node("NudeOutputPlaceholder"),
        _instance_prompt_output(popup, PromptOutput.NUDE, "Nude Prompt"))
    _replace_placeholder(left_col.get_node("NudeNegOutputPlaceholder"),
        _instance_prompt_output(popup, PromptOutput.NUDE_NEGATIVE, "Nude Negative Prompt"))

    # --- Right column: grab node references and wire signals ---
    comfyui_url_input = right_col.get_node("UrlRow/UrlInput")
    comfyui_connect_button = right_col.get_node("UrlRow/ConnectBtn")
    comfyui_connect_button.connect("pressed", self , "_on_connect_pressed")

    status_label = right_col.get_node("StatusLabel")
    model_dropdown = right_col.get_node("ModelDropdown")
    model_dropdown.add_item("(connect first)")
    model_dropdown.connect("item_selected", self , "_on_model_item_selected")

    steps_input = right_col.get_node("SettingsRow1/StepsCol/StepsInput")
    cfg_input = right_col.get_node("SettingsRow1/CfgCol/CfgInput")
    denoise_input = right_col.get_node("SettingsRow1/DenoiseCol/DenoiseInput")
    width_input = right_col.get_node("SettingsRow2/WidthCol/WidthInput")
    height_input = right_col.get_node("SettingsRow2/HeightCol/HeightInput")

    right_col.get_node("SettingsBtn").connect("pressed", self , "_on_settings_pressed")

    btn_generate_body = right_col.get_node("GenBodyBtn")
    btn_generate_body.connect("pressed", self , "_on_gen_body")

    btn_generate_nude = right_col.get_node("NudeRow/GenNudeBtn")
    btn_generate_nude.connect("pressed", self , "_on_gen_nude")
    btn_nude_from_body = right_col.get_node("NudeRow/NudeFromBodyBtn")
    btn_nude_from_body.connect("pressed", self , "_on_gen_nude_from_body")

    btn_generate_pregnant = right_col.get_node("PregRow/GenPregBtn")
    btn_generate_pregnant.connect("pressed", self , "_on_gen_pregnant")
    btn_pregnant_from_body = right_col.get_node("PregRow/PregFromBodyBtn")
    btn_pregnant_from_body.connect("pressed", self , "_on_gen_pregnant_from_body")

    btn_generate_nude_pregnant = right_col.get_node("NudePregRow/GenNudePregBtn")
    btn_generate_nude_pregnant.connect("pressed", self , "_on_gen_nude_pregnant")
    btn_nude_pregnant_from_nude = right_col.get_node("NudePregRow/NudePregFromNudeBtn")
    btn_nude_pregnant_from_nude.connect("pressed", self , "_on_gen_nude_pregnant_from_nude")

    btn_portrait_from_body = right_col.get_node("PortraitRow/PortraitFromBodyBtn")
    btn_portrait_from_body.connect("pressed", self , "_on_gen_portrait_from_body")
    btn_portrait_from_nude = right_col.get_node("PortraitRow/PortraitFromNudeBtn")
    btn_portrait_from_nude.connect("pressed", self , "_on_gen_portrait_from_nude")

    return popup

func _setup_preview_popup():
    var popup = load(MOD_PATH + "/scenes/PreviewPopup.tscn").instance()

    popup.get_node("Panel").add_stylebox_override("panel", _PANEL_BG)

    preview_title_label = popup.get_node("Panel/Margin/Outer/TitleLabel")
    preview_images_row = popup.get_node("Panel/Margin/Outer/ImagesRow")
    preview_images_row.set_alignment(BoxContainer.ALIGN_CENTER)

    var try_again_button = popup.get_node("Panel/Margin/Outer/TryAgainBtn")
    try_again_button.connect("pressed", self , "_on_try_again_pressed")

    return popup

func _setup_settings_popup():
    var popup = load(MOD_PATH + "/scenes/SettingsPopup.tscn").instance()

    popup.get_node("Panel").add_stylebox_override("panel", _PANEL_BG)

    # Workflow dropdowns
    var wf_row = popup.get_node("Panel/Margin/Outer/WorkflowRow")
    for type_key in ["txt2img", "img2img", "portrait"]:
        var col_name = type_key.capitalize().replace("2", "2") + "Col"
        # Node names: Txt2imgCol, Img2imgCol, PortraitCol
        match type_key:
            "txt2img":
                col_name = "Txt2imgCol"
            "img2img":
                col_name = "Img2imgCol"
            "portrait":
                col_name = "PortraitCol"
        var dd = wf_row.get_node(col_name + "/" + col_name.replace("Col", "Dropdown"))
        dd.connect("item_selected", self , "_on_workflow_selected", [type_key])
        _workflow_dropdowns[type_key] = dd

    # LoRA tab buttons
    var tab_row = popup.get_node("Panel/Margin/Outer/TabRow")
    var tab_map = {"global": "GlobalTab", "race": "RaceTab", "sex": "SexTab"}
    for tab_name in tab_map.keys():
        var btn = tab_row.get_node(tab_map[tab_name])
        btn.connect("pressed", self , "_on_lora_tab_pressed", [tab_name])
        _lora_tab_buttons[tab_name] = btn

    # Sub-key container
    _lora_subkey_container = popup.get_node("Panel/Margin/Outer/SubkeyContainer")
    _lora_subkey_dropdown = _lora_subkey_container.get_node("SubkeyDropdown")
    _lora_subkey_dropdown.connect("item_selected", self , "_on_lora_subkey_changed")

    # LoRA entries
    _lora_entries_container = popup.get_node("Panel/Margin/Outer/Scroll/LoraEntries")

    # Add LoRA row
    var add_row = popup.get_node("Panel/Margin/Outer/AddRow")
    _lora_search = add_row.get_node("LoraSearch")
    _lora_search.connect("text_changed", self , "_on_lora_search_changed")
    _lora_search.connect("focus_entered", self , "_on_lora_search_focused")
    _lora_search.connect("focus_exited", self , "_on_lora_search_unfocused")

    _lora_weight_input = add_row.get_node("WeightInput")
    add_row.get_node("AddBtn").connect("pressed", self , "_on_add_lora_pressed")

    # FilterableDropdown for LoRA search
    _lora_popup = _FilterableDropdownScene.instance()
    _lora_popup.set_script(_FilterableDropdownScript)
    _lora_popup.setup(MOD_PATH)
    _lora_popup.connect("item_selected", self , "_on_lora_selected")
    popup.add_child(_lora_popup)

    return popup

func _build_prompting_button():
    var button = TextureButton.new()
    button.set_theme(MAIN_THEME)
    button.set_tooltip("Generate AI prompts")
    button.set_normal_texture(input_handler.loadimage(MOD_PATH + "/resources/images/button_prompting.png"))
    button.set_pressed_texture(input_handler.loadimage(MOD_PATH + "/resources/images/button_prompting_pressed.png"))
    button.set_hover_texture(input_handler.loadimage(MOD_PATH + "/resources/images/button_prompting_hover.png"))
    button.set_margin(0, 1240) # Left
    button.set_margin(1, 976) # Top
    return button

# --- Close Buttons ---

func _add_close_buttons():
    _add_close_button_to_popup(prompt_popup)
    preview_close_btn = _add_close_button_to_popup(preview_popup)
    _add_close_button_to_popup(settings_popup)

func _add_close_button_to_popup(popup):
    var btn = load(ResourceScripts.scenedict.close).instance()
    popup.add_child(btn)
    btn.connect("pressed", popup, "hide")
    btn.set_anchor(MARGIN_LEFT, 1.0)
    btn.set_anchor(MARGIN_TOP, 0.0)
    btn.set_anchor(MARGIN_RIGHT, 1.0)
    btn.set_anchor(MARGIN_BOTTOM, 0.0)
    btn.set_margin(MARGIN_LEFT, -32)
    btn.set_margin(MARGIN_RIGHT, 0)
    btn.set_margin(MARGIN_TOP, 0)
    btn.set_margin(MARGIN_BOTTOM, 32)
    return btn

# --- ComfyUI Client Setup ---

func _setup_comfyui_client():
    comfyui_client = modding_core.modules.PortraitGenerator_comfyui
    lora_config = modding_core.modules.PortraitGenerator_lora_config
    util = modding_core.modules.PortraitGenerator_util
    if lora_config != null:
        lora_config.load_settings()
    if comfyui_client == null:
        return
    var parent = comfyui_client.get_parent()
    if parent != null:
        parent.remove_child(comfyui_client)
    add_child(comfyui_client)
    comfyui_client.connect("connected", self , "_on_comfyui_connected")
    comfyui_client.connect("disconnected", self , "_on_comfyui_disconnected")
    comfyui_client.connect("connection_error", self , "_on_comfyui_connection_error")
    comfyui_client.connect("models_loaded", self , "_on_models_loaded")
    comfyui_client.connect("images_ready", self , "_on_images_ready")
    comfyui_client.connect("upload_complete", self , "_on_upload_complete")
    comfyui_client.connect("upload_error", self , "_on_upload_error")
    comfyui_client.connect("error", self , "_on_comfyui_error")
    comfyui_client.connect("loras_loaded", self , "_on_loras_loaded")
    comfyui_client.connect("progress_update", self , "_on_comfyui_progress_update")

# --- Prompt Panel ---

func toggle_prompt_panel():
    if not prompt_popup.visible:
        _load_ui_settings()
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

func _generate_prompts(force = false):
    _save_ui_settings()
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
    face_positive_prompt = prompts.face_positive
    face_negative_prompt = prompts.face_negative
    _updating_prompts = false

func _on_from_equipment_pressed():
    if active_person == null:
        return
    clothing_input.set_text(modding_core.modules.PortraitGenerator_prompting.build_equipment_prompt(active_person))

func _on_prompt_popup_hide():
    for input in _expanding_inputs:
        if is_instance_valid(input):
            input.return_to_placeholder()

func _sync_all_exp_inputs():
    for input in _expanding_inputs:
        if is_instance_valid(input):
            input.sync_position()

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

    btn_generate_body.set_disabled(not can_generate)
    btn_generate_nude.set_disabled(not can_generate)
    btn_generate_pregnant.set_disabled(not can_generate)
    btn_generate_nude_pregnant.set_disabled(not can_generate)

    btn_nude_from_body.set_disabled(not (can_generate and has_body))
    btn_pregnant_from_body.set_disabled(not (can_generate and has_body))

    btn_nude_pregnant_from_nude.set_disabled(not (can_generate and has_nude))

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

func _save_ui_settings():
    var data = util.read_settings() if util != null else {}
    data["url"] = comfyui_url_input.text
    data["model"] = _get_selected_model()
    data["steps"] = steps_input.text
    data["cfg"] = cfg_input.text
    data["denoise"] = denoise_input.text
    data["width"] = width_input.text
    data["height"] = height_input.text
    data["positive_prompt"] = positive_input.text
    data["negative_prompt"] = negative_input.text
    if util != null:
        util.save_settings(data)

func _load_ui_settings():
    if util == null:
        return
    var data = util.read_settings()
    if data.has("url"):
        comfyui_url_input.set_text(data["url"])
    if data.has("steps"):
        steps_input.set_text(data["steps"])
    if data.has("cfg"):
        cfg_input.set_text(data["cfg"])
    if data.has("denoise"):
        denoise_input.set_text(data["denoise"])
    if data.has("width"):
        width_input.set_text(data["width"])
    if data.has("height"):
        height_input.set_text(data["height"])
    if data.has("positive_prompt"):
        positive_input.set_text(data["positive_prompt"])
    if data.has("negative_prompt"):
        negative_input.set_text(data["negative_prompt"])

func _get_selected_model():
    var idx = model_dropdown.get_selected()
    if idx < 0:
        return ""
    return model_dropdown.get_item_metadata(idx)

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

func _get_available_save_categories():
    return [
        ["Portrait", comfyui_client.SaveCategory.PORTRAIT],
        ["Clothed Body", comfyui_client.SaveCategory.CLOTHED_BODY],
        ["Nude Body", comfyui_client.SaveCategory.NUDE_BODY],
        ["Pregnant Clothed Body", comfyui_client.SaveCategory.PREGNANT_CLOTHED],
        ["Pregnant Nude Body", comfyui_client.SaveCategory.PREGNANT_NUDE],
    ]

func _populate_save_type_dropdown(dropdown, default_category):
    dropdown.clear()
    var categories = _get_available_save_categories()
    var selected_index = 0
    for i in range(categories.size()):
        var item = categories[i]
        dropdown.add_item(item[0])
        dropdown.set_item_metadata(i, item[1])
        if item[1] == default_category:
            selected_index = i
    dropdown.select(selected_index)

func _resolve_selected_save_category(image_index):
    var default_category = _get_save_category()
    if _generated_textures.size() <= 1:
        return default_category
    if not _preview_save_type_selectors.has(image_index):
        return default_category
    var selector = _preview_save_type_selectors[image_index]
    if selector == null or not is_instance_valid(selector):
        return default_category
    var selected_idx = selector.get_selected()
    if selected_idx < 0:
        return default_category
    return selector.get_item_metadata(selected_idx)

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
    comfyui_client.fetch_loras()

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

func _truncate(text, max_length):
    if text.length() <= max_length:
        return text
    return text.substr(0, max_length - 3) + "..."

func _on_models_loaded(model_list):
    model_dropdown.clear()
    if model_list.size() == 0:
        model_dropdown.add_item("(no models found)")
        model_dropdown.set_disabled(true)
        return
    for model_name in model_list:
        model_dropdown.add_item(model_name)
        model_dropdown.set_item_metadata(model_dropdown.get_item_count() - 1, model_name)
    model_dropdown.set_disabled(false)
    var prev_model = (util.read_settings() if util != null else {}).get("model", "")
    if prev_model != "":
        for i in range(model_dropdown.get_item_count()):
            if model_dropdown.get_item_metadata(i) == prev_model:
                model_dropdown.select(i)
                break
    _update_button_states()

func _on_model_item_selected(index):
    var text = _truncate(model_dropdown.get_item_metadata(index), 35)
    model_dropdown.set_text(text)

func _on_images_ready(textures):
    _generated_textures = textures
    status_label.set_text("Status: %d image(s) ready" % textures.size())
    _update_button_states()
    var popup_size = _rebuild_preview_images(textures)
    preview_popup.popup_centered(popup_size)

func _rebuild_preview_images(textures):
    var view_size = get_viewport_rect().size
    var SCREEN_MARGIN = 20
    var MAX_POPUP_W = min(1100, int(view_size.x) - SCREEN_MARGIN)
    var GAP = 8
    var MARGIN = 20
    var CTRL_H_SINGLE = 160
    var CTRL_H_MULTI = 200

    var gen_count = min(textures.size(), 5)
    var is_multi_output = textures.size() > 1
    var has_source = _source_texture != null
    var total_count = gen_count + (1 if has_source else 0)
    var controls_height = CTRL_H_MULTI if is_multi_output else CTRL_H_SINGLE

    if has_source:
        preview_title_label.set_text("Original → Generated")
    else:
        preview_title_label.set_text("Generated Image")

    var max_image_w = int((MAX_POPUP_W - MARGIN - (total_count - 1) * GAP) / total_count)
    var max_image_h = int(view_size.y) - controls_height - SCREEN_MARGIN
    var IMAGE_W = min(max_image_w, int(600.0 * 768.0 / 1088.0))
    var IMAGE_H = int(IMAGE_W * 1088.0 / 768.0)

    if IMAGE_H > max_image_h:
        IMAGE_H = max(120, max_image_h)
        IMAGE_W = int(IMAGE_H * 768.0 / 1088.0)

    var popup_w = total_count * IMAGE_W + (total_count - 1) * GAP + MARGIN
    var popup_h = IMAGE_H + controls_height

    popup_h = min(popup_h, int(view_size.y) - SCREEN_MARGIN)

    preview_popup.set_size(Vector2(popup_w, popup_h))

    var old_children = preview_images_row.get_children()
    for child in old_children:
        preview_images_row.remove_child(child)
        child.free()
    _preview_save_type_selectors.clear()

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

    for i in range(gen_count):
        var col = VBoxContainer.new()
        var tex_rect = TextureRect.new()
        tex_rect.set_custom_minimum_size(Vector2(IMAGE_W, IMAGE_H))
        tex_rect.set_stretch_mode(TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
        tex_rect.set_expand(true)
        tex_rect.set_texture(textures[i])
        col.add_child(tex_rect)
        if is_multi_output:
            var save_type_dropdown = OptionButton.new()
            save_type_dropdown.set_custom_minimum_size(Vector2(IMAGE_W, 0))
            _populate_save_type_dropdown(save_type_dropdown, _get_save_category())
            _preview_save_type_selectors[i] = save_type_dropdown
            col.add_child(save_type_dropdown)
        var save_btn = Button.new()
        save_btn.set_text("Save")
        save_btn.set_custom_minimum_size(Vector2(IMAGE_W, 0))
        save_btn.connect("pressed", self , "_on_save_image_pressed", [i])
        col.add_child(save_btn)
        preview_images_row.add_child(col)

    return Vector2(popup_w, popup_h)

func _on_comfyui_progress_update(progress, max_progress):
    status_label.set_text("Status: Generating... (step %d/%d)" % [progress, max_progress])

func _on_comfyui_error(message):
    status_label.set_text("ComfyUI error: Press F2 or see log for details")
    print("ComfyUI Error: %s" % str(message))
    _update_button_states()
    comfyui_connect_button.set_disabled(false)

# --- Generation Dispatch: txt2img ---

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
    _save_ui_settings()
    _current_generation_type = gen_type
    _generation_person = active_person
    _source_texture = null
    _generate_prompts()
    var model = _get_selected_model()
    if model == "":
        return
    var pos = config[0].text + config[2]
    var neg = config[1].text
    status_label.set_text("Status: Generating %s..." % config[3])
    _disable_all_gen_buttons()
    var wf_name = lora_config.get_workflow_name("txt2img") if lora_config != null else "default"
    var loras = lora_config.resolve_loras(active_person, gen_type) if lora_config != null else []
    comfyui_client.generate_image(active_person.get_full_name(), model, pos, neg, -1, _get_gen_width(), _get_gen_height(), _get_gen_steps(), _get_gen_cfg(), wf_name, loras)

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
    _save_ui_settings()
    _current_generation_type = gen_type
    _generation_person = active_person
    _generate_prompts()
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
            pos = face_positive_prompt
            neg = face_negative_prompt
        GenerationType.PORTRAIT_FROM_NUDE:
            pos = face_positive_prompt
            neg = face_negative_prompt
    var person = _generation_person if _generation_person != null else active_person
    var loras = lora_config.resolve_loras(person, _current_generation_type) if lora_config != null and person != null else []
    if _current_generation_type == GenerationType.PORTRAIT_FROM_BODY or \
            _current_generation_type == GenerationType.PORTRAIT_FROM_NUDE:
        var wf_name = lora_config.get_workflow_name("portrait") if lora_config != null else "default"
        status_label.set_text("Status: Generating portrait (face crop)...")
        comfyui_client.generate_face_crop(person.get_full_name(), model, pos, neg, uploaded_filename, _get_gen_denoise(), -1, _get_gen_steps(), _get_gen_cfg(), wf_name, loras)
    else:
        var wf_name = lora_config.get_workflow_name("img2img") if lora_config != null else "default"
        status_label.set_text("Status: Generating (img2img)...")
        comfyui_client.generate_img2img(person.get_full_name(), model, pos, neg, uploaded_filename, _get_gen_denoise(), -1, _get_gen_steps(), _get_gen_cfg(), wf_name, loras)

func _on_upload_error(message):
    status_label.set_text("Upload error: " + str(message))
    _update_button_states()

# --- Save Handler ---

func _on_save_image_pressed(image_index):
    var person = _generation_person if _generation_person != null else active_person
    if image_index >= _generated_textures.size() or person == null or comfyui_client == null:
        return
    var texture = _generated_textures[image_index]
    var category = _resolve_selected_save_category(image_index)
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

func _load_texture_from_path(path):
    var img = Image.new()
    if img.load(path) != OK:
        return null
    var tex = ImageTexture.new()
    tex.create_from_image(img)
    return tex

# --- Settings Popup ---

func _on_settings_pressed():
    _refresh_workflow_dropdowns()
    settings_popup.popup_centered()
    _on_lora_tab_pressed("global")

func _refresh_workflow_dropdowns():
    if comfyui_client == null:
        return
    for type_key in _workflow_dropdowns.keys():
        var dd = _workflow_dropdowns[type_key]
        dd.clear()
        var names = comfyui_client.scan_workflows(type_key)
        var selected_name = lora_config.get_workflow_name(type_key) if lora_config != null else "default"
        var select_idx = 0
        for i in range(names.size()):
            dd.add_item(names[i])
            dd.set_item_metadata(i, names[i])
            if names[i] == selected_name:
                select_idx = i
        if names.size() > 0:
            dd.select(select_idx)

func _on_workflow_selected(index, type_key):
    if lora_config == null:
        return
    var dd = _workflow_dropdowns[type_key]
    var name = dd.get_item_metadata(index)
    dd.set_text(_truncate(name, 18))
    lora_config.set_workflow(type_key, name)

# --- LoRA Management ---

func _on_loras_loaded(lora_list):
    _available_loras = lora_list
    _available_loras.sort_custom(self , "_sort_by_lowercase")
    if lora_list.size() == 0:
        _lora_search.set_placeholder("(no LoRAs found)")
        _lora_search.set_editable(false)
        return
    _lora_search.set_editable(true)
    _lora_search.set_placeholder("Search " + str(lora_list.size()) + " LoRAs...")
    _lora_search.set_text("")
    _lora_popup.set_items(_available_loras)

func _sort_by_lowercase(a, b):
    return a.to_lower() < b.to_lower()

func _on_lora_search_changed(new_text):
    _lora_popup.filter(new_text, _lora_search)

func _on_lora_search_focused():
    _lora_search.select_all()
    _lora_popup.filter(_lora_search.text, _lora_search)

func _on_lora_search_unfocused():
    if not _lora_popup.visible:
        if _lora_popup.selected_item != "":
            _lora_search.set_text(_truncate(_lora_popup.selected_item, 40))
        else:
            _lora_search.set_text("")

func _on_lora_selected(item_name):
    _lora_search.set_text(_truncate(item_name, 40))

# --- LoRA Tab Management ---

func _on_lora_tab_pressed(tab_name):
    _current_lora_tab = tab_name
    for key in _lora_tab_buttons.keys():
        _lora_tab_buttons[key].set_pressed(key == tab_name)
    _update_lora_subkey_dropdown()
    _rebuild_lora_entries()

func _update_lora_subkey_dropdown():
    _lora_subkey_dropdown.clear()
    if _current_lora_tab == "global":
        _lora_subkey_container.visible = false
        return
    _lora_subkey_container.visible = true
    if _current_lora_tab == "race":
        var race_keys = races.racelist.keys()
        race_keys.sort()
        for r in race_keys:
            _lora_subkey_dropdown.add_item(r)
            _lora_subkey_dropdown.set_item_metadata(_lora_subkey_dropdown.get_item_count() - 1, r)
    elif _current_lora_tab == "sex":
        var items = ["male", "female", "futa"]
        for item in items:
            _lora_subkey_dropdown.add_item(item.capitalize())
            _lora_subkey_dropdown.set_item_metadata(_lora_subkey_dropdown.get_item_count() - 1, item)
            _lora_subkey_dropdown.add_item(item.capitalize() + " (nude)")
            _lora_subkey_dropdown.set_item_metadata(_lora_subkey_dropdown.get_item_count() - 1, item + "_nude")

func _on_lora_subkey_changed(_index):
    _rebuild_lora_entries()

func _get_current_subkey():
    if _current_lora_tab == "global":
        return ""
    var idx = _lora_subkey_dropdown.get_selected()
    if idx < 0:
        return ""
    return _lora_subkey_dropdown.get_item_metadata(idx)

func _rebuild_lora_entries():
    for child in _lora_entries_container.get_children():
        child.queue_free()
    if lora_config == null:
        return
    var subkey = _get_current_subkey()
    var entries = lora_config.get_loras(_current_lora_tab, subkey)
    for i in range(entries.size()):
        var entry = entries[i]
        var row = HBoxContainer.new()
        row.set_h_size_flags(Control.SIZE_EXPAND_FILL)
        var name_label = Label.new()
        name_label.set_text(entry["lora"])
        name_label.set_h_size_flags(Control.SIZE_EXPAND_FILL)
        name_label.set_clip_text(true)
        row.add_child(name_label)
        var weight_label = Label.new()
        weight_label.set_text(str(entry["strength"]))
        weight_label.set_custom_minimum_size(Vector2(50, 0))
        row.add_child(weight_label)
        var remove_btn = Button.new()
        remove_btn.set_text("X")
        remove_btn.set_custom_minimum_size(Vector2(32, 32))
        remove_btn.connect("pressed", self , "_on_remove_lora_pressed", [_current_lora_tab, subkey, i])
        row.add_child(remove_btn)
        _lora_entries_container.add_child(row)

func _on_add_lora_pressed():
    if lora_config == null or _lora_popup.selected_item == "":
        return
    if _available_loras.size() == 0:
        return
    var lora_name = _lora_popup.selected_item
    var weight = 1.0
    if _lora_weight_input.text.is_valid_float():
        weight = float(_lora_weight_input.text)
    var subkey = _get_current_subkey()
    if _current_lora_tab != "global" and subkey == "":
        return
    lora_config.add_lora(_current_lora_tab, subkey, lora_name, weight)
    _rebuild_lora_entries()

func _on_remove_lora_pressed(category, subkey, index):
    if lora_config == null:
        return
    lora_config.remove_lora(category, subkey, index)
    _rebuild_lora_entries()

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

func _copy_prompt_type_pressed(prompt_type):
    match prompt_type:
        PromptOutput.CLOTHED:
            OS.clipboard = clothed_prompt_output.text
        PromptOutput.CLOTHED_NEGATIVE:
            OS.clipboard = clothed_negative_prompt_output.text
        PromptOutput.NUDE:
            OS.clipboard = nude_prompt_output.text
        PromptOutput.NUDE_NEGATIVE:
            OS.clipboard = nude_negative_prompt_output.text
