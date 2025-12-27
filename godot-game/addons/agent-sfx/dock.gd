@tool
extends Control

# Main editor dock for Agent SFX - Phase 2

var analyze_button: Button
var progress_label: Label
var progress_bar: ProgressBar
var results_container: VBoxContainer
var scroll_container: ScrollContainer
var review_panel: Panel
var suggestions_list: VBoxContainer
var generate_button: Button

var code_analyzer: CodeAnalyzer
var llm_analyzer: LLMAnalyzer
var audio_generator: ElevenLabsGenerator
var audio_cache: AudioCache
var auto_wiring: AutoWiring

var analysis_results: Dictionary = {}
var sound_suggestions: Array = []
var http_request: HTTPRequest
var elevenlabs_request: HTTPRequest

var plugin: EditorPlugin
var generation_queue: Array = []
var currently_generating: Dictionary = {}
var generated_files: Array = []

func _initialize(p: EditorPlugin):
	plugin = p
	code_analyzer = CodeAnalyzer.new()
	llm_analyzer = LLMAnalyzer.new()
	audio_generator = ElevenLabsGenerator.new()
	audio_cache = AudioCache.new()
	auto_wiring = AutoWiring.new()
	
	# Get UI references
	analyze_button = $VBoxContainer/TopPanel/VBoxContainer2/HBoxContainer/AnalyzeButton
	progress_label = $VBoxContainer/TopPanel/VBoxContainer2/HBoxContainer/ProgressLabel
	progress_bar = $VBoxContainer/TopPanel/VBoxContainer2/ProgressBar
	scroll_container = $VBoxContainer/ScrollContainer
	results_container = $VBoxContainer/ScrollContainer/ResultsContainer
	review_panel = $VBoxContainer/ReviewPanel
	suggestions_list = $VBoxContainer/ReviewPanel/MarginContainer/VBoxContainer/SuggestionsList
	generate_button = $VBoxContainer/ReviewPanel/MarginContainer/VBoxContainer/GenerateButton
	
	# Hide progress bar initially
	if progress_bar:
		progress_bar.visible = false
		progress_bar.max_value = 100
	
	# Create HTTPRequest nodes for API calls
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_llm_request_completed)
	
	elevenlabs_request = HTTPRequest.new()
	add_child(elevenlabs_request)
	elevenlabs_request.request_completed.connect(_on_elevenlabs_request_completed)
	
	# Connect generator signals
	audio_generator.audio_generated.connect(_on_audio_generated)
	audio_generator.generation_progress.connect(_on_generation_progress)
	audio_generator.generation_complete.connect(_on_generation_complete)
	audio_generator.generation_error.connect(_on_generation_error)
	
	# Load API keys
	_load_api_keys()
	
	# Set output directory
	audio_generator.set_output_directory("res://agent_sfx_generated/")
	
	# Connect UI signals
	if analyze_button:
		analyze_button.pressed.connect(_on_analyze_pressed)
	if generate_button:
		generate_button.pressed.connect(_on_generate_pressed)
	
	# Hide review panel initially
	if review_panel:
		review_panel.visible = false

func _load_api_keys():
	# Load Groq API key
	var groq_key = ProjectSettings.get_setting("agent_sfx/groq_api_key", "")
	if groq_key.is_empty():
		# Try old FAL key name for backward compatibility
		groq_key = ProjectSettings.get_setting("agent_sfx/fal_api_key", "")
		if groq_key.is_empty():
			var file = FileAccess.open("res://GROQ_API_KEY.txt", FileAccess.READ)
			if file:
				groq_key = file.get_as_text().strip_edges()
				file.close()
			# Fallback to old FAL key file
			if groq_key.is_empty():
				var file2 = FileAccess.open("res://FAL_API_KEY.txt", FileAccess.READ)
				if file2:
					groq_key = file2.get_as_text().strip_edges()
					file2.close()
	llm_analyzer.set_api_key(groq_key)
	
	# Load ElevenLabs API key
	var elevenlabs_key = ProjectSettings.get_setting("agent_sfx/elevenlabs_api_key", "")
	if elevenlabs_key.is_empty():
		var file = FileAccess.open("res://ELEVEN_LABS_API_KEY.txt", FileAccess.READ)
		if file:
			elevenlabs_key = file.get_as_text().strip_edges()
			file.close()
	audio_generator.set_api_key(elevenlabs_key)

