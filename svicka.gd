extends StaticBody3D

@export var vyska_od_stredu: float = 0.0

var je_v_ruce: bool = false
var je_rozsvicena: bool = false
var je_schovana: bool = false
var probiha_animace: bool = false
var posledni_zasazeny_objekt: Node3D = null

@onready var svetlo: OmniLight3D = $OmniLight3D
@onready var kolize: CollisionShape3D = $CollisionShape3D
@onready var plamen: Node3D = get_node_or_null("Plamen")

func _ready() -> void:
	# Na začátku hry je svíčka zhasnutá
	je_rozsvicena = false
	aktualizuj_svetlo()
	
	# Pojistka, pokud svíčka začíná schovaná v zavřeném šuplíku
	if get_parent() and get_parent().get("je_otevreny") == false:
		je_schovana = true

func seber() -> void:
	if je_v_ruce or probiha_animace or je_schovana:
		return
	
	var ruka: Node3D = get_tree().current_scene.find_child("Ruka", true, false)
	if ruka:
		je_v_ruce = true
		je_schovana = false
		probiha_animace = true
		kolize.disabled = true
		
		# Svíčka při sebrání zůstává v takovém stavu, v jakém byla (zhasnutá)
		aktualizuj_svetlo()
		
		reparent(ruka, true)
		
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "position", Vector3.ZERO, 0.25)
		tween.tween_property(self, "rotation", Vector3.ZERO, 0.25)
		tween.chain().tween_callback(func() -> void: probiha_animace = false)

func poloz(kamera: Camera3D) -> bool:
	if not je_v_ruce or probiha_animace:
		return false
	
	probiha_animace = true
	posledni_zasazeny_objekt = null
	var cilova_pozice: Vector3 = najdi_misto_polozeni(kamera)
	var cilova_rotace_y: float = global_rotation.y
	
	var novy_rodic: Node = get_tree().current_scene
	if posledni_zasazeny_objekt != null and posledni_zasazeny_objekt.has_method("interaguj"):
		novy_rodic = posledni_zasazeny_objekt
	
	reparent(novy_rodic, true)
	
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", cilova_pozice, 0.25)
	tween.tween_property(self, "rotation", Vector3(0.0, cilova_rotace_y, 0.0), 0.25)
	tween.chain().tween_callback(func() -> void:
		kolize.disabled = false
		je_v_ruce = false
		probiha_animace = false
	)
	return true

func najdi_misto_polozeni(kamera: Camera3D) -> Vector3:
	var prostor: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var start: Vector3 = kamera.global_position
	var smer_pohledu: Vector3 = -kamera.global_transform.basis.z
	var cil_pohledu: Vector3 = start + smer_pohledu * 4.0
	
	var vyjimky: Array[RID] = [get_rid()]
	var hrac: Node = get_tree().current_scene.find_child("Hrac", true, false)
	if hrac is CollisionObject3D:
		vyjimky.append(hrac.get_rid())
	
	var dotaz: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, cil_pohledu)
	dotaz.exclude = vyjimky
	var zasah: Dictionary = prostor.intersect_ray(dotaz)
	
	if not zasah.is_empty():
		var normala: Vector3 = zasah["normal"]
		var bod: Vector3 = zasah["position"]
		var objekt: Object = zasah["collider"]
		if normala.y > 0.6:
			if objekt is Node3D:
				posledni_zasazeny_objekt = objekt as Node3D
			return bod + Vector3(0.0, vyska_od_stredu, 0.0)
		
		var bod_pred_prekazkou: Vector3 = bod + normala * 0.12
		return spust_paprsek_dolu(prostor, bod_pred_prekazkou, vyjimky)
	
	var bod_vpredu: Vector3 = start + smer_pohledu * 2.0
	return spust_paprsek_dolu(prostor, bod_vpredu, vyjimky)

func spust_paprsek_dolu(prostor: PhysicsDirectSpaceState3D, odkud: Vector3, vyjimky: Array[RID]) -> Vector3:
	var dotaz_dolu: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(odkud, odkud + Vector3(0.0, -5.0, 0.0))
	dotaz_dolu.exclude = vyjimky
	var zasah_dolu: Dictionary = prostor.intersect_ray(dotaz_dolu)
	if not zasah_dolu.is_empty():
		var bod_dopadu: Vector3 = zasah_dolu["position"]
		var objekt: Object = zasah_dolu["collider"]
		if objekt is Node3D:
			posledni_zasazeny_objekt = objekt as Node3D
		return bod_dopadu + Vector3(0.0, vyska_od_stredu, 0.0)
	return odkud

func nastav_schovani_v_supliku(schovat: bool) -> void:
	je_schovana = schovat
	aktualizuj_svetlo()

func aktualizuj_svetlo() -> void:
	var ma_svitit: bool = je_rozsvicena and not je_schovana
	svetlo.visible = ma_svitit
	if plamen:
		plamen.visible = ma_svitit

# Rozsvícení a zhasnutí funguje pouze tehdy, když držíš svíčku v ruce
func _unhandled_input(event: InputEvent) -> void:
	if not je_v_ruce:
		return
	
	var stisknuto_prave: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	if stisknuto_prave:
		je_rozsvicena = !je_rozsvicena
		aktualizuj_svetlo()
