@tool
extends RefCounted
class_name AutoWiring

# Automatically wires generated sounds to game events

signal wiring_complete(wired_count: int)

func wire_sounds_to_events(sound_mappings: Array, analysis_results: Dictionary) -> Dictionary:
	"""
	Creates wiring suggestions for sounds based on code analysis
	Returns a dictionary with wiring instructions
	"""
	var wiring_instructions = {
		"files_to_modify": [],
		"nodes_to_add": [],
		"connections_to_make": []
	}
	
	# Map sounds to their contexts
	for mapping in sound_mappings:
		var sound_name = mapping.get("name", "")
		var sound_path = mapping.get("path", "")
		var context = mapping.get("context", "")
		
		# Find matching events in analysis
		for event in analysis_results.get("events", []):
			if context.contains(event.name) or event.name.contains(sound_name):
				# Found a match - create wiring instruction
				var instruction = {
					"file": event.file,
					"function": event.name,
					"sound_path": sound_path,
					"sound_name": sound_name,
					"type": "function_call"
				}
				wiring_instructions.files_to_modify.append(instruction)
		
		# Check signals
		for signal_data in analysis_results.get("signals", []):
			if context.contains(signal_data.name):
				var instruction = {
					"file": signal_data.file,
					"signal": signal_data.name,
					"sound_path": sound_path,
					"sound_name": sound_name,
					"type": "signal_connection"
				}
				wiring_instructions.connections_to_make.append(instruction)
	
	wiring_complete.emit(wiring_instructions.files_to_modify.size())
	return wiring_instructions

func generate_wiring_code(instruction: Dictionary) -> String:
	"""
	Generates GDScript code to wire a sound to an event
	"""
	var code = ""
	
	match instruction.get("type", ""):
		"function_call":
			code = """
# Auto-wired by Agent SFX
func {function_name}():
	var audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	audio_player.stream = load("{sound_path}")
	audio_player.play()
	# Original function code here...
""".format({
				"function_name": instruction.get("function", ""),
				"sound_path": instruction.get("sound_path", "")
			})
		
		"signal_connection":
			code = """
# Auto-wired by Agent SFX
func _on_{signal_name}():
	var audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	audio_player.stream = load("{sound_path}")
	audio_player.play()
""".format({
				"signal_name": instruction.get("signal", ""),
				"sound_path": instruction.get("sound_path", "")
			})
	
	return code

func create_wiring_script_file(instructions: Dictionary, output_path: String = "res://agent_sfx_generated/wiring_instructions.gd"):
	"""
	Creates a helper script file with wiring instructions
	"""
	var script_content = """@tool
extends EditorScript

# Auto-generated wiring instructions by Agent SFX
# This file contains instructions for manually wiring sounds to your game

var wiring_data = """
	
	script_content += JSON.stringify(instructions, "\t")
	script_content += """
	
func _run():
	print("Agent SFX Wiring Instructions:")
	print("==============================")
	for instruction in wiring_data.files_to_modify:
		print("File: ", instruction.file)
		print("Function: ", instruction.function)
		print("Sound: ", instruction.sound_path)
		print("---")
"""
	
	var file = FileAccess.open(output_path, FileAccess.WRITE)
	if file:
		file.store_string(script_content)
		file.close()
		return true
	return false

