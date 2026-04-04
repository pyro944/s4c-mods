extends Node

# LoRA configuration and workflow selection data module.
# Persists to the shared settings file alongside UI settings.

var MOD_PATH = get_script().get_path().get_base_dir() + "/.."

# Maps category name -> character stat key (null = always applied).
# To add a new category, add an entry here and a matching default in _default_lora_config().
const CATEGORY_STATS = {
	"global": null,
	"race": "race",
	"sex": "sex",
}

var util

# { "global": [ {lora, strength}, ... ], "race": { "Human": [...], ... }, "sex": { "male": [...], ... } }
var lora_config = {}

# { "txt2img": "default", "img2img": "default", "portrait": "default" }
var workflow_selections = {"txt2img": "default", "img2img": "default", "portrait": "default"}

func _init():
	lora_config = _default_lora_config()

func _ready():
	util = modding_core.modules.PortraitGenerator_util

# The mod framework calls update on every registered module.
func update():
	pass

# --- Defaults ---

func _default_lora_config():
	return {"global": [], "race": {}, "sex": {}}

# --- Accessors ---

func get_workflow_name(type_key):
	var workflow_name = workflow_selections.get(type_key, "default")
	# If the file no longer exists, reset to default
	if not _workflow_exists(type_key, workflow_name):
		workflow_selections[type_key] = "default"
		save_settings()
		return "default"
	return workflow_name

func _workflow_exists(type_key, name):
	var path = MOD_PATH + "/workflows/%s/%s.json" % [type_key, name]
	var file_access = File.new()
	return file_access.file_exists(path)

func set_workflow(type_key, name):
	workflow_selections[type_key] = name
	save_settings()

# --- LoRA Mutators ---

func add_lora(category, key, lora_name, strength):
	var entry = {"lora": lora_name, "strength": strength}
	if CATEGORY_STATS.get(category) == null:
		# Flat list category (e.g. global)
		lora_config[category].append(entry)
	else:
		# Keyed category (e.g. race -> "Human")
		if not lora_config[category].has(key):
			lora_config[category][key] = []
		lora_config[category][key].append(entry)
	save_settings()

func remove_lora(category, key, index):
	if CATEGORY_STATS.get(category) == null:
		if index >= 0 and index < lora_config[category].size():
			lora_config[category].remove(index)
	else:
		if lora_config[category].has(key):
			var arr = lora_config[category][key]
			if index >= 0 and index < arr.size():
				arr.remove(index)
			if arr.size() == 0:
				lora_config[category].erase(key)
	save_settings()

func get_loras(category, key = ""):
	if CATEGORY_STATS.get(category) == null:
		return lora_config.get(category, [])
	else:
		return lora_config.get(category, {}).get(key, [])

# --- Resolution ---

func resolve_loras(person, gen_type):
	var result = []
	for category in CATEGORY_STATS.keys():
		var stat_key = CATEGORY_STATS[category]
		if stat_key == null:
			# Flat category — always include all entries
			for entry in lora_config.get(category, []):
				result.append(entry)
		else:
			# Keyed category — include entries matching the character stat
			var stat_value = person.get_stat(stat_key)
			# Use nude if the portrait type is nude/nude preg
			if category == 'sex':
				if gen_type in [util.GenerationType.NUDE, util.GenerationType.NUDE_FROM_BODY, util.GenerationType.NUDE_PREGNANT, util.GenerationType.NUDE_PREGNANT_FROM_NUDE]:
					stat_value += '_nude'
			for entry in lora_config.get(category, {}).get(stat_value, []):
				result.append(entry)
	return result

# --- Persistence ---

func save_settings():
	# Read existing file to preserve UI settings written by extended_CharInfoMainModule
	var existing = util.read_settings()
	existing["lora_config"] = lora_config
	existing["workflow_selections"] = workflow_selections
	util.save_settings(existing)

func load_settings():
	var data = util.read_settings()
	if data.has("lora_config"):
		var loaded = data["lora_config"]
		# Merge loaded config over defaults so new categories are present
		var defaults = _default_lora_config()
		for key in defaults.keys():
			if loaded.has(key):
				lora_config[key] = loaded[key]
			else:
				lora_config[key] = defaults[key]
	if data.has("workflow_selections"):
		var loaded_wf = data["workflow_selections"]
		for key in workflow_selections.keys():
			if loaded_wf.has(key):
				workflow_selections[key] = loaded_wf[key]
