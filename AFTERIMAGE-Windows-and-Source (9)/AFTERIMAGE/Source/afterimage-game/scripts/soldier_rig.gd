class_name SoldierRig
extends Node3D
# The supplied soldier and animation files share their original bind skeleton.
# Locomotion stays in place: collision movement owns translation, never the clip.
const CLIPS = ["idle","aim","shoot","reload","walk","backward","left","right","run","hit","death","death_alt"]
const UPPER = ["B-spine","B-chest","B-neck","B-head","B-shoulder.L","B-shoulder.R","B-upperArm.L","B-upperArm.R","B-forearm.L","B-forearm.R","B-hand.L","B-hand.R","B-handProp.L","B-handProp.R"]
static var clips = {}
static var library: AnimationLibrary
var skeleton: Skeleton3D
var model: Node3D
var animator: AnimationPlayer
var material: ShaderMaterial
var bones = {}
var eyes: Array[Node3D] = []
var rifle: Node3D
var elapsed = 0.0
var death_time = 0.0
var hit_time = 0.0
var shot_time = -1.0
var current = ""
var motion_speed = 0.0
var dead_started = false
var foot_offsets = {"L":0.0,"R":0.0}
var recoil = 0.0
var recoil_velocity = 0.0
var aim_blend = 0.0
var muzzle_flash: MeshInstance3D
var muzzle_light: OmniLight3D
var flash_time = 0.0
var upper_tracks = {}
var weapon_local = Transform3D.IDENTITY

func find_type(n: Node, type_name: String):
	if n.is_class(type_name): return n
	for c in n.get_children():
		var found = find_type(c,type_name)
		if found: return found
	return null

func setup():
	model = load("res://assets/soldier/soldier.fbx").instantiate()
	add_child(model)
	skeleton = find_type(model,"Skeleton3D")
	var donor = load("res://assets/soldier/walk.fbx").instantiate()
	var donor_skeleton: Skeleton3D = find_type(donor,"Skeleton3D")
	# Prop sockets are exported only with the animations, so retain their bind transforms.
	for side in ["L","R"]:
		var name = "B-handProp."+side
		var i = skeleton.get_bone_count()
		skeleton.add_bone(name)
		skeleton.set_bone_parent(i,skeleton.find_bone("B-hand."+side))
		var transform = donor_skeleton.get_bone_rest(donor_skeleton.find_bone(name))
		skeleton.set_bone_rest(i,transform)
		skeleton.set_bone_pose_position(i,transform.origin)
		skeleton.set_bone_pose_rotation(i,transform.basis.get_rotation_quaternion())
	donor.free()
	for i in range(skeleton.get_bone_count()): bones[skeleton.get_bone_name(i)] = i
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/charcoal.gdshader")
	paint(model)
	animator = AnimationPlayer.new()
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	add_child(animator)
	if not library:
		library = AnimationLibrary.new()
		for name in CLIPS:
			var source = load("res://assets/soldier/"+name+".fbx").instantiate()
			var player: AnimationPlayer = find_type(source,"AnimationPlayer")
			var clip: Animation = player.get_animation(player.get_animation_list()[0]).duplicate(true)
			for t in range(clip.get_track_count()-1,-1,-1):
				var bone = String(clip.track_get_path(t)).get_slice(":",1)
				if not bones.has(bone): clip.remove_track(t)
				else: clip.track_set_path(t,NodePath(str(get_path_to(skeleton))+":"+bone))
			clip.loop_mode = Animation.LOOP_NONE if name in ["death","death_alt","hit","shoot","reload"] else Animation.LOOP_LINEAR
			clips[name] = clip
			library.add_animation(name,clip)
			source.free()
	animator.add_animation_library("",library)
	for name in CLIPS:
		upper_tracks[name] = []
		var clip: Animation = clips[name]
		for t in range(clip.get_track_count()):
			if clip.track_get_type(t)!=Animation.TYPE_ROTATION_3D: continue
			var bone = String(clip.track_get_path(t)).get_slice(":",1)
			if bone in UPPER or "Finger" in bone or "thumb" in bone or "pinky" in bone:
				upper_tracks[name].append(Vector2i(t,bones[bone]))
	var head = attach("B-head")
	var helmet = load("res://assets/soldier/helmet.fbx").instantiate()
	head.add_child(helmet)
	paint(helmet)
	var glow = StandardMaterial3D.new()
	glow.albedo_color = Color(.7,.66,.5)
	glow.emission_enabled = true
	glow.emission = Color(.7,.6,.38)
	glow.emission_energy_multiplier = 1.4
	for side in [-1,1]:
		var eye = MeshInstance3D.new()
		var shape = SphereMesh.new()
		shape.radius = .010
		shape.height = .012
		eye.mesh = shape
		eye.material_override = glow
		eye.position = Vector3(side*.035,.115,.160)
		head.add_child(eye)
		eyes.append(eye)
	rifle = load("res://assets/soldier/rifle.fbx").instantiate()
	# The pack's prop socket uses -X for the barrel; the FBX rifle uses +Z.
	weapon_local.basis = Basis(Vector3.UP,-PI/2).scaled(Vector3.ONE*.88)
	add_child(rifle)
	rifle.top_level = true
	var gunmetal = StandardMaterial3D.new()
	gunmetal.albedo_color = Color(.16,.18,.17)
	gunmetal.metallic = .55
	gunmetal.roughness = .48
	style_rifle(rifle,gunmetal)
	var muzzle = Marker3D.new()
	muzzle.position = Vector3(0,.025,.77)
	rifle.add_child(muzzle)
	muzzle_flash = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(.23,.23)
	muzzle_flash.mesh = quad
	var flash_mat = StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.albedo_texture = load("res://assets/particles/muzzle_01.png")
	flash_mat.albedo_color = Color(1,.65,.22)
	flash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	muzzle_flash.material_override = flash_mat
	muzzle_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle_flash.visible = false
	muzzle.add_child(muzzle_flash)
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color(1,.48,.16)
	muzzle_light.omni_range = 4.5
	muzzle_light.light_energy = 0
	muzzle_light.light_cull_mask = 1
	muzzle.add_child(muzzle_light)
	select("idle",0)
	animator.advance(0)

