@tool
class_name AiAnalyze
extends CanvasLayer

var ElevenSFX = load("res://lib/eleven_sfx.tscn")
var ElevenDialog = load("res://lib/eleven_dialog.tscn")

var screenshot_url = "https://i.imgur.com/5HsVLmg.png"

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

var sfx_array = null
var dialog_array = []

enum STATE {IDLE, PENDING}
var state = STATE.IDLE

# XXX: maybe we should have extended audiostreamplayer!
func play():
	$SFX.play()

func stop():
	$SFX.stop()

func _ready():
	$HTTPRequest.request_completed.connect(_on_request_completed)
		
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

func analyze_with_ai():
	if state != STATE.IDLE:
		push_error("[GodotAI]: GodotAI is busy right now!")
		return
	
	state = STATE.PENDING
	
	var api_key = get_key()
	var url = "https://queue.fal.run/fal-ai/any-llm/vision"
	var headers = [
		"Authorization: Key {api_key}".format({"api_key": api_key}),
		"Content-Type: application/json"
	]
	
	var prompt = """
this is a game. give me a list of possible sound effects for this game.
for each sound effect, give me a unique audio "name", "description" for how it should sound like, and "why" you think its necessary.
respond with a json object that has a key "fx" that contains this list/array. 
do not output markdown and only output plain text.
	"""
	
	var image_url = get_image_url()
	var json = JSON.stringify({
		"prompt": prompt,
		"image_url": image_url
		# "image_url:": "https://i.imgur.com/5HsVLmg.png"
	})
	print("[GodotAI]: Analyzing game... Please wait!")
	$HTTPRequest.request(url, headers, HTTPClient.METHOD_POST, json)

func get_image_url():
	return screenshot_url
	
	# XXX: Somehow, base64 passing here doesn't work.
	# Unfortunately fal.ai doesn't allow uploads through REST
	# (or at least the docs don't mention it)
	# so we manually upload screenshots for now
	var path = "res://godotai/__temp__/screenshot.png"
	var image = FileAccess.open(path, FileAccess.READ)
	var base64 = Marshalls.raw_to_base64(image.get_buffer(image.get_length()))
	image.close()
	return base64
	
	#var file_path = "res://godotai/asd.txt"
	#var file = FileAccess.open(file_path, FileAccess.WRITE)
		
	#file.store_string(base64)
	#file.close()

func _on_request_completed(result, response_code, headers, body):
	if not (response_code == 200 or response_code == 202):
		push_error("[GodotAI]: Couldn't analyze image!")
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
		
		if json.has("output"):
			%LoadingLabel.visible = false
			var output = json["output"]
			var out_json = JSON.new()
			var error = out_json.parse(output)
			if error != OK:
				push_error("[GodotAI]: Couldn't parse sound effect response!")
				return
			
			sfx_array = out_json.data.fx
			for fx in out_json.data.fx:
				var cont = VBoxContainer.new()
				cont.custom_minimum_size.x = 900
				cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				
				var l_name = Label.new()
				l_name.text = JSON.stringify(fx.name)
				l_name.autowrap_mode = TextServer.AUTOWRAP_WORD
				l_name.custom_minimum_size.x = 900
				var l_desc = Label.new()
				l_desc.text = JSON.stringify(fx.description)
				l_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
				l_desc.custom_minimum_size.x = 900
				var l_why = Label.new()
				l_why.text = JSON.stringify(fx.why)
				l_why.autowrap_mode = TextServer.AUTOWRAP_WORD
				l_why.custom_minimum_size.x = 900
				
				cont.add_child(l_name)
				cont.add_child(l_desc)
				cont.add_child(l_why)
				%ImportList.add_child(cont)
			_process_dialog()

func _process_dialog():
	dialog_array = []
	var dialog_nodes = get_all_dialog_nodes(owner.get_node("CanvasLayer"))
	for dialog in dialog_nodes:
		var dialog_name = dialog.name
		var text = dialog.text
		
		var cont = VBoxContainer.new()
		cont.custom_minimum_size.x = 900
		cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var l_name = Label.new()
		l_name.text = dialog_name
		l_name.autowrap_mode = TextServer.AUTOWRAP_WORD
		l_name.custom_minimum_size.x = 900
		var l_desc = Label.new()
		l_desc.text = text
		l_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		l_desc.custom_minimum_size.x = 900
		
		dialog_array.append({ "name": dialog_name, "dialog": dialog.text })
		
		cont.add_child(l_name)
		cont.add_child(l_desc)
		%ImportList.add_child(cont)

func _request_status(request_id: String):
	var raw_url = "https://queue.fal.run/fal-ai/any-llm/requests/{req_id}/status"
	var url = raw_url.format({"req_id": request_id})
	var headers = [
		"Authorization: Key {api_key}".format({"api_key": get_key()})
	]
	$HTTPRequest.request(url, headers, HTTPClient.METHOD_GET)
	print("[GodotAI]: Please wait! Generating your audio!")

func _request_actual_file(request_id: String):
	var raw_url = "https://queue.fal.run/fal-ai/any-llm/requests/{req_id}"
	var url = raw_url.format({"req_id": request_id})
	var headers = [
		"Authorization: Key {api_key}".format({"api_key": get_key()})
	]
	$HTTPRequest.request(url, headers, HTTPClient.METHOD_GET)


func _on_button_pressed() -> void:
	$CenterContainer.visible = true
	analyze_with_ai()
	# save_to_packed_scene(sfx_array)

func _on_import_pressed() -> void:
	save_to_packed_scene(sfx_array)

func save_to_packed_scene(sfx_array):
	var root = Node2D.new()
	root.name = "SoundEffects"

	var owner_path = owner.get_scene_file_path()
	var folder_path = owner_path.get_base_dir()
	var basename = owner_path.get_file().get_basename()
	
	var save_to_path = "{folder_path}{file_name}".format({
		"folder_path": folder_path,
		"file_name": basename + "_audio.tscn"
	})
	
	for fx in sfx_array:
		var sfx = ElevenSFX.instantiate()
		root.add_child(sfx)
		sfx.owner = root
		sfx.name = fx.name
		sfx.audio_name = fx.name
		sfx.description = fx.description
		
	for dx in dialog_array:
		var sfx = ElevenDialog.instantiate()
		root.add_child(sfx)
		sfx.owner = root
		sfx.voice_id = "INDKfphIpZiLCUiXae4o"
		sfx.name = dx.name
		sfx.audio_name = dx.name
		sfx.dialog = dx.dialog

	# Save Scene
	var scene = PackedScene.new()
	var result = scene.pack(root)
	if result == OK:
		var error = ResourceSaver.save(scene, save_to_path)
		if error != OK:
			push_error(("[GodotAI]: SFX scene could not be saved to disk!"))
		
		%Done.visible = true

# so for now, all dialog nodes are taken via rich text label
# however, you can imagine integrating this with an API,
# say tagging the dialog via godot groups, or through an external
# dialog file
func get_all_dialog_nodes(node: Node) -> Array:
	var labels = []

	if node is RichTextLabel:
		labels.append(node)

	for child in node.get_children():
		labels.append_array(get_all_dialog_nodes(child))

	return labels
