@tool
extends EditorScript

# End-to-End Test Runner for Agent SFX
# Run this via: Editor → Run Script → Select this file

var tests_passed = 0
var tests_failed = 0
var test_results = []

func _separator(char: String = "=", length: int = 60) -> String:
	var result = ""
	for i in range(length):
		result += char
	return result

func _run():
	print(_separator("=", 60))
	print("Agent SFX - End-to-End Test Suite")
	print(_separator("=", 60))
	print("")
	
	# Run all test suites
	run_test_suite("Code Analyzer", test_code_analyzer)
	run_test_suite("LLM Analyzer", test_llm_analyzer)
	run_test_suite("ElevenLabs Generator", test_elevenlabs_generator)
	run_test_suite("Audio Cache", test_audio_cache)
	run_test_suite("API Keys", test_api_keys)
	run_test_suite("Integration", test_integration)
	
	# Print summary
	print("")
	print(_separator("=", 60))
	print("TEST SUMMARY")
	print(_separator("=", 60))
	print("Tests Passed: ", tests_passed)
	print("Tests Failed: ", tests_failed)
	print("Total Tests: ", tests_passed + tests_failed)
	print("")
	
	if tests_failed == 0:
		print("✅ ALL TESTS PASSED!")
	else:
		print("❌ SOME TESTS FAILED - Review output above")
	
	print(_separator("=", 60))

func run_test_suite(suite_name: String, test_func: Callable):
	print("")
	print(_separator("-", 60))
	print("Running: ", suite_name)
	print(_separator("-", 60))
	test_func.call()

func assert_true(condition: bool, message: String):
	if condition:
		tests_passed += 1
		print("  ✅ PASS: ", message)
		return true
	else:
		tests_failed += 1
		print("  ❌ FAIL: ", message)
		return false

func assert_false(condition: bool, message: String):
	return assert_true(not condition, message)

func assert_not_null(value, message: String):
	return assert_true(value != null, message)

func assert_not_empty(value, message: String):
	if value is String:
		return assert_true(not value.is_empty(), message)
	elif value is Array:
		return assert_true(value.size() > 0, message)
	elif value is Dictionary:
		return assert_true(value.size() > 0, message)
	else:
		return assert_true(value != null, message)

func test_code_analyzer():
	var analyzer = CodeAnalyzer.new()
	assert_not_null(analyzer, "CodeAnalyzer can be instantiated")
	
	# Test file finding
	var project_path = ProjectSettings.globalize_path("res://")
	var gd_files = analyzer._find_files(project_path, "*.gd")
	assert_not_empty(gd_files, "Finds .gd files in project")
	
	# Test analysis
	var results = analyzer.analyze_project(project_path)
	assert_not_null(results, "Analysis returns results")
	assert_true(results.has("events"), "Results contain 'events' key")
	assert_true(results.has("actions"), "Results contain 'actions' key")
	assert_true(results.has("interactions"), "Results contain 'interactions' key")
	assert_true(results.has("dialogs"), "Results contain 'dialogs' key")
	assert_true(results.has("signals"), "Results contain 'signals' key")
	
	print("  Found ", results.events.size(), " events")
	print("  Found ", results.actions.size(), " actions")
	print("  Found ", results.interactions.size(), " interactions")
	print("  Found ", results.dialogs.size(), " dialogs")

func test_llm_analyzer():
	var analyzer = LLMAnalyzer.new()
	assert_not_null(analyzer, "LLMAnalyzer can be instantiated")
	
	# Test API key setting
	analyzer.set_api_key("test_key")
	assert_true(analyzer.get_api_key() == "test_key", "API key can be set and retrieved")
	
	# Test model setting
	analyzer.set_model("test_model")
	assert_true(analyzer.get_model() == "test_model", "Model can be set and retrieved")
	
	# Test URL
	assert_not_empty(analyzer.get_api_url(), "API URL is set")
	assert_true("groq.com" in analyzer.get_api_url(), "API URL points to Groq")

