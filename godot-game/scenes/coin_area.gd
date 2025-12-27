extends Area2D

var Coin = preload("res://en/coin.tscn")

func _spawn_coin() -> void:
	var coin = Coin.instantiate()
	owner.add_child(coin)
	coin.global_position = self.global_position
	var tw = create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_parallel(true)
	tw.tween_property(coin, "global_position:y", coin.global_position.y - 50, 0.5)
	tw.tween_property(coin, "modulate:a", 0.0, 0.5)


func _on_timer_timeout() -> void:
	if get_overlapping_areas().size() > 0:
		_spawn_coin()
