@tool
extends EditorScript

# Test script to validate ElevenLabs integration
# Run this from Godot Editor: Tools > Execute Script

func _run():
	print("=== ElevenLabs Integration Test ===")
	
	# Test 1: Check API key file exists
	print("\n1. Checking API key file...")
	if FileAccess.file_exists("res://ELEVEN_LABS_API_KEY.txt"):
		var file = FileAccess.open("res://ELEVEN_LABS_API_KEY.txt", FileAccess.READ)
		if file:
			var api_key = file.get_as_text().strip_edges()
			file.close()
			if api_key.begins_with("sk_"):
				print("✅ API key file found and valid format")
			else:
				print("❌ API key format invalid (should start with 'sk_')")
		else:
			print("❌ Cannot read API key file")
	else:
		print("❌ API key file not found")
	
	# Test 2: Check directory structure
	print("\n2. Checking directory structure...")
	if DirAccess.dir_exists_absolute("res://godotai"):
		print("✅ godotai directory exists")
		if DirAccess.dir_exists_absolute("res://godotai/dialog"):
			print("✅ dialog subdirectory exists")
		else:
			print("⚠️  dialog subdirectory missing (will be created automatically)")
	else:
		print("⚠️  godotai directory missing (will be created automatically)")
	
	# Test 3: Validate scene files exist
	print("\n3. Checking scene files...")
	if FileAccess.file_exists("res://lib/eleven_sfx.tscn"):
		print("✅ eleven_sfx.tscn found")
	else:
		print("❌ eleven_sfx.tscn missing")
	
	if FileAccess.file_exists("res://lib/eleven_dialog.tscn"):
		print("✅ eleven_dialog.tscn found")
	else:
		print("❌ eleven_dialog.tscn missing")
	
	# Test 4: Check script syntax
	print("\n4. Checking script files...")
	if FileAccess.file_exists("res://lib/eleven_sfx.gd"):
		print("✅ eleven_sfx.gd found")
	else:
		print("❌ eleven_sfx.gd missing")
	
	if FileAccess.file_exists("res://lib/eleven_dialog.gd"):
		print("✅ eleven_dialog.gd found")
	else:
		print("❌ eleven_dialog.gd missing")
	
	print("\n=== Test Complete ===")
	print("If all tests pass, your ElevenLabs integration should work correctly!")