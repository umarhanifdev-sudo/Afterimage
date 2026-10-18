class_name HumanRig
extends Node3D
# Fifty deform bones and normalized MakeHuman skin weights. +Z faces forward.
# Distance-based stance/swing cycles are solved with two-bone IK; no billboard rotation.
var skeleton: Skeleton3D
var model: Node3D
var bones = {}
var rest = {}
var phase = 0.0
var elapsed = 0.0
var gait = 0.0
var death_time = 0.0
var mode = "human"
var glow: StandardMaterial3D
var gun_cue: Node3D
var eye_nodes: Array[Node3D] = []
var material: ShaderMaterial
var palm_centres = {}
var palm_frames = {}

func setup(part: String = "human", shadow: bool = false):
	mode = part
	model = load("res://assets/characters/"+part+".glb").instantiate()
	add_child(model)
	skeleton = find_skeleton(model)
	for i in range(skeleton.get_bone_count()):
		bones[skeleton.get_bone_name(i)] = i
		rest[skeleton.get_bone_name(i)] = skeleton.get_bone_global_rest(i).origin
	for side in ["R","L"]:
		var wrist: Vector3 = rest["wrist_"+side]
		var index: Vector3 = rest["finger2-1_"+side]-wrist
		var little: Vector3 = rest["finger5-1_"+side]-wrist
		var distal = ((index+little)*.5).normalized()
		var across = (index-little).slide(distal).normalized()
		palm_centres[side] = (index+little)*.30
		palm_frames[side] = Basis(across,distal.cross(across).normalized(),distal)
	if shadow:
		material = ShaderMaterial.new()
		material.shader = load("res://shaders/charcoal.gdshader")
		apply_material(model,material,1)
		var attachment = attach("head")
		glow = StandardMaterial3D.new()
		glow.albedo_color = Color(.8,.75,.58)
		glow.emission_enabled = true
		glow.emission = Color(.6,.5,.33)
		glow.emission_energy_multiplier = 1.2
		for side in [-1,1]:
			var eye = MeshInstance3D.new()
			var sphere = SphereMesh.new()
			sphere.radius = .009
			sphere.height = .010
			eye.mesh = sphere
			eye.material_override = glow
			eye.position = Vector3(side*.031,.031,.129)
			attachment.add_child(eye)
			eye_nodes.append(eye)
		# Rounded helmet and rim make the charred silhouette recognizably a soldier.
		var helmet = MeshInstance3D.new()
		var cap = SphereMesh.new()
		cap.radius = .116
		cap.height = .14
		cap.radial_segments = 28
		cap.rings = 12
		helmet.mesh = cap
		helmet.position = Vector3(0,.132,-.008)
		helmet.scale = Vector3(1.13,1,1.18)
		helmet.material_override = material
		attachment.add_child(helmet)
		var rim = MeshInstance3D.new()
		var ring = TorusMesh.new()
		ring.inner_radius = .113
		ring.outer_radius = .132
		ring.rings = 28
		ring.ring_segments = 8
		rim.mesh = ring
		rim.position = Vector3(0,.105,-.008)
		rim.material_override = material
		attachment.add_child(rim)
		gun_cue = ServiceWeapon.new()
		gun_cue.build(1)
		gun_cue.scale = Vector3.ONE*.72
		gun_cue.position = Vector3(0,-.04,.07)
		gun_cue.rotation = Vector3(0,PI,0)
		attach("wrist_R").add_child(gun_cue)
		apply_layer(gun_cue,1)
	else:
		apply_layer(model,2)

func find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D: return n
	for c in n.get_children():
		var result = find_skeleton(c)
		if result: return result
	return null

func apply_material(n: Node, mat: Material, layer: int):
	if n is MeshInstance3D:
		n.material_override = mat
		n.layers = layer
	for c in n.get_children(): apply_material(c,mat,layer)

func apply_layer(n: Node, layer: int):
	if n is MeshInstance3D:
		n.layers = layer
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if layer==2 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for c in n.get_children(): apply_layer(c,layer)

func attach(bone: String) -> BoneAttachment3D:
	var a = BoneAttachment3D.new()
	a.bone_name = bone
	skeleton.add_child(a)
	return a

