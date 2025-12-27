@tool
extends EditorScript

# Static Code Structure Validator
# Validates that all required classes and methods exist
# Run this via: Editor → Run Script → Select this file

var validation_passed = 0
var validation_failed = 0

func _separator(char: String = "=", length: int = 60) -> String:
	var result = ""
	for i in range(length):
		result += char
	return result

func _run():
	print(_separator("=", 60))
	print("Agent SFX - Code Structure Validator")
	print(_separator("=", 60))
	print("")
	
	validate_classes()
	validate_methods()
	validate_files()
	
	print("")
	print(_separator("=", 60))
	print("VALIDATION SUMMARY")
	print(_separator("=", 60))
	print("Passed: ", validation_passed)
	print("Failed: ", validation_failed)
	print("")
	
	if validation_failed == 0:
		print("✅ ALL VALIDATIONS PASSED!")
	else:
		print("❌ SOME VALIDATIONS FAILED")
	print(_separator("=", 60))

func validate_classes():
	print(_separator("-", 60))
	print("Validating Classes...")
	print(_separator("-", 60))
	
	# Test CodeAnalyzer
	if test_class_exists("CodeAnalyzer"):
		test_method_exists("CodeAnalyzer", "analyze_project")
		test_method_exists("CodeAnalyzer", "_find_files")
		test_method_exists("CodeAnalyzer", "_analyze_gd_file")
		test_method_exists("CodeAnalyzer", "_analyze_scene_file")
	
	# Test LLMAnalyzer
	if test_class_exists("LLMAnalyzer"):
		test_method_exists("LLMAnalyzer", "set_api_key")
		test_method_exists("LLMAnalyzer", "get_api_key")
		test_method_exists("LLMAnalyzer", "get_api_url")
		test_method_exists("LLMAnalyzer", "get_model")
	
	# Test ElevenLabsGenerator
	if test_class_exists("ElevenLabsGenerator"):
		test_method_exists("ElevenLabsGenerator", "set_api_key")
		test_method_exists("ElevenLabsGenerator", "generate_sound_effect")
		test_method_exists("ElevenLabsGenerator", "generate_dialog")
		test_method_exists("ElevenLabsGenerator", "handle_response")
	
	# Test AudioCache
	if test_class_exists("AudioCache"):
		test_method_exists("AudioCache", "get_file_hash")
		test_method_exists("AudioCache", "get_analysis_cache_key")
		test_method_exists("AudioCache", "save_audio_metadata")
		test_method_exists("AudioCache", "is_audio_generated")
	
	# Test AutoWiring
	if test_class_exists("AutoWiring"):
		test_method_exists("AutoWiring", "wire_sounds_to_events")

func validate_methods():
	print("")
	print(_separator("-", 60))
	print("Validating Critical Methods...")
	print(_separator("-", 60))
	
	# Test dock methods
	var dock_script = load("res://addons/agent-sfx/dock.gd")
	if dock_script:
		validate("Dock script exists", true)
		# Check for critical methods in dock
		var source = dock_script.get_script_source_code()
		if source:
			validate("Dock has _initialize", "_initialize" in source)
			validate("Dock has _on_analyze_pressed", "_on_analyze_pressed" in source)
			validate("Dock has _on_generate_pressed", "_on_generate_pressed" in source)
			validate("Dock has _on_llm_request_completed", "_on_llm_request_completed" in source)
			validate("Dock has _on_elevenlabs_request_completed", "_on_elevenlabs_request_completed" in source)
	else:
		validate("Dock script exists", false)

func validate_files():
	print("")
	print(_separator("-", 60))
	print("Validating Required Files...")
	print(_separator("-", 60))
	
	var required_files = [
		"res://addons/agent-sfx/plugin.gd",
		"res://addons/agent-sfx/plugin.cfg",
		"res://addons/agent-sfx/dock.gd",
		"res://addons/agent-sfx/dock.tscn",
		"res://addons/agent-sfx/code_analyzer.gd",
		"res://addons/agent-sfx/llm_analyzer.gd",
		"res://addons/agent-sfx/elevenlabs_generator.gd",
		"res://addons/agent-sfx/audio_cache.gd",
		"res://addons/agent-sfx/auto_wiring.gd"
	]
	
	for file_path in required_files:
		validate("File exists: " + file_path.get_file(), ResourceLoader.exists(file_path))

func test_class_exists(class_name: String) -> bool:
	var script_path = "res://addons/agent-sfx/" + class_name.to_snake_case() + ".gd"
	if ResourceLoader.exists(script_path):
		validate("Class file exists: " + class_name, true)
		return true
	else:
		validate("Class file exists: " + class_name, false)
		return false

func test_method_exists(class_name: String, method_name: String):
	var script_path = "res://addons/agent-sfx/" + class_name.to_snake_case() + ".gd"
	if ResourceLoader.exists(script_path):
		var script = load(script_path)
		if script:
			var source = script.get_script_source_code()
			if source:
				var pattern = "func " + method_name
				validate("Method exists: " + class_name + "." + method_name, pattern in source)
			else:
				validate("Method exists: " + class_name + "." + method_name, false)
		else:
			validate("Method exists: " + class_name + "." + method_name, false)

func validate(message: String, condition: bool):
	if condition:
		validation_passed += 1
		print("  ✅ ", message)
	else:
		validation_failed += 1
		print("  ❌ ", message)


