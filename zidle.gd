extends StaticBody3D

@onready var pozice_sezeni: Marker3D = $PoziceSezeni
@onready var pozice_vstani: Marker3D = $PoziceVstani

func sedni_si(hrac: CharacterBody3D) -> void:
	if hrac.has_method("posad_se"):
		hrac.posad_se(
			pozice_sezeni.global_position,
			pozice_sezeni.global_rotation.y,
			pozice_vstani.global_position
		)
