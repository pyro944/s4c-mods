extends Node

# ComfyUI client for the PortraitGenerator mod.
# Must be added as a child of a scene-tree node so _process() runs.

enum State {
    DISCONNECTED,
    CONNECTING,
    CONNECTED,
    GENERATING,
    FETCHING_RESULT
}

enum SaveCategory {
    PORTRAIT, # user://portraits
    CLOTHED_BODY, # user://bodies
    NUDE_BODY, # user://exposed
    PREGNANT_CLOTHED, # user://bodies_pregnant
    PREGNANT_NUDE # user://exposed_pregnant
}

signal connected()
signal disconnected()
signal connection_error(message)
signal models_loaded(model_list)
signal generation_complete(prompt_id)
signal images_ready(textures)
signal upload_complete(filename)
signal upload_error(message)
signal error(message)

var state = State.DISCONNECTED
var comfyui_url = "http://127.0.0.1:8000"
var client_id = ""
var current_prompt_id = ""

var _ws_client = null
var _http_models = null
var _http_prompt = null
var _http_history = null
var _http_image = null
var _http_upload = null

# Sequential multi-image download state
var _pending_images = []
var _collected_textures = []

# The mod framwork calls update on every Node registered in the mod. This looks unnecessary, but is actually required.
func update():
    pass

func _init():
    client_id = _generate_uuid()

func _ready():
    _ws_client = WebSocketClient.new()
    _ws_client.connect("connection_established", self , "_on_ws_connected")
    _ws_client.connect("data_received", self , "_on_ws_data")
    _ws_client.connect("connection_closed", self , "_on_ws_closed")
    _ws_client.connect("connection_error", self , "_on_ws_error")

    _http_models = HTTPRequest.new()
    _http_models.connect("request_completed", self , "_on_models_response")
    add_child(_http_models)

    _http_prompt = HTTPRequest.new()
    _http_prompt.connect("request_completed", self , "_on_prompt_response")
    add_child(_http_prompt)

    _http_history = HTTPRequest.new()
    _http_history.connect("request_completed", self , "_on_history_response")
    add_child(_http_history)

    _http_image = HTTPRequest.new()
    _http_image.connect("request_completed", self , "_on_image_response")
    add_child(_http_image)

    _http_upload = HTTPRequest.new()
    _http_upload.connect("request_completed", self , "_on_upload_response")
    add_child(_http_upload)

func _process(_delta):
    if _ws_client != null and state != State.DISCONNECTED:
        _ws_client.poll()

# --- Connection Management ---

func connect_to_comfyui(url):
    comfyui_url = url.rstrip("/")
    var ws_url = comfyui_url.replace("http://", "ws://").replace("https://", "wss://")
    ws_url += "/ws?clientId=" + client_id
    state = State.CONNECTING
    var err = _ws_client.connect_to_url(ws_url)
    if err != OK:
        state = State.DISCONNECTED
        emit_signal("connection_error", "Failed to initiate WebSocket connection (error %d)" % err)

func disconnect_from_comfyui():
    if _ws_client:
        _ws_client.disconnect_from_host()
    state = State.DISCONNECTED
    emit_signal("disconnected")

func _on_ws_connected(_protocol):
    state = State.CONNECTED
    emit_signal("connected")

func _on_ws_closed(_was_clean):
    var was_generating = state == State.GENERATING or state == State.FETCHING_RESULT
    var was_connected = state != State.CONNECTING
    state = State.DISCONNECTED
    if was_generating:
        emit_signal("error", "Connection lost during generation")
    if was_connected:
        emit_signal("disconnected")
    else:
        emit_signal("connection_error", "WebSocket connection closed during handshake")

func _on_ws_error():
    var was_generating = state == State.GENERATING or state == State.FETCHING_RESULT
    state = State.DISCONNECTED
    if was_generating:
        emit_signal("error", "Connection lost during generation")
    emit_signal("connection_error", "WebSocket connection failed")

# --- Model Fetching ---

func fetch_models():
    if state == State.DISCONNECTED:
        emit_signal("error", "Not connected to ComfyUI")
        return
    var url = comfyui_url + "/models/checkpoints"
    var err = _http_models.request(url, [], false, HTTPClient.METHOD_GET)
    if err != OK:
        emit_signal("error", "Failed to request model list (error %d)" % err)

func _on_models_response(result, response_code, _headers, body):
    if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
        emit_signal("error", "Failed to fetch models (HTTP %d)" % response_code)
        return
    var json = JSON.parse(body.get_string_from_utf8())
    if json.error != OK:
        emit_signal("error", "Failed to parse model list JSON")
        return
    emit_signal("models_loaded", json.result)

