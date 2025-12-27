@tool
extends EditorScript

# Full End-to-End Test - Simulates the complete workflow
# This test runs the actual analysis and generation process
# Run this via: Editor → Run Script → Select this file

var tests_passed = 0
var tests_failed = 0
var test_steps = []

func _separator(char: String = "=", length: int = 60) -> String:
	var result = ""
	for i in range(length):
		result += char
	return result

func _run():
	print(_separator("=", 60))
	print("Agent SFX - Full End-to-End Test")
	print("This will test the complete workflow")
	print(_separator("=", 60))
	print("")
	
	# Check prerequisites
	if not check_prerequisites():
		print("❌ Prerequisites not met. Cannot run end-to-end test.")
		return
	
	# Run the full workflow
	await run_full_workflow()
	
	# Print summary
	print("")
	print(_separator("=", 60))
	print("END-TO-END TEST SUMMARY")
	print(_separator("=", 60))
	for step in test_steps:
		var status = "✅" if step.passed else "❌"
		print(status, " ", step.name)
	print("")
	print("Steps Passed: ", tests_passed)
	print("Steps Failed: ", tests_failed)
	print(_separator("=", 60))
	
	if tests_failed == 0:
		print("🎉 ALL STEPS PASSED! System is working correctly.")
	else:
		print("⚠️  Some steps failed. Review output above.")

func check_prerequisites() -> bool:
	print("Checking prerequisites...")
	
	# Check API keys
	var groq_key = ProjectSettings.get_setting("agent_sfx/groq_api_key", "")
	if groq_key.is_empty():
		var file = FileAccess.open("res://GROQ_API_KEY.txt", FileAccess.READ)
		if file:
			groq_key = file.get_as_text().strip_edges()
			file.close()
	
	if groq_key.is_empty():
		print("  ❌ Groq API key not found")
		return false
	print("  ✅ Groq API key found")
	
	var elevenlabs_key = ProjectSettings.get_setting("agent_sfx/elevenlabs_api_key", "")
	if elevenlabs_key.is_empty():
		var file = FileAccess.open("res://ELEVEN_LABS_API_KEY.txt", FileAccess.READ)
		if file:
			elevenlabs_key = file.get_as_text().strip_edges()
			file.close()
	
	if elevenlabs_key.is_empty():
		print("  ⚠️  ElevenLabs API key not found (audio generation will be skipped)")
	else:
		print("  ✅ ElevenLabs API key found")
	
	# Check project has files
	var project_path = ProjectSettings.globalize_path("res://")
	var dir = DirAccess.open(project_path)
	if not dir:
		print("  ❌ Cannot access project directory")
		return false
	
	print("  ✅ Project directory accessible")
	print("")
	return true

func run_full_workflow():
	print(_separator("=", 60))
	print("STEP 1: Code Analysis")
	print(_separator("=", 60))
	
	var analyzer = CodeAnalyzer.new()
	var project_path = ProjectSettings.globalize_path("res://")
	
	# Connect to signal
	var analysis_complete = false
	var analysis_results = {}
	
	analyzer.analysis_complete.connect(func(results):
		analysis_complete = true
		analysis_results = results
	)
	
	print("  Analyzing project: ", project_path)
	analyzer.analyze_project(project_path)
	
	# Wait a bit for analysis (EditorScript doesn't have get_tree)
	for i in range(60):  # Wait up to 1 second (60 frames at 60fps)
		await Engine.get_main_loop().process_frame
		if analysis_complete:
			break
	
	if analysis_complete:
		record_step("Code Analysis", true, "Found " + str(analysis_results.events.size()) + " events")
		print("  ✅ Code analysis complete")
		print("    Events: ", analysis_results.events.size())
		print("    Actions: ", analysis_results.actions.size())
		print("    Interactions: ", analysis_results.interactions.size())
		print("    Dialogs: ", analysis_results.dialogs.size())
	else:
		record_step("Code Analysis", false, "Analysis did not complete")
		print("  ❌ Code analysis failed or timed out")
		return
	
	print("")
	print(_separator("=", 60))
	print("STEP 2: LLM Analysis (Groq AI)")
	print(_separator("=", 60))
	
	var llm = LLMAnalyzer.new()
	var groq_key = ProjectSettings.get_setting("agent_sfx/groq_api_key", "")
	if groq_key.is_empty():
		var file = FileAccess.open("res://GROQ_API_KEY.txt", FileAccess.READ)
		if file:
			groq_key = file.get_as_text().strip_edges()
			file.close()
	
	llm.set_api_key(groq_key)
	
	# Build prompt
	var prompt = build_test_prompt(analysis_results)
	
	# Make API call
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	var url = llm.get_api_url()
	var headers = [
		"Authorization: Bearer " + groq_key,
		"Content-Type: application/json"
	]
	
	var request_data = {
		"model": llm.get_model(),
		"messages": [
			{
				"role": "user",
				"content": prompt
			}
		],
		"temperature": 0.6,
		"max_tokens": 2000
	}
	
	var json = JSON.stringify(request_data)
	print("  Sending request to Groq API...")
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json)
	if error != OK:
		record_step("LLM API Call", false, "Failed to send request")
		print("  ❌ Failed to send request: ", error)
		http_request.queue_free()
		return
	
	# Wait for response
	var completed = false
	var result_data = {}
	
	http_request.request_completed.connect(func(result, response_code, headers, body):
		completed = true
		result_data = {"result": result, "response_code": response_code, "body": body}
	)
	
	# Wait up to 30 seconds
	for i in range(600):  # 30 seconds at 60fps
		await Engine.get_main_loop().process_frame
		if completed:
			break
	
	var response_code = result_data.response_code
	var body = result_data.body
	
	http_request.queue_free()
	
	if response_code == 200:
		var response_json = JSON.parse_string(body.get_string_from_utf8())
		if response_json and response_json.has("choices"):
			var content = response_json.choices[0].get("message", {}).get("content", "")
			
			# Parse JSON
			var json_start = content.find("{")
			var json_end = content.rfind("}")
			if json_start >= 0 and json_end > json_start:
				var json_content = content.substr(json_start, json_end - json_start + 1)
				var parsed = JSON.parse_string(json_content)
				
				if parsed and parsed.has("fx") and parsed.fx is Array:
					record_step("LLM Analysis", true, "Got " + str(parsed.fx.size()) + " suggestions")
					print("  ✅ LLM analysis complete")
					print("    Suggestions: ", parsed.fx.size())
					
					# Test audio generation if key is available
					var elevenlabs_key = ProjectSettings.get_setting("agent_sfx/elevenlabs_api_key", "")
					if elevenlabs_key.is_empty():
						var file = FileAccess.open("res://ELEVEN_LABS_API_KEY.txt", FileAccess.READ)
						if file:
							elevenlabs_key = file.get_as_text().strip_edges()
							file.close()
					
					if not elevenlabs_key.is_empty():
						await test_audio_generation(parsed.fx)
					else:
						print("")
						print(_separator("=", 60))
						print("STEP 3: Audio Generation (SKIPPED - No API Key)")
						print(_separator("=", 60))
						print("  ⚠️  ElevenLabs API key not set, skipping audio generation test")
				else:
					record_step("LLM Analysis", false, "Invalid response format")
					print("  ❌ Invalid response format")
			else:
				record_step("LLM Analysis", false, "Could not parse JSON")
				print("  ❌ Could not extract JSON from response")
		else:
			record_step("LLM API Call", false, "Invalid response")
			print("  ❌ Invalid response format")
	else:
		record_step("LLM API Call", false, "API error: " + str(response_code))
		print("  ❌ API error: ", response_code)

