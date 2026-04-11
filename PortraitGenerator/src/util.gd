extends Node

# Shared code to break circular dependencies

enum _GenerationType {
    BODY,
    BODY_FROM_NUDE,
    NUDE,
    NUDE_FROM_BODY,
    PREGNANT,
    PREGNANT_FROM_BODY,
    NUDE_PREGNANT,
    NUDE_PREGNANT_FROM_NUDE,
    PORTRAIT_FROM_BODY,
    PORTRAIT_FROM_NUDE
}

var GenerationType = _GenerationType

# --- Shared Settings Persistence ---

const SETTINGS_PATH = "user://portrait_generator_settings.json"

# Read and parse the settings file. Returns an empty dict if file doesn't exist or is invalid.
func read_settings():
    var file = File.new()
    if not file.file_exists(SETTINGS_PATH):
        return {}
    if file.open(SETTINGS_PATH, File.READ) != OK:
        return {}
    var json = JSON.parse(file.get_as_text())
    file.close()
    if json.error != OK:
        return {}
    return json.result if json.result is Dictionary else {}

# Write settings data to the file.
func save_settings(data):
    var file = File.new()
    if file.open(SETTINGS_PATH, File.WRITE) == OK:
        file.store_string(JSON.print(data))
        file.close()
