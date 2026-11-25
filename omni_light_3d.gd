extends OmniLight3D

var cas: float = 0.0

func _process(delta: float) -> void:
	cas += delta * 8.0
	# Plynulé nepravidelné kolísání intenzity světla
	light_energy = 1.25 + sin(cas) * 0.12 + cos(cas * 2.3) * 0.08
