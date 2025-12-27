extends Area2D

var msg_key = "NPC2Message"
@export var panel: Panel
@onready var dialog_node = get_owner().get_node("SoundEffects/" + msg_key)

func _on_area_entered(area: Area2D) -> void:
	if panel:
		var rtl = panel.get_node("MarginContainer/" + msg_key)
		panel.visible = true
		rtl.visible_ratio = 0
		dialog_node.play()
		var seconds = dialog_node.audio_length
		var tw = create_tween()
		tw.tween_property(
			rtl,
			"visible_ratio",
			1,
			seconds
		)
		tw.tween_callback(func(): dialog_node.stop())


func _on_area_exited(area: Area2D) -> void:
	if panel:
		panel.visible = false
