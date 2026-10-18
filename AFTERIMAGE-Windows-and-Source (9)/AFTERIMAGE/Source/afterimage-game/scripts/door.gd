class_name MemoryDoor
extends Node3D
# Stable, collision-checked hinge motion; actors can block the swing.
var identity = "door"
var locked = false
var jammed = false
var resistance = 0.0
var target_angle = 0.0
var width = 1.8
var height = 2.75
var leaf: AnimatableBody3D
var door_shape: BoxShape3D
var current_angle = 0.0
var wood: Material
var base_basis: Basis
var noise_time = 0.0
var force_time = 0.0
var last_angle = 0.0

func _ready():
	leaf = AnimatableBody3D.new()
	leaf.sync_to_physics = false
	leaf.collision_layer = 1
	leaf.collision_mask = 1|2|4
	leaf.position = Vector3(width*.5,height*.5,0)
	leaf.set_meta("door",self)
	add_child(leaf)
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(width,height-.08,.11)
	door_shape = shape
	col.shape = shape
	leaf.add_child(col)
	part(Vector3.ZERO,shape.size,wood)
	var metal = StandardMaterial3D.new()
	metal.albedo_color = Color(.17,.16,.12)
	metal.metallic = .7
	metal.roughness = .42
	for z in [-.085,.085]:
		for y in [-.7,.25]:
			part(Vector3(0,y,z),Vector3(width-.27,.65,.05),wood)
		part(Vector3(width*.5-.21,-.08,z*1.6),Vector3(.26,.055,.07),metal)
func part(pos: Vector3, size: Vector3, mat: Material):
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	mesh.position = pos
	leaf.add_child(mesh)

func angle() -> float:
	return current_angle

func centre() -> Vector3:
	return leaf.global_position

func prompt() -> String:
	if identity=="fire_exit": return "LEAVE THROUGH THE FIRE DOOR"
	if locked: return "LOCKED / RESTORE EXIT CIRCUIT ON FLOOR 02"
	if jammed: return "HOLD E / FORCE JAMMED DOOR"
	return "CLOSE DOOR" if absf(target_angle)>.2 else "OPEN DOOR"

func interact(p):
	if locked:
		Sound.at("door_locked",centre(),.65)
		GameState.toast("LOCKED / EXIT CIRCUIT ON FLOOR 02")
		return
	if jammed:
		Sound.at("door_locked",centre(),.45)
		return
	var local = to_local(p.global_position)
	target_angle = (-1 if local.z<0 else 1)*deg_to_rad(96) if absf(target_angle)<.2 else 0.0
	Sound.at("door_creak",centre(),.6)

func force(dt: float, actor: Node3D = null):
	if not jammed or locked: return
	resistance = minf(1.6,resistance+dt)
	if resistance>=1.6:
		jammed = false
		target_angle = (-1 if actor==null or to_local(actor.global_position).z<0 else 1)*deg_to_rad(100)
		Sound.at("door_slam",centre(),.8)
		GameState.toast("THE FRAME GIVES WAY")

func open_for_shadow(dt: float, actor: Node3D = null):
	if locked or absf(target_angle)>.4: return
	force_time += dt
	if force_time>1.1:
		jammed = false
		target_angle = (-1 if actor==null or to_local(actor.global_position).z<0 else 1)*deg_to_rad(100)
		Sound.at("door_slam",centre(),.7)
		force_time = -3

func pose_at(value: float) -> Transform3D:
	var basis = Basis(Vector3.UP,value)
	return Transform3D(basis,basis*Vector3(width*.5,height*.5,0))

func _physics_process(dt):
	noise_time = maxf(0,noise_time-dt)
	var desired = 0.0 if locked or jammed else clampf(target_angle,-1.8,1.8)
	var change = clampf(desired-current_angle,-dt*1.4,dt*1.4)
	if absf(change)<.00001: return
	# At most 2.2 cm of outer-edge travel per collision query.
	var steps = maxi(1,ceili(absf(change)/.012))
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = door_shape
	query.collision_mask = 1|2|4
	query.exclude = [leaf.get_rid()]
	query.margin = .002
	for i in range(steps):
		var candidate = current_angle+change/steps
		query.transform = global_transform*pose_at(candidate)
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): break
		current_angle = candidate
	leaf.transform = pose_at(current_angle)
	if absf(current_angle)<.001 and absf(last_angle)>.001 and noise_time<=0:
		Sound.at("door_slam",centre(),.55)
		noise_time = 1.5
	last_angle = current_angle
