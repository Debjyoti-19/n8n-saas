@tool
extends EditorScript

# API Integration Test - Tests actual API calls
# WARNING: This will make real API calls and may consume credits
# Run this via: Editor → Run Script → Select this file

var tests_passed = 0
var tests_failed = 0

func _separator(char: String = "=", length: int = 60) -> String:
	var result = ""
	for i in range(length):
		result += char
	return result

func _run():
	print(_separator("=", 60))
	print("Agent SFX - API Integration Test")
	print("WARNING: This makes real API calls!")
	print(_separator("=", 60))
	print("")
	
	# Check API keys first
	if not check_api_keys():
		print("❌ API keys not configured. Skipping API tests.")
		return
	
	print("Starting API integration tests...")
	print("")
	
	# Test Groq API
	test_groq_api()
	
	# Test ElevenLabs API (optional - comment out if you don't want to use credits)
	# test_elevenlabs_api()
	
	# Print summary
	print("")
	print(_separator("=", 60))
	print("API TEST SUMMARY")
	print(_separator("=", 60))
	print("Tests Passed: ", tests_passed)
	print("Tests Failed: ", tests_failed)
	print(_separator("=", 60))

func check_api_keys() -> bool:
	var groq_key = ProjectSettings.get_setting("agent_sfx/groq_api_key", "")
	if groq_key.is_empty():
		var file = FileAccess.open("res://GROQ_API_KEY.txt", FileAccess.READ)
		if file:
			groq_key = file.get_as_text().strip_edges()
			file.close()
	
	if groq_key.is_empty():
		print("❌ Groq API key not found")
		return false
	
	print("✅ Groq API key found")
	return true

func test_groq_api():
	print(_separator("-", 60))
	print("Testing Groq AI API...")
	print(_separator("-", 60))
	
	var llm = LLMAnalyzer.new()
	var groq_key = ProjectSettings.get_setting("agent_sfx/groq_api_key", "")
	if groq_key.is_empty():
		var file = FileAccess.open("res://GROQ_API_KEY.txt", FileAccess.READ)
		if file:
			groq_key = file.get_as_text().strip_edges()
			file.close()
	
	llm.set_api_key(groq_key)
	
	# Create a simple test request
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	var url = llm.get_api_url()
	var headers = [
		"Authorization: Bearer " + groq_key,
		"Content-Type: application/json"
	]
	
	var test_prompt = """You are analyzing a game. Provide a JSON object with a key "fx" containing an array with ONE sound effect suggestion.
Example: {"fx": [{"name": "test_sound", "description": "a test sound", "why": "for testing", "context": "test"}]}
Respond with ONLY valid JSON, no markdown."""
	
	var request_data = {
		"model": llm.get_model(),
		"messages": [
			{
				"role": "user",
				"content": test_prompt
			}
		],
		"temperature": 0.6,
		"max_tokens": 500
	}
	
	var json = JSON.stringify(request_data)
	print("  Sending request to Groq API...")
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json)
	
	if error != OK:
		print("  ❌ FAIL: Failed to send request: ", error)
		tests_failed += 1
		http_request.queue_free()
		return
	
	# Wait for response
	print("  Waiting for response...")
	var completed = false
	var result_data = {}
	
	http_request.request_completed.connect(func(result, response_code, headers, body):
		completed = true
		result_data = {"result": result, "response_code": response_code, "body": body}
	)
	
	# Wait up to 30 seconds
	for i in range(30):
		await Engine.get_main_loop().process_frame
		if completed:
			break
	
	if not completed:
		print("  ❌ FAIL: Request timed out")
		tests_failed += 1
		http_request.queue_free()
		return
	
	var result = result_data.result
	var response_code = result_data.response_code
	var body = result_data.body
	
	http_request.queue_free()
	
	if response_code == 200:
		var response_json = JSON.parse_string(body.get_string_from_utf8())
		if response_json and response_json.has("choices"):
			var content = response_json.choices[0].get("message", {}).get("content", "")
			if not content.is_empty():
				print("  ✅ PASS: Groq API responded successfully")
				var preview = content.substr(0, 100) if content.length() > 100 else content
				print("  Response preview: ", preview, "...")
				tests_passed += 1
				
				# Try to parse as JSON
				var json_start = content.find("{")
				var json_end = content.rfind("}")
				if json_start >= 0 and json_end > json_start:
					var length = json_end - json_start + 1
					var json_content = content.substr(json_start, length)
					var parsed = JSON.parse_string(json_content)
					if parsed and parsed.has("fx"):
						print("  ✅ PASS: Response contains valid JSON with 'fx' key")
						tests_passed += 1
					else:
						print("  ❌ FAIL: Response JSON missing 'fx' key")
						tests_failed += 1
				else:
					print("  ⚠️  WARNING: Could not extract JSON from response")
			else:
				print("  ❌ FAIL: Empty response content")
				tests_failed += 1
		else:
			print("  ❌ FAIL: Invalid response format")
			tests_failed += 1
	else:
		print("  ❌ FAIL: API returned error code: ", response_code)
		print("  Response: ", body.get_string_from_utf8())
		tests_failed += 1

func test_elevenlabs_api():
	print(_separator("-", 60))
	print("Testing ElevenLabs API...")
	print("⚠️  WARNING: This will consume API credits!")
	print(_separator("-", 60))
	
	var generator = ElevenLabsGenerator.new()
	var elevenlabs_key = ProjectSettings.get_setting("agent_sfx/elevenlabs_api_key", "")
	if elevenlabs_key.is_empty():
		var file = FileAccess.open("res://ELEVEN_LABS_API_KEY.txt", FileAccess.READ)
		if file:
			elevenlabs_key = file.get_as_text().strip_edges()
			file.close()
	
	if elevenlabs_key.is_empty():
		print("  ❌ ElevenLabs API key not found - skipping test")
		return
	
	generator.set_api_key(elevenlabs_key)
	
	# Test with a very short sound effect
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	var test_data = {
		"name": "test_sound",
		"description": "short beep sound, 0.2 seconds"
	}
	
	print("  Generating test sound effect...")
	generator.generate_sound_effect(test_data, http_request)
	
	var completed = false
	var result_data = {}
	
	http_request.request_completed.connect(func(result, response_code, headers, body):
		completed = true
		result_data = {"result": result, "response_code": response_code, "body": body}
	)
	
	# Wait up to 30 seconds
	for i in range(30):
		await Engine.get_main_loop().process_frame
		if completed:
			break
	
	if not completed:
		print("  ❌ FAIL: Request timed out")
		tests_failed += 1
		http_request.queue_free()
		return
	
	var result = result_data.result
	var response_code = result_data.response_code
	var body = result_data.body
	
	http_request.queue_free()
	
	if response_code == 200:
		print("  ✅ PASS: ElevenLabs API responded successfully")
		print("  Audio data size: ", body.size(), " bytes")
		tests_passed += 1
		
		# Try to save it
		var file_path = generator.handle_response("test_sound", response_code, body, "sfx")
		if not file_path.is_empty():
			print("  ✅ PASS: Audio file saved successfully: ", file_path)
			tests_passed += 1
		else:
			print("  ❌ FAIL: Failed to save audio file")
			tests_failed += 1
	else:
		print("  ❌ FAIL: API returned error code: ", response_code)
		print("  Response: ", body.get_string_from_utf8())
		tests_failed += 1