func pose(bone: String, angles: Vector3):
	if bones.has(bone): skeleton.set_bone_pose_rotation(bones[bone],Quaternion.from_euler(angles))

func bend_fingers(side: String, amount: float, trigger: bool = false):
	for finger in range(1,6):
		for joint in range(1,4):
			var curl = amount*(.42 if trigger and finger==2 else [0.0,.95,1.35,.70][joint])
			pose("finger%d-%d_%s"%[finger,joint,side],Vector3(curl,(-.4 if side=="L" else .4)*amount if finger==1 else 0,0))

func solve_limb(upper: String, lower: String, end: String, target: Vector3, bend: Vector3, end_rotation: Quaternion = Quaternion.IDENTITY, root_anchor: Vector3 = Vector3.INF, upper_length: float = 0.0):
	var i = bones[upper]
	var j = bones[lower]
	var k = bones[end]
	var start = skeleton.get_bone_global_pose(i).origin
	var a = rest[upper].distance_to(rest[lower])
	var b = rest[lower].distance_to(rest[end])
	if root_anchor!=Vector3.INF: start = root_anchor
	if upper_length>0: a = upper_length
	var delta = target-start
	var length = clampf(delta.length(),absf(a-b)+.005,a+b-.004)
	var axis = delta.normalized()
	var perpendicular = (bend-axis*bend.dot(axis)).normalized()
	if perpendicular.length()<.01: perpendicular = Vector3.FORWARD
	var along = (a*a-b*b+length*length)/(2*length)
	var height = sqrt(maxf(.00001,a*a-along*along))
	var middle = start+axis*along+perpendicular*height
	var tip = start+axis*length
	var qa = Quaternion((rest[lower]-rest[upper]).normalized(),(middle-start).normalized())
	var qb = Quaternion((rest[end]-rest[lower]).normalized(),(tip-middle).normalized())
	skeleton.set_bone_global_pose(i,Transform3D(Basis(qa),start))
	skeleton.set_bone_global_pose(j,Transform3D(Basis(qb),middle))
	skeleton.set_bone_global_pose(k,Transform3D(Basis(end_rotation),tip))

func animate_shadow(dt: float, speed: float, role: int, state: int, hit: float, dead: bool, armed: bool):
	elapsed += dt
	if dead:
		death_time += dt
		var t = clampf(death_time/1.25,0,1)
		var collapse = smoothstep(.25,1,t)
		rotation.x = -collapse*1.49
		rotation.z = collapse*.18
		position.y = collapse*.23
		pose("spine03",Vector3(.5*sin(t*PI),0,.15*collapse))
		pose("head",Vector3(.3,0,.35*collapse))
		for side in ["L","R"]:
			pose("upperleg01_"+side,Vector3(-.5*sin(t*PI),0,0))
			pose("lowerleg01_"+side,Vector3(.9*sin(t*PI),0,0))
			pose("upperarm01_"+side,Vector3(-.2,0,(-.65 if side=="L" else .65)))
		if gun_cue: gun_cue.visible = armed
		for eye in eye_nodes: eye.visible = death_time<.3
		return
	gait = lerpf(gait,clampf(speed/.8,0,1),minf(1,dt*8))
	var stride = .62 if speed<2.6 else .96
	phase = fmod(phase+dt*speed*.58/stride,1)
	var run = clampf((speed-2.4)/2,0,1)
	var afraid = state==8
	skeleton.set_bone_pose_scale(bones["head"],Vector3(.88,1.18,.94) if role==2 else Vector3.ONE)
	pose("spine03",Vector3(.09+run*.12+hit*.20,0,sin(phase*TAU)*.025*gait))
	pose("spine01",Vector3(.05, sin(elapsed*.8)*.025,0))
	pose("neck01",Vector3(-.08,0,.03*sin(elapsed*1.7)))
	pose("head",Vector3(.03*sin(elapsed*2),sin(elapsed*.7)*.06,(.13 if role==2 else .04)+sin(elapsed*43)*hit*.16))
	for side in ["L","R"]:
		var sign_side = 1.0 if side=="L" else -1.0
		var cycle = fmod(phase+(0.5 if side=="R" else 0),1)
		var swing = maxf(0,(cycle-.58)/.42)
		var z = (stride*.5-stride*cycle/.58) if cycle<.58 else (-stride*.5+stride*smoothstep(0,1,swing))
		var foot = rest["foot_"+side]+Vector3(-sign_side*.04,sin(swing*PI)*(.13+run*.09)*gait,z*gait)
		var world_foot = to_global(foot)
		var ground_query = PhysicsRayQueryParameters3D.create(world_foot+Vector3.UP*.45,world_foot-Vector3.UP*.55,1)
		var ground = get_world_3d().direct_space_state.intersect_ray(ground_query)
		if not ground.is_empty():
			foot.y += clampf(ground.position.y-world_foot.y+.08*scale.y,-.23,.32)/scale.y
		solve_limb("upperleg01_"+side,"lowerleg01_"+side,"foot_"+side,foot,Vector3(0,0,1))
		var hand = Vector3(sign_side*.22,1.0+sin(elapsed*1.8)*.008,.08-sin(cycle*TAU)*.18*gait)
		if armed: hand = Vector3(sign_side*.11,1.28,.36 if side=="L" else .26)
		if afraid: hand = Vector3(sign_side*.32,1.5,.20)
		if state==4: hand += Vector3(sign_side*.06,.12,.15+sin(elapsed*8)*.025)
		if state==5: hand += Vector3(0,-.05,.1)
		hand += Vector3(0,hit*.05,-hit*.11)
		solve_limb("upperarm01_"+side,"lowerarm01_"+side,"wrist_"+side,hand,Vector3(sign_side,-.4,-.4),Quaternion.from_euler(Vector3(0.0 if armed else -.4,0,0)))
		bend_fingers(side,.0 if afraid else .65,armed)
	if gun_cue: gun_cue.visible = armed

