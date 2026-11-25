extends StaticBody3D

@export var vysunuti: float = 0.25
var je_otevreny: bool = false

@onready var suplik_mesh: Node3D = get_parent()

# Spustí se po kliknutí levým tlačítkem myši na čelo šuplíku
func interaguj() -> void:
	je_otevreny = !je_otevreny
	var cil_z: float = vysunuti if je_otevreny else 0.0
	
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(suplik_mesh, "position:z", cil_z, 0.35)
	
	# Pokud je v šuplíku položená svíčka, při zavření ztlumíme její světlo, ať neprosvítá skrz dřevo
	for potomek in get_children():
		if potomek.has_method("nastav_schovani_v_supliku"):
			potomek.nastav_schovani_v_supliku(not je_otevreny)
