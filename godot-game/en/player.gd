extends Area2D


const SPEED = 5

enum STATE {WALKING, CHOPPING}
var state = STATE.WALKING
var move_dir = Vector2.ZERO

func _physics_process(delta: float) -> void:
	move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if move_dir.length() > 0:
		state = STATE.WALKING
		$Sprite2D.animation = "walking"
	else:
		var areas = get_overlapping_areas()
		for area in areas:
			if area.is_in_group("tree"):
				state = STATE.CHOPPING
				$Sprite2D.animation = "chopping"
	
	match state:
		STATE.WALKING:
			_p_walking()
		STATE.CHOPPING:
			_p_chopping()

func _p_walking():
	if move_dir.length() <= 0:
		$ElevenSFX.stop()
		$Sprite2D.pause()
		return

	if $SFX_Walk_Timer.time_left <= 0:
		$ElevenSFX.play()
		$ElevenSFX.pitch_scale = randf_range(0.8, 1.2)
		$SFX_Walk_Timer.start(0.2)
		
	$Sprite2D.play()
	$Sprite2D.flip_h = move_dir.x < 0
	
	position += move_dir * SPEED

func _p_chopping():
	$Sprite2D.play()

func _on_sprite_2d_frame_changed() -> void:
	if $Sprite2D.animation == "chopping" and $Sprite2D.frame == 6:
		$ChoppingSFX.play()
