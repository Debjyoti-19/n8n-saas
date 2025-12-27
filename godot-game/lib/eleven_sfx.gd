@tool
extends Node2D

# TODO: we need some sort of IDEMPOTENCY key here
# since the user can spam "Generate audio"
@export var audio_name = ""
@export var description = ""
@export var duration_seconds = 0.5  # Must be between 0.5 and 30.0
@export var prompt_influence = 0.3  # Must be between 0.0 and 1.0
@export var model_id = "eleven_text_to_sound_v2"  # Default sound generation model
@export var loop_sound = false  # Whether to create a looping sound effect
@export_tool_button("Generate Audio", "Callable") var gen_sfx_action = gen_sfx

# XXX: It should be possible to save this
# data/node somewhere hidden
# but let's do this for now.
@export var do_not_edit_file_path = ""
var pitch_scale = 1:
	set(value):
		pitch_scale = value
		$SFX.pitch_scale = value

@export var autoplay = false

enum STATE {IDLE, PENDING}
var state = STATE.IDLE

# XXX: maybe we should have extended audiostreamplayer!
func play():
	$SFX.play()

func stop():
	$SFX.stop()

func _ready():
	if Engine.is_editor_hint():
		$HTTPRequest.request_completed.connect(_on_request_completed)
		
	if not do_not_edit_file_path:
		return
		
	self.pitch_scale = pitch_scale
	$SFX.stream = load(do_not_edit_file_path)
	if autoplay:
		$SFX.play()

func gen_sfx():
	if state == STATE.PENDING:
		push_error("[GodotAI]: GodotAI is busy right now!")
		return
	
	if audio_name.length() <= 3 or description.length() <=3:
		push_error("[GodotAI]: Please provide more info for SoundFX!")
		return
	
	# Validate duration_seconds
	if duration_seconds < 0.5 or duration_seconds > 30.0:
		push_error("[GodotAI]: Duration must be between 0.5 and 30.0 seconds!")
		return
	
	# Validate prompt_influence
	if prompt_influence < 0.0 or prompt_influence > 1.0:
		push_error("[GodotAI]: Prompt influence must be between 0.0 and 1.0!")
		return
	
	state = STATE.PENDING
	
	# godot on mac does not support environment variables
	# https://github.com/godotengine/godot/issues/96409#issuecomment-2323042441
	# we read a gitignored (and godot ignored) file for now.
	# var api_key = OS.get_environment("ELEVEN_LABS_API_KEY")
	# Check if API key file exists
	if not FileAccess.file_exists("res://ELEVEN_LABS_API_KEY.txt"):
		push_error("[GodotAI]: ELEVEN_LABS_API_KEY.txt file not found!")
		state = STATE.IDLE
		return
		
	var file = FileAccess.open("res://ELEVEN_LABS_API_KEY.txt", FileAccess.READ)
	if not file:
		push_error("[GodotAI]: Could not read API key file!")
		state = STATE.IDLE
		return
	var api_key = file.get_as_text().split("\n")[0].strip_edges()
	file.close()
	
	var url = "https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128"
	var headers = [
		"xi-api-key: {api_key}".format({"api_key": api_key}),
		"Content-Type: application/json"
	]
	
	# Build request data with all parameters
	var data = {
		"text": "video game {description}".format({"description": description}),
		"duration_seconds": duration_seconds,
		"prompt_influence": prompt_influence,
		"model_id": model_id
	}
	
	# Add loop parameter if using eleven_text_to_sound_v2 model
	if model_id == "eleven_text_to_sound_v2" and loop_sound:
		data["loop"] = true
	var json = JSON.stringify(data)
	
	print("[GodotAI]: Generating audio file")
	$HTTPRequest.request(url, headers, HTTPClient.METHOD_POST, json)

func _on_request_completed(result, response_code, headers, body):
	state = STATE.IDLE  # Reset state first
	
	# Check for network errors
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("[GodotAI]: Network error occurred: " + str(result))
		return
	
	# Check response code
	if response_code != 200:
		push_error("[GodotAI]: Couldn't generate SoundFX! Response code: " + str(response_code))
		if body.size() > 0:
			var error_text = body.get_string_from_utf8()
			push_error("[GodotAI]: Error details: " + error_text)
		return
	
	# Validate response body
	if body.size() == 0:
		push_error("[GodotAI]: Received empty response body!")
		return
	
	# Ensure directory exists
	if not DirAccess.dir_exists_absolute("res://godotai"):
		var dir = DirAccess.open("res://")
		if not dir.make_dir("godotai"):
			push_error("[GodotAI]: Failed to create godotai directory!")
			return
	
	var file_path = "res://godotai/{name}.mp3".format({"name": audio_name})
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if not file:
		push_error("[GodotAI]: Failed to open file for writing: " + file_path)
		return
		
	file.store_buffer(body)
	file.close()
	do_not_edit_file_path = file_path
	print("[GodotAI]: SoundFX successfully generated! File: " + file_path)
