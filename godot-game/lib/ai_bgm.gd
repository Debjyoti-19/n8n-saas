@tool
extends Node2D

# TODO: we need some sort of IDEMPOTENCY key here
# since the user can spam "Generate audio"
@export var audio_name = ""
@export_multiline var description = ""
@export_tool_button("Generate BGM", "Callable") var gen_sfx_action = gen_sfx

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
		return
		
	if not do_not_edit_file_path:
		return
		
	self.pitch_scale = pitch_scale
	$SFX.stream = load(do_not_edit_file_path)
	if autoplay:
		$SFX.play()

func get_key():
	# godot on mac does not support environment variables
	# https://github.com/godotengine/godot/issues/96409#issuecomment-2323042441
	# we read a gitignored (and godot ignored) file for now.
	# var api_key = OS.get_environment("FAL_API_KEY")
	var file = FileAccess.open("res://FAL_API_KEY.txt", FileAccess.READ)
	return file.get_as_text().split("\n")[0]

func gen_sfx():
	if state != STATE.IDLE:
		push_error("[GodotAI]: GodotAI is busy right now!")
		return
	
	if audio_name.length() <= 3 or description.length() <=3:
		push_error("[GodotAI]: Please provide more info for the BGM!")
		return
	
	state = STATE.PENDING
	
	var api_key = get_key()
	var url = "https://queue.fal.run/fal-ai/stable-audio"
	var headers = [
		"Authorization: Key {api_key}".format({"api_key": api_key}),
		"Content-Type: application/json"
	]
	
	var json = JSON.stringify({
		"prompt": description
	})
	
	print("[GodotAI]: Generating audio file... Please wait!")
	$HTTPRequest.request(url, headers, HTTPClient.METHOD_POST, json)

func _on_request_completed(result, response_code, headers, body):
	if not (response_code == 200 or response_code == 202):
		push_error("[GodotAI]: Couldn't generate BGM!")
		return
	
	var content_type = ""
	for header in headers:
		if header.to_lower().begins_with("content-type:"):
			content_type = header.split(": ", true, 1)[1]
			break
			
	if (content_type.begins_with("application/json")):
		var json = JSON.parse_string(body.get_string_from_utf8())
		
		# FAL uses a queue system, interesting
		
		# TODO: make an actual queue system for the audio gen
		# since we're just using godot's @tool, our 'plugin' caps
		# are a bit limited. let's just make the user wait for the response
		# _wait_for_bgm_request(request_id)
		
		
		# TODO: LOL we really need an idempotency key here probs LOL
		if json.has("status"):
			var request_id = json["request_id"]
			match json["status"]:
				"COMPLETED":
					_request_actual_file(request_id)
				"IN_QUEUE":
					# if it's in queue/progress, we need to wait.
					# for now, let's just POLL
					await get_tree().create_timer(5.0).timeout
					_request_status(request_id)
				"IN_PROGRESS":
					# if it's in queue/progress, we need to wait.
					# for now, let's just POLL
					await get_tree().create_timer(5.0).timeout
					_request_status(request_id)
		
		if json.has("audio_file"):
			var url = json["audio_file"]["url"]
			$HTTPRequest.request(url, [], HTTPClient.METHOD_GET)
	elif (content_type.begins_with("application/octet-stream")):
		_process_file_body(body)

func _request_status(request_id: String):
	var raw_url = "https://queue.fal.run/fal-ai/stable-audio/requests/{req_id}/status"
	var url = raw_url.format({"req_id": request_id})
	var headers = [
		"Authorization: Key {api_key}".format({"api_key": get_key()})
	]
	$HTTPRequest.request(url, headers, HTTPClient.METHOD_GET)
	print("[GodotAI]: Please wait! Generating your audio!")

func _request_actual_file(request_id: String):
	var raw_url = "https://queue.fal.run/fal-ai/stable-audio/requests/{req_id}"
	var url = raw_url.format({"req_id": request_id})
	var headers = [
		"Authorization: Key {api_key}".format({"api_key": get_key()})
	]
	$HTTPRequest.request(url, headers, HTTPClient.METHOD_GET)

func _process_file_body(body):
	var file_path = "res://godotai/bgm/{name}.wav".format({"name": audio_name})
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if not file:
		push_error("Failed to open file for writing: " + file_path)
		return
		
	file.store_buffer(body)
	file.close()
	state = STATE.IDLE
	do_not_edit_file_path = file_path
	print("[GodotAI]: BGM successfully generated!")