# --- Image Generation ---

func generate_image(model_name, positive_prompt, negative_prompt, image_seed = -1, width = 768, height = 1088, steps = 20, cfg = 8.0):
    var workflow = _build_workflow(model_name, positive_prompt, negative_prompt, image_seed, width, height, steps, cfg)
    _submit_workflow(workflow)

func generate_img2img(model_name, positive_prompt, negative_prompt, source_filename, denoise = 0.7, image_seed = -1, steps = 20, cfg = 8.0):
    var workflow = _build_img2img_workflow(model_name, positive_prompt, negative_prompt, source_filename, denoise, image_seed, steps, cfg)
    _submit_workflow(workflow)

func generate_face_crop(model_name, positive_prompt, negative_prompt, source_filename, image_seed = -1, steps = 20, cfg = 8.0):
    var workflow = _build_face_crop_workflow(model_name, positive_prompt, negative_prompt, source_filename, image_seed, steps, cfg)
    _submit_workflow(workflow)

func _submit_workflow(workflow):
    if state != State.CONNECTED:
        emit_signal("error", "Not connected to ComfyUI")
        return
    state = State.GENERATING
    current_prompt_id = _generate_uuid()
    var payload = JSON.print({
        "prompt": workflow,
        "client_id": client_id,
        "prompt_id": current_prompt_id
    })
    var url = comfyui_url + "/prompt"
    var headers = ["Content-Type: application/json"]
    var err = _http_prompt.request(url, headers, false, HTTPClient.METHOD_POST, payload)
    if err != OK:
        state = State.CONNECTED
        emit_signal("error", "Failed to queue prompt (error %d)" % err)

func _on_prompt_response(result, response_code, _headers, body):
    if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
        var detail = ""
        if body.size() > 0:
            detail = body.get_string_from_utf8().substr(0, 200)
        state = State.CONNECTED
        emit_signal("error", "ComfyUI rejected prompt (HTTP %d): %s" % [response_code, detail])
        return
    emit_signal("generation_complete", current_prompt_id)
    # WebSocket will notify us when execution actually finishes

# --- WebSocket Message Handling ---

func _on_ws_data():
    var peer = _ws_client.get_peer(1)
    var packet = peer.get_packet()
    # Ignore binary frames (latent previews)
    if peer.was_string_packet():
        var text = packet.get_string_from_utf8()
        _handle_ws_message(text)

func _handle_ws_message(text):
    var json = JSON.parse(text)
    if json.error != OK:
        return

    var msg = json.result
    var msg_type = msg.get("type", "")

    match msg_type:
        "executing":
            var data = msg.get("data", {})
            var node = data.get("node", "")
            var prompt_id = str(data.get("prompt_id", ""))
            if (node == null or node == "") and prompt_id == current_prompt_id:
                _fetch_history(current_prompt_id)
        "execution_error":
            if state == State.GENERATING:
                state = State.CONNECTED
                var data = msg.get("data", {})
                emit_signal("error", "ComfyUI execution error: %s" % str(data.get("exception_message", "Unknown error")))

# --- Result Fetching ---

func _fetch_history(prompt_id):
    state = State.FETCHING_RESULT
    var url = comfyui_url + "/history/" + prompt_id
    var err = _http_history.request(url, [], false, HTTPClient.METHOD_GET)
    if err != OK:
        state = State.CONNECTED
        emit_signal("error", "Failed to fetch history (error %d)" % err)

func _on_history_response(result, response_code, _headers, body):
    if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
        state = State.CONNECTED
        emit_signal("error", "Failed to fetch history (HTTP %d)" % response_code)
        return

    var json = JSON.parse(body.get_string_from_utf8())
    if json.error != OK:
        state = State.CONNECTED
        emit_signal("error", "Failed to parse history JSON")
        return

    var history = json.result
    if not history.has(current_prompt_id):
        state = State.CONNECTED
        emit_signal("error", "Prompt ID not found in history")
        return

    # Collect all images from every SaveImage node in the output
    var outputs = history[current_prompt_id].get("outputs", {})
    _pending_images = []
    for node_id in outputs:
        var node_output = outputs[node_id]
        if node_output.has("images"):
            for img_info in node_output.get("images", []):
                _pending_images.append(img_info)

    if _pending_images.size() == 0:
        state = State.CONNECTED
        emit_signal("error", "No images in ComfyUI output")
        return

    _collected_textures = []
    _fetch_next_image()

func _fetch_next_image():
    if _pending_images.size() == 0:
        state = State.CONNECTED
        emit_signal("images_ready", _collected_textures)
        return
    var img_info = _pending_images.pop_front()
    _fetch_image(img_info.get("filename", ""), img_info.get("subfolder", ""), img_info.get("type", "output"))