func _on_analyze_pressed():
	if not analyze_button:
		return
	
	analyze_button.disabled = true
	progress_label.text = "Analyzing code..."
	if progress_bar:
		progress_bar.visible = true
		progress_bar.value = 0
	
	if results_container:
		results_container.queue_free()
	results_container = VBoxContainer.new()
	results_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(results_container)
	
	# Get project root
	var project_path = ProjectSettings.globalize_path("res://")
	
	# Check cache first
	var cache_key = audio_cache.get_analysis_cache_key(project_path)
	var cached_results = audio_cache.get_cached_analysis(cache_key)
	
	if not cached_results.is_empty():
		progress_label.text = "Using cached analysis..."
		await get_tree().process_frame
		_on_code_analysis_complete(cached_results)
		return
	
	# Start analysis
	code_analyzer.analysis_complete.connect(_on_code_analysis_complete, CONNECT_ONE_SHOT)
	code_analyzer.analyze_project(project_path)

func _on_code_analysis_complete(results: Dictionary):
	analysis_results = results
	
	# Save to cache
	var project_path = ProjectSettings.globalize_path("res://")
	var cache_key = audio_cache.get_analysis_cache_key(project_path)
	audio_cache.save_analysis_cache(cache_key, results)
	
	progress_label.text = "Code analysis complete. Querying LLM..."
	if progress_bar:
		progress_bar.value = 50
	
	# Now send to LLM
	_send_to_llm(results)

func _send_to_llm(code_results: Dictionary):
	var prompt = _build_llm_prompt(code_results)
	
	var api_key = llm_analyzer.get_api_key()
	if api_key.is_empty():
		progress_label.text = "Error: Groq API key not set!"
		analyze_button.disabled = false
		if progress_bar:
			progress_bar.visible = false
		return
	
	var url = llm_analyzer.get_api_url()
	var headers = [
		"Authorization: Bearer " + api_key,
		"Content-Type: application/json"
	]
	
	var request_data = {
		"model": llm_analyzer.get_model(),
		"messages": [
			{
				"role": "user",
				"content": prompt
			}
		],
		"temperature": 0.6,
		"max_tokens": 4096,
		"top_p": 0.95
	}
	
	var json = JSON.stringify(request_data)
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json)
	
	if error != OK:
		progress_label.text = "Error: Failed to send request"
		analyze_button.disabled = false
		if progress_bar:
			progress_bar.visible = false

func _build_llm_prompt(code_results: Dictionary) -> String:
	var prompt = """You are analyzing a Godot game project to suggest sound effects.

Based on the code analysis, here are the detected game events and actions:

EVENTS:
"""
	
	for event in code_results.get("events", []):
		prompt += "- " + event.name + " (" + event.sound_hint + "): " + event.context + "\n"
	
	prompt += "\nACTIONS:\n"
	for action in code_results.get("actions", []):
		prompt += "- " + action.name + " (" + action.sound_hint + ")\n"
	
	prompt += "\nINTERACTIONS:\n"
	for interaction in code_results.get("interactions", []):
		prompt += "- " + interaction.type + " (" + interaction.sound_hint + ")\n"
	
	prompt += """
DIALOGS:
"""
	for dialog in code_results.get("dialogs", []):
		prompt += "- " + dialog.name + ": " + dialog.text + "\n"
	
	prompt += """
Based on this analysis, provide a JSON object with a key "fx" containing an array of sound effect suggestions.
Each suggestion should have:
- "name": unique identifier (e.g., "player_footstep", "coin_collect")
- "description": detailed description of how the sound should sound
- "why": explanation of why this sound is needed
- "context": the game event/action this sound is for

Respond with ONLY valid JSON, no markdown formatting. Example format:
{"fx": [{"name": "player_footstep", "description": "soft grass footstep sound, 0.2s duration", "why": "player walks on grass", "context": "_p_walking function"}]}
"""
	
	return prompt

