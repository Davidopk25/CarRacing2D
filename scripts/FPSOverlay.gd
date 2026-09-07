extends CanvasLayer

@onready var label: Label = $FPS
 
func _process(_delta: float) -> void:
	if Global.fps_enabled:
		label.visible = true
		label.text = "FPS: " + str(Engine.get_frames_per_second())
	else:
		label.visible = false
