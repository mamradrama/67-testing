extends CharacterBody3D

const RYCHLOST = 3.2
const SILA_SKOKU = 4.5
const CITLIVOST_MYSI = 0.003

@export var nazev_animace_stoji: String = "Idle"
@export var nazev_animace_chuze: String = "mixamo_com"
@export var nazev_animace_sezeni: String = "Sit"

var gravitace: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var hlava_id: int = -1
var je_usazeny: bool = false
var ulozena_pozice_vstani: Vector3 = Vector3.ZERO

@onready var kamera: Camera3D = $Camera3D
@onready var paprsek: RayCast3D = $Camera3D/RayCast3D
@onready var kolize_hrace: CollisionShape3D = get_node_or_null("CollisionShape3D")
@onready var ruka: Node3D = get_node_or_null("Camera3D/Ruka")
@onready var anim_player: AnimationPlayer = find_child("AnimationPlayer", true, false)
@onready var kostra: Skeleton3D = find_child("Skeleton3D", true, false)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	process_priority = 10

	# Pojistka: vytvoří uzel Ruka pod kamerou, pokud tam není
	if not ruka and kamera:
		ruka = Node3D.new()
		ruka.name = "Ruka"
		ruka.position = Vector3(0.28, -0.25, -0.45)
		kamera.add_child(ruka)

	# Paprsek ignoruje vlastní tělo hráče a vidí StaticBody3D i Area3D
	if paprsek:
		paprsek.add_exception(self)
		for kolizni_potomek in find_children("*", "CollisionObject3D", true, false):
			paprsek.add_exception(kolizni_potomek)
		paprsek.collide_with_areas = true
		paprsek.collide_with_bodies = true

	# Skryje hlavu postavy z Mixama, aby neblokovala výhled kamery
	if kostra:
		for i in kostra.get_bone_count():
			if "Head" in kostra.get_bone_name(i):
				hlava_id = i
				break

	# Automaticky zapne smyčku u nalezených animací
	if anim_player:
		var seznam := anim_player.get_animation_list()
		for anim_nazev in seznam:
			if anim_nazev != "RESET":
				anim_player.get_animation(anim_nazev).loop_mode = Animation.LOOP_LINEAR

		if not anim_player.has_animation(nazev_animace_chuze):
			for anim_nazev in seznam:
				if anim_nazev != "RESET" and anim_nazev != nazev_animace_stoji and anim_nazev != nazev_animace_sezeni:
					nazev_animace_chuze = anim_nazev
					break

func _process(_delta: float) -> void:
	if kostra and hlava_id != -1:
		kostra.set_bone_pose_scale(hlava_id, Vector3.ZERO)

func _unhandled_input(event: InputEvent) -> void:
	# ESC uvolní kurzor myši
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Levé tlačítko myši: zamkne kurzor, nebo použije dveře / předmět (funguje i vsedě u stolu)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		zkus_interakci()

	# Klávesa F: pokud sedíš, postaví tě; jinak sebere svíčku, posadí tě na židli nebo použije předmět
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
		if je_usazeny:
			vstan()
			return
		zkus_interakci()

	# Klávesa G: položí drženou svíčku
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_G:
		poloz_predmet_v_ruce()

	# Rozhlížení myší (funguje při chůzi i vsedě)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * CITLIVOST_MYSI)
		kamera.rotate_x(-event.relative.y * CITLIVOST_MYSI)
		kamera.rotation.x = clamp(kamera.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func poloz_predmet_v_ruce() -> void:
	if ruka and ruka.get_child_count() > 0:
		for dite in ruka.get_children():
			if dite.has_method("poloz"):
				if dite.poloz(kamera):
					return

func zkus_interakci() -> void:
	if not paprsek:
		return
	paprsek.force_raycast_update()
	if paprsek.is_colliding():
		var cil := paprsek.get_collider()
		if not cil:
			return
		for uzel in [cil, cil.get_parent()]:
			if not uzel:
				continue
			if uzel.has_method("seber"):
				uzel.seber()
				return
			if uzel.has_method("sedni_si"):
				uzel.sedni_si(self)
				return
			if uzel.has_method("interaguj"):
				uzel.interaguj()
				return
			if uzel.has_method("pouzij"):
				uzel.pouzij()
				return

# Tuto funkci volá skript židle
func posad_se(pozice_sezeni: Vector3, rotace_y: float, pozice_vstani: Vector3) -> void:
	if je_usazeny:
		return
	je_usazeny = true
	ulozena_pozice_vstani = pozice_vstani
	velocity = Vector3.ZERO
	if kolize_hrace:
		kolize_hrace.disabled = true
	global_position = pozice_sezeni
	rotation.y = rotace_y
	kamera.rotation.x = 0.0

func vstan() -> void:
	if not je_usazeny:
		return
	je_usazeny = false
	global_position = ulozena_pozice_vstani
	if kolize_hrace:
		kolize_hrace.disabled = false

func _physics_process(delta: float) -> void:
	# Pokud hráč sedí, nepadá gravitací a nechodí; mezerníkem může také vstát
	if je_usazeny:
		velocity = Vector3.ZERO
		if Input.is_physical_key_pressed(KEY_SPACE):
			vstan()
			return
		if anim_player and anim_player.has_animation(nazev_animace_sezeni):
			prehraj_animaci(nazev_animace_sezeni)
		elif anim_player and anim_player.is_playing():
			anim_player.stop()
		return

	if not is_on_floor():
		velocity.y -= gravitace * delta
	elif Input.is_physical_key_pressed(KEY_SPACE):
		velocity.y = SILA_SKOKU

	var vstup_z := float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	var vstup_x := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var smer := (transform.basis * Vector3(vstup_x, 0, vstup_z)).normalized()

	if smer != Vector3.ZERO:
		velocity.x = smer.x * RYCHLOST
		velocity.z = smer.z * RYCHLOST
		prehraj_animaci(nazev_animace_chuze)
	else:
		velocity.x = move_toward(velocity.x, 0, RYCHLOST)
		velocity.z = move_toward(velocity.z, 0, RYCHLOST)
		if anim_player and anim_player.has_animation(nazev_animace_stoji):
			prehraj_animaci(nazev_animace_stoji)
		elif anim_player and anim_player.is_playing():
			anim_player.stop()

	move_and_slide()

func prehraj_animaci(nazev: String) -> void:
	if anim_player and anim_player.has_animation(nazev):
		if anim_player.current_animation != nazev:
			anim_player.play(nazev)