func _on_llm_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		
		if json == null:
			progress_label.text = "Error: Invalid JSON response"
			analyze_button.disabled = false
			if progress_bar:
				progress_bar.visible = false
			return
		
		# Groq API response format
		if json.has("choices") and json.choices.size() > 0:
			var content = json.choices[0].get("message", {}).get("content", "")
			if content.is_empty():
				progress_label.text = "Error: Empty response from Groq"
				analyze_button.disabled = false
				if progress_bar:
					progress_bar.visible = false
				return
			_parse_llm_response(content)
		else:
			progress_label.text = "Error: Unexpected response format"
			analyze_button.disabled = false
			if progress_bar:
				progress_bar.visible = false
	else:
		var error_body = body.get_string_from_utf8()
		var error_json = JSON.parse_string(error_body)
		var error_msg = "API request failed (code " + str(response_code) + ")"
		if error_json and error_json.has("error"):
			error_msg += ": " + str(error_json.error.get("message", ""))
		progress_label.text = "Error: " + error_msg
		analyze_button.disabled = false
		if progress_bar:
			progress_bar.visible = false

func _parse_llm_response(output: String):
	# Try to extract JSON from markdown if present
	var json_start = output.find("{")
	var json_end = output.rfind("}")
	if json_start >= 0 and json_end > json_start:
		var length = json_end - json_start + 1
		output = output.substr(json_start, length)
	
	# Parse JSON response
	var json = JSON.parse_string(output)
	
	if json == null:
		progress_label.text = "Error: Could not parse LLM response as JSON"
		analyze_button.disabled = false
		if progress_bar:
			progress_bar.visible = false
		return
	
	if json.has("fx") and json.fx is Array:
		sound_suggestions = json.fx
		_show_review_panel()
	else:
		progress_label.text = "Error: Invalid response format (missing 'fx' array)"
		analyze_button.disabled = false
		if progress_bar:
			progress_bar.visible = false

func _show_review_panel():
	review_panel.visible = true
	
	# Clear existing suggestions
	for child in suggestions_list.get_children():
		child.queue_free()
	
	# Create UI for each suggestion
	for i in range(sound_suggestions.size()):
		var suggestion = sound_suggestions[i]
		var item = _create_suggestion_item(suggestion, i)
		suggestions_list.add_child(item)
	
	progress_label.text = "Review and edit suggestions, then generate audio"
	analyze_button.disabled = false
	if progress_bar:
		progress_bar.visible = false