func _fetch_image(filename, subfolder, type):
    var url = comfyui_url + "/view?filename=" + filename.percent_encode()
    if subfolder != "":
        url += "&subfolder=" + subfolder.percent_encode()
    url += "&type=" + type.percent_encode()
    var err = _http_image.request(url, [], false, HTTPClient.METHOD_GET)
    if err != OK:
        state = State.CONNECTED
        emit_signal("error", "Failed to download image (error %d)" % err)

func _on_image_response(result, response_code, _headers, body):
    if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
        state = State.CONNECTED
        emit_signal("error", "Failed to download image (HTTP %d)" % response_code)
        return

    var image = Image.new()
    var err = image.load_png_from_buffer(body)
    if err != OK:
        state = State.CONNECTED
        emit_signal("error", "Failed to decode PNG image (error %d)" % err)
        return

    var texture = ImageTexture.new()
    texture.create_from_image(image)
    _collected_textures.append(texture)
    _fetch_next_image()

# --- Image Saving ---

# Saves the image to the appropriate directory for the given category.
# Returns the saved path on success, or "" on failure.
func save_image(image_texture, character_id, character_name, category):
    var image = image_texture.get_data()
    var save_dir = _get_save_dir(category)
    var dir = Directory.new()
    if not dir.dir_exists(save_dir):
        dir.make_dir_recursive(save_dir)
    var path = save_dir + "/%s_%s.png" % [character_name, str(character_id)]
    var err = image.save_png(path)
    if err != OK:
        emit_signal("error", "Failed to save image (error %d)" % err)
        return ""
    return path

func _get_save_dir(category):
    match category:
        SaveCategory.PORTRAIT: return "user://portraits"
        SaveCategory.CLOTHED_BODY: return "user://bodies"
        SaveCategory.NUDE_BODY: return "user://exposed"
        SaveCategory.PREGNANT_CLOTHED: return "user://bodies_pregnant"
        SaveCategory.PREGNANT_NUDE: return "user://exposed_pregnant"
    return "user://portraits"

# --- Image Upload ---

func upload_image(image_path):
    var file = File.new()
    var err = file.open(image_path, File.READ)
    if err != OK:
        emit_signal("upload_error", "Cannot open file: %s (error %d)" % [image_path, err])
        return
    var file_data = file.get_buffer(file.get_len())
    file.close()

    var filename = image_path.get_file()
    var boundary = "----GodotBoundary" + _generate_uuid().replace("-", "")

    var body = PoolByteArray()
    body.append_array(("--%s\r\n" % boundary).to_utf8())
    body.append_array(("Content-Disposition: form-data; name=\"image\"; filename=\"%s\"\r\n" % filename).to_utf8())
    body.append_array("Content-Type: image/png\r\n\r\n".to_utf8())
    body.append_array(file_data)
    body.append_array("\r\n".to_utf8())
    body.append_array(("--%s\r\n" % boundary).to_utf8())
    body.append_array("Content-Disposition: form-data; name=\"overwrite\"\r\n\r\n".to_utf8())
    body.append_array("true\r\n".to_utf8())
    body.append_array(("--%s--\r\n" % boundary).to_utf8())

    var headers = ["Content-Type: multipart/form-data; boundary=" + boundary]
    var url = comfyui_url + "/upload/image"
    err = _http_upload.request_raw(url, headers, false, HTTPClient.METHOD_POST, body)
    if err != OK:
        emit_signal("upload_error", "Failed to initiate upload (error %d)" % err)

func _on_upload_response(result, response_code, _headers, body):
    if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
        emit_signal("upload_error", "Upload failed (HTTP %d)" % response_code)
        return
    var json = JSON.parse(body.get_string_from_utf8())
    if json.error != OK:
        emit_signal("upload_error", "Failed to parse upload response")
        return
    var uploaded_filename = json.result.get("name", "")
    emit_signal("upload_complete", uploaded_filename)

# --- Workflow Builder ---

func _resolve_seed(image_seed):
    if image_seed < 0:
        var rng = RandomNumberGenerator.new()
        rng.randomize()
        return rng.randi() & 0x7FFFFFFF
    return image_seed