func style_rifle(n: Node, mat: Material):
	if n is MeshInstance3D:
		n.material_override = mat
		n.layers = 1
	for c in n.get_children(): style_rifle(c,mat)

func paint(n: Node):
	if n is MeshInstance3D:
		n.material_override = material
		n.layers = 1
	for c in n.get_children(): paint(c)

func attach(name: String) -> BoneAttachment3D:
	var socket = BoneAttachment3D.new()
	socket.bone_name = name
	skeleton.add_child(socket)
	return socket

func select(name: String, blend: float = .18):
	if current==name: return
	current = name
	animator.play(name,blend)

func fire():
	shot_time = 0.0
	recoil_velocity += 2.6
	flash_time = .065
	muzzle_flash.visible = true
	muzzle_light.light_energy = 1.0

func weapon_transform() -> Transform3D:
	# Read the current bone pose directly; BoneAttachment rendering can be a frame behind.
	var pose = skeleton.global_transform*skeleton.get_bone_global_pose(bones["B-handProp.R"])
	# Strip accumulated shear/nonuniform bone scaling from the firearm only.
	# Character proportions and animated hand positions remain intact.
	pose.basis = pose.basis.orthonormalized().scaled(Vector3.ONE*global_basis.get_scale().x)
	var local = weapon_local
	local.origin = -local.basis.z*recoil*.24
	return pose*local

func muzzle_position() -> Vector3: return weapon_transform()*Vector3(0,.025,.77)
func muzzle_direction() -> Vector3: return weapon_transform().basis.z.normalized()

func aim_at(target: Vector3, weight: float):
	if target==Vector3.INF or weight<=0: return
	# Rotating the shoulder also moves the muzzle. Refine the correction so the
	# final barrel line, rather than the previous muzzle position, meets the aim.
	for iteration in range(3):
		var transform = weapon_transform()
		var from = (skeleton.global_basis.inverse()*transform.basis.z).normalized()
		var to = (skeleton.global_basis.inverse()*(target-muzzle_position())).normalized()
		var correction = Quaternion(from,to)
		var angle = correction.get_angle()
		if angle>.85: correction = Quaternion.IDENTITY.slerp(correction,.85/angle)
		var chest: int = bones["B-chest"]
		var pose = skeleton.get_bone_global_pose(chest)
		pose.basis = Basis(Quaternion.IDENTITY.slerp(correction,weight))*pose.basis.orthonormalized()
		skeleton.set_bone_global_pose(chest,pose)

func upper_pose(name: String, time: float, weight: float):
	var clip: Animation = clips[name]
	for track in upper_tracks[name]:
		var i: int = track.y
		var target = clip.rotation_track_interpolate(track.x,clampf(time,0,clip.length))
		skeleton.set_bone_pose_rotation(i,skeleton.get_bone_pose_rotation(i).slerp(target,weight))

