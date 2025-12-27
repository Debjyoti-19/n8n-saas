@tool
extends RefCounted
class_name ElevenLabsGenerator

# Handles ElevenLabs API calls for audio generation

signal audio_generated(sound_name: String, file_path: String)
signal generation_progress(current: int, total: int, sound_name: String)
signal generation_complete(all_files: Array)
signal generation_error(sound_name: String, error_message: String)

var api_key: String = ""
var base_url: String = "https://api.elevenlabs.io/v1"
var output_directory: String = "res://agent_sfx_generated/"

func set_api_key(key: String):
	api_key = key

func set_output_directory(path: String):
	output_directory = path
	# Ensure directory exists
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(output_directory.trim_prefix("res://")):
		dir.make_dir_recursive(output_directory.trim_prefix("res://"))

func generate_sound_effect(sound_data: Dictionary, http_request: HTTPRequest) -> void:
	"""
	Generate a sound effect using ElevenLabs sound generation API
	sound_data should have: name, description
	"""
	var sound_name = sound_data.get("name", "unnamed")
	var description = sound_data.get("description", "")
	
	if description.is_empty():
		generation_error.emit(sound_name, "Description is empty")
		return
	
	var url = base_url + "/sound-generation"
	var headers = [
		"xi-api-key: " + api_key,
		"Content-Type: application/json"
	]
	
	var request_data = {
		"text": "video game sound effect: " + description,
		"duration_seconds": _estimate_duration(description),
		"prompt_influence": 0.8
	}
	
	var json = JSON.stringify(request_data)
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json)
	
	if error != OK:
		generation_error.emit(sound_name, "Failed to send request: " + str(error))

func generate_dialog(sound_data: Dictionary, http_request: HTTPRequest) -> void:
	"""
	Generate dialog audio using ElevenLabs text-to-speech API
	sound_data should have: name, dialog (text), voice_id (optional), use_dialogue_api (optional)
	"""
	var sound_name = sound_data.get("name", "unnamed")
	var dialog_text = sound_data.get("dialog", "")
	var voice_id = sound_data.get("voice_id", "Xb7hH8MSUJpSbSDYk0k2")
	var model_id = sound_data.get("model_id", "eleven_multilingual_v2")
	var use_dialogue_api = sound_data.get("use_dialogue_api", false)
	
	if dialog_text.is_empty():
		generation_error.emit(sound_name, "Dialog text is empty")
		return
	
	# Use Text to Dialogue API if requested (better for multi-speaker conversations)
	if use_dialogue_api:
		_generate_text_to_dialogue(sound_name, dialog_text, voice_id, model_id, http_request)
	else:
		# Standard Text to Speech
		var url = base_url + "/text-to-speech/" + voice_id + "?output_format=mp3_44100_128"
		var headers = [
			"xi-api-key: " + api_key,
			"Content-Type: application/json"
		]
		
		var request_data = {
			"text": dialog_text,
			"model_id": model_id
		}
		
		var json = JSON.stringify(request_data)
		var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json)
		
		if error != OK:
			generation_error.emit(sound_name, "Failed to send request: " + str(error))

func _generate_text_to_dialogue(sound_name: String, dialog_text: String, voice_id: String, model_id: String, http_request: HTTPRequest):
	"""
	Generate dialogue using Text to Dialogue API (better for multi-speaker conversations)
	"""
	var url = base_url + "/text-to-dialogue"
	var headers = [
		"xi-api-key: " + api_key,
		"Content-Type: application/json"
	]
	
	var request_data = {
		"text": dialog_text,
		"voice_id": voice_id,
		"model_id": model_id,
		"output_format": "mp3_44100_128"
	}
	
	var json = JSON.stringify(request_data)
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json)
	
	if error != OK:
		generation_error.emit(sound_name, "Failed to send dialogue request: " + str(error))

func generate_music(sound_data: Dictionary, http_request: HTTPRequest) -> void:
	"""
	Generate background music using ElevenLabs Music API
	sound_data should have: name, description/prompt, duration (optional)
	Note: API access coming soon, currently web-only
	"""
	var sound_name = sound_data.get("name", "unnamed")
	var prompt = sound_data.get("description", sound_data.get("prompt", ""))
	var duration = sound_data.get("duration", 30.0)  # Default 30 seconds
	
	if prompt.is_empty():
		generation_error.emit(sound_name, "Music prompt is empty")
		return
	
	# Note: Music API endpoint may vary when it becomes available
	# This is a placeholder for when the API is released
	var url = base_url + "/music-generation"
	var headers = [
		"xi-api-key: " + api_key,
		"Content-Type: application/json"
	]
	
	var request_data = {
		"prompt": prompt,
		"duration": duration
	}
	
	var json = JSON.stringify(request_data)
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json)
	
	if error != OK:
		generation_error.emit(sound_name, "Failed to send music request: " + str(error))

func handle_response(sound_name: String, response_code: int, body: PackedByteArray, audio_type: String = "sfx") -> String:
	"""
	Handle HTTP response and save audio file
	Returns the file path if successful, empty string if error
	audio_type: "sfx", "dialog", "music", "bgm"
	"""
	if response_code != 200:
		generation_error.emit(sound_name, "API returned error code: " + str(response_code))
		return ""
	
	# Determine file path based on audio type
	var subdir = ""
	match audio_type:
		"dialog":
			subdir = "dialog/"
		"music", "bgm":
			subdir = "music/"
		_:
			subdir = ""  # Sound effects go to root
	
	var file_path = output_directory + subdir + sound_name + ".mp3"
	
	# Ensure directory exists
	var full_path = file_path.trim_prefix("res://")
	var dir_path = full_path.get_base_dir()
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(dir_path):
		dir.make_dir_recursive(dir_path)
	
	# Save file
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		generation_error.emit(sound_name, "Failed to open file for writing: " + file_path)
		return ""
	
	file.store_buffer(body)
	file.close()
	
	# Import the resource so Godot recognizes it
	EditorInterface.get_resource_filesystem().update_file(file_path)
	
	audio_generated.emit(sound_name, file_path)
	return file_path

func _estimate_duration(description: String) -> float:
	# Estimate duration based on description keywords
	var desc_lower = description.to_lower()
	if "short" in desc_lower or "quick" in desc_lower or "brief" in desc_lower:
		return 0.3
	elif "long" in desc_lower or "extended" in desc_lower:
		return 2.0
	elif "footstep" in desc_lower or "step" in desc_lower:
		return 0.2
	elif "explosion" in desc_lower or "impact" in desc_lower:
		return 1.0
	else:
		return 0.5  # Default