func _checkpoint_node(model_name):
    return {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": model_name}}

func _clip_encode_node(text, clip_source = "4"):
    return {"class_type": "CLIPTextEncode", "inputs": {"clip": [clip_source, 1], "text": text}}

func _save_image_node(image_source, image_output = 0):
    return {"class_type": "SaveImage", "inputs": {"filename_prefix": "PortraitGenerator", "images": [image_source, image_output]}}

func _vae_decode_node(samples_source, vae_source = "4"):
    return {"class_type": "VAEDecode", "inputs": {"samples": [samples_source, 0], "vae": [vae_source, 2]}}

func _build_workflow(model_name, positive_prompt, negative_prompt, image_seed, width, height, steps = 20, cfg = 8.0):
    image_seed = _resolve_seed(image_seed)
    return {
        "3": {
            "class_type": "KSampler",
            "inputs": {
                "cfg": cfg,
                "denoise": 1.0,
                "latent_image": ["5", 0],
                "model": ["4", 0],
                "negative": ["7", 0],
                "positive": ["6", 0],
                "sampler_name": "euler",
                "scheduler": "normal",
                "seed": image_seed,
                "steps": steps
            }
        },
        "4": _checkpoint_node(model_name),
        "5": {
            "class_type": "EmptyLatentImage",
            "inputs": {"batch_size": 1, "height": height, "width": width}
        },
        "6": _clip_encode_node(positive_prompt),
        "7": _clip_encode_node(negative_prompt),
        "8": _vae_decode_node("3"),
        "9": _save_image_node("8")
    }

# --- Image-to-Image ---

func _build_img2img_workflow(model_name, positive_prompt, negative_prompt, source_filename, denoise, image_seed, steps, cfg):
    image_seed = _resolve_seed(image_seed)
    return {
        "3": {
            "class_type": "KSampler",
            "inputs": {
                "cfg": cfg,
                "denoise": denoise,
                "latent_image": ["10", 0],
                "model": ["4", 0],
                "negative": ["7", 0],
                "positive": ["6", 0],
                "sampler_name": "euler",
                "scheduler": "normal",
                "seed": image_seed,
                "steps": steps
            }
        },
        "4": _checkpoint_node(model_name),
        "5": {
            "class_type": "LoadImage",
            "inputs": {"image": source_filename}
        },
        "6": _clip_encode_node(positive_prompt),
        "7": _clip_encode_node(negative_prompt),
        "8": _vae_decode_node("3"),
        "9": _save_image_node("8"),
        "10": {
            "class_type": "VAEEncode",
            "inputs": {"pixels": ["5", 0], "vae": ["4", 2]}
        }
    }

# --- Face Crop (portrait from body/nude) ---

func _build_face_crop_workflow(model_name, positive_prompt, negative_prompt, source_filename, image_seed, steps, cfg):
    image_seed = _resolve_seed(image_seed)
    return {
        "1": {
            "class_type": "LoadImage",
            "inputs": {"image": source_filename}
        },
        "2": {
            "class_type": "UltralyticsDetectorProvider",
            "inputs": {"model_name": "bbox/face_yolov8m.pt"}
        },
        "4": _checkpoint_node(model_name),
        "6": _clip_encode_node(positive_prompt),
        "7": _clip_encode_node(negative_prompt),
        "8": {
            "class_type": "FaceDetailer",
            "inputs": {
                "image": ["1", 0],
                "model": ["4", 0],
                "clip": ["4", 1],
                "vae": ["4", 2],
                "positive": ["6", 0],
                "negative": ["7", 0],
                "bbox_detector": ["2", 0],
                "guide_size": 64,
                "guide_size_for": true,
                "max_size": 256,
                "seed": image_seed,
                "steps": steps,
                "cfg": cfg,
                "sampler_name": "euler",
                "scheduler": "normal",
                "denoise": 0.1,
                "feather": 0,
                "noise_mask": true,
                "force_inpaint": true,
                "bbox_threshold": 0.5,
                "bbox_dilation": 0,
                "bbox_crop_factor": 1.5,
                "sam_detection_hint": "center-1",
                "sam_dilation": 0,
                "sam_threshold": 0.93,
                "sam_bbox_expansion": 0,
                "sam_mask_hint_threshold": 0.7,
                "sam_mask_hint_use_negative": "False",
                "drop_size": 10,
                "cycle": 1,
                "wildcard": ""
            }
        },
        "10": {
            "class_type": "ImageScale",
            "inputs": {
                "image": ["8", 1],
                "upscale_method": "lanczos",
                "width": 256,
                "height": 256,
                "crop": "center"
            }
        },
        "9": _save_image_node("10")
    }

# --- UUID Generation ---

func _generate_uuid():
    var rng = RandomNumberGenerator.new()
    rng.randomize()
    var hex = ""
    for _i in range(16):
        hex += "%02x" % rng.randi_range(0, 255)
    return "%s-%s-4%s-%s-%s" % [
        hex.substr(0, 8),
        hex.substr(8, 4),
        hex.substr(13, 3),
        hex.substr(16, 4),
        hex.substr(20, 12)
    ]