func test_audio_generation(suggestions: Array):
	print("")
	print(_separator("=", 60))
	print("STEP 3: Audio Generation (ElevenLabs)")
	print(_separator("=", 60))
	print("  ⚠️  WARNING: This will consume API credits!")
	print("  Generating first suggestion only for testing...")
	
	if suggestions.is_empty():
		record_step("Audio Generation", false, "No suggestions to generate")
		print("  ❌ No suggestions available")
		return
	
	var generator = ElevenLabsGenerator.new()
	var elevenlabs_key = ProjectSettings.get_setting("agent_sfx/elevenlabs_api_key", "")
	if elevenlabs_key.is_empty():
		var file = FileAccess.open("res://ELEVEN_LABS_API_KEY.txt", FileAccess.READ)
		if file:
			elevenlabs_key = file.get_as_text().strip_edges()
			file.close()
	
	generator.set_api_key(elevenlabs_key)
	generator.set_output_directory("res://agent_sfx_generated/")
	
	# Test with first suggestion
	var test_suggestion = suggestions[0]
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	print("  Generating: ", test_suggestion.get("name", "unknown"))
	generator.generate_sound_effect(test_suggestion, http_request)
	
	var completed = false
	var result_data = {}
	
	http_request.request_completed.connect(func(result, response_code, headers, body):
		completed = true
		result_data = {"result": result, "response_code": response_code, "body": body}
	)
	
	# Wait up to 30 seconds
	for i in range(600):  # 30 seconds at 60fps
		await Engine.get_main_loop().process_frame
		if completed:
			break
	
	if not completed:
		record_step("Audio Generation", false, "Request timed out")
		print("  ❌ Request timed out")
		http_request.queue_free()
		return
	
	var response_code = result_data.response_code
	var body = result_data.body
	
	http_request.queue_free()
	
	if response_code == 200:
		var file_path = generator.handle_response(
			test_suggestion.get("name", "test"),
			response_code,
			body,
			"sfx"
		)
		
		if not file_path.is_empty():
			record_step("Audio Generation", true, "File saved: " + file_path)
			print("  ✅ Audio generated and saved: ", file_path)
			
			# Verify file exists
			if FileAccess.file_exists(file_path):
				record_step("File Verification", true, "File exists and is valid")
				print("  ✅ File verified: ", file_path)
			else:
				record_step("File Verification", false, "File not found")
				print("  ❌ File not found: ", file_path)
		else:
			record_step("Audio Generation", false, "Failed to save file")
			print("  ❌ Failed to save audio file")
	else:
		record_step("Audio Generation", false, "API error: " + str(response_code))
		print("  ❌ API error: ", response_code)

func build_test_prompt(results: Dictionary) -> String:
	var prompt = """You are analyzing a Godot game project to suggest sound effects.

Based on the code analysis, here are the detected game events and actions:

EVENTS:
"""
	
	for event in results.get("events", []):
		prompt += "- " + event.name + " (" + event.sound_hint + ")\n"
	
	prompt += "\nACTIONS:\n"
	for action in results.get("actions", []):
		prompt += "- " + action.name + " (" + action.sound_hint + ")\n"
	
	prompt += """
Based on this analysis, provide a JSON object with a key "fx" containing an array of 3-5 sound effect suggestions.
Each suggestion should have:
- "name": unique identifier
- "description": detailed description
- "why": explanation
- "context": the game event

Respond with ONLY valid JSON, no markdown.
"""
	
	return prompt

func record_step(name: String, passed: bool, details: String = ""):
	test_steps.append({
		"name": name,
		"passed": passed,
		"details": details
	})
	if passed:
		tests_passed += 1
	else:
		tests_failed += 1