func update_pose(dt: float, world_velocity: Vector3, role: int, state: int, hit: float, dead: bool, armed: bool, target: Vector3 = Vector3.INF):
	dt = minf(dt,.05)
	elapsed += dt
	# Procedural IK must start from authored rest translations/scales each frame.
	for i in range(skeleton.get_bone_count()):
		skeleton.set_bone_pose_position(i,skeleton.get_bone_rest(i).origin)
		skeleton.set_bone_pose_scale(i,Vector3.ONE)
	rifle.visible = armed
	flash_time = maxf(0,flash_time-dt)
	muzzle_flash.visible = flash_time>0 and armed and not dead
	muzzle_light.light_energy = 1.0 if muzzle_flash.visible else 0.0
	recoil_velocity += (-recoil*130-recoil_velocity*20)*dt
	recoil = clampf(recoil+recoil_velocity*dt,0,.18)

	if dead:
		if not dead_started:
			dead_started = true
			animator.speed_scale = 1.0
			select("death_alt" if role%2 else "death",.10)
		death_time += dt
		animator.advance(dt)
		for eye in eyes: eye.visible = death_time<.2
		rifle.global_transform = weapon_transform()
		return
	var local = global_basis.inverse()*Vector3(world_velocity.x,0,world_velocity.z)
	var actual = Vector2(local.x,local.z).length()
	motion_speed = move_toward(motion_speed,actual,dt*9)
	var clip = "reload" if state==10 else "idle"
	if state!=10 and actual>.12 and motion_speed>.18:
		if motion_speed>2.35 and local.z>absf(local.x)*.55: clip = "run"
		elif absf(local.x)>absf(local.z)*1.2: clip = "left" if local.x>0 else "right"
		elif local.z<-.15: clip = "backward"
		else: clip = "walk"
	select(clip)
	var reference = 3.5 if clip=="run" else 1.45
	animator.speed_scale = clampf(actual/reference,.25,1.65) if clip not in ["idle","reload"] else 1.0
	animator.advance(dt)
	if armed and state!=10:
		aim_blend = move_toward(aim_blend,1.0 if state in [4,5,9] else .65,dt*6)
		var shooting = shot_time>=0 and shot_time<float(clips["shoot"].length)
		upper_pose("shoot" if shooting else "aim",shot_time if shooting else fmod(elapsed,float(clips["aim"].length)),aim_blend)
		var compensated = target
		if target!=Vector3.INF: compensated -= Vector3.UP*tan(recoil*.65)*muzzle_position().distance_to(target)
		aim_at(compensated,aim_blend)
		var chest: int = bones["B-chest"]
		var pose = skeleton.get_bone_global_pose(chest)
		pose.basis = Basis(Quaternion(Vector3.RIGHT,-recoil))*pose.basis.orthonormalized()
		skeleton.set_bone_global_pose(chest,pose)
	if shot_time>=0: shot_time += dt
	if hit>.8 and hit_time<=0: hit_time = float(clips["hit"].length)
	if hit_time>0:
		upper_pose("hit",float(clips["hit"].length)-hit_time,minf(1,hit_time*8)*.78)
		hit_time = maxf(0,hit_time-dt)
	if state==7:
		# Open, raised hands remain a readable surrender cue on the animated rig.
		for side in ["L","R"]:
			var i: int = bones["B-upperArm."+side]
			var rest_rotation = skeleton.get_bone_rest(i).basis.get_rotation_quaternion()
			skeleton.set_bone_pose_rotation(i,rest_rotation*Quaternion(Vector3.FORWARD,(-.7 if side=="L" else .7)))
			var elbow: int = bones["B-forearm."+side]
			skeleton.set_bone_pose_rotation(elbow,skeleton.get_bone_rest(elbow).basis.get_rotation_quaternion()*Quaternion(Vector3.RIGHT,-1.6))
	var head: int = bones["B-head"]
	skeleton.set_bone_pose_scale(head,Vector3(.92,1.12,.94) if role==2 else Vector3.ONE)
	ground_feet(dt)
	rifle.global_transform = weapon_transform()

func ground_feet(dt: float):
	# Small terrain corrections preserve the authored gait on stair ramps.
	for side in ["L","R"]:
		var upper: int = bones["B-thigh."+side]
		var lower: int = bones["B-shin."+side]
		var end: int = bones["B-foot."+side]
		var a = skeleton.get_bone_global_pose(upper)
		var b = skeleton.get_bone_global_pose(lower)
		var c = skeleton.get_bone_global_pose(end)
		var sole = skeleton.to_global(c.origin-Vector3(0,.12,0))
		var q = PhysicsRayQueryParameters3D.create(sole+Vector3.UP*.35,sole-Vector3.UP*.35,1)
		var hit = get_world_3d().direct_space_state.intersect_ray(q)
		var adjustment = 0.0
		if not hit.is_empty(): adjustment = clampf((hit.position.y-sole.y)/global_basis.y.length(),-.16,.20)
		# Never drag a lifted swing foot down into the floor.
		if adjustment<-.055: adjustment = 0
		foot_offsets[side] = lerpf(float(foot_offsets[side]),adjustment,minf(1,dt*18))
		var target = c.origin+Vector3.UP*float(foot_offsets[side])
		var first = a.origin.distance_to(b.origin)
		var second = b.origin.distance_to(c.origin)
		var delta = target-a.origin
		var length = clampf(delta.length(),.01,first+second-.001)
		var axis = delta.normalized()
		var pole = b.origin-a.origin
		pole = (pole-axis*pole.dot(axis)).normalized()
		if pole.length()<.1: pole = Vector3.FORWARD
		var along = (first*first-second*second+length*length)/(2*length)
		var knee = a.origin+axis*along+pole*sqrt(maxf(0,first*first-along*along))
		var tip = a.origin+axis*length
		var qa = Quaternion((b.origin-a.origin).normalized(),(knee-a.origin).normalized())
		var qb = Quaternion((c.origin-b.origin).normalized(),(tip-knee).normalized())
		skeleton.set_bone_global_pose(upper,Transform3D(Basis(qa)*a.basis,a.origin))
		skeleton.set_bone_global_pose(lower,Transform3D(Basis(qb)*b.basis,knee))
		skeleton.set_bone_global_pose(end,Transform3D(c.basis,tip))
