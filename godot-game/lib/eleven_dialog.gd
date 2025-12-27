@tool
extends Node2D

# TODO: we need some sort of IDEMPOTENCY key here
# since the user can spam "Generate audio"
@export var audio_name = ""
@export var voice_id = "pNInz6obpgDQGcFmaJgB"  # Adam - Dominant, Firm (verified voice ID)
@export var model_id = "eleven_multilingual_v2"
@export var language_code = ""  # Optional: ISO 639-1 language code (e.g., "en", "es")
@export var enable_logging = true  # Set to false for zero retention mode
@export_multiline var dialog = ""
@export_tool_button("Generate Dialog Audio", "Callable") var gen_sfx_action = gen_sfx

# XXX: It should be possible to save this
# data/node somewhere hidden
# but let's do this for now.
@export var do_not_edit_file_path = ""
var pitch_scale = 1:
	set(value):
		pitch_scale = value
		$SFX.pitch_scale = value

var audio_length:
	get():
		return $SFX.stream.get_length()

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
	
	if audio_name.length() <= 3 or dialog.length() <=3:
		push_error("[GodotAI]: Please provide more info for the Dialog Audio!")
		return
	
	# Validate text length (API limit for free users is 2500 characters for multilingual_v2)
	if dialog.length() > 2500:
		push_error("[GodotAI]: Dialog text too long! Maximum 2500 characters for free users.")
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
	
	# Build URL with query parameters
	var url = "https://api.elevenlabs.io/v1/text-to-speech/{voice_id}?output_format=mp3_44100_128".format({"voice_id": voice_id})
	if not enable_logging:
		url += "&enable_logging=false"
	
	var headers = [
		"xi-api-key: {api_key}".format({"api_key": api_key}),
		"Content-Type: application/json"
	]
	
	# Build request data
	var data = {
		"text": dialog,
		"model_id": model_id
	}
	
	# Add optional language code if specified
	if language_code.length() > 0:
		data["language_code"] = language_code
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
		push_error("[GodotAI]: Couldn't generate Dialog Audio! Response code: " + str(response_code))
		if body.size() > 0:
			var error_text = body.get_string_from_utf8()
			push_error("[GodotAI]: Error details: " + error_text)
		return
	
	# Validate response body
	if body.size() == 0:
		push_error("[GodotAI]: Received empty response body!")
		return
	
	# Ensure directory exists
	if not DirAccess.dir_exists_absolute("res://godotai/dialog"):
		var dir = DirAccess.open("res://godotai")
		if not dir or not dir.make_dir("dialog"):
			push_error("[GodotAI]: Failed to create dialog directory!")
			return
	
	var file_path = "res://godotai/dialog/{name}.mp3".format({"name": audio_name})
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if not file:
		push_error("[GodotAI]: Failed to open file for writing: " + file_path)
		return
		
	file.store_buffer(body)
	file.close()
	do_not_edit_file_path = file_path
	print("[GodotAI]: Dialog Audio successfully generated! File: " + file_path)
