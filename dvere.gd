extends StaticBody3D

var jsou_otevrene: bool = false
@onready var panty: Node3D = get_parent()

func interaguj() -> void:
	jsou_otevrene = !jsou_otevrene
	
	# Pokud se dveře otevírají na opačnou stranu (do tebe místo ven), změň 90.0 na -90.0
	var cilovy_uhel := deg_to_rad(90.0) if jsou_otevrene else 0.0
	
	# Plynulá animace otočení pantů za 0,7 vteřiny
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(panty, "rotation:y", cilovy_uhel, 0.7)