func _create_suggestion_item(suggestion: Dictionary, index: int) -> Control:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	
	# Top row with name and preview button
	var top_hbox = HBoxContainer.new()
	
	# Name field
	var name_label = Label.new()
	name_label.text = "Name:"
	name_label.custom_minimum_size.x = 60
	var name_edit = LineEdit.new()
	name_edit.text = suggestion.get("name", "")
	name_edit.placeholder_text = "sound_name"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(text): sound_suggestions[index]["name"] = text)
	
	# Preview button (if audio exists)
	var preview_button = Button.new()
	preview_button.text = "Preview"
	preview_button.custom_minimum_size.x = 80
	
	# Check if audio already exists
	var audio_path = audio_cache.get_audio_path(suggestion.get("name", ""))
	if audio_path and ResourceLoader.exists(audio_path):
		preview_button.pressed.connect(func(): _preview_audio(audio_path))
	else:
		preview_button.disabled = true
		preview_button.text = "Not generated"
	
	top_hbox.add_child(name_label)
	top_hbox.add_child(name_edit)
	top_hbox.add_child(preview_button)
	
	# Description field
	var desc_label = Label.new()
	desc_label.text = "Description:"
	var desc_edit = TextEdit.new()
	desc_edit.text = suggestion.get("description", "")
	desc_edit.custom_minimum_size.y = 40
	desc_edit.text_changed.connect(func(): sound_suggestions[index]["description"] = desc_edit.text)
	
	# Why field
	var why_label = Label.new()
	why_label.text = "Why:"
	var why_edit = TextEdit.new()
	why_edit.text = suggestion.get("why", "")
	why_edit.custom_minimum_size.y = 30
	why_edit.text_changed.connect(func(): sound_suggestions[index]["why"] = why_edit.text)
	
	# Context (read-only)
	var context_label = Label.new()
	context_label.text = "Context: " + suggestion.get("context", "")
	context_label.add_theme_color_override("font_color", Color.GRAY)
	
	# Status label
	var status_label = Label.new()
	status_label.name = "StatusLabel"
	if audio_path:
		status_label.text = "✓ Generated: " + audio_path
		status_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		status_label.text = "Not generated yet"
		status_label.add_theme_color_override("font_color", Color.YELLOW)
	
	# Remove button
	var remove_button = Button.new()
	remove_button.text = "Remove"
	remove_button.pressed.connect(func(): _remove_suggestion(index))
	
	container.add_child(top_hbox)
	container.add_child(desc_label)
	container.add_child(desc_edit)
	container.add_child(why_label)
	container.add_child(why_edit)
	container.add_child(context_label)
	container.add_child(status_label)
	container.add_child(remove_button)
	
	# Add separator
	var separator = HSeparator.new()
	container.add_child(separator)
	
	return container

func _preview_audio(file_path: String):
	# Load and play audio in editor
	var audio_stream = load(file_path) as AudioStream
	if not audio_stream:
		push_error("Failed to load audio: " + file_path)
		return
	
	# Create a temporary AudioStreamPlayer to preview
	var player = AudioStreamPlayer.new()
	add_child(player)
	player.stream = audio_stream
	player.play()
	
	# Remove after playback
	await player.finished
	player.queue_free()

func _remove_suggestion(index: int):
	sound_suggestions.remove_at(index)
	_show_review_panel()  # Refresh

func _on_generate_pressed():
	if sound_suggestions.is_empty():
		return
	
	generate_button.disabled = true
	progress_label.text = "Generating audio files..."
	if progress_bar:
		progress_bar.visible = true
		progress_bar.value = 0
		progress_bar.max_value = sound_suggestions.size()
	
	# Build generation queue
	generation_queue.clear()
	generated_files.clear()
	
	for suggestion in sound_suggestions:
		# Check if already generated
		var audio_path = audio_cache.get_audio_path(suggestion.get("name", ""))
		if audio_path and ResourceLoader.exists(audio_path):
			generated_files.append(audio_path)
			continue
		
		generation_queue.append(suggestion)
	
	# Start generation
	_generate_next_audio()

func _generate_next_audio():
	if generation_queue.is_empty():
		_on_generation_complete(generated_files)
		return
	
	var suggestion = generation_queue.pop_front()
	currently_generating = suggestion
	
	progress_label.text = "Generating: " + suggestion.get("name", "unknown")
	if progress_bar:
		progress_bar.value = sound_suggestions.size() - generation_queue.size()
	
	# Determine audio type
	var audio_type = suggestion.get("type", "auto")  # auto, sfx, dialog, music, bgm
	
	if audio_type == "auto":
		# Auto-detect based on content
		if suggestion.has("dialog") and not suggestion.get("dialog", "").is_empty():
			audio_type = "dialog"
		elif suggestion.has("description") and ("music" in suggestion.get("description", "").to_lower() or "bgm" in suggestion.get("description", "").to_lower()):
			audio_type = "music"
		else:
			audio_type = "sfx"
	
	match audio_type:
		"dialog":
			audio_generator.generate_dialog(suggestion, elevenlabs_request)
		"music", "bgm":
			audio_generator.generate_music(suggestion, elevenlabs_request)
		_:
			audio_generator.generate_sound_effect(suggestion, elevenlabs_request)