func grip_pose(side: String, contact: Transform3D, curl: float, trigger: bool = false):
	# Grip anchors describe the palm, not the wrist. Follow the prop's full
	# orientation so recoil, ADS and lowering cannot detach the fingers.
	var local = skeleton.global_transform.affine_inverse()*contact
	var orientation = local.basis.orthonormalized()*palm_frames[side].inverse()
	var wrist = local.origin-orientation*palm_centres[side]
	# Viewmodel sleeves must continue below/behind the camera, rather than
	# exposing the cropped shoulder edge in the middle of the screen. Preserve
	# the anatomical forearm and hand; only the offscreen upper sleeve extends.
	var shoulder_world = get_parent().to_global(Vector3(.36 if side=="R" else -.36,-.60,.08))
	var shoulder = skeleton.to_local(shoulder_world)
	var forearm: float = rest["lowerarm01_"+side].distance_to(rest["wrist_"+side])
	var upper_length = maxf(rest["upperarm01_"+side].distance_to(rest["lowerarm01_"+side]),shoulder.distance_to(wrist)-forearm*.78)
	solve_limb("upperarm01_"+side,"lowerarm01_"+side,"wrist_"+side,wrist,
		Vector3(-1 if side=="R" else 1,-1,-.4),orientation.get_rotation_quaternion(),shoulder,upper_length)
	var axis: Vector3 = palm_frames[side].x
	for finger in range(1,6):
		for joint in range(1,4):
			var amount = curl*[0.0,.28,1.12,.82][joint]
			if trigger and finger==2: amount *= .38
			var q = Quaternion(axis,amount)
			if finger==1:
				q = Quaternion(palm_frames[side].z,(-.55 if side=="R" else .55)*curl)*Quaternion(axis,.25*curl)
			skeleton.set_bone_pose_rotation(bones["finger%d-%d_%s"%[finger,joint,side]],q)

func palm_position(side: String) -> Vector3:
	return skeleton.global_transform*skeleton.get_bone_global_pose(bones["wrist_"+side])*palm_centres[side]

func animate_grips(right: Transform3D, left: Transform3D, right_curl: float, left_curl: float):
	grip_pose("R",right,right_curl,true)
	grip_pose("L",left,left_curl)

func animate_body(dt: float, speed: float):
	phase += dt*speed*1.3
	for side in ["L","R"]:
		var cycle = phase+(PI if side=="R" else 0)
		var motion = clampf(speed/3,0,1)
		pose("upperleg01_"+side,Vector3(sin(cycle)*.28*motion,0,0))
		pose("lowerleg01_"+side,Vector3(maxf(0,-sin(cycle))*.44*motion,0,0))