func test_elevenlabs_generator():
	var generator = ElevenLabsGenerator.new()
	assert_not_null(generator, "ElevenLabsGenerator can be instantiated")
	
	# Test API key setting
	generator.set_api_key("test_key")
	assert_true(generator.api_key == "test_key", "API key can be set")
	
	# Test output directory
	generator.set_output_directory("res://test_output/")
	assert_true(generator.output_directory == "res://test_output/", "Output directory can be set")
	
	# Test duration estimation
	var duration = generator._estimate_duration("short quick sound")
	assert_true(duration < 1.0, "Short sounds get short duration")
	
	duration = generator._estimate_duration("long extended sound")
	assert_true(duration > 1.0, "Long sounds get long duration")

func test_audio_cache():
	var cache = AudioCache.new()
	assert_not_null(cache, "AudioCache can be instantiated")
	
	# Test file hash
	var test_path = ProjectSettings.globalize_path("res://addons/agent-sfx/plugin.gd")
	if FileAccess.file_exists(test_path):
		var hash = cache.get_file_hash(test_path)
		assert_not_empty(hash, "File hash can be generated")
	
	# Test cache key generation
	var project_path = ProjectSettings.globalize_path("res://")
	var cache_key = cache.get_analysis_cache_key(project_path)
	assert_not_empty(cache_key, "Cache key can be generated")
	
	# Test metadata storage
	cache.save_audio_metadata("test_sound", "res://test.mp3", "test description")
	assert_true(cache.is_audio_generated("test_sound"), "Audio metadata can be stored")
	assert_true(cache.get_audio_path("test_sound") == "res://test.mp3", "Audio path can be retrieved")

func test_api_keys():
	# Test Groq key loading
	var groq_key = ProjectSettings.get_setting("agent_sfx/groq_api_key", "")
	var has_groq_key = not groq_key.is_empty()
	
	# Also check file fallback
	if groq_key.is_empty():
		var file = FileAccess.open("res://GROQ_API_KEY.txt", FileAccess.READ)
		if file:
			groq_key = file.get_as_text().strip_edges()
			file.close()
			has_groq_key = not groq_key.is_empty()
	
	if has_groq_key:
		assert_true(true, "Groq API key is configured")
	else:
		print("  ⚠️  WARNING: Groq API key not set (some tests may fail)")
		assert_false(true, "Groq API key is configured")  # This will fail but warn user
	
	# Test ElevenLabs key loading
	var elevenlabs_key = ProjectSettings.get_setting("agent_sfx/elevenlabs_api_key", "")
	var has_elevenlabs_key = not elevenlabs_key.is_empty()
	
	if elevenlabs_key.is_empty():
		var file = FileAccess.open("res://ELEVEN_LABS_API_KEY.txt", FileAccess.READ)
		if file:
			elevenlabs_key = file.get_as_text().strip_edges()
			file.close()
			has_elevenlabs_key = not elevenlabs_key.is_empty()
	
	if has_elevenlabs_key:
		assert_true(true, "ElevenLabs API key is configured")
	else:
		print("  ⚠️  WARNING: ElevenLabs API key not set (audio generation will fail)")
		assert_false(true, "ElevenLabs API key is configured")  # This will fail but warn user

func test_integration():
	print("  Running integration tests...")
	
	# Test that all components can work together
	var analyzer = CodeAnalyzer.new()
	var llm = LLMAnalyzer.new()
	var generator = ElevenLabsGenerator.new()
	var cache = AudioCache.new()
	
	assert_not_null(analyzer, "CodeAnalyzer instantiated")
	assert_not_null(llm, "LLMAnalyzer instantiated")
	assert_not_null(generator, "ElevenLabsGenerator instantiated")
	assert_not_null(cache, "AudioCache instantiated")
	
	# Test that output directory exists or can be created
	var output_dir = "res://agent_sfx_generated/"
	var dir = DirAccess.open("res://")
	if dir:
		var dir_path = output_dir.trim_prefix("res://")
		if not dir.dir_exists(dir_path):
			dir.make_dir_recursive(dir_path)
		assert_true(dir.dir_exists(dir_path), "Output directory exists or can be created")
	
	print("  ✅ Integration test: All components can be instantiated together")

