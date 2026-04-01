# PortraitGenerator Mod — Architecture Guide

This document walks through how the PortraitGenerator mod works, aimed at an engineer
who is new to the project. It covers how the mod hooks into the base game, how
character data is turned into Stable Diffusion prompts, and how those prompts are sent
to a ComfyUI server for image generation.

**Game engine:** [Godot 3.5](https://docs.godotengine.org/en/3.5/)
**Image generation backend:** [ComfyUI](https://github.com/comfyanonymous/ComfyUI)

---

## Table of Contents

- [File Map](#file-map)
- [How the Mod Loads](#how-the-mod-loads)
- [Module System](#module-system)
- [The Main UI — extended_CharInfoMainModule.gd](#the-main-ui--extended_charinfomodule)
- [Prompt Generation](#prompt-generation)
  - [Character Stat → Tag Pipeline](#character-stat--tag-pipeline)
  - [Equipment Prompts](#equipment-prompts)
- [Race Data — races.gd](#race-data--racesgd)
- [Item Data — items.gd](#item-data--itemsgd)
- [ComfyUI Client — comfyui_client.gd](#comfyui-client--comfyui_clientgd)
  - [Connection Lifecycle](#connection-lifecycle)
  - [Workflow Templates](#workflow-templates)
  - [Generation Flow](#generation-flow)
  - [Image Saving](#image-saving)
- [LoRA Configuration — lora_config.gd](#lora-configuration--lora_configgd)
- [Settings Persistence](#settings-persistence)
- [Workarounds and Design Decisions](#workarounds-and-design-decisions)

---

## File Map

```
PortraitGenerator/
├── mod_config.ini                           # Mod registration (entry point for the mod framework)
├── module.gd                                # Bootstrapper — hooks into the game's scene tree
├── version.txt
├── docs/
├── resources/images/                        # Button textures for the UI
├── src/
│   ├── extended_CharInfoMainModule.gd       # Main UI (1500+ lines) — extends the game's character info panel
│   ├── comfyui_client.gd                    # WebSocket + HTTP client for ComfyUI
│   ├── prompting.gd                         # Translates character stats → Stable Diffusion tags
│   ├── races.gd                             # Per-race prompt descriptors (~40 races)
│   ├── items.gd                             # Item/equipment → text descriptions
│   ├── lora_config.gd                       # LoRA selection and workflow config, with persistence
│   └── util.gd                              # Shared GenerationType enum
└── workflows/
    ├── txt2img/default.json                 # ComfyUI API-format workflow for text-to-image
    ├── img2img/default.json                 # ComfyUI API-format workflow for image-to-image
    └── portrait/default.json                # ComfyUI API-format workflow for face crop
```

---

## How the Mod Loads

The game's modding framework reads `mod_config.ini` at startup. The key sections are:

```ini
[Modules]
PortraitGenerator="module.gd"
PortraitGenerator_prompting="src/prompting.gd"
PortraitGenerator_comfyui="src/comfyui_client.gd"
# ... (all 7 modules listed)

[NodeScripts]
PortraitGenerator=true

[ExtendedMethods]
NODE_SLAVEMODULE=["_ready"]
```

1. **`[Modules]`** — Each `.gd` file is loaded as a child node of `modding_core` and
   becomes accessible at `modding_core.modules.<name>` (e.g.,
   `modding_core.modules.PortraitGenerator_prompting`).

2. **`[NodeScripts]`** — Marks `PortraitGenerator` (i.e., `module.gd`) as a node script,
   which causes the framework to call its `extend_nodes()` function.

3. **`[ExtendedMethods]`** — Tells the framework that this mod extends the `_ready`
   method of the game node `NODE_SLAVEMODULE`. This is the character info
   management UI panel.

### module.gd (the bootstrapper)

```gdscript
func extend_nodes():
    var slave_node = modding_core.get_spec_node(input_handler.NODE_SLAVEMODULE)
    modding_core.extend_node(slave_node, path + '/src/extended_CharInfoMainModule.gd')
```

This replaces the script on the game's `CharInfoMainModule` node with our extended
version. `extended_CharInfoMainModule.gd` begins with:

```gdscript
extends "res://gui_modules/CharacterInfo/CharInfoMainModule.gd"
```

So it inherits all of the base game's character info panel behavior — its variables
(`active_person`, the current character), its submodule references, and its lifecycle
methods — then layers our AI generation UI on top.

**Relevant game file:**
`gui_modules/CharacterInfo/CharInfoMainModule.gd`
— the base panel we extend. It provides `active_person` (the character being viewed),
`update()`, and references to child modules like `BodyModule` and `SummaryModule`.

---

## Module System

All modules are registered in `mod_config.ini` and live as children of `modding_core`.
They reference each other through `modding_core.modules.<name>`:

| Module name                     | File                    | Purpose                            |
| ------------------------------- | ----------------------- | ---------------------------------- |
| `PortraitGenerator`             | `module.gd`             | Entry point, hooks into scene tree |
| `PortraitGenerator_prompting`   | `src/prompting.gd`      | Character-to-prompt translation    |
| `PortraitGenerator_comfyui`     | `src/comfyui_client.gd` | ComfyUI HTTP/WebSocket client      |
| `PortraitGenerator_lora_config` | `src/lora_config.gd`    | LoRA and workflow settings         |
| `PortraitGenerator_races`       | `src/races.gd`          | Race body/skin/negative tag data   |
| `PortraitGenerator_items`       | `src/items.gd`          | Equipment descriptions             |
| `PortraitGenerator_util`        | `src/util.gd`           | Shared enum, settings file IO      |

### Why util.gd exists

`util.gd` serves two purposes:

1. **Shared `GenerationType` enum** — Both `extended_CharInfoMainModule.gd` and
   `lora_config.gd` need to reference this enum, but they can't import each other
   without creating a circular dependency. Putting the enum in a third module breaks the
   cycle.

2. **Settings file persistence** — The `read_settings()` and `save_settings(data)`
   functions provide a single source of truth for reading and writing the shared
   `user://portrait_generator_settings.json` file. This centralizes the file IO logic
   and ensures both modules use the same path and error handling.

---

<a id="the-main-ui--extended_charinfomodule"></a>

## The Main UI — extended_CharInfoMainModule.gd

This is the largest file. It builds the entire mod UI programmatically
in GDScript; there are no `.tscn` scene files for the mod's panels.

### Initialization

In `_init()`:

1. Loads the `GenerationType` enum from `util.gd`.
2. Creates a `TextureButton` (the "AI" button) positioned at the bottom of the
   character portrait area.
3. Builds three popup windows: the prompt panel, the preview popup, and the settings
   popup.
4. Defers `_setup_comfyui_client()` and `_add_close_buttons()` to the next frame.

### Prompt Panel (main panel)

A popup with two columns:

**Left column — Prompt editing:**

- Positive prompt input (user style tags)
- Clothing description input (with a "From equipment" auto-fill button)
- Negative prompt input
- "Generate Prompts" button
- Four read-only prompt outputs (Clothed+, Clothed-, Nude+, Nude-), each with a
  clipboard copy button

The outputs are auto-generated from character stats, but the user can hand-edit them.
The `_output_user_modified` dictionary tracks which outputs have been touched — if the
user edits one, auto-generation won't overwrite it until the user clicks "Generate
Prompts" again (which forces a refresh).

**Right column — ComfyUI controls:**

- Server URL input + Connect/Disconnect button
- Status label (shows connection state, progress steps, errors)
- Checkpoint model dropdown (populated after connecting)
- Generation settings: Steps, CFG, Denoise, Width, Height
- "Workflow settings..." button (opens the settings popup)
- Nine generation buttons organized by type

### Generation Types

Defined in `util.gd`:

| Enum value                | Method    | Description                                           |
| ------------------------- | --------- | ----------------------------------------------------- |
| `BODY`                    | txt2img   | Clothed full-body image                               |
| `NUDE`                    | txt2img   | Nude full-body image                                  |
| `PREGNANT`                | txt2img   | Clothed pregnant (appends ", pregnant" to prompt)     |
| `NUDE_PREGNANT`           | txt2img   | Nude pregnant                                         |
| `NUDE_FROM_BODY`          | img2img   | Generates nude using the clothed body image as source |
| `PREGNANT_FROM_BODY`      | img2img   | Generates pregnant using the clothed body as source   |
| `NUDE_PREGNANT_FROM_NUDE` | img2img   | Generates nude pregnant from the nude image           |
| `PORTRAIT_FROM_BODY`      | face crop | Crops a face portrait from the body image             |
| `PORTRAIT_FROM_NUDE`      | face crop | Crops a face portrait from the nude image             |

### Preview Popup

After generation completes, a dynamically-sized popup shows:

- The source image (for img2img operations) on the left
- Generated image(s) with individual Save buttons
- A "Try Again" button to re-run the same generation

### Settings Popup

A popup containing:

- **Workflow selection** — dropdowns for txt2img, img2img, and portrait workflows.
  Custom workflows can be added by placing JSON files in the `workflows/` subdirectories.
- **LoRA configuration** — tabbed interface with Global, Race, and Sex tabs. Each tab
  lets you search and add LoRAs with configurable weights. Race/Sex tabs have a
  sub-key dropdown to target specific races or sexes.

---

## Prompt Generation

`src/prompting.gd` is the core module that translates in-game character stats into
Stable Diffusion-compatible tag strings.

### Character Stat → Tag Pipeline

`build_prompts(character, positive_user_tags, clothing_user_tags, negative_user_tags)`
reads stats from the character via `character.get_stat()` and produces four prompt
strings:

```
{
    clothed_positive:  user_positive + base_tags + "fully clothed" + clothing_tags
    clothed_negative:  user_negative + race_negatives + sex_negatives + nudity_negatives
    nude_positive:     user_positive + base_tags + nudity_tags + genitals_tags
    nude_negative:     user_negative + race_negatives + sex_negatives + [futa_ball_negatives]
}
```

User-provided tags are always prepended so they receive the highest weight in the
prompt.

**Base tags** are assembled from these functions (in order):

| Function           | Stats used                                                    | Example output                          |
| ------------------ | ------------------------------------------------------------- | --------------------------------------- |
| `subject_tags()`   | sex, race                                                     | `1girl, (spider girl:1.5)`              |
| `age_tags()`       | age, sex                                                      | `mature woman`                          |
| `skin_tags()`      | body_color_skin, skin_coverage                                | `fair skin`, `brown fur`                |
| `eye_tags()`       | eye_color, eye_shape                                          | `blue eyes, slit pupils`                |
| `hair_tags()`      | hair_color, hair_length, hair_style, beard, hair_facial_color | `blonde hair, long hair, straight hair` |
| `body_type_tags()` | height, ass_size, sex                                         | `very tall, wide hips`                  |
| `breasts_tags()`   | tits_size, sex                                                | `large breasts`                         |
| `wings_tags()`     | wings, body_color_wings                                       | `white angel wings`                     |
| `tail_tags()`      | tail, body_color_tail                                         | `brown fox tail`                        |
| `horns_tags()`     | horns, body_color_horns                                       | `black demon horns`                     |
| `ears_tags()`      | ears                                                          | `elf ears`                              |

Some notable translation details:

- `hair_color: "yellow"` → `"blonde"`
- `hair_length: "ear"` → `"very short hair"`, `"hips"` → `"extremely long hair"`
- Skin colors like `human1`–`human5` map to `fair`, `light`, `light brown`, `brown`, `dark brown`
- `skin_coverage` can override skin color when the character has fur/scales (e.g., `fur_brown` → `brown fur`)
- The `to_alpha()` helper strips digits and underscores from stat values using a regex

**Character stats** come from the game's character class:
`src/character/CharacterClass.gd`
(accessed via `character.get_stat(stat_name)`).

### Equipment Prompts

`build_equipment_prompt(character)` iterates gear slots in this order:

```
chest → hands → head → neck → legs → rhand → lhand → tool → underwear → ass → crotch
```

If the character has leg armor equipped, the `ass`, `crotch`, and `underwear` slots are
skipped (they'd be hidden under the leg armor). Items in the same gear slot as an
already-seen item ID are deduplicated.

Each slot gets a natural-language phrase:

- `head` → `"wearing iron helm on her head"`
- `rhand` → `"holding a steel sword in his right hand"`
- `chest` / `legs` → `"wearing iron chainmail"`

Item objects are resolved from `ResourceScripts.game_res.items[item_id]`, which returns
an `ItemClass` instance.

**Relevant game files:**

- `src/character/ch_equip.gd` — equipment data; the
  `gear` dictionary has keys for each slot (`chest`, `rhand`, `legs`, etc.)
- `src/classes/ItemClass.gd` — provides `name`, `code`, `itembase`, `parts`

---

## Race Data — races.gd

A dictionary (`_ATTRIBUTES`) mapping race names to prompt data. Each entry has:

```gdscript
'Arachna': {
    'body': ['arachne', 'human spider hybrid', 'human torso attached to spider body', 'fused at the waist'],
    'skin': 'skin',
    'negative': ['spider-man', 'spiderman', 'human legs', 'thighs'],
    'personal_descriptor': '(spider $PERSON:1.5)',
}
```

- **`body`** — Tags describing the race's body structure, appended to the positive prompt.
- **`skin`** — The skin type string: `'skin'`, `'fur'`, `'scales'`, `'feathers'`, or
  combinations like `'skin and scales'`. Used by `prompting.gd` in `skin_tags()`.
- **`negative`** — Tags to suppress in the negative prompt (e.g., suppress "human legs"
  for Arachna since they have a spider body).
- **`personal_descriptor`** — A weighted prompt template. `$PERSON` gets replaced with
  "boy" or "girl" based on the character's sex.

The game's race list is accessed via the `races` global
(`races.racelist` in res://src/data/races_data.gd) for populating dropdowns.

---

## Item Data — items.gd

Two lookup strategies:

1. **`_ATTRIBUTE_OVERRIDES`** — A hardcoded dictionary of special items. Keyed by
   `item.code` or `item.itembase`, each maps to a hand-written prompt description.
   Some entries embed inline LoRA tags (e.g., `<lora:chastity:0.6>`) for items that
   benefit from a specific LoRA model.

2. **`_generic_item_desc(item)`** — Fallback for items not in the override dictionary.
   Builds a description from `item.name` plus material adjectives for secondary parts.
   Uses `Items.itemlist` and `Items.materiallist` from the game globals.

**Relevant game globals:**

- `Items.itemlist[itembase]` — Base item definitions including `partmaterialname`
- `Items.materiallist[mat_code]` — Material data including `adjective` (e.g., "golden", "iron")

---

## ComfyUI Client — comfyui_client.gd

A full async ComfyUI client using Godot's
[`WebSocketClient`](https://docs.godotengine.org/en/3.5/classes/class_websocketclient.html)
and
[`HTTPRequest`](https://docs.godotengine.org/en/3.5/classes/class_httprequest.html)
nodes.

### Connection Lifecycle

```
State machine:  DISCONNECTED → CONNECTING → CONNECTED → GENERATING → FETCHING_RESULT → CONNECTED
```

`connect_to_comfyui(url)`:

1. Converts the HTTP URL to a WebSocket URL (`http://` → `ws://`).
2. Appends `/ws?clientId=<uuid>` (the client ID is generated once in `_init()`).
3. Opens the WebSocket connection.
4. On success, the UI fetches the model list and LoRA list automatically.

The WebSocket connection is polled every frame in `_process()`. This is why the
comfyui_client node **must** be in the active scene tree — see
[Workarounds](#workarounds-and-design-decisions).

Six separate `HTTPRequest` child nodes handle concurrent API calls:

- `_http_models` — `GET /models/checkpoints`
- `_http_loras` — `GET /models/loras`
- `_http_prompt` — `POST /prompt`
- `_http_history` — `GET /history/<prompt_id>`
- `_http_image` — `GET /view?filename=...`
- `_http_upload` — `POST /upload/image`

**ComfyUI API reference:**
The endpoints used are part of ComfyUI's built-in server. See
[ComfyUI API examples](https://github.com/comfyanonymous/ComfyUI/blob/master/script_examples/basic_api_example.py)
for the canonical reference.

### Workflow Templates

Workflows live in `workflows/<type>/default.json` in
[ComfyUI API format](https://github.com/comfyanonymous/ComfyUI/blob/master/script_examples/basic_api_example.py)
(node-graph JSON, not the UI-export format).

Users can add custom workflows by dropping JSON files into the `workflows/` subdirectories.
The settings popup scans these directories and populates the workflow dropdown.

**How workflow templates are populated:**

`_populate_workflow(template, params)` iterates all nodes in the JSON and matches them
by their `_meta.title` field. When a node title matches a parameter name, its input
value is set based on the node's `class_type`:

| class_type        | Behavior                                 |
| ----------------- | ---------------------------------------- |
| `PrimitiveString` | Sets `inputs.value` as string            |
| `PrimitiveInt`    | Sets `inputs.value` as int               |
| `PrimitiveFloat`  | Sets `inputs.value` as float             |
| `LoadImage`       | Sets `inputs.image` as string (filename) |

After parameter population:

- `_populate_static_nodes()` — Sets `SaveImage.filename_prefix` and
  `CheckpointLoaderSimple.ckpt_name` across all matching nodes.
- `_populate_loras()` — Finds `Power Lora Loader (rgthree)` nodes, clears existing
  `lora_#` entries, and adds the configured LoRAs.

**Convention:** When building a custom workflow, use Primitive nodes titled with the
parameter name you want to control (e.g., title a PrimitiveString node `positive_prompt`
and it will automatically receive the generated positive prompt).

### Generation Flow

**txt2img** (BODY, NUDE, PREGNANT, NUDE_PREGNANT):

```
User clicks button
  → _do_txt2img() saves settings, generates prompts, resolves LoRAs
  → comfyui_client.generate_image() builds workflow JSON, POST /prompt
  → WebSocket receives "progress" messages (step N/M) → UI updates
  → WebSocket receives "executing" with null node → execution done
  → GET /history/<prompt_id> → parse output image list
  → GET /view?filename=... for each image (sequentially)
  → emit images_ready → preview popup opens
```

**img2img** (NUDE_FROM_BODY, PREGNANT_FROM_BODY, NUDE_PREGNANT_FROM_NUDE):

```
User clicks button
  → _do_upload_gen() uploads source image via POST /upload/image
  → On upload_complete → _on_upload_complete() dispatches generate_img2img()
  → Same workflow submission + WebSocket + history flow as txt2img
```

**portrait / face crop** (PORTRAIT_FROM_BODY, PORTRAIT_FROM_NUDE):

```
Same upload flow as img2img
  → On upload_complete → dispatches generate_face_crop()
  → Uses the portrait workflow (face detection + bounding-box crop, no diffusion)
  → Output is always 256x256
```

The portrait workflow uses the [ComfyUI_FaceAnalysis](https://github.com/cubiq/ComfyUI_FaceAnalysis)
custom node with InsightFace for face detection — it does not run the diffusion model.

### Image Saving

When the user clicks "Save" on a preview image:

1. `comfyui_client.save_image()` writes the PNG to a game directory based on the
   `SaveCategory`:

   | Category           | Directory                 |
   | ------------------ | ------------------------- |
   | `PORTRAIT`         | `user://portraits`        |
   | `CLOTHED_BODY`     | `user://bodies`           |
   | `NUDE_BODY`        | `user://exposed`          |
   | `PREGNANT_CLOTHED` | `user://bodies_pregnant`  |
   | `PREGNANT_NUDE`    | `user://exposed_pregnant` |

   Filenames follow the pattern: `<sanitized_name>_<character_id>.png`

2. `_apply_saved_image_stat()` updates character stats so the game uses the new image:
   - **Portrait:** Sets `icon_image`, `dynamic_portrait=false`,
     `player_selected_icon=true`, `portrait_update=false`
   - **Clothed body:** Sets `body_image`, `player_selected_body=true`

3. `_update_page()` refreshes the game's body module and summary display so the new
   image appears immediately.

   **Relevant game nodes:**
   - `gui_controller.slavepanel.BodyModule` — the body image display module
   - `gui_controller.slavepanel.SummaryModule` — the character summary panel

---

## LoRA Configuration — lora_config.gd

LoRAs are organized into three categories:

| Category | Key                                                     | When applied                                                                                         |
| -------- | ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `global` | (flat list)                                             | Always included in every generation                                                                  |
| `race`   | Race name (e.g., `"Human"`, `"Elf"`)                    | Included when the character's race matches                                                           |
| `sex`    | Sex value (e.g., `"male"`, `"female"`, `"female_nude"`) | Included when the character's sex matches; for nude generation types, `_nude` is appended to the key |

`resolve_loras(person, gen_type)` collects the union of all applicable LoRAs at
generation time. The `CATEGORY_STATS` dictionary maps each category to the character stat
name used for lookups (`null` for global = always applied).

---

## Settings Persistence

Both `extended_CharInfoMainModule.gd` and `lora_config.gd` persist to the same file:

```
user://portrait_generator_settings.json
```

**File IO is centralized in `util.gd`:**
- `read_settings()` — Reads and parses the settings file, returns an empty dict on error
- `save_settings(data)` — Writes the data dict to the settings file

Both modules call these shared functions:

- **`lora_config.gd`** calls `util.read_settings()` in `load_settings()` and
  `util.save_settings()` in `save_settings()`. It merges its LoRA and workflow data
  before writing.
- **`extended_CharInfoMainModule.gd`** calls `util.read_settings()` in
  `_load_ui_settings()` and `util.save_settings()` in `_save_ui_settings()`. It
  preserves the LoRA config when writing.

This pattern ensures both modules read the full file, modify their own keys, and write
back the complete data, so neither module clobbers the other's settings.

The file contains:

```json
{
  "url": "http://127.0.0.1:8000",
  "model": "checkpoint_name.safetensors",
  "steps": "20",
  "cfg": "7.5",
  "denoise": "0.90",
  "width": "768",
  "height": "1088",
  "positive_prompt": "...",
  "negative_prompt": "...",
  "lora_config": { "global": [], "race": {}, "sex": {} },
  "workflow_selections": {
    "txt2img": "default",
    "img2img": "default",
    "portrait": "default"
  }
}
```

The clothing prompt is intentionally **not** persisted — it's character-specific and
unlikely to be relevant for the next character viewed.

---

## Workarounds and Design Decisions

### 1. Scene tree reparenting (comfyui_client)

**Location:** `extended_CharInfoMainModule.gd:_setup_comfyui_client()`

```gdscript
var parent = comfyui_client.get_parent()
if parent != null:
    parent.remove_child(comfyui_client)
add_child(comfyui_client)
```

**Why:** The mod framework loads modules as children of `modding_core`, but Godot's
[`_process()`](https://docs.godotengine.org/en/3.5/classes/class_node.html#class-node-method-process)
and `HTTPRequest` nodes only function when they're in the **active scene tree**. The
comfyui client needs `_process()` to poll the WebSocket, and its six HTTPRequest
children need the scene tree to fire HTTP requests. Reparenting it under the
CharInfoMainModule node (which _is_ in the active scene tree) makes everything work.

### 2. Empty update() stubs

**Location:** `comfyui_client.gd:54`, `lora_config.gd:31`

```gdscript
func update():
    pass
```

**Why:** The mod framework calls `update()` on every registered module node. Without
this stub, the engine would log errors about a missing method. These do nothing — the
actual update logic runs through signals and `_process()`.

### 3. Expanding TextEdit workaround

**Location:** `extended_CharInfoMainModule.gd`

TextEdit fields in the prompt panel are reparented to the popup root when focused and
returned to their original placeholder when unfocused. This is a workaround for Godot
3.5's UI layering: child controls can't render above sibling containers without being
higher in the scene tree. By temporarily reparenting a focused TextEdit to the popup
root, it renders on top of all other panel content.

The TextEdit is also configured to suppress newlines (Enter key), making it behave like
a single-line `LineEdit` while still supporting word-wrap for long prompts. Height is
dynamically calculated based on text content width.

### 4. Deferred initialization

**Location:** `extended_CharInfoMainModule.gd:_init()`

```gdscript
call_deferred("_setup_comfyui_client")
call_deferred("_add_close_buttons")
```

**Why:** `_init()` runs before the node is added to the scene tree. Close button
positioning uses
[`get_global_rect()`](https://docs.godotengine.org/en/3.5/classes/class_control.html#class-control-method-get-global-rect),
which needs a valid layout pass. `call_deferred()` delays execution to the end of the
frame, after layout is computed.

### 5. Generation person capture

**Location:** `extended_CharInfoMainModule.gd:_do_txt2img()` and `_do_upload_gen()`

```gdscript
_generation_person = active_person
```

**Why:** `active_person` is a reference to whichever character the player is currently
viewing. Since image generation is asynchronous (takes seconds to minutes), the user
could navigate to a different character before the result comes back. Capturing the
reference at dispatch time ensures the save handler writes to the correct character.

### 6. Shared settings file with centralized IO

**Why share a file?** Both `lora_config.gd` and the main UI persist to the same JSON
file because they're logically a single configuration surface. This is a pragmatic choice
over introducing a central settings manager, keeping the module count low.

**How it works:** Instead of each module duplicating file IO logic, both call shared
functions in `util.gd` (`read_settings()` and `save_settings(data)`). Each module reads
the full file, modifies its keys, and writes back the complete data. This eliminates
duplication and ensures they use consistent error handling and file paths.

### 7. All UI built in code (no .tscn files)

The mod builds every panel, button, label, and layout container programmatically in
GDScript. This is intentional — the game's mod framework supports script extension via
`modding_core.extend_node()`, but doesn't have good facilities for loading custom
`.tscn` scene files. Building UI in code also avoids path-resolution issues across
different mod installation paths.

We could probably build `.tscn` files in the future.

### 8. Inline LoRA tags in item descriptions

**Location:** `items.gd` — entries like `chastity_belt` and `tentacle_suit`

Some item descriptions embed Stable Diffusion LoRA syntax directly
(e.g., `<lora:chastity:0.6>`). This means the LoRA is injected via the prompt text
rather than through the workflow's LoRA loader node. This will only work if the
user has a ComfyUI node configured to read these inline directives. Otherwise,
they shouldn't do much of anything.

### 9. LoRA popup deferred close

**Location:** `extended_CharInfoMainModule.gd:_close_lora_popup()`

The LoRA search popup's hide is deferred with `call_deferred()` so the click event
finishes processing before the popup disappears. Without this, the click can "fall
through" to controls behind the popup.

---

## Game Globals Reference

These singletons are used throughout the mod and come from the base game:

| Global            | Usage                                                                                  |
| ----------------- | -------------------------------------------------------------------------------------- |
| `modding_core`    | Module registry (`modules.*`), node extension (`extend_node()`)                        |
| `input_handler`   | `NODE_SLAVEMODULE` constant, `loadimage()` for texture loading, `globalsettings`       |
| `gui_controller`  | `slavepanel.BodyModule`, `slavepanel.SummaryModule` — for refreshing the UI after save |
| `ResourceScripts` | `scenedict.close` (close button scene), `game_res.items` (item ID → ItemClass lookup)  |
| `Items`           | `itemlist` (base item definitions), `materiallist` (material properties)               |
| `races`           | `racelist` (game's race definitions, used for LoRA dropdown population)                |
| `variables`       | `portraits_folder` path                                                                |