func _on_elevenlabs_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var sound_name = currently_generating.get("name", "unknown")
	var audio_type = currently_generating.get("type", "auto")
	
	# Determine audio type for file organization
	if audio_type == "auto":
		if currently_generating.has("dialog") and not currently_generating.get("dialog", "").is_empty():
			audio_type = "dialog"
		elif currently_generating.has("description") and ("music" in currently_generating.get("description", "").to_lower() or "bgm" in currently_generating.get("description", "").to_lower()):
			audio_type = "music"
		else:
			audio_type = "sfx"
	
	var file_path = audio_generator.handle_response(sound_name, response_code, body, audio_type)
	
	if not file_path.is_empty():
		generated_files.append(file_path)
		audio_cache.save_audio_metadata(sound_name, file_path, currently_generating.get("description", ""))
		
		# Refresh UI to show preview button
		_show_review_panel()
	
	# Generate next
	_generate_next_audio()

func _on_audio_generated(sound_name: String, file_path: String):
	# Audio file was successfully generated
	pass

func _on_generation_progress(current: int, total: int, sound_name: String):
	progress_label.text = "Generating: " + sound_name + " (" + str(current) + "/" + str(total) + ")"

func _on_generation_complete(all_files: Array):
	progress_label.text = "✓ Generated " + str(all_files.size()) + " audio files!"
	generate_button.disabled = false
	if progress_bar:
		progress_bar.value = progress_bar.max_value
		await get_tree().create_timer(2.0).timeout
		progress_bar.visible = false
	
	# Show auto-wiring option
	_offer_auto_wiring()

func _on_generation_error(sound_name: String, error_message: String):
	push_error("[Agent SFX] Error generating " + sound_name + ": " + error_message)
	progress_label.text = "Error generating " + sound_name + ". Continuing..."
	
	# Continue with next
	_generate_next_audio()

func _offer_auto_wiring():
	# Offer to auto-wire sounds to game events
	var dialog = AcceptDialog.new()
	dialog.title = "Auto-Wire Sounds?"
	dialog.dialog_text = "Would you like to automatically wire the generated sounds to your game events?"
	add_child(dialog)
	
	var yes_button = dialog.add_button("Yes", true, "yes")
	var no_button = dialog.add_button("No", false, "no")
	
	dialog.confirmed.connect(func(): _perform_auto_wiring())
	dialog.canceled.connect(func(): dialog.queue_free())
	
	dialog.popup_centered()

func _perform_auto_wiring():
	progress_label.text = "Auto-wiring sounds to game events..."
	
	# Build sound mappings
	var sound_mappings = []
	for suggestion in sound_suggestions:
		var audio_path = audio_cache.get_audio_path(suggestion.get("name", ""))
		if audio_path:
			sound_mappings.append({
				"name": suggestion.get("name", ""),
				"path": audio_path,
				"context": suggestion.get("context", "")
			})
	
	# Perform auto-wiring analysis
	var wiring_instructions = auto_wiring.wire_sounds_to_events(sound_mappings, analysis_results)
	
	# Create wiring script file
	var wiring_file = "res://agent_sfx_generated/wiring_instructions.gd"
	if auto_wiring.create_wiring_script_file(wiring_instructions, wiring_file):
		progress_label.text = "✓ Auto-wiring complete! " + str(wiring_instructions.files_to_modify.size()) + " connections found."
		push_warning("[Agent SFX] Run the wiring_instructions.gd script in Editor → Run Script to see wiring details.")
	else:
		progress_label.text = "Auto-wiring analysis complete, but failed to save instructions."
