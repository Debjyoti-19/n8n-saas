extends Area2D

@export var panel: Panel

func _on_area_entered(area: Area2D) -> void:
	if panel:
		var rtl = panel.get_node("MarginContainer/NPC1Message")
		panel.visible = true
		rtl.visible_ratio = 0
		$SFXGibberish.play()
		var seconds = 0.05 * rtl.get_total_character_count()
		var tw = create_tween()
		tw.tween_property(
			rtl,
			"visible_ratio",
			1,
			seconds
		)
		tw.tween_callback(func(): $SFXGibberish.stop())


func _on_area_exited(area: Area2D) -> void:
	if panel:
		panel.visible = false
